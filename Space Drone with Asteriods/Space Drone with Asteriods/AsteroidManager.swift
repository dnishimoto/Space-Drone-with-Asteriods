//
//  AsteroidManager.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

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
    private let oceanSpawnInterval: CGFloat = 0.7

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

        // ----------------------------------------------------
        // Update existing tunnel asteroids
        // ----------------------------------------------------

        for asteroid in game.asteroids {

            asteroid.updateTunnel(
                dt: dt,
                shipSpeed:
                    game.spaceShip.forwardSpeed
            )
        }

        // ----------------------------------------------------
        // Remove asteroids well behind the ship
        // ----------------------------------------------------

        let shipPosition = game.spaceShip.position

        game.asteroids.removeAll { asteroid in

            let dx = asteroid.x - CGFloat(shipPosition.x)
            let dy = asteroid.y - CGFloat(shipPosition.y)
            let dz = asteroid.z - CGFloat(shipPosition.z)

            let distance = sqrt(
                dx * dx +
                dy * dy +
                dz * dz
            )

            return distance > 15.0 &&
                   asteroid.z < CGFloat(shipPosition.z)
        }
    }

    // ========================================================
    // CREATE TUNNEL ASTEROID
    // ========================================================

    //
    // The spaceship travels toward +Z.
    //
    // Therefore:
    //
    //     asteroid.z > ship.z
    //
    // means the asteroid is in front of the spaceship.
    //
    // ========================================================

    private func spawnTunnelAsteroid(
        game: GameState
    ) {

        // ----------------------------------------------------
        // Current spaceship position
        // ----------------------------------------------------

        // ----------------------------------------------------
        // ALWAYS SPAWN AHEAD OF THE SHIP
        // ----------------------------------------------------

        let spawnDistance =
            CGFloat.random(
                in: 30.0...55.0
            )

        let spawnZ =
            spawnDistance

        // ----------------------------------------------------
        // Random tunnel angle
        // ----------------------------------------------------

        let angle =
            Double.random(
                in: 0...(Double.pi * 2.0)
            )

        // ----------------------------------------------------
        // Radial position inside tunnel
        // ----------------------------------------------------

        let radialOffset =
            CGFloat.random(
                in: 0.30...0.85
            )

        // ----------------------------------------------------
        // Radial movement
        // ----------------------------------------------------

        let radialVelocity =
            CGFloat.random(
                in: -0.20...0.20
            )

        // ----------------------------------------------------
        // Angular movement
        // ----------------------------------------------------

        let angularVelocity =
            Double.random(
                in: -0.35...0.35
            )

        // ----------------------------------------------------
        // Create asteroid
        // ----------------------------------------------------

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

        // ----------------------------------------------------
        // Safety check
        //
        // Never append an asteroid that is not ahead of
        // the spaceship.
        // ----------------------------------------------------


        game.asteroids.append(
            asteroid
        )
    }

    // ========================================================
    // OCEAN ASTEROIDS
    // ========================================================

    //
    // Ocean asteroids originate above the ocean/cloud layer
    // and fall downward.
    //
    // They are also spawned ahead of the spaceship on +Z.
    //
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

        // ----------------------------------------------------
        // Update ocean asteroids
        // ----------------------------------------------------

        for asteroid in game.asteroids {

            asteroid.updateOcean(
                dt: dt,
                shipSpeed:
                    game.spaceShip.forwardSpeed
            )
        }

        // ----------------------------------------------------
        // Remove asteroids:
        //
        // 1. Once they fall below the ocean
        // 2. Once they are sufficiently behind the ship
        // ----------------------------------------------------

        let shipPosition = game.spaceShip.position

        game.asteroids.removeAll { asteroid in

            let dx = asteroid.x - CGFloat(shipPosition.x)
            let dy = asteroid.y - CGFloat(shipPosition.y)
            let dz = asteroid.z - CGFloat(shipPosition.z)

            let distance = sqrt(
                dx * dx +
                dy * dy +
                dz * dz
            )

            return distance > 15.0 &&
                   asteroid.z < CGFloat(shipPosition.z)
        }
    }

    // ========================================================
    // CREATE OCEAN ASTEROID
    // ========================================================

    //
    // Ocean asteroid layout:
    //
    //             CLOUDS
    //        ☄          ☄
    //             ↓
    //             ↓
    //
    //        ~~~~~~~~~~~~~
    //             OCEAN
    //
    //               🚀
    //
    // The asteroid begins above the ocean AND ahead of
    // the spaceship.
    //
    // ========================================================

    private func spawnOceanAsteroid(
        game: GameState
    ) {

  
        let x =
            CGFloat.random(
                in: -7.0...7.0
            )

        // ====================================================
        // HEIGHT ABOVE OCEAN
        // ====================================================

        let y =
            CGFloat.random(
                in: 18.0...22.0
            )

        // ====================================================
        // ASTEROID MUST BE IN FRONT OF SHIP
        //
        // +Z = forward
        //
        // The asteroid will ALWAYS be at least 35 units
        // in front of the current ship position.
        // ====================================================

        let minimumForwardDistance:
            CGFloat = 35.0

        let additionalDistance =
            CGFloat.random(
                in: 0.0...30.0
            )

        let spawnZ =
            minimumForwardDistance
            + additionalDistance

        // ====================================================
        // CREATE OCEAN ASTEROID
        // ====================================================

        let asteroid =
            Asteroid(
                lateralAngle: 0,

                z:
                    spawnZ,

                size:
                    randomAsteroidSize(),

                radialOffset: 0,

                radialVel: 0,

                angularVel: 0,

                x:
                    x,

                y:
                    y,

                // =================================================
                // DOWNWARD VELOCITY
                // =================================================

                verticalVelocity:
                    CGFloat.random(
                        in: -1.1 ... -0.5
                    ),

                // =================================================
                // HORIZONTAL DRIFT
                // =================================================

                horizontalVelocity:
                    CGFloat.random(
                        in: -0.8...0.8
                    ),

                // =================================================
                // GRAVITY
                // =================================================

                oceanGravity:
                    CGFloat.random(
                        in: 2.0...3.3
                    )
            )

          // ====================================================
        // ADD TO GAME STATE
        // ====================================================

        game.asteroids.append(
            asteroid
        )
    }

    // ========================================================
    // RANDOM ASTEROID SIZE
    // ========================================================

    private func randomAsteroidSize()
        -> AsteroidSize
    {

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
