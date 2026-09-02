//
//  TunnelGameState.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 9/2/26.
//

import Foundation
import SceneKit

@MainActor
enum TunnelGameState {

    // ============================================================
    // TUNNEL STATE
    // ============================================================

    private static var asteroids: [Asteroid] = []

    private static var enemySpaceShip:
        EnemySpaceShip? = nil

    private static var enemySpawnTimer: Timer?

    private static var asteroidSpawnClock: CGFloat = 0

    private static let asteroidSpawnInterval:
        CGFloat = 1.1

    // ============================================================
    // UPDATE
    // ============================================================

    static func update(
        game: GameState,
        dt: CGFloat
    ) {

        // --------------------------------------------------------
        // ASTEROID SPAWNING
        // --------------------------------------------------------

        asteroidSpawnClock += dt

        if asteroidSpawnClock >= asteroidSpawnInterval {

            asteroidSpawnClock -=
                asteroidSpawnInterval

            spawnAsteroid(game: game)
        }

        // --------------------------------------------------------
        // ASTEROIDS
        // --------------------------------------------------------

        for asteroid in asteroids {

            asteroid.update(
                dt: dt,
                shipSpeed:
                    game.spaceShip.forwardSpeed
            )
        }

        asteroids.removeAll {
            $0.z < -5.0
        }

        // --------------------------------------------------------
        // ENEMY SPACECRAFT
        // --------------------------------------------------------

        if let enemy = enemySpaceShip,
           !enemy.destroyed {

            enemy.update(
                dt: dt,
                shipSpeed:
                    game.spaceShip.forwardSpeed,
                playerAngle:
                    game.spaceShip.lateralAngle
            )

            if enemy.shootCooldown <= 0 {

                enemy.shootCooldown =
                    CGFloat.random(
                        in: 1.0...2.2
                    )

                let origin =
                    enemyWorldPosition(
                        enemy
                    )

                let direction =
                    enemyWorldDirectionTowardPlayer(
                        enemy,
                        game: game
                    )

                game.enemyLasers.append(
                    Laser(
                        lateralAngle:
                            enemy.lateralAngle,

                        elevationAngle:
                            0.0,

                        z:
                            enemy.z - 1.5,

                        radialOffset:
                            Tunnel.shipRadialInset,

                        origin:
                            origin,

                        direction:
                            direction,

                        stepSize:
                            0.1,

                        isPlayerLaser:
                            false
                    )
                )
            }

            if enemy.z < -6.0 {

                enemySpaceShip = nil

                scheduleEnemy(
                    game: game
                )
            }
        }

        // --------------------------------------------------------
        // TUNNEL COLLISIONS
        // --------------------------------------------------------

        checkCollisions(game: game)
    }

    // ============================================================
    // START ENEMY
    // ============================================================

    static func scheduleEnemy(
        game: GameState
    ) {

        enemySpaceShip = nil

        enemySpawnTimer?.invalidate()

        enemySpawnTimer = Timer.scheduledTimer(
            withTimeInterval: 12.0,
            repeats: false
        ) { _ in

            Task { @MainActor in

                guard !game.gameOver else {
                    return
                }

                enemySpaceShip =
                    EnemySpaceShip(
                        lateralAngle:
                            Double.random(
                                in: 0.0..<(2.0 * .pi)
                            ),

                        playerZ:
                            game.spaceShip.z,

                        spawnDistance:
                            CGFloat.random(
                                in: 35.0...55.0
                            )
                    )
            }
        }
    }

    // ============================================================
    // ASTEROID
    // ============================================================

    private static func spawnAsteroid(
        game: GameState
    ) {

        let size: AsteroidSize = {

            let r =
                Double.random(
                    in: 0...1
                )

            if r < 0.45 {
                return .small
            }

            if r < 0.80 {
                return .medium
            }

            return .large
        }()

        let maxR = max(
            Tunnel.minRadialOffset,
            1.0 -
            size.radius / Tunnel.radius -
            0.05
        )

        let radialOffset =
            CGFloat.random(
                in:
                    Tunnel.minRadialOffset...maxR
            )

        let aheadDistance =
            CGFloat(Tunnel.segmentsAhead) *
            Tunnel.segmentLength *
            -1.0

        let minimumAhead =
            max(
                15.0,
                aheadDistance * 0.85
            )

        let maximumAhead =
            max(
                minimumAhead + 8.0,
                aheadDistance * 0.98
            )

        let spawnDistance =
            CGFloat.random(
                in:
                    minimumAhead...maximumAhead
            )

        let spawnZ =
            game.spaceShip.z +
            spawnDistance

        let asteroid =
            Asteroid(

                lateralAngle:
                    Double.random(
                        in:
                            0.0..<(2.0 * .pi)
                    ),

                z:
                    spawnZ,

                size:
                    size,

                radialOffset:
                    radialOffset,

                radialVel:
                    CGFloat.random(
                        in: -0.9...0.9
                    ),

                angularVel:
                    Double.random(
                        in: -0.6...0.6
                    )
            )

        asteroids.append(asteroid)
    }

    // ============================================================
    // ENEMY POSITION
    // ============================================================

    private static func enemyWorldPosition(
        _ enemy: EnemySpaceShip
    ) -> SCNVector3 {

        let radius =
            Tunnel.radius *
            Tunnel.shipRadialInset

        let angle =
            enemy.lateralAngle

        return SCNVector3(

            Float(
                radius *
                CGFloat(cos(angle))
            ),

            Float(
                radius *
                CGFloat(sin(angle))
            ),

            Float(enemy.z)
        )
    }

    // ============================================================
    // ENEMY AIM
    // ============================================================

    private static func enemyWorldDirectionTowardPlayer(
        _ enemy: EnemySpaceShip,
        game: GameState
    ) -> SCNVector3 {

        let origin =
            enemyWorldPosition(enemy)

        let playerRadius =
            Tunnel.radius *
            Tunnel.shipRadialInset

        let playerAngle =
            game.spaceShip.lateralAngle

        let target =
            SCNVector3(

                Float(
                    playerRadius *
                    CGFloat(cos(playerAngle))
                ),

                Float(
                    playerRadius *
                    CGFloat(sin(playerAngle))
                ),

                0
            )

        let dx =
            target.x - origin.x

        let dy =
            target.y - origin.y

        let dz =
            target.z - origin.z

        let length =
            sqrt(
                dx * dx +
                dy * dy +
                dz * dz
            )

        guard length > 0.0001 else {
            return SCNVector3(
                0,
                0,
                -1
            )
        }

        return SCNVector3(
            dx / length,
            dy / length,
            dz / length
        )
    }

    // ============================================================
    // COLLISIONS
    // ============================================================

    private static func checkCollisions(
        game: GameState
    ) {

        let laserList =
            game.playerLasers

        for laser in laserList {

            let laserPosition =
                laser.worldPosition()

            // ------------------------------
            // ASTEROIDS
            // ------------------------------

            for asteroid in asteroids {

                let radius =
                    Tunnel.radius *
                    asteroid.radialOffset

                let asteroidPosition =
                    SCNVector3(

                        Float(
                            radius *
                            CGFloat(
                                cos(
                                    asteroid.lateralAngle
                                )
                            )
                        ),

                        Float(
                            radius *
                            CGFloat(
                                sin(
                                    asteroid.lateralAngle
                                )
                            )
                        ),

                        Float(asteroid.z)
                    )

                let collisionRadius:
                    CGFloat

                switch asteroid.size {

                case .small:
                    collisionRadius = 1.1

                case .medium:
                    collisionRadius = 1.5

                case .large:
                    collisionRadius = 2.1
                }

                let distance =
                    vectorDistance(
                        laserPosition,
                        asteroidPosition
                    )

                if distance <=
                    collisionRadius {

                    game.score +=
                        asteroid.size.score

                    game.spawnExplosion(
                        x:
                            CGFloat(
                                asteroidPosition.x
                            ),
                        y:
                            CGFloat(
                                asteroidPosition.y
                            ),
                        z:
                            CGFloat(
                                asteroidPosition.z
                            ),
                        scale:
                            asteroid.size == .large
                            ? 1.6
                            : 1.0
                    )

                  
                }
            }
        }


        // --------------------------------------------------------
        // ENEMY LASERS → PLAYER
        // --------------------------------------------------------

        let playerRadius =
            Tunnel.radius *
            Tunnel.shipRadialInset

        let playerAngle =
            game.spaceShip.lateralAngle

        let playerPosition =
            SCNVector3(

                Float(
                    playerRadius *
                    CGFloat(
                        cos(playerAngle)
                    )
                ),

                Float(
                    playerRadius *
                    CGFloat(
                        sin(playerAngle)
                    )
                ),

                0
            )

        for laser in game.enemyLasers {

            if vectorDistance(
                laser.worldPosition(),
                playerPosition
            ) <= 1.0 {

                if !game.shieldActive {

                    game.gameOver = true
                    game.stopFiring()
                }
            }
        }
    }

    // ============================================================
    // DISTANCE
    // ============================================================

    private static func vectorDistance(
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> CGFloat {

        let dx =
            CGFloat(a.x - b.x)

        let dy =
            CGFloat(a.y - b.y)

        let dz =
            CGFloat(a.z - b.z)

        return (
            dx * dx +
            dy * dy +
            dz * dz
        ).squareRoot()
    }

    // ============================================================
    // RESET
    // ============================================================

    static func reset() {

        asteroids.removeAll()

        enemySpaceShip = nil

        enemySpawnTimer?.invalidate()
        enemySpawnTimer = nil

        asteroidSpawnClock = 0
    }
}
