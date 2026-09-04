import SceneKit
import CoreGraphics

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

        self.direction = Laser.normalizedDirection(direction)

        self.stepSize = max(
            stepSize,
            0.000001
        )

        self.isPlayerLaser = isPlayerLaser

        self.distance = 0.0
    }
    static func rotatedByYaw(
        _ direction: SCNVector3,
        yawRadians: Float
    ) -> SCNVector3 {

        let cosYaw = cos(yawRadians)
        let sinYaw = sin(yawRadians)

        let rotated = SCNVector3(
            direction.x * cosYaw + direction.z * sinYaw,
            direction.y,
            -direction.x * sinYaw + direction.z * cosYaw
        )

        return normalizedDirection(
            rotated
        )
    }

    // ============================================================
    // DIRECTION ROTATION
    // ============================================================

    /// Rotates a direction around the fixed world X axis.
    ///
    /// Positive pitch:
    ///     +Z forward -> -Y down
    ///
    /// Negative pitch:
    ///     +Z forward -> +Y up
    ///
    /// This uses the standard X-axis rotation:
    ///
    ///     x' = x
    ///     y' = y cos(θ) - z sin(θ)
    ///     z' = y sin(θ) + z cos(θ)
    /// ============================================================

    static func rotatedByPitch(
        _ direction: SCNVector3,
        pitchRadians: Float
    ) -> SCNVector3 {

        let cosPitch = cos(pitchRadians)
        let sinPitch = sin(pitchRadians)

        let rotated = SCNVector3(
            direction.x,
            direction.y * cosPitch - direction.z * sinPitch,
            direction.y * sinPitch + direction.z * cosPitch
        )

        return normalizedDirection(rotated)
    }

    // ============================================================
    // NORMALIZATION
    // ============================================================

    /// Returns a normalized direction vector.
    ///
    /// Falls back to world forward (+Z) if the input direction has
    /// effectively zero length.
    // ============================================================

    static func normalizedDirection(
        _ vector: SCNVector3
    ) -> SCNVector3 {

        let length = sqrt(
            vector.x * vector.x +
            vector.y * vector.y +
            vector.z * vector.z
        )

        guard length > 0.000001 else {
            return SCNVector3(
                0,
                0,
                1
            )
        }

        return SCNVector3(
            vector.x / length,
            vector.y / length,
            vector.z / length
        )
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
    //
    // NOTE:
    //
    // Player lasers should normally use the real live direction
    // calculated from muzzleNode.presentation instead of this
    // trig helper. This helper remains useful if a future system
    // needs a direction derived only from yaw/pitch angles.
    // ============================================================

    static func makeCannonDirection(
        yaw: Double,
        pitch: Double
    ) -> SCNVector3 {

        // Starting world-forward direction:
        //
        //     +Z
        //
        let sinYaw = sin(yaw)
        let cosYaw = cos(yaw)

        let yawedDirection = SCNVector3(
            -Float(sinYaw),
            0.0,
            Float(cosYaw)
        )

        let sinPitch = sin(pitch)
        let cosPitch = cos(pitch)

        let pitchedDirection = SCNVector3(
            yawedDirection.x * Float(cosPitch),
            Float(sinPitch),
            yawedDirection.z * Float(cosPitch)
        )

        return normalizedDirection(pitchedDirection)
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

            // Player laser is already moving through world space.
            travelSpeed = Laser.speed

        } else {

            // Enemy lasers compensate for forward tunnel motion.
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
