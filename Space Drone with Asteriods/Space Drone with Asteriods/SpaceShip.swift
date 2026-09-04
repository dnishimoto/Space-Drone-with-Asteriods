//
//  StarShip.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit

struct SpaceShip {
    private let oceanMinimumX: CGFloat = -45.0
    private let oceanMaximumX: CGFloat = 45.0
    private let oceanSurfaceY: CGFloat = -16.0
    private let cloudCeilingY: CGFloat = 42.0
    private let oceanShipClearance: CGFloat = 1.5
    
    var position: SCNVector3 = SCNVector3(
        0,
        0,
        0
    )
    var lateralAngle: Double = 0.0
    var verticalPosition: CGFloat = 0.0
    var radialOffset: CGFloat = Tunnel.shipRadialInset
    var oceanX: CGFloat = 0.0
    var oceanY: CGFloat = 0.0
    var lateralInput: Double = 0.0
    var verticalInput: Double = 0.0
    var forwardSpeed: CGFloat = 12.0
    var z: CGFloat = 0.0
    var progress: CGFloat = 0.0

   
      /// This method contains NO ocean logic.
    mutating func updateTunnel(dt: CGFloat) {

        let lateralSpeed: CGFloat = 1.8
        let verticalSpeed: CGFloat = 6.0

        // ============================================================
        // LEFT / RIGHT AROUND THE TUNNEL
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
        // ============================================================

        verticalPosition +=
            verticalInput *
            verticalSpeed *
            dt

        // ============================================================
        // TUNNEL BOUNDARY
        //
        // The ship must remain inside the cylindrical tunnel.
        // ============================================================

        let shipClearance: CGFloat = 0.55

        let maximumRadius =
            max(
                0.0,
                Tunnel.radius - shipClearance
            )

        // X position is determined by the ship's position
        // around the tunnel circumference.

        let worldRadius =
            maximumRadius * radialOffset

        var worldX =
            worldRadius *
            CGFloat(cos(lateralAngle))

        var worldY =
            verticalPosition

        // ============================================================
        // HARD RADIAL CONSTRAINT
        //
        // sqrt(X² + Y²) must never exceed the tunnel radius.
        // ============================================================

        let distanceFromCenter =
            hypot(worldX, worldY)

        if distanceFromCenter > maximumRadius {

            let scale =
                maximumRadius /
                max(distanceFromCenter, 0.000001)

            worldX *= scale
            worldY *= scale

            // Keep the stored vertical position synchronized
            // with the constrained world position.
            verticalPosition = worldY
        }

        // ============================================================
        // FORWARD
        // ============================================================

        z += forwardSpeed * dt
        progress += forwardSpeed * dt

        // ============================================================
        // TUNNEL WORLD POSITION
        // ============================================================

        position = SCNVector3(
            Float(worldX),
            Float(worldY),
            0.0
        )
    }

    // ============================================================
    // OCEAN UPDATE
    // ============================================================

    /// Updates the ship using ocean flight physics.
    ///
    /// The ocean has NO tunnel/radial physics.
    ///
    /// X = left/right
    /// Y = up/down
    /// Z = forward
    mutating func updateOcean(dt: CGFloat) {

        let lateralSpeed: CGFloat = 1.8
        let verticalSpeed: CGFloat = 6.0

        let oldX = oceanX
        let oldY = oceanY
        let oldZ = 0.0

        // --------------------------------------------------------
        // LEFT / RIGHT
        // --------------------------------------------------------

        oceanX +=
            lateralInput *
            lateralSpeed *
            dt

        
        oceanX = max(
            oceanMinimumX,
            min(
                oceanMaximumX,
                oceanX
            )
        )

        // --------------------------------------------------------
        // UP / DOWN
        // --------------------------------------------------------

        oceanY +=
            verticalInput *
            verticalSpeed *
            dt

        let minimumShipY =
            oceanSurfaceY +
            oceanShipClearance

        let maximumShipY =
            cloudCeilingY -
            oceanShipClearance

        oceanY = max(
            minimumShipY,
            min(
                maximumShipY,
                oceanY
            )
        )

        // --------------------------------------------------------
        // FORWARD
        // --------------------------------------------------------

       // z += forwardSpeed * dt
       // progress += forwardSpeed * dt

        // --------------------------------------------------------
        // WORLD POSITION
        // --------------------------------------------------------

        position = SCNVector3(
            Float(oceanX),
            Float(oceanY),
            Float(0.0)
        )

        verticalPosition = oceanY

        // --------------------------------------------------------
        // DEBUG POSITION CHANGE
        // --------------------------------------------------------
/*
        if oldX != oceanX ||
           oldY != oceanY ||
           oldZ != z {

            print("""
            ==================================================
            OCEAN SHIP MOVED
            ==================================================
            INPUT:
              lateral = \(lateralInput)
              vertical = \(verticalInput)

            POSITION BEFORE:
              x = \(oldX)
              y = \(oldY)
              z = \(oldZ)

            POSITION AFTER:
              x = \(oceanX)
              y = \(oceanY)
              z = \(z)

            SCNVector3:
              x = \(position.x)
              y = \(position.y)
              z = \(position.z)

            ==================================================
            """)
        }
*/
    }
    // ============================================================
    // OPTIONAL COMPATIBILITY UPDATE
    // ============================================================

    /// Compatibility wrapper for existing callers.
    ///
    /// New code should preferably call updateTunnel() or
    /// updateOcean() explicitly.
    mutating func update(
        dt: CGFloat,
        currentSection: SceneSection
    ) {

        if currentSection == .ocean {
            updateOcean(dt: dt)
        } else {
            updateTunnel(dt: dt)
        }
    }
}
