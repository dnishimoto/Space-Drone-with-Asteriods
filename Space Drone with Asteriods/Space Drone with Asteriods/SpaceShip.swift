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
    
    private let terrainMinimumX: CGFloat = -36.0
    private let terrainMaximumX: CGFloat = 36.0
    
    private let terrainLateralSpeed: CGFloat = 14.0


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
    mutating func updateTerrain(dt: CGFloat) {

        // ============================================================
        // LEFT / RIGHT
        // ============================================================

        var worldX =
            CGFloat(position.x) +
            lateralInput *
            terrainLateralSpeed *
            dt

        worldX = max(
            terrainMinimumX,
            min(
                terrainMaximumX,
                worldX
            )
        )

        // ============================================================
        // FORWARD PROGRESS
        // ============================================================
        //
        // Unconditional: the ship advances along Z every frame this
        // mode runs, regardless of joystick input, exactly like the
        // tunnel/ocean modes advance forward on their own. Unlike
        // those modes (which reset position.z to 0 every frame and
        // track forward motion separately), the terrain ship's Z IS
        // its real world Z: TerrainSceneWorld reads position.x/z
        // every frame to sample terrain height and recycle terrain
        // segments, so it must be persisted here, not reset.
        //
        // Uses the same `forwardSpeed` the rest of the ship already
        // uses for lasers/asteroids/score, so terrain motion can't
        // silently drift out of sync with those systems.
        //
        let worldZ =
            CGFloat(position.z) +
            forwardSpeed *
            dt

        z = worldZ

        progress +=
            forwardSpeed *
            dt

        // ============================================================
        // FINAL WORLD POSITION
        // ============================================================
        //
        // Y is deliberately left as whatever it already is here.
        // TerrainSceneWorld overwrites it from the real terrain
        // height immediately after calling this, then writes the
        // corrected position back into GameState.
        //
        position = SCNVector3(
            Float(worldX),
            position.y,
            Float(worldZ)
        )

        verticalPosition =
            CGFloat(position.y)
    }


    // MARK: - Main Update

    mutating func update(
        dt: CGFloat,
        currentSection: SceneSection
    ) {

        switch currentSection {

        case .ocean:
            updateOcean(
                dt: dt
            )

        case .terrain:
            updateTerrain(
                dt: dt
            )

        case .tunnel:
            updateTunnel(
                dt: dt
            )
        }
    }
}
