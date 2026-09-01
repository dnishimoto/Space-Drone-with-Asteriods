//
//  EnemyShip.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//
import Foundation
import SceneKit

final class EnemySpaceShip {
    var lateralAngle: Double
    var z: CGFloat
    var destroyed = false
    var shootCooldown: CGFloat = 1.5

    init(
        lateralAngle: Double,
        playerZ: CGFloat,
        spawnDistance: CGFloat = 35.0
    ) {
        self.lateralAngle = lateralAngle
        self.z = playerZ + spawnDistance
    }

    func update(
        dt: CGFloat,
        shipSpeed: CGFloat,
        playerAngle: Double
    ) {
        guard !destroyed else { return }

        // Enemy approaches the player along the tunnel axis.
        z -= shipSpeed * dt * 0.85

        var delta = playerAngle - lateralAngle

        while delta > .pi {
            delta -= 2.0 * .pi
        }

        while delta < -.pi {
            delta += 2.0 * .pi
        }

        lateralAngle += delta * 0.6 * Double(dt)
        shootCooldown -= dt
    }

    var position: SCNVector3 {
        let radius = Float(Tunnel.radius * Tunnel.shipRadialInset)

        return SCNVector3(
            radius * Float(cos(lateralAngle)),
            radius * Float(sin(lateralAngle)),
            Float(z)
        )
    }
}
