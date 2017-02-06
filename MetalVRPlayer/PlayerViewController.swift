//
//  PlayerViewController.swift
//  MetalVRPlayer
//
//  Created by 魏靖南 on 20/1/2017.
//  Copyright © 2017年 魏靖南. All rights reserved.
//

import UIKit
import SceneKit

class PlayerViewController: UIViewController {
    
    @IBOutlet weak var leftSceneView: SCNView!
    @IBOutlet weak var rightSceneView: SCNView!
    @IBOutlet weak var leftSceneWidth: NSLayoutConstraint!
    @IBOutlet weak var rightSceneWidth: NSLayoutConstraint!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
