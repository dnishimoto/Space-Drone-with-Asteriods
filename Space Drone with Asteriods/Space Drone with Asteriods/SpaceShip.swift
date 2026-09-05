//
//  StarShip.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit

struct SpaceShip {

    // MARK: - Ocean Limits

    private let oceanMinimumX: CGFloat = -45.0
    private let oceanMaximumX: CGFloat = 45.0

    private let oceanSurfaceY: CGFloat = -16.0
    private let cloudCeilingY: CGFloat = 42.0
    private let oceanShipClearance: CGFloat = 1.5

    // MARK: - World Position

    /// Actual world-space position of the ship.
    ///
    /// The ship moves in X/Y.
    /// The ship does NOT rotate.
    ///
    /// Tunnel:
    ///     X = lateral position
    ///     Y = vertical position
    ///     Z = 0
    ///
    /// Ocean:
    ///     X = lateral position
    ///     Y = vertical position
    ///     Z = 0
    var position: SCNVector3 = SCNVector3(
        0,
        0,
        0
    )

    // MARK: - Tunnel Position

    /// Logical position around the tunnel.
    ///
    /// This is a movement value only.
    /// It is NOT a ship rotation.
    var lateralAngle: Double = 0.0

    /// Vertical position inside the tunnel.
    var verticalPosition: CGFloat = 0.0

    /// Fraction of the available tunnel radius.
    var radialOffset: CGFloat = Tunnel.shipRadialInset

    // MARK: - Ocean Position

    var oceanX: CGFloat = 0.0
    var oceanY: CGFloat = 0.0

    // MARK: - Input

    var lateralInput: Double = 0.0
    var verticalInput: Double = 0.0

    // MARK: - Forward Motion

    /// Forward movement speed through the tunnel.
    ///
    /// The ship itself remains at Z = 0.
    /// Tunnel objects move relative to it.
    var forwardSpeed: CGFloat = 12.0

    /// Logical forward position.
    ///
    /// This is NOT the SceneKit Z position.
    var z: CGFloat = 0.0

    /// Total tunnel progress.
    var progress: CGFloat = 0.0


    // MARK: - Tunnel Update

    mutating func updateTunnel(dt: CGFloat) {

        let lateralSpeed: CGFloat = 1.8
        let verticalSpeed: CGFloat = 6.0


        // ============================================================
        // LEFT / RIGHT AROUND THE TUNNEL
        // ============================================================
        //
        // lateralAngle determines WHERE the ship is located.
        //
        // It does NOT rotate the ship.
        //
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
        // ============================================================

        let shipClearance: CGFloat = 0.55

        let maximumRadius = max(
            0.0,
            Tunnel.radius - shipClearance
        )


        // ============================================================
        // CALCULATE X/Y POSITION
        // ============================================================
        //
        // This moves the ship.
        //
        // No rotation occurs here.
        //
        let worldRadius =
            maximumRadius * radialOffset

        var worldX =
            worldRadius *
            CGFloat(cos(lateralAngle))

        var worldY =
            verticalPosition


        // ============================================================
        // HARD RADIAL CONSTRAINT
        // ============================================================
        //
        // Keep the ship inside the tunnel.
        //
        let distanceFromCenter =
            hypot(
                worldX,
                worldY
            )

        if distanceFromCenter > maximumRadius {

            let scale =
                maximumRadius /
                max(
                    distanceFromCenter,
                    0.000001
                )

            worldX *= scale
            worldY *= scale

            verticalPosition = worldY
        }


        // ============================================================
        // FORWARD PROGRESS
        // ============================================================
        //
        // The ship stays visually at Z = 0.
        //
        // The tunnel/enemies/asteroids move relative to the ship.
        //
        z += forwardSpeed * dt
        progress += forwardSpeed * dt


        // ============================================================
        // FINAL WORLD POSITION
        // ============================================================
        //
        // POSITION ONLY.
        //
        // There is deliberately no rotation here.
        //
        position = SCNVector3(
            Float(worldX),
            Float(worldY),
            0.0
        )
    }


    // MARK: - Ocean Update

    mutating func updateOcean(dt: CGFloat) {

        let lateralSpeed: CGFloat = 1.8
        let verticalSpeed: CGFloat = 6.0


        // ============================================================
        // LEFT / RIGHT
        // ============================================================

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


        // ============================================================
        // UP / DOWN
        // ============================================================

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


        // ============================================================
        // WORLD POSITION
        // ============================================================
        //
        // Again: position only.
        // No ship rotation.
        //
        position = SCNVector3(
            Float(oceanX),
            Float(oceanY),
            0.0
        )

        verticalPosition = oceanY
    }


    // MARK: - Main Update

    mutating func update(
        dt: CGFloat,
        currentSection: SceneSection
    ) {

        if currentSection == .ocean {

            updateOcean(
                dt: dt
            )

        } else {

            updateTunnel(
                dt: dt
            )
        }
    }
}
