
//
//  PlayerLaser.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit
import simd

final class PlayerLaser {

    // MARK: - Position and Direction

    /// Current world-space position of the laser.
    var position: SCNVector3

    /// Normalized world-space direction of the laser.
    ///
    /// This is captured from the actual cannon direction
    /// when the laser is fired.
    var direction: SCNVector3

    // MARK: - Cannon Angles

    /// Left/right cannon rotation, in radians.
    ///
    /// Stored for reference/debugging.
    var lateralAngle: Float

    /// Up/down cannon rotation, in radians.
    ///
    /// Stored for reference/debugging.
    var elevationAngle: Float

    // MARK: - Travel

    /// Distance traveled by the laser.
    var distance: Float = 0.0

    /// Laser speed in scene units per second.
    let speed: Float = 120.0

    // MARK: - Initialization

    init(
        position: SCNVector3,
        lateralAngle: Float,
        elevationAngle: Float,
        direction: SCNVector3
    ) {

        self.position = position
        self.lateralAngle = lateralAngle
        self.elevationAngle = elevationAngle

        // ============================================================
        // USE THE ACTUAL CANNON DIRECTION
        //
        // SceneWorld calculates cannonWorldDirection from the
        // actual cannon/muzzle orientation.
        //
        // PlayerLaser does NOT independently calculate yaw/pitch.
        // ============================================================

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

            // Safe default:
            // cannon points straight forward along -Z.
            self.direction = SCNVector3(
                0,
                0,
                -1
            )
        }
    }

    // MARK: - Orientation

    /// Orientation of the laser.
    ///
    /// The laser geometry is assumed to point along local -Z.
    ///
    /// This creates a quaternion that rotates local -Z into the
    /// actual world-space laser direction.
    var orientation: SCNQuaternion {

        let dx = direction.x
        let dy = direction.y
        let dz = direction.z

        let length = sqrt(
            dx * dx +
            dy * dy +
            dz * dz
        )

        // Invalid direction.
        if length <= 0.000001 {

            return SCNQuaternion(
                0,
                0,
                0,
                1
            )
        }

        // Normalize direction.
        let x = dx / length
        let y = dy / length
        let z = dz / length

        // ============================================================
        // SOURCE VECTOR
        //
        // SceneKit convention:
        //
        //     forward = -Z
        // ============================================================

        let from = SCNVector3(
            0,
            0,
            -1
        )

        // ============================================================
        // TARGET VECTOR
        // ============================================================

        let to = SCNVector3(
            x,
            y,
            z
        )

        // ============================================================
        // DOT PRODUCT
        // ============================================================

        let dot =
            from.x * to.x +
            from.y * to.y +
            from.z * to.z

        // ============================================================
        // ALREADY ALIGNED
        // ============================================================

        if dot > 0.999999 {

            return SCNQuaternion(
                0,
                0,
                0,
                1
            )
        }

        // ============================================================
        // EXACTLY OPPOSITE
        //
        // Local -Z must rotate 180 degrees.
        //
        // Rotate around Y.
        // ============================================================

        if dot < -0.999999 {

            return SCNQuaternion(
                0,
                1,
                0,
                0
            )
        }

        // ============================================================
        // CROSS PRODUCT
        //
        // from × to
        // ============================================================

        let axis = SCNVector3(
            from.y * to.z - from.z * to.y,
            from.z * to.x - from.x * to.z,
            from.x * to.y - from.y * to.x
        )

        // ============================================================
        // QUATERNION
        // ============================================================

        let s = sqrt(
            (1.0 + dot) * 2.0
        )

        let inverseS = 1.0 / s

        return SCNQuaternion(
            axis.x * inverseS,
            axis.y * inverseS,
            axis.z * inverseS,
            s * 0.5
        )
    }

    // MARK: - Update

    /// Move the laser forward.
    ///
    /// The laser NEVER recalculates its direction here.
    ///
    /// It continues traveling along the exact direction captured
    /// when it was fired.
    func update(
        dt: Double,
        shipSpeed: CGFloat
    ) {

        let step = speed * Float(dt)

        // ============================================================
        // MOVE IN CANNON DIRECTION
        // ============================================================

        position.x += direction.x * step
        position.y += direction.y * step
        position.z += direction.z * step

        distance += step
    }

    // MARK: - World Position

    /// Return the laser's current world-space position.
    func worldPosition() -> SCNVector3 {
        return position
    }
}
