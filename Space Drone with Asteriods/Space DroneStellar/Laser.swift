
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
    // LEGACY / TUNNEL STATE
    // ============================================================

    var z: CGFloat

    // ============================================================
    // TRAVEL
    // ============================================================

    var distance: CGFloat
    var stepSize: CGFloat

    let isPlayerLaser: Bool

    static let speed: CGFloat = 28.0

    // ============================================================
    // WORLD POSITION AND DIRECTION
    //
    // IMPORTANT:
    //
    // position is ALWAYS WORLD SPACE.
    // direction is ALWAYS WORLD SPACE.
    //
    // Once the laser is created, its direction never changes.
    // ============================================================

    var position: SCNVector3
    var direction: SCNVector3

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(
        lateralAngle: Double,
        elevationAngle: Double,
        z: CGFloat,
        origin: SCNVector3,
        direction: SCNVector3,
        stepSize: CGFloat,
        isPlayerLaser: Bool
    ) {

        self.lateralAngle = lateralAngle
        self.elevationAngle = elevationAngle

        self.z = z

        self.stepSize = max(
            stepSize,
            0.000001
        )

        self.isPlayerLaser = isPlayerLaser

        self.distance = 0.0

        self.position = origin

        // --------------------------------------------------------
        // Normalize the direction exactly once when the laser
        // is created.
        // --------------------------------------------------------

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

            // SceneKit forward direction.
            self.direction = SCNVector3(
                0,
                0,
                -1
            )
        }
    }

    // ============================================================
    // UPDATE
    //
    // WORLD-SPACE LASER MOVEMENT
    //
    // IMPORTANT:
    //
    // The laser does NOT use:
    //
    // - cannon angles
    // - ship position
    // - cannon position
    // - current camera rotation
    // - current scene position
    //
    // after it has been fired.
    //
    // Its direction is captured at creation time and remains fixed.
    // ============================================================


    mutating func update(
        dt: TimeInterval,
        shipSpeed: Float
    ) {
        let deltaTime = CGFloat(dt)

        let currentSpeed: CGFloat

        if isPlayerLaser {
            currentSpeed = Laser.speed
        } else {
            currentSpeed = Laser.speed + CGFloat(shipSpeed)
        }

        let distanceStep = currentSpeed * deltaTime

        // Calculate each axis separately.
        // Keeping these as individual expressions prevents
        // Swift's type checker from becoming overloaded.

        let dx = direction.x * Float(distanceStep)
        let dy = direction.y * Float(distanceStep)
        let dz = direction.z * Float(distanceStep)

        let newX = position.x + dx
        let newY = position.y + dy
        let newZ = position.z + dz

        position.x = newX
        position.y = newY
        position.z = newZ

        // Track actual world-space distance traveled.
        distance += distanceStep

        // Keep legacy Z synchronized.
        z = CGFloat(position.z)
    }



    // ============================================================
    // LOCAL POSITION
    //
    // NO LONGER USED FOR PHYSICAL MOVEMENT.
    //
    // The laser position is world-space.
    // ============================================================

    func localPosition() -> SCNVector3 {

        return SCNVector3(
            0,
            0,
            0
        )
    }

    // ============================================================
    // WORLD POSITION
    //
    // position is ALREADY world-space.
    // ============================================================

    func worldPosition() -> SCNVector3 {

        return position
    }

    // ============================================================
    // WORLD POSITION FROM PARENT
    //
    // IMPORTANT:
    //
    // DO NOT call parentNode.convertPosition().
    //
    // position is already in the SceneKit world coordinate system.
    //
    // The old implementation performed a second coordinate
    // transformation and could cause the laser to move incorrectly
    // when the parent node was moving or rotated.
    // ============================================================

    func worldPosition(
        from parentNode: SCNNode
    ) -> SCNVector3 {

        return position
    }

    // ============================================================
    // LOCAL FORWARD
    // ============================================================

    static let localDirection = SCNVector3(
        0,
        0,
        -1
    )

    // ============================================================
    // LASER NODE
    //
    // IMPORTANT:
    //
    // This node represents the laser's CURRENT world-space state.
    //
    // The parent of this node should be a WORLD-SPACE laser
    // container, not the moving cannon.
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
        // The cylinder's natural long axis is LOCAL +Y.
        //
        // Rotate +Y so it points in the actual laser direction.
        //
        // This means the visible laser cannot remain pointing
        // backward while its physics travels forward.
        // --------------------------------------------------------

        let from =
            SIMD3<Float>(
                0,
                1,
                0
            )

        let to =
            SIMD3<Float>(
                Float(direction.x),
                Float(direction.y),
                Float(direction.z)
            )

        let directionLength = sqrt(
            to.x * to.x +
            to.y * to.y +
            to.z * to.z
        )

        if directionLength > 0.000001 {

            let normalizedTo =
                SIMD3<Float>(
                    to.x / directionLength,
                    to.y / directionLength,
                    to.z / directionLength
                )

            let rotation =
                simd_quatf(
                    from: from,
                    to: normalizedTo
                )

            beamNode.simdOrientation = rotation
        }

        // --------------------------------------------------------
        // IMPORTANT:
        //
        // This position is intended to be interpreted by the
        // WORLD-SPACE laser container.
        //
        // The caller should subsequently set:
        //
        // node.position = laser.position
        //
        // before adding the node to the world laser container.
        // --------------------------------------------------------

        beamNode.position = position

        return beamNode
    }

    // ============================================================
    // CANNON DIRECTION
    //
    // SceneKit forward is -Z.
    //
    // This helper is retained for compatibility, but your current
    // GameState should preferably use cannonWorldDirection captured
    // from the actual cannon node.
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
            -cosYaw * cosPitch
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

        return normalizedDirection(
            rotated
        )
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

        return normalizedDirection(
            rotated
        )
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

