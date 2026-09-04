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

        // ============================================================
        // ALIEN SHARK
        //
        // Coordinate system:
        // +Z = shark head / forward
        // -Z = tail
        // +Y = up
        // +/-X = left / right
        // ============================================================


        // ============================================================
        // BODY
        // ============================================================

        let body = SCNCapsule(
            capRadius: 0.15,
            height: 1.05
        )

        body.firstMaterial?.diffuse.contents =
            UIColor(
                red: 1.0,
                green: 0.30,
                blue: 0.02,
                alpha: 1.0
            )

        body.firstMaterial?.emission.contents =
            UIColor(
                red: 0.45,
                green: 0.06,
                blue: 0.0,
                alpha: 1.0
            )

        body.firstMaterial?.roughness.contents = 0.28

        let bodyNode =
            SCNNode(geometry: body)

        bodyNode.eulerAngles.x =
            .pi / 2

        root.addChildNode(bodyNode)


        // ============================================================
        // ALIEN HEAD / SNOUT
        // ============================================================

        let head =
            SCNSphere(radius: 0.20)

        head.firstMaterial?.diffuse.contents =
            UIColor(
                red: 1.0,
                green: 0.42,
                blue: 0.02,
                alpha: 1.0
            )

        head.firstMaterial?.emission.contents =
            UIColor(
                red: 0.55,
                green: 0.10,
                blue: 0.0,
                alpha: 1.0
            )

        let headNode =
            SCNNode(geometry: head)

        headNode.position =
            SCNVector3(
                0,
                0,
                0.48
            )

        headNode.scale =
            SCNVector3(
                0.90,
                0.82,
                1.35
            )

        root.addChildNode(headNode)


        // ============================================================
        // GLOWING YELLOW ALIEN EYES
        // ============================================================

        let eyeMaterial =
            SCNMaterial()

        eyeMaterial.diffuse.contents =
            UIColor(
                red: 1.0,
                green: 0.90,
                blue: 0.05,
                alpha: 1.0
            )

        eyeMaterial.emission.contents =
            UIColor(
                red: 1.0,
                green: 0.65,
                blue: 0.0,
                alpha: 1.0
            )

        for side: Float in [-1, 1] {

            let eye =
                SCNSphere(radius: 0.055)

            eye.firstMaterial =
                eyeMaterial

            let eyeNode =
                SCNNode(geometry: eye)

            eyeNode.position =
                SCNVector3(
                    side * 0.145,
                    0.075,
                    0.48
                )

            root.addChildNode(eyeNode)
        }


        // ============================================================
        // SECONDARY YELLOW EYES
        // ============================================================

        let secondaryEyeMaterial =
            SCNMaterial()

        secondaryEyeMaterial.diffuse.contents =
            UIColor(
                red: 1.0,
                green: 0.75,
                blue: 0.05,
                alpha: 1.0
            )

        secondaryEyeMaterial.emission.contents =
            UIColor(
                red: 1.0,
                green: 0.45,
                blue: 0.0,
                alpha: 1.0
            )

        for side: Float in [-1, 1] {

            let eye =
                SCNSphere(radius: 0.025)

            eye.firstMaterial =
                secondaryEyeMaterial

            let eyeNode =
                SCNNode(geometry: eye)

            eyeNode.position =
                SCNVector3(
                    side * 0.105,
                    -0.045,
                    0.50
                )

            root.addChildNode(eyeNode)
        }


        // ============================================================
        // YELLOW / ORANGE FIN MATERIAL
        // ============================================================

        let dorsalMaterial =
            SCNMaterial()

        dorsalMaterial.diffuse.contents =
            UIColor(
                red: 1.0,
                green: 0.68,
                blue: 0.02,
                alpha: 1.0
            )

        dorsalMaterial.emission.contents =
            UIColor(
                red: 0.75,
                green: 0.25,
                blue: 0.0,
                alpha: 1.0
            )

        dorsalMaterial.roughness.contents =
            0.25


        // ============================================================
        // DORSAL FIN
        // ============================================================

        let dorsalFin =
            SCNCone(
                topRadius: 0.0,
                bottomRadius: 0.11,
                height: 0.30
            )

        dorsalFin.firstMaterial =
            dorsalMaterial

        let dorsalNode =
            SCNNode(
                geometry: dorsalFin
            )

        dorsalNode.position =
            SCNVector3(
                0,
                0.22,
                0.05
            )

        dorsalNode.eulerAngles.x =
            .pi / 2

        root.addChildNode(dorsalNode)


        // ============================================================
        // LEFT PECTORAL FIN
        // ============================================================

        let finLeft =
            SCNCone(
                topRadius: 0.0,
                bottomRadius: 0.065,
                height: 0.34
            )

        finLeft.firstMaterial =
            dorsalMaterial

        let finLeftNode =
            SCNNode(
                geometry: finLeft
            )

        finLeftNode.position =
            SCNVector3(
                -0.17,
                -0.02,
                0.12
            )

        finLeftNode.eulerAngles.z =
            -.pi / 2.4

        root.addChildNode(finLeftNode)


        // ============================================================
        // RIGHT PECTORAL FIN
        // ============================================================

        let finRight =
            SCNCone(
                topRadius: 0.0,
                bottomRadius: 0.065,
                height: 0.34
            )

        finRight.firstMaterial =
            dorsalMaterial

        let finRightNode =
            SCNNode(
                geometry: finRight
            )

        finRightNode.position =
            SCNVector3(
                0.17,
                -0.02,
                0.12
            )

        finRightNode.eulerAngles.z =
            .pi / 2.4

        root.addChildNode(finRightNode)


        // ============================================================
        // TAIL STEM
        // ============================================================

        let tailStem =
            SCNCylinder(
                radius: 0.075,
                height: 0.24
            )

        tailStem.firstMaterial =
            dorsalMaterial

        let tailStemNode =
            SCNNode(
                geometry: tailStem
            )

        tailStemNode.position =
            SCNVector3(
                0,
                0,
                -0.53
            )

        tailStemNode.eulerAngles.x =
            .pi / 2

        root.addChildNode(tailStemNode)


        // ============================================================
        // UPPER TAIL
        // ============================================================

        let upperTail =
            SCNCone(
                topRadius: 0.0,
                bottomRadius: 0.10,
                height: 0.27
            )

        upperTail.firstMaterial =
            dorsalMaterial

        let upperTailNode =
            SCNNode(
                geometry: upperTail
            )

        upperTailNode.position =
            SCNVector3(
                0,
                0.11,
                -0.68
            )

        upperTailNode.eulerAngles.x =
            .pi / 2

        root.addChildNode(upperTailNode)


        // ============================================================
        // LOWER TAIL
        // ============================================================

        let lowerTail =
            SCNCone(
                topRadius: 0.0,
                bottomRadius: 0.085,
                height: 0.23
            )

        lowerTail.firstMaterial =
            dorsalMaterial

        let lowerTailNode =
            SCNNode(
                geometry: lowerTail
            )

        lowerTailNode.position =
            SCNVector3(
                0,
                -0.11,
                -0.68
            )

        lowerTailNode.eulerAngles.x =
            -.pi / 2

        root.addChildNode(lowerTailNode)


        // ============================================================
        // ALIEN ORANGE/YELLOW GLOW STRIP
        // ============================================================

        let glowMaterial =
            SCNMaterial()

        glowMaterial.diffuse.contents =
            UIColor(
                red: 1.0,
                green: 0.85,
                blue: 0.05,
                alpha: 1.0
            )

        glowMaterial.emission.contents =
            UIColor(
                red: 1.0,
                green: 0.45,
                blue: 0.0,
                alpha: 1.0
            )

        let glow =
            SCNCylinder(
                radius: 0.025,
                height: 0.58
            )

        glow.firstMaterial =
            glowMaterial

        let glowNode =
            SCNNode(
                geometry: glow
            )

        glowNode.position =
            SCNVector3(
                0,
                0.135,
                -0.02
            )

        glowNode.eulerAngles.x =
            .pi / 2

        root.addChildNode(glowNode)


        // ============================================================
        // RETURN SHARK
        // ============================================================

        return root
    }
}

