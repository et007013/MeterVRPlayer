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

class PlayerViewController: UIViewController {
    
    @IBOutlet weak var leftSceneView: SCNView!
    @IBOutlet weak var rightSceneView: SCNView!
    @IBOutlet weak var leftSceneWidth: NSLayoutConstraint!
    @IBOutlet weak var rightSceneWidth: NSLayoutConstraint!
    
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
    
    var vrPlayer : VideoPlayer?
    var currentAngleX : Float!
    var currentAngleY : Float!
    var oldY : Float!
    var oldX : Float!
    var progressObserver : AnyObject?
    var isStereo : Bool = false
    var hiddenButtons = false
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.leftSceneView.delegate  = self
        self.rightSceneView.delegate = self
        let camX : Float             = 0.0
        let camY : Float             = 0.0
        let camZ : Float             = 0.0
        let zFar                     = 50.0
        
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
            
            rightSceneView?.scene    = scene2
            leftCamera.xFov          = 80
            rightCamera.xFov         = 80
            leftCamera.yFov          = 80
            rightCamera.yFov         = 80
            
            cameraNodeRight.addChildNode(rightCameraNode)
            cameraRollNodeRight.addChildNode(cameraNodeRight)
            cameraPitchNodeRight.addChildNode(cameraRollNodeRight)
            cameraYawNodeRight.addChildNode(cameraPitchNodeRight)
            
        } else {
            scenes = [scene1]
            cameraNodes = [cameraNodeLeft]
            cameraRollNodes = [cameraRollNodeLeft]
            cameraPitchNodes = [cameraPitchNodeLeft]
            cameraYawNodes = [cameraYawNodeLeft]
            rightSceneView?.scene = scene1

        }
        
        leftCameraNode.position  = SCNVector3(x : camX + ((true  == isStereo) ? 0.0  : 0.5), y :camY, z :camZ)
        rightCameraNode.position = SCNVector3(x : camX + ((true == isStereo) ? 0.0  : 0.5), y : camY, z : camZ)
        
        let camerasNodeAngles    = getCamerasNodeAngle()
        
        for cameraNode in cameraNodes {
            cameraNode.position    = SCNVector3(x : camX, y : camY, z : camZ)
            cameraNode.eulerAngles = SCNVector3Make( Float(camerasNodeAngles[0]), Float(camerasNodeAngles[1]), Float(camerasNodeAngles[2]) )
        }

        if scenes.count == cameraYawNodes.count {
            
            for index in 0 ..< scenes.count {
                let scene         = scenes[index]
                let cameraYawNode = cameraYawNodes[index]
                scene.rootNode.addChildNode(cameraYawNode)
            }
            
        }
        
        leftSceneView.pointOfView = leftCameraNode
        rightSceneView.pointOfView = rightCameraNode
        
        leftSceneView.isPlaying = true
        rightSceneView.isPlaying = true
        
        motionManager = CMMotionManager()
        motionManager?.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager?.startDeviceMotionUpdates(using: CMAttitudeReferenceFrame.xArbitraryZVertical)
        
        recognizer = UITapGestureRecognizer(target: self, action: #selector(PlayerViewController.tapTheScreen))
        recognizer?.delegate = self
        view.addGestureRecognizer(recognizer!)
        
        panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(PlayerViewController.panGesture(sender:)))
        
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

    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    // MARK: - 释放资源
    deinit {
        
    }

}

// MARK: - Gesture
extension PlayerViewController:UIGestureRecognizerDelegate {
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
        
    }
    
}
