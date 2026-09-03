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
        // Remove asteroids behind the ship
        // ----------------------------------------------------

        let shipZ =
            game.spaceShip.z

        game.asteroids.removeAll { asteroid in

            asteroid.z <
                shipZ - 15.0
        }
    }

    // ========================================================
    // CREATE TUNNEL ASTEROID
    // ========================================================

    private func spawnTunnelAsteroid(
        game: GameState
    ) {

        let shipZ =
            game.spaceShip.z

        let spawnDistance =
            CGFloat.random(
                in: 30.0...55.0
            )

        let spawnZ =
            shipZ +
            spawnDistance

        let angle =
            Double.random(
                in: 0...(Double.pi * 2.0)
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

        guard asteroid.z > shipZ else {
            return
        }

        game.asteroids.append(
            asteroid
        )
    }

    // ========================================================
    // OCEAN ASTEROIDS
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
        // Remove ocean asteroids when:
        //
        // 1. They fall below the ocean
        // 2. They move behind the ship
        // ----------------------------------------------------

        let shipZ =
            game.spaceShip.z

        game.asteroids.removeAll { asteroid in

            asteroid.y < -20.0 ||
            asteroid.z < shipZ - 15.0
        }
    }

    // ========================================================
    // CREATE OCEAN ASTEROID
    // ========================================================
    //
    // Ocean asteroid spawning follows the same basic
    // positioning concept as the swarm:
    //
    //      X = randomized horizontal position
    //      Y = 18...25
    //      Z = randomized position ahead of ship
    //
    // The asteroid then falls toward the ocean.
    //
    // ========================================================

    private func spawnOceanAsteroid(
        game: GameState
    ) {
        let oceanY: CGFloat = 0.0
        let cloudHeight: CGFloat = 28.0

        // ====================================================
        // CURRENT SHIP POSITION
        // ====================================================

        let shipZ = CGFloat(game.spaceShip.position.z)
        let shipX = CGFloat(game.spaceShip.position.x)

        // ====================================================
        // HORIZONTAL POSITION
        // ====================================================

        let x = shipX + CGFloat.random(in: -2.0...2.0)

        // ====================================================
        // STARTING HEIGHT
        //
        // Asteroids begin at cloudHeight.
        // ====================================================

        let y = cloudHeight

        // ====================================================
        // FLOCK-STYLE Z POSITION
        //
        // The entire spawn region moves with the ship.
        //
        // Every time update() causes a new asteroid to spawn,
        // its Z is calculated from the ship's CURRENT Z.
        // ====================================================

        let spawnZ = shipZ + CGFloat.random(in: 25.0...38.0)

        // ====================================================
        // DOWNWARD VELOCITY
        // ====================================================

        let verticalVelocity = CGFloat.random(in: -1.2 ... -0.8)

        // ====================================================
        // HORIZONTAL DRIFT
        // ====================================================

        let horizontalVelocity = CGFloat.random(in: -0.5...0.5)

        // ====================================================
        // GRAVITY
        // ====================================================

        let oceanGravity = CGFloat.random(in: 2.8...3.8)

        // ====================================================
        // CREATE ASTEROID
        // ====================================================

        let asteroid = Asteroid(
            lateralAngle: 0,
            z: spawnZ,
            size: randomAsteroidSize(),
            radialOffset: 0,
            radialVel: 0,
            angularVel: 0,
            x: x,
            y: y,
            verticalVelocity: verticalVelocity,
            horizontalVelocity: horizontalVelocity,
            oceanGravity: oceanGravity
        )

        // ====================================================
        // ADD TO ACTIVE ASTEROID SWARM
        // ====================================================

        game.asteroids.append(asteroid)
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

    public static func clampShipVertical(_ game: GameState) {
        let oceanY: CGFloat = 0.0
        let cloudHeight: CGFloat = 28.0
        var pos = game.spaceShip.position
        pos.y = max(
            Float(oceanY),
            min(
                Float(cloudHeight),
                pos.y
            )
        )
        game.spaceShip.position = pos
    }
}
