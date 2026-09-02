//
//  Shark.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 9/2/26.
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
    
    var z: CGFloat
    

    init(
        position: SCNVector3 = SCNVector3(0, 0, 20),
        lateralAngle: CGFloat = 0,
        animPhase: Float = 0,
        destroyed: Bool = false,
        forwardSpeed: CGFloat = 0,
        lateralSpeed: CGFloat = 0,
        z: CGFloat = 0
    ) {
        self.position = position
        self.lateralAngle = lateralAngle
        self.animPhase = animPhase
        self.destroyed = destroyed
        self.forwardSpeed = forwardSpeed
        self.lateralSpeed = lateralSpeed
        self.z = z
    }

    // MARK: - Update

    func update(
        dt: CGFloat,
        shipSpeed: CGFloat,
        playerAngle: Double
    ) {
        guard !destroyed else {
            return
        }

        // Move forward through the ocean relative to the player's ship.
        let relativeSpeed = forwardSpeed + shipSpeed

        position.z -=
            Float(relativeSpeed * dt)

        // Move around the tunnel/ocean circumference.
        lateralAngle +=
            lateralSpeed * dt

        let twoPi = CGFloat.pi * 2.0

        // Keep the angle within 0 ... 2π.
        while lateralAngle >= twoPi {
            lateralAngle -= twoPi
        }

        while lateralAngle < 0 {
            lateralAngle += twoPi
        }

        // Gently steer toward the player's lateral position.
        let targetAngle = CGFloat(playerAngle)

        var angleDifference =
            targetAngle - lateralAngle

        // Normalize angular difference to -π ... +π.
        while angleDifference > CGFloat.pi {
            angleDifference -= twoPi
        }

        while angleDifference < -CGFloat.pi {
            angleDifference += twoPi
        }

        let steeringStrength: CGFloat = 0.65

        lateralAngle +=
            angleDifference *
            steeringStrength *
            dt

        // Normalize again after steering.
        while lateralAngle >= twoPi {
            lateralAngle -= twoPi
        }

        while lateralAngle < 0 {
            lateralAngle += twoPi
        }

        // Preserve the shark's current radial distance.
        let radius = sqrt(
            position.x * position.x +
            position.y * position.y
        )

        // Update swimming animation.
        animPhase += Float(dt * 6.0)

        if animPhase >= Float.pi * 2.0 {
            animPhase -= Float.pi * 2.0
        }
    }
}
