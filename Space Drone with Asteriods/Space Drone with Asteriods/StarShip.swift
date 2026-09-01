//
//  StarShip.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit

struct SpaceShip {

    // ------------------------------------------------------------
    // WORLD POSITION
    // ------------------------------------------------------------

    var position: SCNVector3 = SCNVector3(
        0,
        0,
        0
    )

    // ------------------------------------------------------------
    // TUNNEL POSITION
    // ------------------------------------------------------------

    var lateralAngle: Double = 0.0

    /// Vertical position inside the tunnel.
    /// Negative = down
    /// Positive = up
    var verticalPosition: CGFloat = 0.0

    /// Radial distance from the tunnel axis.
    var radialOffset: CGFloat = Tunnel.shipRadialInset

    // ------------------------------------------------------------
    // INPUT
    // ------------------------------------------------------------

    var lateralInput: Double = 0.0
    var verticalInput: Double = 0.0

    // ------------------------------------------------------------
    // MOVEMENT
    // ------------------------------------------------------------

    var forwardSpeed: CGFloat = 12.0

    var z: CGFloat = 0.0

    var progress: CGFloat = 0.0

      mutating func update(dt: CGFloat) {

        let lateralSpeed: CGFloat = 1.8
        let verticalSpeed: CGFloat = 6.0

        // ============================================================
        // LEFT / RIGHT
        // ============================================================

        lateralAngle +=
            lateralInput *
            Double(lateralSpeed * dt)

        lateralAngle.formTruncatingRemainder(
            dividingBy: 2.0 * Double.pi
        )

        if lateralAngle < 0 {
            lateralAngle += 2.0 * Double.pi
        }

        // ============================================================
        // UP / DOWN
        //
        // Y is the vertical direction.
        //
        // Keep the CENTER of the ship away from the tube ceiling
        // and floor so the ship itself remains inside the tube.
        // ============================================================

        verticalPosition +=
            verticalInput *
            verticalSpeed *
            dt

        // Clearance between the ship and tube wall.
        let shipClearance: CGFloat = 0.55
        let tubeRadius = Tunnel.radius - shipClearance
        let x = tubeRadius * CGFloat(cos(lateralAngle)) * radialOffset
        let yLimit = sqrt(max(0, tubeRadius * tubeRadius - x * x))
        verticalPosition = max(-yLimit, min(yLimit, verticalPosition))

        // ============================================================
        // FORWARD MOVEMENT
        // ============================================================

        z += forwardSpeed * dt

        progress += forwardSpeed * dt

        // ============================================================
        // CALCULATE WORLD POSITION
        // ============================================================

        let worldRadius = Tunnel.radius * radialOffset
        let worldX = worldRadius * CGFloat(cos(lateralAngle))

        let y =
            verticalPosition

        // ============================================================
        // AUTHORITATIVE POSITION
        // ============================================================

        position = SCNVector3(
            Float(worldX),
            Float(y),
            Float(z)
        )
    }

}

