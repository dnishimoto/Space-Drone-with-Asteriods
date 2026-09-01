//
//  SwarmAlien.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit

final class SwarmAlien {
    var lateralAngle: Double
    var z: CGFloat
    var destroyed = false
    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double
    var animPhase: Float
    let bodyRadius: CGFloat = 0.32

    init(lateralAngle: Double, z: CGFloat, radialOffset: CGFloat = 0.7,
         radialVel: CGFloat = 0, angularVel: Double = 0) {
        self.lateralAngle = lateralAngle
        self.z = z
        self.radialOffset = radialOffset
        self.radialVel = radialVel
        self.angularVel = angularVel
        self.animPhase = Float.random(in: 0...(Float.pi * 2))
    }

    func update(dt: CGFloat, shipSpeed: CGFloat, playerAngle: Double, difficulty: Double = 1.0) {
        guard !destroyed else { return }
        z -= shipSpeed * dt * CGFloat(difficulty)
        animPhase += Float(dt) * 4.5 * Float(difficulty)

        var delta = playerAngle - lateralAngle
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        angularVel += delta * 1.1 * Double(dt) * difficulty
        angularVel *= pow(0.94, difficulty)
        lateralAngle += angularVel * Double(dt)

        radialVel += CGFloat.random(in: -0.15...0.15) * dt * CGFloat(difficulty)
        TubePhysics.integrateRadial(radialOffset: &radialOffset, radialVel: &radialVel,
                                    entityRadius: bodyRadius, dt: dt)
        radialVel *= pow(0.99, CGFloat(difficulty))
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * radialOffset)
        return SCNVector3(r * Float(cos(lateralAngle)), r * Float(sin(lateralAngle)), Float(z))
    }
}

