
//
//  Shark.swift
//  Space Drone with Asteriods
//

import Foundation
import SceneKit

final class Shark: Identifiable {

    let id = UUID()

    // ============================================================
    // WORLD-SPACE POSITION
    // ============================================================

    var position: SCNVector3

    // ============================================================
    // ROTATION AROUND THE OCEAN
    // ============================================================

    var lateralAngle: CGFloat

    // ============================================================
    // ANIMATION
    // ============================================================

    var animPhase: Float

    // ============================================================
    // DESTRUCTION STATE
    // ============================================================

    var destroyed: Bool

    // ============================================================
    // MOVEMENT
    // ============================================================

    var forwardSpeed: CGFloat
    var lateralSpeed: CGFloat
    var z: CGFloat

    // ============================================================
    // INITIALIZER
    // ============================================================

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

    // ============================================================
    // UPDATE
    // ============================================================

    func update(
        dt: CGFloat,
        shipSpeed: CGFloat,
        playerAngle: Double
    ) {

        guard !destroyed else {
            return
        }

        // ========================================================
        // MOVE FORWARD THROUGH THE OCEAN
        // ========================================================

        let relativeSpeed =
            forwardSpeed + shipSpeed

        position.z -=
            Float(relativeSpeed * dt)

        // ========================================================
        // MOVE AROUND THE OCEAN
        // ========================================================

        lateralAngle +=
            lateralSpeed * dt

        let twoPi =
            CGFloat.pi * 2.0

        // Keep angle within 0 ... 2π.

        while lateralAngle >= twoPi {
            lateralAngle -= twoPi
        }

        while lateralAngle < 0 {
            lateralAngle += twoPi
        }

        // ========================================================
        // STEER TOWARD PLAYER
        // ========================================================

        let targetAngle =
            CGFloat(playerAngle)

        var angleDifference =
            targetAngle - lateralAngle

        // Normalize angular difference to -π ... +π.

        while angleDifference > CGFloat.pi {
            angleDifference -= twoPi
        }

        while angleDifference < -CGFloat.pi {
            angleDifference += twoPi
        }

        let steeringStrength: CGFloat =
            0.65

        lateralAngle +=
            angleDifference *
            steeringStrength *
            dt

        // ========================================================
        // NORMALIZE ANGLE AGAIN
        // ========================================================

        while lateralAngle >= twoPi {
            lateralAngle -= twoPi
        }

        while lateralAngle < 0 {
            lateralAngle += twoPi
        }

        // ========================================================
        // PRESERVE RADIAL DISTANCE
        // ========================================================

        let radius = sqrt(
            position.x * position.x +
            position.y * position.y
        )

        // Radius is intentionally preserved here.
        // The shark's X/Y position is controlled by
        // SharkManager's hunting and ocean-boundary behavior.

        _ = radius

        // ========================================================
        // SWIMMING ANIMATION
        // ========================================================

        animPhase +=
            Float(dt * 6.0)

        if animPhase >= Float.pi * 2.0 {
            animPhase -= Float.pi * 2.0
        }
    }
}

