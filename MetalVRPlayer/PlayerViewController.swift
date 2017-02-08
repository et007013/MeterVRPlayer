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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.leftSceneView.delegate = self
        self.rightSceneView.delegate = self
        let camx : Float = 0.0
        let camY : Float = 0.0
        let camZ : Float = 0.0
        let zFar = 50.0
        
        let leftCamera = SCNCamera()
        let rightCamera = SCNCamera()
        leftCamera.zFar = zFar
        rightCamera.zFar = zFar
        
        let leftCameraNode = SCNNode()
        leftCameraNode.camera = leftCamera
        let rightCameraNode = SCNNode()
        rightCameraNode.camera = rightCamera
        
        let scene1 = SCNScene()
        
        let cameraNodeLeft = SCNNode()
        let cameraRollNodeLeft = SCNNode()
        let cameraPitchNodeLeft = SCNNode()
        let cameraYawNodeLeft = SCNNode()
        
        cameraNodeLeft.addChildNode(leftCameraNode)
        cameraNodeLeft.addChildNode(rightCameraNode)
        cameraRollNodeLeft.addChildNode(cameraNodeLeft)
        cameraPitchNodeLeft.addChildNode(cameraRollNodeLeft)
        cameraYawNodeLeft.addChildNode(cameraPitchNodeLeft)
        
        self.leftSceneView.scene = scene1
        
        if isStereo {
            let scene2 = SCNScene()
            let cameraNodeRight = SCNNode()
            let cameraRollNodeRight = SCNNode()
            let cameraPitchNodeRight = SCNNode()
            let cameraYawNodeRight = SCNNode()
            
            scenes = [scene1, scene2]
            cameraNodes = [cameraNodeLeft, cameraNodeRight]
            cameraRollNodes = [cameraRollNodeLeft, cameraRollNodeRight]
            cameraPitchNodes = [cameraPitchNodeLeft, cameraPitchNodeRight]
            cameraYawNodes = [cameraYawNodeLeft, cameraYawNodeRight]
            
            rightSceneView?.scene = scene2
            leftCamera.xFov = 80
            rightCamera.xFov = 80
            leftCamera.yFov = 80
            rightCamera.yFov = 80
            
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

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}

extension PlayerViewController:UIGestureRecognizerDelegate {
    
}

extension PlayerViewController:SCNSceneRendererDelegate {
    
}
