//
//  Asteroid.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit


/// Represents an asteroid entity in the game.
/// 
/// Note: Asteroid behaviors may vary depending on the current scene stage or section.
/// The update method is structured to allow conditional behavior based on the game section in the future.
final class Asteroid {
    var lateralAngle: Double
    var z: CGFloat
    var size: AsteroidSize
    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double
    var spin: Float = 0

    init(lateralAngle: Double, z: CGFloat, size: AsteroidSize,
         radialOffset: CGFloat = 0.55, radialVel: CGFloat = 0, angularVel: Double = 0) {
        self.lateralAngle = lateralAngle
        self.z = z
        self.size = size
        self.radialOffset = radialOffset
        self.radialVel = radialVel
        self.angularVel = angularVel
    }

    func update(dt: CGFloat, shipSpeed: CGFloat) {
        z -= shipSpeed * dt
        spin += Float(dt) * 1.2
        lateralAngle += angularVel * Double(dt)
        TubePhysics.integrateRadial(radialOffset: &radialOffset, radialVel: &radialVel,
                                    entityRadius: size.radius, dt: dt)
        TubePhysics.dampAgainstWall(radialOffset: radialOffset, radialVel: &radialVel,
                                    entityRadius: size.radius)
        angularVel *= 0.998
        radialVel *= 0.999
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * radialOffset)
        return SCNVector3(r * Float(cos(lateralAngle)), r * Float(sin(lateralAngle)), Float(z))
    }
}

