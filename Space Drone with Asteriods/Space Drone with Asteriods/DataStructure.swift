//
//  DataStructure.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit



final class Shark: Identifiable {

    let id = UUID()

    // World-space position
    var position: SCNVector3

    // Rotation around the tunnel
    var lateralAngle: CGFloat

    // Animation phase
    var animPhase: Float

    // Destruction state
    var destroyed: Bool

    // Movement
    var forwardSpeed: CGFloat
    var lateralSpeed: CGFloat

    init(
        position: SCNVector3 = SCNVector3(0, 0, 20),
        lateralAngle: CGFloat = 0,
        animPhase: Float = 0,
        destroyed: Bool = false,
        forwardSpeed: CGFloat = 0,
        lateralSpeed: CGFloat = 0
    ) {
        self.position = position
        self.lateralAngle = lateralAngle
        self.animPhase = animPhase
        self.destroyed = destroyed
        self.forwardSpeed = forwardSpeed
        self.lateralSpeed = lateralSpeed
    }
}

enum CreatureMesh {
    /// Alien squid: mantle + glowing eye + trailing tentacles
    static func makeSquid() -> SCNNode {
        let root = SCNNode()

        // Mantle (head/body)
        let mantle = SCNSphere(radius: 0.22)
        mantle.segmentCount = 16
        mantle.firstMaterial?.diffuse.contents = UIColor(red: 0.45, green: 0.1, blue: 0.55, alpha: 1)
        mantle.firstMaterial?.emission.contents = UIColor(red: 0.35, green: 0.0, blue: 0.5, alpha: 1)
        let mantleNode = SCNNode(geometry: mantle)
        mantleNode.scale = SCNVector3(1.0, 1.15, 1.35)
        root.addChildNode(mantleNode)

        // Eye
        let eye = SCNSphere(radius: 0.07)
        eye.firstMaterial?.diffuse.contents = UIColor.cyan
        eye.firstMaterial?.emission.contents = UIColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1)
        let eyeNode = SCNNode(geometry: eye)
        eyeNode.position = SCNVector3(0, 0.06, 0.18)
        root.addChildNode(eyeNode)

        let pupil = SCNSphere(radius: 0.03)
        pupil.firstMaterial?.diffuse.contents = UIColor.black
        let pupilNode = SCNNode(geometry: pupil)
        pupilNode.position = SCNVector3(0, 0.06, 0.24)
        root.addChildNode(pupilNode)

        // Tentacles (behind body, along -Z)
        let tentacleCount = 6
        for i in 0..<tentacleCount {
            let angle = Float(i) / Float(tentacleCount) * Float.pi * 2
            let tent = SCNCylinder(radius: 0.035, height: 0.55)
            tent.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.15, blue: 0.7, alpha: 1)
            tent.firstMaterial?.emission.contents = UIColor(red: 0.25, green: 0.0, blue: 0.4, alpha: 1)
            let tNode = SCNNode(geometry: tent)
            tNode.name = "tentacle_\(i)"
            tNode.eulerAngles.x = .pi / 2
            tNode.position = SCNVector3(
                cos(angle) * 0.1,
                sin(angle) * 0.1,
                -0.35
            )
            // Slight outward splay
            tNode.eulerAngles.y = angle * 0.15
            root.addChildNode(tNode)
        }

        root.eulerAngles.x = 0
        return root
    }

    /// Deep-ocean alien fish: long body, fins, bioluminescent spots, forked tail
    static func makeDeepFish() -> SCNNode {
        let root = SCNNode()

        // Body
        let body = SCNCapsule(capRadius: 0.1, height: 0.55)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.05, green: 0.25, blue: 0.35, alpha: 1)
        body.firstMaterial?.emission.contents = UIColor(red: 0.0, green: 0.2, blue: 0.35, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.eulerAngles.z = .pi / 2 // long axis along Z
        bodyNode.eulerAngles.y = .pi / 2
        // Capsule height along Y; rotate so length is along Z
        bodyNode.eulerAngles = SCNVector3(Double.pi / 2, 0, 0)
        root.addChildNode(bodyNode)

        // Head bulb
        let head = SCNSphere(radius: 0.12)
        head.firstMaterial?.diffuse.contents = UIColor(red: 0.08, green: 0.3, blue: 0.4, alpha: 1)
        head.firstMaterial?.emission.contents = UIColor(red: 0.0, green: 0.35, blue: 0.45, alpha: 1)
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 0, 0.28)
        root.addChildNode(headNode)

        // Glowing lure (angler-style)
        let lureStem = SCNCylinder(radius: 0.015, height: 0.2)
        lureStem.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 0.4, blue: 0.5, alpha: 1)
        let stemNode = SCNNode(geometry: lureStem)
        stemNode.position = SCNVector3(0, 0.12, 0.32)
        stemNode.eulerAngles.x = -0.6
        root.addChildNode(stemNode)

        let lure = SCNSphere(radius: 0.045)
        lure.firstMaterial?.diffuse.contents = UIColor(red: 0.3, green: 1.0, blue: 0.7, alpha: 1)
        lure.firstMaterial?.emission.contents = UIColor(red: 0.2, green: 1.0, blue: 0.6, alpha: 1)
        let lureNode = SCNNode(geometry: lure)
        lureNode.name = "lure"
        lureNode.position = SCNVector3(0, 0.2, 0.38)
        root.addChildNode(lureNode)

        // Eyes
        let eyeMat = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        for side: Float in [-1, 1] {
            let eye = SCNSphere(radius: 0.035)
            eye.firstMaterial?.diffuse.contents = eyeMat
            eye.firstMaterial?.emission.contents = eyeMat
            let e = SCNNode(geometry: eye)
            e.position = SCNVector3(side * 0.08, 0.04, 0.32)
            root.addChildNode(e)
        }

        // Side fins
        for side: Float in [-1, 1] {
            let fin = SCNCone(topRadius: 0, bottomRadius: 0.08, height: 0.22)
            fin.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 0.45, blue: 0.55, alpha: 1)
            fin.firstMaterial?.emission.contents = UIColor(red: 0.0, green: 0.25, blue: 0.35, alpha: 1)
            let f = SCNNode(geometry: fin)
            f.name = side < 0 ? "finL" : "finR"
            f.position = SCNVector3(side * 0.14, 0, 0)
            f.eulerAngles.z = side * 0.9
            f.eulerAngles.x = .pi / 2
            root.addChildNode(f)
        }

        // Tail (forked via two cones)
        for side: Float in [-1, 1] {
            let tail = SCNCone(topRadius: 0, bottomRadius: 0.07, height: 0.2)
            tail.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 0.5, blue: 0.55, alpha: 1)
            let t = SCNNode(geometry: tail)
            t.name = "tail_\(side < 0 ? "L" : "R")"
            t.position = SCNVector3(side * 0.05, 0, -0.38)
            t.eulerAngles.x = .pi / 2
            t.eulerAngles.y = side * 0.45
            root.addChildNode(t)
        }

        // Bioluminescent spots
        for i in 0..<4 {
            let spot = SCNSphere(radius: 0.02)
            spot.firstMaterial?.emission.contents = UIColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1)
            spot.firstMaterial?.diffuse.contents = UIColor.cyan
            let s = SCNNode(geometry: spot)
            s.position = SCNVector3(0.06, 0, Float(i) * 0.1 - 0.1)
            root.addChildNode(s)
        }

        return root
    }

    static func animateSquid(_ node: SCNNode, phase: Float) {
        for child in node.childNodes {
            guard let name = child.name, name.hasPrefix("tentacle_") else { continue }
            let idx = Float(name.dropFirst("tentacle_".count)) ?? 0
            let wave = sin(phase + idx * 0.9) * 0.35
            child.eulerAngles.x = .pi / 2 + wave
            child.eulerAngles.z = wave * 0.4
        }
    }

    static func animateFish(_ node: SCNNode, phase: Float) {
        let sway = sin(phase) * 0.25
        if let finL = node.childNode(withName: "finL", recursively: false) {
            finL.eulerAngles.z = -0.9 + sway
        }
        if let finR = node.childNode(withName: "finR", recursively: false) {
            finR.eulerAngles.z = 0.9 - sway
        }
        for child in node.childNodes {
            if let name = child.name, name.hasPrefix("tail_") {
                child.eulerAngles.y = (name.hasSuffix("L") ? -0.45 : 0.45) + sway * 0.5
            }
        }
        if let lure = node.childNode(withName: "lure", recursively: false) {
            let pulse = 0.85 + 0.15 * sin(phase * 2)
            lure.scale = SCNVector3(pulse, pulse, pulse)
        }
    }
}

enum Tunnel {
    static let radius: CGFloat = 8.0
    static let segmentLength: CGFloat = 40.0
    static let segmentsAhead = 8
    static let segmentsBehind = 2
    static let shipRadialInset: CGFloat = 0.82
    static let minSpeed: CGFloat = 2.5
    static let maxSpeed: CGFloat = 16.0
    static let defaultSpeed: CGFloat = 6.0
    static let lateralSpeed: Double = 2.4
    static let speedAccel: CGFloat = 12.0
    static let minRadialOffset: CGFloat = 0.18
    static let wallRestitution: CGFloat = 0.72
}

// MARK: - Tube physics

enum TubePhysics {
    static func integrateRadial(
        radialOffset: inout CGFloat,
        radialVel: inout CGFloat,
        entityRadius: CGFloat,
        dt: CGFloat
    ) {
        radialOffset += radialVel * dt
        let maxOffset = max(Tunnel.minRadialOffset, 1.0 - entityRadius / Tunnel.radius)
        let minOffset = Tunnel.minRadialOffset
        if radialOffset >= maxOffset {
            radialOffset = maxOffset
            if radialVel > 0 { radialVel = -radialVel * Tunnel.wallRestitution }
        } else if radialOffset <= minOffset {
            radialOffset = minOffset
            if radialVel < 0 { radialVel = -radialVel * Tunnel.wallRestitution }
        }
    }

    static func dampAgainstWall(radialOffset: CGFloat, radialVel: inout CGFloat, entityRadius: CGFloat) {
        let maxOffset = max(Tunnel.minRadialOffset, 1.0 - entityRadius / Tunnel.radius)
        if radialOffset >= maxOffset - 0.02 && radialVel > 0 { radialVel *= 0.5 }
    }
}

// MARK: - Asteroid size

enum AsteroidSize {
    case small, medium, large
    var radius: CGFloat {
        switch self {
        case .small: return 0.55
        case .medium: return 0.85
        case .large: return 1.25
        }
    }
    var score: Int {
        switch self {
        case .small: return 50
        case .medium: return 75
        case .large: return 100
        }
    }
}


public extension SCNVector3 {
    static let up = SCNVector3(0, 1, 0)
    static let forward = SCNVector3(0, 0, -1)

    var length: Float {
        return sqrt(x * x + y * y + z * z)
    }
    func normalizedFunc() -> SCNVector3 {

          let length = sqrt(
              x * x +
              y * y +
              z * z
          )

          guard length > 0.000001 else {
              return SCNVector3(0, 0, -1)
          }

          return SCNVector3(
              x / length,
              y / length,
              z / length
          )
      }
    var normalized: SCNVector3 {
        let l = length
        guard l > 0.0001 else { return SCNVector3(0, 0, 0) }
        return SCNVector3(x / l, y / l, z / l)
    }
}
private protocol IdentifiableWrapper {
    var wrapperID: ObjectIdentifier { get }
}
