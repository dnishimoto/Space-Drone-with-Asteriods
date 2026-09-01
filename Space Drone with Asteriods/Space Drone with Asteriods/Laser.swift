
//
//  Laser.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit

struct Laser {

    // ============================================================
    // CANNON ANGLES
    // ============================================================

    /// Left/right cannon angle, in radians.
    var lateralAngle: Double

    /// Up/down cannon angle, in radians.
    var elevationAngle: Double

    // ============================================================
    // TUNNEL COORDINATES
    // ============================================================

    var z: CGFloat
    var radialOffset: CGFloat

    // ============================================================
    // WORLD SPACE
    // ============================================================

    /// Exact world-space position where the laser was fired.
    var origin: SCNVector3

    /// Final normalized world-space firing direction.
    var direction: SCNVector3

    // ============================================================
    // TRAVEL
    // ============================================================

    var distance: CGFloat

    var stepSize: CGFloat

    let isPlayerLaser: Bool

    static let speed: CGFloat = 28.0

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(
        lateralAngle: Double,
        elevationAngle: Double,
        z: CGFloat,
        radialOffset: CGFloat,
        origin: SCNVector3,
        direction: SCNVector3,
        stepSize: CGFloat,
        isPlayerLaser: Bool
    ) {

        self.lateralAngle = lateralAngle
        self.elevationAngle = elevationAngle

        self.z = z
        self.radialOffset = radialOffset

        self.origin = origin

        self.stepSize = max(
            stepSize,
            0.000001
        )

        self.isPlayerLaser = isPlayerLaser

        self.distance = 0.0

        // ========================================================
        // PLAYER LASER
        //
        // IMPORTANT:
        //
        // The camera is rotated 180 degrees around Y.
        //
        // Therefore:
        //
        //     cannon local -Z
        //              ↓
        //          world +Z
        //
        // The player laser must therefore use +Z as its neutral
        // world-space forward direction.
        // ========================================================

        if isPlayerLaser {

            self.direction = Laser.makeCannonDirection(
                yaw: lateralAngle,
                pitch: elevationAngle
            )

        } else {

            // ====================================================
            // ENEMY LASER
            // ====================================================

            let length = sqrt(
                direction.x * direction.x +
                direction.y * direction.y +
                direction.z * direction.z
            )

            if length > 0.000001 {

                self.direction = SCNVector3(
                    direction.x / length,
                    direction.y / length,
                    direction.z / length
                )

            } else {

                self.direction = SCNVector3(
                    0,
                    0,
                    1
                )
            }
        }
    }

    // ============================================================
    // CANNON DIRECTION
    //
    // TWO EXPLICIT TRANSFORMATIONS
    //
    //     1. YAW
    //     2. PITCH
    //
    // WORLD FORWARD:
    //
    //     +Z
    //
    // because the camera is rotated 180 degrees around Y.
    // ============================================================

    static func makeCannonDirection(
        yaw: Double,
        pitch: Double
    ) -> SCNVector3 {

        // ========================================================
        // STARTING WORLD FORWARD
        // ========================================================

        let forward = SCNVector3(
            0,
            0,
            1
        )

        // ========================================================
        // TRANSFORMATION #1 — YAW
        //
        // The visible cannon uses:
        //
        //     cockpitCannonNode.eulerAngles.y = -yaw
        //
        // because the camera itself is rotated by PI.
        //
        // Therefore the matching world-space yaw is:
        //
        //     x = -sin(yaw)
        //     z =  cos(yaw)
        // ========================================================

        let sinYaw = sin(yaw)
        let cosYaw = cos(yaw)

        let yawDirection = SCNVector3(
            forward.x * Float(cosYaw) + forward.z * Float(-sinYaw),
            0.0,
            -forward.x * Float(-sinYaw) + forward.z * Float(cosYaw)
        )

        // With forward = (0,0,1), this simplifies to:
        //
        //     (-sin(yaw), 0, cos(yaw))
        //
        // Keep that explicit result.

        let yawedDirection = SCNVector3(
            -Float(sinYaw),
             0.0,
            Float(cosYaw)
        )

        // ========================================================
        // TRANSFORMATION #2 — PITCH
        //
        // Pitch is applied AFTER yaw.
        //
        // Positive elevation means UP.
        //
        // Therefore:
        //
        //     Y = +sin(pitch)
        //
        // while the horizontal component is reduced by
        // cos(pitch).
        // ========================================================

        let sinPitch = sin(pitch)
        let cosPitch = cos(pitch)

        let pitchedDirection = SCNVector3(
            yawedDirection.x * Float(cosPitch),
            Float(sinPitch),
            yawedDirection.z * Float(cosPitch)
        )

        // ========================================================
        // NORMALIZE
        // ========================================================

        let length = sqrt(
            pitchedDirection.x * pitchedDirection.x +
            pitchedDirection.y * pitchedDirection.y +
            pitchedDirection.z * pitchedDirection.z
        )

        if length > 0.000001 {

            return SCNVector3(
                pitchedDirection.x / length,
                pitchedDirection.y / length,
                pitchedDirection.z / length
            )
        }

        // ========================================================
        // SAFE FALLBACK
        // ========================================================

        return SCNVector3(
            0,
            0,
            1
        )
    }

    // ============================================================
    // UPDATE
    // ============================================================

    mutating func update(
        dt: CGFloat,
        shipSpeed: CGFloat
    ) {

        let travelSpeed: CGFloat

        if isPlayerLaser {

            travelSpeed = Laser.speed

        } else {

            travelSpeed = Laser.speed + shipSpeed
        }

        distance += travelSpeed * dt

        // ========================================================
        // CURRENT WORLD POSITION
        // ========================================================

        let p = worldPosition()

        // ========================================================
        // SYNCHRONIZE TUNNEL COORDINATES
        // ========================================================

        z = CGFloat(p.z)

        let radial = hypot(
            CGFloat(p.x),
            CGFloat(p.y)
        )

        radialOffset = max(
            Tunnel.minRadialOffset,
            min(
                0.98,
                radial / Tunnel.radius
            )
        )
    }

    // ============================================================
    // WORLD POSITION
    // ============================================================

    func worldPosition() -> SCNVector3 {

        let d = Float(distance)

        return SCNVector3(
            origin.x + direction.x * d,
            origin.y + direction.y * d,
            origin.z + direction.z * d
        )
    }
}

