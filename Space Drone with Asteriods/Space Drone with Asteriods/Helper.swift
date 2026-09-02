//
//  Helper.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 9/2/26.
//

import Foundation
import SceneKit

extension CreatureMesh {
    static func animateShark(_ node: SCNNode, phase: Float) {
        // Simple tail wiggle
        for child in node.childNodes {
            if let cone = child.geometry as? SCNCone, abs(child.position.z) > 0.3 {
                child.eulerAngles.y = sin(phase * 2) * 0.3
            }
        }
    }
    static func makeShark() -> SCNNode {
        let root = SCNNode()
        // Body (elongated capsule)
        let body = SCNCapsule(capRadius: 0.13, height: 0.88)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 0.18, blue: 0.4, alpha: 1)
        body.firstMaterial?.emission.contents = UIColor(red: 0.18, green: 0.23, blue: 0.65, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.eulerAngles.x = .pi / 2
        root.addChildNode(bodyNode)
        // Dorsal fin
        let fin = SCNCone(topRadius: 0, bottomRadius: 0.07, height: 0.18)
        fin.firstMaterial?.diffuse.contents = UIColor.white
        let finNode = SCNNode(geometry: fin)
        finNode.position = SCNVector3(0, 0.19, 0.18)
        finNode.eulerAngles.x = .pi / 2
        root.addChildNode(finNode)
        // Tail fin
        let tail = SCNCone(topRadius: 0, bottomRadius: 0.08, height: 0.20)
        tail.firstMaterial?.diffuse.contents = UIColor(red: 0.22, green: 0.26, blue: 0.7, alpha: 1)
        let tailNode = SCNNode(geometry: tail)
        tailNode.position = SCNVector3(0, 0, -0.38)
        tailNode.eulerAngles.x = .pi / 2
        root.addChildNode(tailNode)
        // Eyes
        let eyeMat = UIColor.white
        for side: Float in [-1, 1] {
            let eye = SCNSphere(radius: 0.03)
            eye.firstMaterial?.diffuse.contents = eyeMat
            let e = SCNNode(geometry: eye)
            e.position = SCNVector3(side * 0.11, 0.08, 0.33)
            root.addChildNode(e)
        }
        return root
    }
}

