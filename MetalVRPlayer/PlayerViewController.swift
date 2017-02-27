//
//  PlayerViewController.swift
//  MetalVRPlayer
//
//  Created by 魏靖南 on 20/1/2017.
//  Copyright © 2017年 魏靖南. All rights reserved.
//

import UIKit
import SceneKit
import SpriteKit
import CoreMotion
import AVFoundation

class PlayerViewController: UIViewController {
    
    //MARK: - Property
    @IBOutlet weak var leftSceneView: SCNView!
    @IBOutlet weak var rightSceneView: SCNView!
    @IBOutlet weak var leftSceneWidth: NSLayoutConstraint!
    @IBOutlet weak var leftSceneHeight: NSLayoutConstraint!
    @IBOutlet weak var playerButton: UIButton!
    
    var scenes : [SCNScene]!
    var videoNodes : [SCNNode]!
    var videoSpriteKitNodes : [SKVideoNode]!
    var cameraNodes : [SCNNode]!
    var cameraRollNodes : [SCNNode]!
    var cameraPitchNodes : [SCNNode]!
    var cameraYawNodes : [SCNNode]!
    var motionManager : CMMotionManager?
    var recognizer : UITapGestureRecognizer?
    var panRecognizer : UIPanGestureRecognizer?
    
    var vrPlayer : VideoPlayer!
//    var player : AVPlayer!
    var currentAngleX : Float!
    var currentAngleY : Float!
    var oldY : Float!
    var oldX : Float!
    var progressObserver : AnyObject?
    var isStereo : Bool = false
    var hiddenButtons = false
    var cardboardViewOn = true
    
    //MARK: - Life circle
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.sceneViewConfig(isStereoOrNot: isStereo)
        
        motionManager                             = CMMotionManager()
        motionManager?.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager?.startDeviceMotionUpdates(using : CMAttitudeReferenceFrame.xArbitraryZVertical)
        
        recognizer                                = UITapGestureRecognizer(target : self, action : #selector(PlayerViewController.tapTheScreen))
        recognizer?.delegate                      = self
        view.addGestureRecognizer(recognizer!)
        
        panRecognizer                             = UIPanGestureRecognizer(target : self, action : #selector(PlayerViewController.panGesture(sender :)))
        panRecognizer?.delegate                   = self
        view.addGestureRecognizer(panRecognizer!)
        
        //Initialize position variable (for the panGesture)
        currentAngleX                             = 0
        currentAngleY                             = 0
        
        oldX                                      = 0
        oldY                                      = 0
        
        self.configPlayer(videoAddr: Bundle.main.url(forResource: "118", withExtension: "mp4")!.absoluteString)
        
        self.doPlayVideo()
        
        self.playerButton.isSelected = true
        
    }
    
    fileprivate func sceneViewConfig(isStereoOrNot : Bool) {
        
        self.leftSceneView.delegate  = self
        self.rightSceneView.delegate = self
        let camX : Float = 0.0
        let camY : Float = 0.0
        let camZ : Float = 0.0
        let zFar         = 50.0
        
        let leftCamera               = SCNCamera()
        let rightCamera              = SCNCamera()
        leftCamera.zFar              = zFar
        rightCamera.zFar             = zFar
        
        let leftCameraNode           = SCNNode()
        leftCameraNode.camera        = leftCamera
        let rightCameraNode          = SCNNode()
        rightCameraNode.camera       = rightCamera
        
        let scene1                   = SCNScene()
        
        let cameraNodeLeft           = SCNNode()
        let cameraRollNodeLeft       = SCNNode()
        let cameraPitchNodeLeft      = SCNNode()
        let cameraYawNodeLeft        = SCNNode()
        
        cameraNodeLeft.addChildNode(leftCameraNode)
        cameraNodeLeft.addChildNode(rightCameraNode)
        cameraRollNodeLeft.addChildNode(cameraNodeLeft)
        cameraPitchNodeLeft.addChildNode(cameraRollNodeLeft)
        cameraYawNodeLeft.addChildNode(cameraPitchNodeLeft)
        
        self.leftSceneView.scene = scene1
        
        if isStereo {
            let scene2               = SCNScene()
            let cameraNodeRight      = SCNNode()
            let cameraRollNodeRight  = SCNNode()
            let cameraPitchNodeRight = SCNNode()
            let cameraYawNodeRight   = SCNNode()
            
            scenes                   = [scene1, scene2]
            cameraNodes              = [cameraNodeLeft, cameraNodeRight]
            cameraRollNodes          = [cameraRollNodeLeft, cameraRollNodeRight]
            cameraPitchNodes         = [cameraPitchNodeLeft, cameraPitchNodeRight]
            cameraYawNodes           = [cameraYawNodeLeft, cameraYawNodeRight]
            
            rightSceneView?.scene = scene2
            leftCamera.xFov       = 80
            rightCamera.xFov      = 80
            leftCamera.yFov       = 80
            rightCamera.yFov      = 80
            
            cameraNodeRight.addChildNode(rightCameraNode)
            cameraRollNodeRight.addChildNode(cameraNodeRight)
            cameraPitchNodeRight.addChildNode(cameraRollNodeRight)
            cameraYawNodeRight.addChildNode(cameraPitchNodeRight)
            
        } else {
            let scene2               = SCNScene()
            let cameraNodeRight      = SCNNode()
            let cameraRollNodeRight  = SCNNode()
            let cameraPitchNodeRight = SCNNode()
            let cameraYawNodeRight   = SCNNode()
            
            scenes                = [scene1, scene2]
            cameraNodes           = [cameraNodeLeft, cameraNodeRight]
            cameraRollNodes       = [cameraRollNodeLeft, cameraRollNodeRight]
            cameraPitchNodes      = [cameraPitchNodeLeft, cameraPitchNodeRight]
            cameraYawNodes        = [cameraYawNodeLeft, cameraYawNodeRight]
            rightSceneView?.scene = scene2
            
        }
        
        leftCameraNode.position  = SCNVector3(x : camX - ((true == isStereo) ? 0.0  : 0.5), y : camY, z : camZ)
        rightCameraNode.position = SCNVector3(x : camX + ((true == isStereo) ? 0.0  : 0.5), y : camY, z : camZ)
        
        let camerasNodeAngles                     = getCamerasNodeAngle()
        
        for cameraNode in cameraNodes {
            cameraNode.position                   = SCNVector3(x                  : camX, y                  : camY, z                  : camZ)
            cameraNode.eulerAngles                = SCNVector3Make( Float(camerasNodeAngles[0]), Float(camerasNodeAngles[1]), Float(camerasNodeAngles[2]) )
        }
        
        if scenes.count == cameraYawNodes.count {
            
            for index in 0 ..< scenes.count {
                let scene                         = scenes[index]
                let cameraYawNode                 = cameraYawNodes[index]
                scene.rootNode.addChildNode(cameraYawNode)
            }
            
        }
        
        leftSceneView.pointOfView                 = leftCameraNode
        rightSceneView.pointOfView                = rightCameraNode
        
        leftSceneView.isPlaying                   = true
        rightSceneView.isPlaying                  = true
        
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let _ = leftSceneView, let _ = rightSceneView {
            displayIfNeededCardboardView()
        }
    }
    
    fileprivate func displayIfNeededCardboardView() {
        
        let width                 = (view.bounds.width > view.bounds.height) ? view.bounds.width : view.bounds.height;
        
        leftSceneWidth?.constant  = (true == cardboardViewOn) ? (width / 2.0) : 1
        leftSceneHeight?.constant = (true == cardboardViewOn) ? (width / 2.0) : 1
        leftSceneView.isHidden    = (false == cardboardViewOn)
        
        if UIInterfaceOrientationIsLandscape(.portrait) {
            
        } else {
            
        }
        
//        cardboardButton?.setImage(UIImage(named: (true == cardboardViewOn) ? "cardboardOn" : "cardboardOff"), for: UIControlState())
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getCamerasNodeAngle() -> [Double] {
        
        var camerasNodeAngle1 : Double! = 0.0
        var camerasNodeAngle2 : Double! = 0.0
        
        let orientation                = UIApplication.shared.statusBarOrientation.rawValue
        
        if orientation == 1 {
            camerasNodeAngle1          = -M_PI_2
        } else if orientation == 2 {
            camerasNodeAngle1          = M_PI_2
        } else if orientation == 3 {
            camerasNodeAngle1          = 0.0
            camerasNodeAngle2          = M_PI
        }
        
        return [ -M_PI_2, camerasNodeAngle1, camerasNodeAngle2]
        
    }
    
    // MARK: - Camera Orientation
    override func willAnimateRotation(to toInterfaceOrientation: UIInterfaceOrientation, duration: TimeInterval) {
       
        let cameraNodeAngles = getCamerasNodeAngle()
        
        leftSceneWidth?.isActive = (.portrait != toInterfaceOrientation && .portraitUpsideDown != toInterfaceOrientation)
        leftSceneHeight?.isActive = (.portrait == toInterfaceOrientation || .portraitUpsideDown == toInterfaceOrientation)
        
        for cameraNode in cameraNodes {
            cameraNode.eulerAngles = SCNVector3Make(Float(cameraNodeAngles[0]), Float(cameraNodeAngles[1]), Float(cameraNodeAngles[2]))
        }
        
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    @IBAction func touchToPlayPause(_ sender: Any) {
        
        self.doPlayVideo()
        self.playerButton.isSelected = !self.playerButton.isSelected
        
    }
    
    
    // MARK: - 释放资源
    deinit {
        motionManager?.stopDeviceMotionUpdates()
        motionManager = nil

    }

}

// MARK: - Player Controller
extension PlayerViewController : VideoPlayerDelegate {
    
    func configPlayer(videoAddr : String) -> Void {
        
        self.vrPlayer = VideoPlayer(url: URL(string: videoAddr)!)
//        self.player = AVPlayer(url: URL(fileURLWithPath: videoAddr))
        
        if let player = vrPlayer.player {
            let screenScale : CGFloat            = 3.0
            let videoSpriteKitNodeLeft           = SKVideoNode(avPlayer : player)
            let videoNodeLeft                    = SCNNode()
            let spriteKitScene1                  = SKScene(size : CGSize(width : 1280 * screenScale, height : 1280 * screenScale))
            spriteKitScene1.shouldRasterize      = true
            var spriteKitScenes                  = [spriteKitScene1]
            
            videoNodeLeft.geometry               = SCNSphere(radius : 30)
            spriteKitScene1.scaleMode            = .aspectFit
            videoSpriteKitNodeLeft.position      = CGPoint(x : spriteKitScene1.size.width / 2.0, y : spriteKitScene1.size.height / 2.0)
            videoSpriteKitNodeLeft.size          = spriteKitScene1.size
            
            if true == isStereo {
                let videoSpriteKitNodeRight      = SKVideoNode(avPlayer : player)
                let videoNodeRight               = SCNNode()
                let spriteKitScene2              = SKScene(size : CGSize(width : 1280 * screenScale, height : 1280 * screenScale))
                spriteKitScene2.shouldRasterize  = true
                
                videoSpriteKitNodes              = [videoSpriteKitNodeLeft, videoSpriteKitNodeRight]
                videoNodes                       = [videoNodeLeft, videoNodeRight]
                spriteKitScenes                  = [spriteKitScene1, spriteKitScene2]
                
                videoNodeRight.geometry          = SCNSphere(radius : 30)
                spriteKitScene2.scaleMode        = .aspectFit
                videoSpriteKitNodeRight.position = CGPoint(x : spriteKitScene1.size.width / 2.0, y : spriteKitScene1.size.height / 2.0)
                videoSpriteKitNodeRight.size     = spriteKitScene2.size
                
                let mask                         = SKShapeNode(rect : CGRect(x : 0, y : 0, width : spriteKitScene1.size.width, height : spriteKitScene1.size.width / 2.0))
                mask.fillColor                   = SKColor.black
                
                let cropNode                     = SKCropNode()
                cropNode.maskNode                = mask
                
                cropNode.addChild(videoSpriteKitNodeLeft)
                cropNode.yScale                  = 2
                cropNode.position                = CGPoint(x : 0, y : 0)
                
                let mask2                        = SKShapeNode(rect : CGRect(x : 0, y : spriteKitScene1.size.width / 2.0, width : spriteKitScene1.size.width,
                                                                             height : spriteKitScene1.size.width / 2.0))
                mask2.fillColor                  = SKColor.black
                let cropNode2                    = SKCropNode()
                cropNode2.maskNode               = mask2
                
                cropNode2.addChild(videoSpriteKitNodeRight)
                cropNode2.yScale                 = 2
                cropNode2.position               = CGPoint(x : 0, y : -spriteKitScene1.size.width)
                
                spriteKitScene1.addChild(cropNode2)
                spriteKitScene2.addChild(cropNode)
                
            } else {
                let videoSpriteKitNodeRight      = SKVideoNode(avPlayer : player)
                let videoNodeRight               = SCNNode()
                let spriteKitScene2              = SKScene(size : CGSize(width : 1280 * screenScale, height : 1280 * screenScale))
                spriteKitScene2.shouldRasterize  = true
                
                videoSpriteKitNodes              = [videoSpriteKitNodeLeft, videoSpriteKitNodeRight]
                videoNodes                       = [videoNodeLeft, videoNodeRight]
                spriteKitScenes                  = [spriteKitScene1, spriteKitScene2]
                
                videoNodeRight.geometry          = SCNSphere(radius : 30)
                spriteKitScene2.scaleMode        = .aspectFit
                videoSpriteKitNodeRight.position = CGPoint(x : spriteKitScene1.size.width / 2.0, y : spriteKitScene1.size.height / 2.0)
                videoSpriteKitNodeRight.size     = spriteKitScene2.size
                
                spriteKitScene1.addChild(videoSpriteKitNodeLeft)
                spriteKitScene2.addChild(videoSpriteKitNodeRight)
            }

            if videoNodes.count == spriteKitScenes.count && scenes.count == videoNodes.count {
                for i in 0 ..< videoNodes.count {
                    weak var spriteKitScene = spriteKitScenes[i]
                    let videoNode = videoNodes[i]
                    let scene = scenes[i]
                    
                    videoNode.geometry?.firstMaterial?.diffuse.contents = spriteKitScene
                    videoNode.geometry?.firstMaterial?.isDoubleSided = true
                    
                    // Flip video upside down, so that it's shown in the right position
                    var transform                                                = SCNMatrix4MakeRotation(Float(M_PI), 0.0, 0.0, 1.0)
                    transform                                                    = SCNMatrix4Translate(transform, 1.0, 1.0, 0.0)
                    
                    videoNode.pivot                                              = SCNMatrix4MakeRotation(Float(M_PI_2), 0.0, -1.0, 0.0)
                    videoNode.geometry?.firstMaterial?.diffuse.contentsTransform = transform
                    
                    videoNode.position                                           = SCNVector3(x : 0, y : 0, z : 0)
                    videoNode.position                                           = SCNVector3(x : 0, y : 0, z : 0)
                    
                    scene.rootNode.addChildNode(videoNode)
                }
            }
            
//            progressObserver = player.addPeriodicTimeObserver(forInterval: CMTimeMakeWithSeconds(0.1, Int32(NSEC_PER_SEC)), queue: nil, using: { (time:CMTime) in
//                //do sth
//            }) as AnyObject
            
        }
        
    }
    
    func doPlayVideo() -> Void {
//        self.vrPlayer.play()
        for videoNode in videoSpriteKitNodes {
            
            if self.playerButton.isSelected {
                self.vrPlayer.pause()
//                videoNode.pause()
                
            } else {
                self.vrPlayer.play()
//                videoNode.play()
                
            }
            
        }
        
    }
    
    func videoPlayerIsReadyToPlayVideo(player : VideoPlayer) -> Void {
        
    }
    
    func videoPlayerIsReadyDidReachEnd(player : VideoPlayer) -> Void {
        
    }
    
    func videoPlayerTimeDidChange(player : VideoPlayer, Duration duration:Float) -> Void {
        
    }
    
    func videoPlayerLoadedTimeRangeDidChange(player : VideoPlayer, Duration duration:Float) -> Void {
        
    }
    
    func videoPlayerPlaybackBufferEmpty(player : VideoPlayer) -> Void {
        
    }
    
    func videoPlayerPlaybackLikelyToKeepUp(player : VideoPlayer) -> Void {
        
    }
    
    func videoPlayerDidFailWithError(player : VideoPlayer, Error error:Error) -> Void {
        
    }

}

// MARK: - Gesture
extension PlayerViewController : UIGestureRecognizerDelegate {
    @objc fileprivate func tapTheScreen() -> Void {
        
        if hiddenButtons {
            
        } else {
            
        }
        
        hiddenButtons = !hiddenButtons
    }
    
    @objc fileprivate func panGesture(sender : UIPanGestureRecognizer) {
        
        let translation = sender.translation(in: sender.view)
        let protection : Float = 2.0
        
        if abs(Float(translation.x) - oldX) >= protection {
            let newAngleX = Float(translation.x) - oldX - protection
            currentAngleX = newAngleX / 100 + currentAngleX
            oldX = Float(translation.x)
        }
        
        if abs(Float(translation.y) - oldY) >= protection {
            let newAngleY = Float(translation.y) - oldY - protection
            currentAngleY = newAngleY / 100 + currentAngleY
            oldY = Float(translation.y)
        }
        
        if sender.state == .ended {
            oldX = 0
            oldY = 0
        }
        
    }
}

// MARK: - Render
extension PlayerViewController:SCNSceneRendererDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        
        DispatchQueue.main.async { [weak self] in
            
            if let weakSelf = self {
                
                if let mm = weakSelf.motionManager, let motion = mm.deviceMotion {
                    let currentAttitude = motion.attitude
                    var roll : Double = currentAttitude.roll
                    
                    if (UIApplication.shared.statusBarOrientation == .landscapeRight) {
                        roll = -1.0 * (-M_PI - roll)
                    }
                    
                    for cameraRollNode in weakSelf.cameraRollNodes {
                        cameraRollNode.eulerAngles.x = Float(roll) - weakSelf.currentAngleY
                    }
                    
                    for cameraPitchNode in weakSelf.cameraPitchNodes {
                        cameraPitchNode.eulerAngles.z = Float(currentAttitude.pitch)
                    }
                    
                    for cameraYawNode in weakSelf.cameraYawNodes {
                        cameraYawNode.eulerAngles.y = Float(currentAttitude.yaw) + weakSelf.currentAngleX
                    }
                    
                }
                
            }
            
        }
        
    }
    
}
