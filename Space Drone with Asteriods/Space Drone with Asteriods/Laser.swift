import SceneKit
import CoreGraphics
import UIKit

struct Laser {

    // ============================================================
    // CANNON ANGLES
    // ============================================================

    var lateralAngle: Double
    var elevationAngle: Double

    // ============================================================
    // TUNNEL STATE
    // ============================================================

    var z: CGFloat
    var radialOffset: CGFloat

    // ============================================================
    // TRAVEL
    // ============================================================

    var distance: CGFloat
    var stepSize: CGFloat

    let isPlayerLaser: Bool

    static let speed: CGFloat = 28.0

    // ============================================================
    // WORLD POSITION AND DIRECTION
    // ============================================================

    var position: SCNVector3 // current world position
    var direction: SCNVector3 // normalized world-space direction

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

        self.stepSize = max(
            stepSize,
            0.000001
        )

        self.isPlayerLaser = isPlayerLaser

        self.distance = 0.0

        self.position = origin
        let length = sqrt(direction.x * direction.x + direction.y * direction.y + direction.z * direction.z)
        if length > 0.000001 {
            self.direction = SCNVector3(direction.x / length, direction.y / length, direction.z / length)
        } else {
            self.direction = SCNVector3(0, 0, -1)
        }
    }

    // ============================================================
    // UPDATE
    //
    // Laser movement is now world-space based on position and direction.
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

        let step = travelSpeed * dt

        // Move position by direction * step
        position.x += direction.x * Float(step)
        position.y += direction.y * Float(step)
        position.z += direction.z * Float(step)

        distance += step

        // For compatibility, update z with current position.z
        z = CGFloat(position.z)
    }

    // ============================================================
    // LOCAL POSITION
    //
    // Position relative to muzzleNode (no longer used for movement).
    // ============================================================

    func localPosition() -> SCNVector3 {
        return SCNVector3(0, 0, 0)
    }

    /// Returns the laser's tunnel world position based on its lateral angle, radial offset, and z.
    func worldPosition() -> SCNVector3 {
        return position
    }

    // ============================================================
    // WORLD POSITION
    //
    // Converts the laser's world position into the SceneKit world coordinate system.
    // ============================================================

    func worldPosition(
        from parentNode: SCNNode
    ) -> SCNVector3 {

        return parentNode.convertPosition(
            position,
            to: nil
        )
    }

   

    // ============================================================
    // LOCAL DIRECTION
    // ============================================================

    static let localDirection = SCNVector3(
        0,
        0,
        -1
    )

    // ============================================================
    // LASER NODE
    //
    // This node is intended to be placed under:
    //
    // muzzleNode
    //     └── laserContainer
    //             └── laserNode
    // ============================================================

    func makeLaserNode(
        color: UIColor
    ) -> SCNNode {

        let geometry = SCNCylinder(
            radius: 0.05,
            height: 0.75
        )

        geometry.firstMaterial?.diffuse.contents = color
        geometry.firstMaterial?.emission.contents = color
        geometry.firstMaterial?.isDoubleSided = true

        let beamNode = SCNNode(
            geometry: geometry
        )

        // --------------------------------------------------------
        // Cylinder local Y -> local -Z
        // --------------------------------------------------------

        beamNode.eulerAngles.x = -.pi / 2.0

        // --------------------------------------------------------
        // Position relative to muzzleNode.
        // --------------------------------------------------------

        beamNode.position = localPosition()

        return beamNode
    }

    // ============================================================
    // CANNON DIRECTION
    // ============================================================

    static func makeCannonDirection(
        yaw: Double,
        pitch: Double
    ) -> SCNVector3 {

        let cosYaw = Float(cos(yaw))
        let sinYaw = Float(sin(yaw))

        let cosPitch = Float(cos(pitch))
        let sinPitch = Float(sin(pitch))

        let direction = SCNVector3(
            -sinYaw * cosPitch,
            sinPitch,
            cosYaw * cosPitch
        )

        return normalizedDirection(direction)
    }

    // ============================================================
    // YAW
    // ============================================================

    static func rotatedByYaw(
        _ direction: SCNVector3,
        yawRadians: Float
    ) -> SCNVector3 {

        let cosYaw = cos(yawRadians)
        let sinYaw = sin(yawRadians)

        let rotated = SCNVector3(
            direction.x * cosYaw +
                direction.z * sinYaw,

            direction.y,

            -direction.x * sinYaw +
                direction.z * cosYaw
        )

        return normalizedDirection(rotated)
    }

    // ============================================================
    // PITCH
    // ============================================================

    static func rotatedByPitch(
        _ direction: SCNVector3,
        pitchRadians: Float
    ) -> SCNVector3 {

        let cosPitch = cos(pitchRadians)
        let sinPitch = sin(pitchRadians)

        let rotated = SCNVector3(
            direction.x,

            direction.y * cosPitch -
                direction.z * sinPitch,

            direction.y * sinPitch +
                direction.z * cosPitch
        )

        return normalizedDirection(rotated)
    }

    // ============================================================
    // NORMALIZATION
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
                -1
            )
        }

        return SCNVector3(
            vector.x / length,
            vector.y / length,
            vector.z / length
        )
    }
}
