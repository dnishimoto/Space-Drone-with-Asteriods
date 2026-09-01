//
//  File.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit

final class FlockAlien {
    var lateralAngle: Double
    var z: CGFloat
    var destroyed = false
    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double
    var animPhase: Float
    let bodyRadius: CGFloat = 0.22

    init(lateralAngle: Double, z: CGFloat, radialOffset: CGFloat = 0.65,
         radialVel: CGFloat = 0, angularVel: Double = 0) {
        self.lateralAngle = lateralAngle
        self.z = z
        self.radialOffset = radialOffset
        self.radialVel = radialVel
        self.angularVel = angularVel
        self.animPhase = Float.random(in: 0...(Float.pi * 2))
    }

    func update(dt: CGFloat, shipSpeed: CGFloat, playerAngle: Double, neighbors: [FlockAlien], difficulty: Double = 1.0) {
        guard !destroyed else { return }
        z -= shipSpeed * dt * 1.05 * CGFloat(difficulty)
        animPhase += Float(dt) * 5.0

        var sep: Double = 0
        var cohesionAngle = 0.0
        var cohesionRadial: CGFloat = 0
        var count = 0

        for other in neighbors where other !== self && !other.destroyed {
            var d = lateralAngle - other.lateralAngle
            while d > .pi { d -= 2 * .pi }
            while d < -.pi { d += 2 * .pi }
            let angDist = abs(d)
            if angDist < 0.4 && abs(z - other.z) < 8 {
                if angDist < 0.22 { sep += (d > 0 ? 1.2 : -1.2) * difficulty }
                cohesionAngle += other.lateralAngle * difficulty
                cohesionRadial += other.radialOffset * CGFloat(difficulty)
                count += 1
            }
        }

        var seek = playerAngle - lateralAngle
        while seek > .pi { seek -= 2 * .pi }
        while seek < -.pi { seek += 2 * .pi }

        angularVel += (sep * 0.55 + seek * 0.35) * Double(dt) * difficulty
        if count > 0 {
            var avg = cohesionAngle / Double(count)
            var toCenter = avg - lateralAngle
            while toCenter > .pi { toCenter -= 2 * .pi }
            while toCenter < -.pi { toCenter += 2 * .pi }
            angularVel += toCenter * 0.25 * Double(dt) * difficulty
            radialVel += (cohesionRadial / CGFloat(count) - radialOffset) * 0.4 * dt * CGFloat(difficulty)
        }

        angularVel *= 0.93
        lateralAngle += angularVel * Double(dt)
        TubePhysics.integrateRadial(radialOffset: &radialOffset, radialVel: &radialVel,
                                    entityRadius: bodyRadius, dt: dt)
        radialVel *= 0.985
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * radialOffset)
        return SCNVector3(r * Float(cos(lateralAngle)), r * Float(sin(lateralAngle)), Float(z))
    }
}
