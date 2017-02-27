//
//  VideoPlayer.swift
//  MetalVRPlayer
//
//  Created by 魏靖南 on 19/1/2017.
//  Copyright © 2017年 魏靖南. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion
import SpriteKit
import Foundation
import Darwin
import CoreGraphics

protocol VideoPlayerDelegate : NSObjectProtocol {

    func videoPlayerIsReadyToPlayVideo(player : VideoPlayer) -> Void
    func videoPlayerIsReadyDidReachEnd(player : VideoPlayer) -> Void
    func videoPlayerTimeDidChange(player : VideoPlayer, Duration duration:Float) -> Void
    func videoPlayerLoadedTimeRangeDidChange(player : VideoPlayer, Duration duration:Float) -> Void
    func videoPlayerPlaybackBufferEmpty(player : VideoPlayer) -> Void
    func videoPlayerPlaybackLikelyToKeepUp(player : VideoPlayer) -> Void
    func videoPlayerDidFailWithError(player : VideoPlayer, Error error:Error) -> Void
}

fileprivate var VideoPlayer_PlayerItermStatusContext                = "VideoPlayer_PlayerItermStatusContext"
fileprivate var VideoPlayer_PlayerExternalPlaybackActiveContext     = "VideoPlayer_PlayerExternalPlaybackActiveContext"
fileprivate var VideoPlayer_PlayerRateChangedContext                = "VideoPlayer_PlayerRateChangedContext"
fileprivate var VideoPlayer_PlayerItemPlaybackLikelyToKeepUpContext = "VideoPlayer_PlayerItemPlaybackLikelyToKeepUpContext"
fileprivate var VideoPlayer_PlayerItemPlaybackBufferEmptyContext    = "VideoPlayer_PlayerItemPlaybackBufferEmptyContext"
fileprivate var VideoPlayer_PlayerItemLoadedTimeRangesContext       = "VideoPlayer_PlayerItemLoadedTimeRangesContext"

fileprivate let DefaultPlayableBufferLength                         = 2.0
fileprivate let DefaultVolumeFadeDuration                           = 1.0
fileprivate let TimeObserverInterval                                = 0.01

fileprivate let VRPlayerQueue                                       = "com.gcwQueue.mMtalVRPlayer"

/// 播放器的错误类型
///
/// - kVideoPlayerErrorDomain: 针对的是unknown error
enum VideoPlayerError : Error {
    case kVideoPlayerErrorDomain(reson : String)
}

class VideoPlayer: NSObject {

    var asset : AVAsset?
    var playerItem : AVPlayerItem?
    var player : AVPlayer?
    var playerBufferLength = 0.0
    var volumeFadeDuration = 0.0
    //是否立体
    var isScrubbing        = false
    var seeking : Bool     = false
    /// 播放器代理
    var vpDelegate : VideoPlayerDelegate?
    
    //MARK : - 只读变量
    fileprivate(set) var playerIsPlaying : Bool = false
    fileprivate(set) var videoAddr : URL?
    
    fileprivate var isAtEndTime : Bool? {
        
        willSet {
            
        }
        
        didSet(oldVar) {
            
            if self.player == nil && self.player!.currentItem == nil {
                return self.isAtEndTime = oldVar
            }
            
            var currentTime = 0.0
            if CMTIME_IS_INVALID(self.player!.currentTime()) {
                currentTime = CMTimeGetSeconds(self.player!.currentTime())
            }
            
            var videoDuration = 0.0
            if CMTIME_IS_INVALID(self.player!.currentItem!.duration) {
                videoDuration = CMTimeGetSeconds(self.player!.currentItem!.duration)
            }
            
            if currentTime > 0.0 && videoDuration > 0.0 {
                
                if fabs(currentTime - videoDuration) < 0.001 {
                    self.isAtEndTime = true
                } else {
                    self.isAtEndTime = false
                }
                
            } else {
                self.isAtEndTime = false
            }
            
        }
    }
    
    
    /// 初始化韩式
    ///
    /// - Parameter url: 播放视频的地址,不能为空
    init(url : URL) {
        
        videoAddr  = url
        asset      = AVAsset(url: videoAddr!)
        playerItem = AVPlayerItem(asset: asset!)
        player     = AVPlayer(playerItem: playerItem)
        self.isAtEndTime = false
        
        super.init()
        
        self.setupPlayer()
        self.addPlayerObservers()
        self.setupAudioSession()
    }
    
    
    deinit {
        
        self.resetPlayerItemIfNecessary()
        self.removePlayerObservers()
        
    }
    
}

//MARK: - Player Controll function
extension VideoPlayer {
    
    func setUrl(urlAddr : String?) -> Void {
        
        if urlAddr == nil {
            return
        }
        
        self.videoAddr = URL(string: urlAddr!)
        self.resetPlayerItemIfNecessary()
        let avIterm : AVPlayerItem? = AVPlayerItem(url: self.videoAddr!)
        
        if avIterm == nil {
            self.reportUnableToCreatePlayerItem()
        }
        
    }
    
    func play() -> Void {
        
        if self.player!.currentItem == nil {
            return
        }
        
        self.playerIsPlaying = true
        
        if self.player!.currentItem!.status == .readyToPlay {
            
            if self.isAtEndTime! {
                self.reStart()
            } else {
                self.player?.play()
            }
            
        }
        
    }
    
    func pause() -> Void {
        self.playerIsPlaying = false
        self.player?.pause()
    }
    
    func reStart() -> Void {
        self.player?.seek(to: kCMTimeZero, toleranceBefore: kCMTimeZero, toleranceAfter: kCMTimeZero, completionHandler: { [weak self] (finish:Bool) in
            let weakSelf = self
            if finish {
                weakSelf?.isAtEndTime = false
                if weakSelf!.playerIsPlaying {
                    weakSelf?.play()
                }
            }
            
        })
    }
    
    func seekToTime(time:Float) -> Void {
        if self.seeking {
            return
        }
        
        if self.player != nil {
            let cmTime = CMTimeMakeWithSeconds(Float64(time), self.player!.currentTime().timescale)
            
            if CMTIME_IS_INVALID(cmTime) || self.player!.currentItem!.status == .readyToPlay {
                return
            }
            
            self.seeking = true
            
            DispatchQueue(label: VRPlayerQueue, qos: DispatchQoS.default).async(execute: {
                self.player?.seek(to: cmTime, completionHandler: { (finish:Bool) in
                    self.isAtEndTime = false
                    self.seeking = false
                    
                    if finish {
                        self.isScrubbing = false
                    }
                    
                })
                
            })
            
        }
        
    }
    
    func resetPlayer() -> Void {
        self.player?.pause()
        self.resetPlayerItemIfNecessary()
    }
    
    func calcLoadedDuration() -> Float {
        var loadedDuration : Float = 0.0
        
        if self.player != nil && self.player!.currentItem != nil {
            let loadedTimeRanges : [NSValue]? = self.player!.currentItem!.loadedTimeRanges
            
            if loadedTimeRanges != nil && loadedTimeRanges!.count > 0 {
                let timeRange   = loadedTimeRanges!.first!.timeRangeValue
                let startSec    = CMTimeGetSeconds(timeRange.start)
                let durationSec = CMTimeGetSeconds(timeRange.duration)
                
                loadedDuration  = Float(startSec + durationSec)
            }
            
        }
        
        return loadedDuration
        
    }
    
    //MARK:- Private function
    fileprivate func reportUnableToCreatePlayerItem() -> Void {
        
        if self.vpDelegate != nil && self.vpDelegate!.responds(to: Selector(("videoPlayerDidFailWithError:"))) {
            let error = VideoPlayerError.kVideoPlayerErrorDomain(reson: "Unable to create AVPlayerItem.")
            self.vpDelegate?.videoPlayerDidFailWithError(player: self, Error: error)
        }
        
    }
    
    fileprivate func setupPlayer() {
        
        if player != nil {
            self.player!.isMuted = false
        }
    }
    
    fileprivate func setupAudioSession() {
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch let error {
            
            print("error is \(error.localizedDescription)")
            
        }
        
    }
    
    fileprivate func resetPlayerItemIfNecessary() {
        
        if self.playerItem != nil {
            self.removeAVPlayerItemObservers(curPlayerItem: self.playerItem!)
            self.player?.replaceCurrentItem(with: nil)
            self.playerItem = nil
        }
        
        self.playerIsPlaying    = false
        self.playerBufferLength = DefaultPlayableBufferLength
        self.volumeFadeDuration = DefaultVolumeFadeDuration
    }
    
    @objc fileprivate func playerItemDidPlayToEndTime(nofication : Notification) {
        //TODO: to write code
        if #available(iOS 10.0, *) {
            if (nofication.object as! UIAccessibilityCustomRotorItemResult) != self.player!.currentItem {
                return
            }
        } else {
            // Fallback on earlier versions
        }
        
        self.isAtEndTime = true
        self.playerIsPlaying = false
        
        if self.vpDelegate != nil && self.vpDelegate!.responds(to: Selector(("videoPlayerIsReadyDidReachEnd:"))) {
            self.vpDelegate?.videoPlayerIsReadyDidReachEnd(player: self)
        }
        
    }
}

//KVO设置
extension VideoPlayer {
    //设置Video Player的KVO
    func addPlayerObservers() -> Void {
        
        self.player!.addObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayer.isExternalPlaybackActive)),
                                 options: .new, context: &VideoPlayer_PlayerExternalPlaybackActiveContext)
        
        self.player!.addObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayer.rate)),
                                 options: [.initial, .new], context: &VideoPlayer_PlayerRateChangedContext)
        
    }
    
    func removePlayerObservers() -> Void {
        self.player!.removeObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayer.isExternalPlaybackActive)),
                                    context: &VideoPlayer_PlayerExternalPlaybackActiveContext)
        self.player!.removeObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayer.rate)),
                                    context: &VideoPlayer_PlayerRateChangedContext)
    }

    
    //设置AVPlayer的KVO
    func addAVPlayerItemObservers(curPlayerItem : AVPlayerItem) -> Void {
        
        curPlayerItem.addObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayerItem.status)),
                                     options: [.initial, .new, .old], context: &VideoPlayer_PlayerItermStatusContext)
        
        curPlayerItem.addObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayerItem.isPlaybackLikelyToKeepUp)),
                                     options: [.initial, .new], context: &VideoPlayer_PlayerItemPlaybackLikelyToKeepUpContext)
        
        curPlayerItem.addObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayerItem.isPlaybackBufferEmpty)),
                                     options: [.initial, .new], context: &VideoPlayer_PlayerItemPlaybackBufferEmptyContext)
        
        curPlayerItem.addObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayerItem.loadedTimeRanges)),
                                     options: [.initial, .new], context: &VideoPlayer_PlayerItemLoadedTimeRangesContext)
        
        NotificationCenter.default.addObserver(self, selector: #selector(VideoPlayer.playerItemDidPlayToEndTime(nofication:)), name: .AVPlayerItemDidPlayToEndTime, object: curPlayerItem)
        
    }
    
    func removeAVPlayerItemObservers(curPlayerItem : AVPlayerItem) -> Void {
        
        curPlayerItem.cancelPendingSeeks()
        
        curPlayerItem.removeObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayerItem.status)), context: &VideoPlayer_PlayerItermStatusContext)
        
        curPlayerItem.removeObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayerItem.isPlaybackLikelyToKeepUp)), context: &VideoPlayer_PlayerItemPlaybackLikelyToKeepUpContext)
        
        curPlayerItem.removeObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayerItem.isPlaybackBufferEmpty)), context: &VideoPlayer_PlayerItemPlaybackBufferEmptyContext)
        
        curPlayerItem.removeObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: AVPlayerItem.loadedTimeRanges)), context: &VideoPlayer_PlayerItemLoadedTimeRangesContext)
        
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: curPlayerItem)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if (context == &VideoPlayer_PlayerRateChangedContext) {
            
            if !self.isScrubbing && self.playerIsPlaying && abs(self.player!.rate - 0.0) < 0.001 {
                //TODO: Show loading indicator
            }
            
        } else if (context == &VideoPlayer_PlayerItermStatusContext) {
            
            let newStatus : AVPlayerStatus = change![NSKeyValueChangeKey.newKey] as! AVPlayerStatus
            let oldStatus : AVPlayerStatus = change![NSKeyValueChangeKey.oldKey] as! AVPlayerStatus
            
            if newStatus != oldStatus {
                
                switch newStatus {
                    
                case .unknown:
                    break
                    
                case .readyToPlay:
                    
                    if self.vpDelegate != nil && self.vpDelegate!.responds(to: Selector(("videoPlayerIsReadyToPlayVideo:"))) {
                        
                        DispatchQueue.main.async(execute: { 
                            self.vpDelegate!.videoPlayerIsReadyToPlayVideo(player: self)
                        })
                    }
                    
                    break
                    
                case .failed:
                    
                    var playerError : Error? = nil
                    
                    if let error = self.player!.error {
                        
                        playerError = error
                        
                    } else {
                        
                        let error = VideoPlayerError.kVideoPlayerErrorDomain(reson: "unknown player error, status == AVPlayerItemStatusFailed")
                        
                        playerError = error
                    }
                    
                    self.resetPlayer()
                    
                    if self.vpDelegate != nil && self.vpDelegate!.responds(to: Selector(("videoPlayerDidFailWithError:"))) {
                        self.vpDelegate?.videoPlayerDidFailWithError(player: self, Error: playerError!)
                    }
                    
                    break
                    
                }
                
            } else if (newStatus == .readyToPlay) {
                // When playback resumes after a buffering event, a new ReadyToPlay status is set [RH]
                if self.vpDelegate != nil && self.vpDelegate!.responds(to: Selector(("videoPlayerPlaybackLikelyToKeepUp:"))) {
                    
                    DispatchQueue.main.async(execute: {
                        self.vpDelegate?.videoPlayerPlaybackLikelyToKeepUp(player: self)
                    })
                    
                }
            }
            
        } else if (context == &VideoPlayer_PlayerItemPlaybackBufferEmptyContext) {
            
            if self.player!.currentItem!.isPlaybackBufferEmpty {
                
                if self.playerIsPlaying {
                    DispatchQueue.main.async(execute: { 
                        if self.vpDelegate != nil && self.vpDelegate!.responds(to: Selector(("videoPlayerPlaybackBufferEmpty"))) {
                            self.vpDelegate!.videoPlayerPlaybackBufferEmpty(player: self)
                        }
                    })
                }
                
            }
            
        } else if (context == &VideoPlayer_PlayerItemPlaybackLikelyToKeepUpContext) {
            
            if self.player!.currentItem!.isPlaybackLikelyToKeepUp {
                
                // TODO: Hide loading indicator
                if !self.isScrubbing && self.playerIsPlaying && self.player!.rate == 0.0  {
                    self.play()
                }
                
            }
            
        } else if (context == &VideoPlayer_PlayerItemLoadedTimeRangesContext) {
            
            let loadedDuration = self.calcLoadedDuration()
            
            if !self.isScrubbing && self.playerIsPlaying && self.player!.rate == 0.0 {
                
                if loadedDuration >= Float(CMTimeGetSeconds(self.player!.currentTime()) + self.playerBufferLength) {
                    self.playerBufferLength *= 2
                    
                    if self.playerBufferLength > 64 {
                        self.playerBufferLength = 64
                    }
                    
                    self.play()
                }
                
            }
            
            if self.vpDelegate != nil && self.vpDelegate!.responds(to: Selector(("videoPlayerLoadedTimeRangeDidChange:"))) {
                self.vpDelegate!.videoPlayerTimeDidChange(player: self, Duration: loadedDuration)
            }
            
        } else if (context == &VideoPlayer_PlayerExternalPlaybackActiveContext) {
        
        
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
}
