import SceneKit
import CoreGraphics

struct Laser {

    // ============================================================
    // CANNON ANGLES
    // ============================================================

    var lateralAngle: Double
    var elevationAngle: Double

    // ============================================================
    // TUNNEL COORDINATES
    // ============================================================

    var z: CGFloat
    var radialOffset: CGFloat

    // ============================================================
    // WORLD SPACE
    // ============================================================

    var origin: SCNVector3
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

        self.direction =
            Laser.normalizedDirection(direction)

        self.stepSize = max(
            stepSize,
            0.000001
        )

        self.isPlayerLaser = isPlayerLaser
        self.distance = 0.0
    }

    // ============================================================
    // CANNON DIRECTION
    //
    // +Z = FORWARD
    // +Y = UP
    // -Y = DOWN
    // ============================================================

    static func makeCannonDirection(
        yaw: Double,
        pitch: Double
    ) -> SCNVector3 {

        let sinYaw = Float(sin(yaw))
        let cosYaw = Float(cos(yaw))

        let sinPitch = Float(sin(pitch))
        let cosPitch = Float(cos(pitch))

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
    // LASER NODE
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

        // Cylinder's local Y axis -> local -Z.
        beamNode.eulerAngles.x = -.pi / 2.0
        
    

        let container = SCNNode()

        container.addChildNode(
            beamNode
        )

        // ========================================================
        // POSITION
        // ========================================================

        let start = worldPosition()

        container.position = start

        // ========================================================
        // AIM USING ACTUAL TRAVEL DIRECTION
        // ========================================================

        let worldEnd = SCNVector3(
            start.x + direction.x,
            start.y + direction.y,
            start.z + direction.z
        )

        container.look(
            at: worldEnd,
            up: SCNVector3(
                0,
                1,
                0
            ),
            localFront: SCNVector3(
                0,
                0,
                -1
            )
        )

        return container
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

        let p = worldPosition()

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
                1
            )
        }

        return SCNVector3(
            vector.x / length,
            vector.y / length,
            vector.z / length
        )
    }
}
