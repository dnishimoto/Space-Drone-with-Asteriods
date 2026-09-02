

import Foundation
import SceneKit

/// Represents an asteroid entity in the game.
///
/// Asteroids have two independent behaviors:
///
/// TUNNEL
/// - Moves toward the player along Z.
/// - Rotates around the tunnel.
/// - Moves radially.
/// - Bounces against the tunnel wall.
///
/// OCEAN
/// - Falls downward from the clouds.
/// - Accelerates under gravity.
/// - Drifts horizontally.
/// - Moves toward the player along Z.
/// - Does not use TubePhysics.
final class Asteroid {

    // MARK: - Common Properties

    var size: AsteroidSize

    /// Visual rotation.
    var spin: Float = 0

    // MARK: - Tunnel Properties

    /// Angular position around the tunnel.
    var lateralAngle: Double

    /// Forward position along the tunnel.
    var z: CGFloat

    /// Radial position inside the tunnel.
    var radialOffset: CGFloat

    /// Radial velocity.
    var radialVel: CGFloat

    /// Angular velocity around the tunnel.
    var angularVel: Double

    // MARK: - Ocean Properties

    /// Horizontal position in the ocean.
    var x: CGFloat

    /// Vertical position in the ocean.
    var y: CGFloat

    /// Vertical velocity.
    var verticalVelocity: CGFloat

    /// Horizontal drift velocity.
    var horizontalVelocity: CGFloat

    /// Gravity applied to the asteroid.
    var oceanGravity: CGFloat

    // MARK: - Initialization

    init(
        lateralAngle: Double,
        z: CGFloat,
        size: AsteroidSize,
        radialOffset: CGFloat = 0.55,
        radialVel: CGFloat = 0,
        angularVel: Double = 0,
        x: CGFloat = 0,
        y: CGFloat = 12.0,
        verticalVelocity: CGFloat = 0,
        horizontalVelocity: CGFloat = 0,
        oceanGravity: CGFloat = 4.0
    ) {
        self.lateralAngle = lateralAngle
        self.z = z
        self.size = size

        self.radialOffset = radialOffset
        self.radialVel = radialVel
        self.angularVel = angularVel

        self.x = x
        self.y = y
        self.verticalVelocity = verticalVelocity
        self.horizontalVelocity = horizontalVelocity
        self.oceanGravity = oceanGravity
    }

    // MARK: - TUNNEL UPDATE

    /// Updates an asteroid using tunnel physics.
    func updateTunnel(
        dt: CGFloat,
        shipSpeed: CGFloat
    ) {
        // Move toward the player.
        z -= shipSpeed * dt

        // Rotate the asteroid.
        spin += Float(dt) * 1.2

        // Move around the tunnel.
        lateralAngle += angularVel * Double(dt)

        // Radial movement and tunnel-wall collision.
        TubePhysics.integrateRadial(
            radialOffset: &radialOffset,
            radialVel: &radialVel,
            entityRadius: size.radius,
            dt: dt
        )

        // Dampen radial velocity near the wall.
        TubePhysics.dampAgainstWall(
            radialOffset: radialOffset,
            radialVel: &radialVel,
            entityRadius: size.radius
        )

        // Damping.
        angularVel *= 0.998
        radialVel *= 0.999
    }

    // MARK: - OCEAN UPDATE

    /// Updates an asteroid using ocean cloud-fall physics.
    ///
    /// The asteroid falls from the clouds toward the ocean.
    /// No tunnel physics is applied.
    func updateOcean(
        dt: CGFloat,
        shipSpeed: CGFloat
    ) {
        // Gravity accelerates the asteroid downward.
        verticalVelocity -= oceanGravity * dt

        // Apply downward movement.
        y += verticalVelocity * dt

        // Move toward the player.
        z -= shipSpeed * dt

        // Apply horizontal drift.
        x += horizontalVelocity * dt

        // Rotate the asteroid.
        spin += Float(dt) * 1.2
    }

    // MARK: - TUNNEL POSITION

    /// World position for tunnel behavior.
    var tunnelPosition: SCNVector3 {

        let r = Float(Tunnel.radius * radialOffset)

        return SCNVector3(
            r * Float(cos(lateralAngle)),
            r * Float(sin(lateralAngle)),
            Float(z)
        )
    }

    // MARK: - OCEAN POSITION

    /// World position for ocean cloud-fall behavior.
    var oceanPosition: SCNVector3 {

        return SCNVector3(
            Float(x),
            Float(y),
            Float(z)
        )
    }

    // MARK: - EXISTING POSITION

    /// Compatibility property for existing tunnel rendering code.
    ///
    /// Existing code such as:
    ///
    ///     node.position = asteroid.position
    ///
    /// continues to work and uses the tunnel position.
    var position: SCNVector3 {
        return tunnelPosition
    }
}

