import Foundation
import SceneKit

@MainActor
final class AsteroidManager {

    // ========================================================
    // TUNNEL
    // ========================================================

    private var tunnelSpawnClock: CGFloat = 0

    private let tunnelSpawnInterval: CGFloat = 1.1

    // ========================================================
    // OCEAN
    // ========================================================

    private var oceanSpawnClock: CGFloat = 0

    private let oceanSpawnInterval: CGFloat = 0.7 // spawns twice as fast for more asteroids

    // ========================================================
    // UPDATE
    // ========================================================

    func update(
        game: GameState,
        dt: CGFloat
    ) {

        switch game.currentSection {

        case .tunnel:

            updateTunnel(
                game: game,
                dt: dt
            )

        case .ocean:

            updateOcean(
                game: game,
                dt: dt
            )

        default:

            break
        }
    }

    // ========================================================
    // TUNNEL ASTEROIDS
    // ========================================================

    private func updateTunnel(
        game: GameState,
        dt: CGFloat
    ) {

        tunnelSpawnClock += dt

        if tunnelSpawnClock >= tunnelSpawnInterval {

            tunnelSpawnClock -=
                tunnelSpawnInterval

            spawnTunnelAsteroid(
                game: game
            )
        }

        for asteroid in game.asteroids {

            asteroid.updateTunnel(
                dt: dt,
                shipSpeed:
                    game.spaceShip.forwardSpeed
            )
        }

        game.asteroids.removeAll { asteroid in

            asteroid.z <
                game.spaceShip.z - 15.0
        }
    }

    // ========================================================
    // CREATE TUNNEL ASTEROID
    // ========================================================

    private func spawnTunnelAsteroid(
        game: GameState
    ) {

        let angle =
            Double.random(
                in:
                    0...(Double.pi * 2.0)
            )

        let radialOffset =
            CGFloat.random(
                in: 0.30...0.85
            )

        let radialVelocity =
            CGFloat.random(
                in: -0.20...0.20
            )

        let angularVelocity =
            Double.random(
                in: -0.35...0.35
            )

        let spawnDistance =
            CGFloat.random(
                in: 30.0...55.0
            )

        let spawnZ =
            game.spaceShip.z +
            spawnDistance

        let asteroid =
            Asteroid(
                lateralAngle:
                    angle,

                z:
                    spawnZ,

                size:
                    randomAsteroidSize(),

                radialOffset:
                    radialOffset,

                radialVel:
                    radialVelocity,

                angularVel:
                    angularVelocity
            )

        game.asteroids.append(
            asteroid
        )
    }

    // ========================================================
    // OCEAN ASTEROIDS
    // ========================================================
    //
    // Asteroids originate ABOVE the ocean.
    //
    // They begin near the cloud ceiling and fall downward.
    //
    // Y decreases because gravity is negative.
    // ========================================================

    private func updateOcean(
        game: GameState,
        dt: CGFloat
    ) {

        oceanSpawnClock += dt

        if oceanSpawnClock >= oceanSpawnInterval {

            oceanSpawnClock -=
                oceanSpawnInterval

            spawnOceanAsteroid(
                game: game
            )
        }

        for asteroid in game.asteroids {

            asteroid.updateOcean(
                dt: dt,
                shipSpeed:
                    game.spaceShip.forwardSpeed
            )
        }

        // Remove asteroids once they have fallen
        // below the ocean surface or passed the ship.

        game.asteroids.removeAll { asteroid in

            asteroid.y < -20.0 ||
            asteroid.z <
                game.spaceShip.z - 15.0
        }
    }

    // ========================================================
    // CREATE FALLING OCEAN ASTEROID
    // ========================================================

    private func spawnOceanAsteroid(
        game: GameState
    ) {

        // Horizontal position over the ocean.
        let x =
            CGFloat.random(
                in: -7.0...7.0
            )

        // Start above the ocean.
        //
        // This represents the cloud region.
        let y =
            CGFloat.random(
                in: 18.0...22.0
            )

        // Always spawn asteroids in front of the ship (never behind).
        let z =
            game.spaceShip.z +
            CGFloat.random(
                in: 25.0...55.0
            )

        let asteroid =
            Asteroid(
                lateralAngle: 0,
                z: z,

                size:
                    randomAsteroidSize(),

                radialOffset: 0,
                radialVel: 0,
                angularVel: 0,

                x: x,
                y: y,

                // Always start with a clear downward velocity.
                verticalVelocity:
                    CGFloat.random(
                        in: -1.1 ... -0.5
                    ),

                // Asteroid can drift left/right
                // as it falls.
                horizontalVelocity:
                    CGFloat.random(
                        in: -0.8...0.8
                    ),

                // Slightly increased gravity for faster drop.
                oceanGravity:
                    CGFloat.random(
                        in: 2.0...3.3
                    )
            )

        game.asteroids.append(
            asteroid
        )
    }

    // ========================================================
    // RANDOM ASTEROID SIZE
    // ========================================================

    private func randomAsteroidSize()
        -> AsteroidSize {

        let value =
            Int.random(
                in: 0...99
            )

        if value < 55 {
            return .small
        }

        if value < 85 {
            return .medium
        }

        return .large
    }

    // ========================================================
    // RESET
    // ========================================================

    func reset(
        game: GameState
    ) {

        tunnelSpawnClock = 0
        oceanSpawnClock = 0

        game.asteroids.removeAll()
    }
}

