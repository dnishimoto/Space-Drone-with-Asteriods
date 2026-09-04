//
//  OceanGameState.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 9/2/26.
//
import Foundation
import SceneKit

@MainActor
enum OceanGameState {

    // ============================================================
    // OCEAN STATE
    // ============================================================


    // Magnetic current affecting the ship.
    static var magneticCurrent =
        CGVector(dx: 0, dy: 0)

    // Current strength.
    static var magneticCurrentStrength:
        CGFloat = 0.0

    // ============================================================
    // UPDATE
    // ============================================================

    static func update(
        gameState : GameState,
        dt: CGFloat
    ) {

        // --------------------------------------------------------
        // MAGNETIC CURRENT
        // --------------------------------------------------------

        updateMagneticCurrent(
            game: gameState,
            dt: dt
        )

        // --------------------------------------------------------
        // SQUIDS
        // --------------------------------------------------------

        gameState.swarmManager.update(
            dt: dt,
            shipSpeed:
                gameState.spaceShip.forwardSpeed,
            playerAngle:
                gameState.spaceShip.lateralAngle,
            progress:
                gameState.spaceShip.progress
        )

        // --------------------------------------------------------
        // FISH
        // --------------------------------------------------------

        let difficulty =
            1.0 +
            min(
                Double(gameState.score),
                400.0
            ) /
            400.0 *
            2.0

        gameState.flockManager.update(
            dt: dt,
            shipSpeed:
                gameState.spaceShip.forwardSpeed,
            playerAngle:
                gameState.spaceShip.lateralAngle,
            progress:
                gameState.spaceShip.progress,
            difficulty:
                difficulty
        )

        gameState.asteroidManager.update(
            game: gameState,
            dt: dt
        )
       
        // --------------------------------------------------------
        // SHARKS
        // --------------------------------------------------------

        gameState.sharkManager.update(
            game: gameState,
            dt: dt
        )

        // --------------------------------------------------------
        // OCEAN COLLISIONS
        // --------------------------------------------------------

        checkCollisions(
            game: gameState
        )
    }

    // ============================================================
    // MAGNETIC CURRENT
    // ============================================================

    private static func updateMagneticCurrent(
        game: GameState,
        dt: CGFloat
    ) {

        let time =
            CGFloat(game.frameTick) * dt

        // Oscillating electromagnetic turbulence.
        let horizontal =
            sin(time * 1.7)

        let vertical =
            cos(time * 1.3)

        magneticCurrentStrength =
            0.35 +
            0.20 *
            abs(sin(time * 0.8))

        magneticCurrent =
            CGVector(

                dx:
                    horizontal *
                    magneticCurrentStrength,

                dy:
                    vertical *
                    magneticCurrentStrength
            )

        // --------------------------------------------------------
        // PUSH SHIP
        // --------------------------------------------------------

        // Magnetic currents physically push the ship
        // while it crosses the Alien Ocean.

        game.spaceShip.verticalPosition +=
            Double(
                magneticCurrent.dy *
                dt *
                4.0
            )

        game.spaceShip.lateralAngle +=
            Double(
                magneticCurrent.dx *
                dt *
                0.25
            )
    }

    // ============================================================
    // SHARKS
    // ============================================================

    private static func updateSharks(
        game: GameState,
        dt: CGFloat
    ) {
        for shark in game.sharks {
            shark.update(
                dt: dt,
                shipSpeed: game.spaceShip.forwardSpeed,
                playerAngle: game.spaceShip.lateralAngle
            )
        }

        game.sharks.removeAll {
            $0.position.z < -10.0
        }
    }

    // ============================================================
    // COLLISIONS
    // ============================================================


    // ============================================================
    // MARK: - Collision Detection
    // ============================================================

    private static func checkCollisions(
        game: GameState
    ) {

        // ============================================================
        // PLAYER LASERS → SQUIDS
        // ============================================================

        for laser in game.playerLasers {

            let laserPosition =
                laser.worldPosition()

            for alien in
                    game.swarmManager.squids
            where !alien.destroyed {

                let position =
                    alien.position

                if distance(
                    laserPosition,
                    position
                ) <= 1.3 {

                    alien.destroyed = true

                    game.score += 75

                    game.spawnExplosion(
                        x: CGFloat(position.x),
                        y: CGFloat(position.y),
                        z: CGFloat(position.z),
                        scale: 0.9
                    )
                }
            }
        }


        // ============================================================
        // PLAYER LASERS → FISH
        // ============================================================

        for laser in game.playerLasers {

            let laserPosition =
                laser.worldPosition()

            for alien in
                    game.flockManager.aliens
            where !alien.destroyed {

                let position =
                    alien.position

                if distance(
                    laserPosition,
                    position
                ) <= 1.3 {

                    alien.destroyed = true

                    game.score += 60

                    game.spawnExplosion(
                        x: CGFloat(position.x),
                        y: CGFloat(position.y),
                        z: CGFloat(position.z),
                        scale: 0.85
                    )
                }
            }
        }


        // ============================================================
        // OCEAN WORLD COLLISIONS
        //
        // Ocean objects use their actual 3D position.
        //
        // We do NOT use:
        //
        //     Tunnel.radius
        //     lateralAngle
        //     radialOffset
        //
        // for ocean collision detection.
        // ============================================================


        // ============================================================
        // SHIP POSITION
        // ============================================================

        let shipPosition =
            game.spaceShip.position


        // ============================================================
        // SHIP → SQUID
        // ============================================================

        for alien in
                game.swarmManager.squids
        where !alien.destroyed {

            let alienPosition =
                alien.position

            if distance(
                shipPosition,
                alienPosition
            ) <= 1.5 {

                // ----------------------------------------------------
                // SHIELD
                // ----------------------------------------------------

                if game.shieldActive {

                    alien.destroyed = true

                    continue
                }

                // ----------------------------------------------------
                // NO SHIELD = GAME OVER
                // ----------------------------------------------------

                print(
                    "GAME OVER: SQUID hit spaceship"
                )

                print(
                    "  Ship position: \(shipPosition)"
                )

                print(
                    "  Squid position: \(alienPosition)"
                )
                
                game.score -= 5

                return
            }
        }


        // ============================================================
        // SHIP → FISH
        // ============================================================

        for alien in
                game.flockManager.aliens
        where !alien.destroyed {

            let alienPosition =
                alien.position

            if distance(
                shipPosition,
                alienPosition
            ) <= 1.5 {

                // ----------------------------------------------------
                // SHIELD
                // ----------------------------------------------------

                if game.shieldActive {

                    alien.destroyed = true

                    continue
                }

                // ----------------------------------------------------
                // NO SHIELD = GAME OVER
                // ----------------------------------------------------

                print(
                    "GAME OVER: FISH hit spaceship"
                )

                print(
                    "  Ship position: \(shipPosition)"
                )

                print(
                    "  Fish position: \(alienPosition)"
                )

                game.score -= 5

                return
            }
        }


        // ============================================================
        // SHIP → SHARK
        //
        // Sharks are major ocean enemies.
        //
        // A shark collision causes immediate Game Over unless
        // the shield is active.
        // ============================================================

        for shark in game.sharks
        where !shark.destroyed {

            let sharkPosition =
                shark.position

            if distance(
                shipPosition,
                sharkPosition
            ) <= 0.1 {

                // ----------------------------------------------------
                // SHIELD
                // ----------------------------------------------------

                if game.shieldActive {

                    shark.destroyed = true

                    continue
                }

                // ----------------------------------------------------
                // SHARK HIT = GAME OVER
                // ----------------------------------------------------

                print(
                    "GAME OVER: SHARK hit spaceship"
                )

                print(
                    "  Ship position: \(shipPosition)"
                )

                print(
                    "  Shark position: \(sharkPosition)"
                )

                game.gameOver = true

                game.stopFiring()

                return
            }
        }


        // ============================================================
        // PLAYER LASERS → ASTEROIDS
        // ============================================================

        let laserList =
            game.playerLasers

        var asteroidsToRemove:
            [Asteroid] = []


        for laser in laserList {

            let laserPosition =
                laser.worldPosition()

            for asteroid in game.asteroids {

                let asteroidPosition =
                    asteroid.tunnelPosition

                let collisionRadius:
                    CGFloat

                switch asteroid.size {

                case .small:
                    collisionRadius = 1.1

                case .medium:
                    collisionRadius = 2.5

                case .large:
                    collisionRadius = 3.1
                }


                let collisionDistance =
                    vectorDistance(
                        laserPosition,
                        asteroidPosition
                    )


                if collisionDistance <=
                    collisionRadius {

                    game.score +=
                        asteroid.size.score


                    game.spawnExplosion(
                        x: CGFloat(
                            asteroidPosition.x
                        ),
                        y: CGFloat(
                            asteroidPosition.y
                        ),
                        z: CGFloat(
                            asteroidPosition.z
                        ),
                        scale:
                            asteroid.size == .large
                            ? 1.6
                            : 1.0
                    )


                    asteroidsToRemove.append(
                        asteroid
                    )

                    break
                }
            }
        }


        // ============================================================
        // ASTEROIDS → SPACESHIP
        // ============================================================

        let spaceshipPosition =
            game.spaceShip.position


        for asteroid in game.asteroids {

            // --------------------------------------------------------
            // Don't test an asteroid already destroyed by a laser.
            // --------------------------------------------------------

            if asteroidsToRemove.contains(
                where: { $0 === asteroid }
            ) {
                continue
            }


            let asteroidPosition =
                asteroid.tunnelPosition


            let spaceshipCollisionRadius:
                CGFloat


            switch asteroid.size {

            case .small:
                spaceshipCollisionRadius = 0.1

            case .medium:
                spaceshipCollisionRadius = 0.4

            case .large:
                spaceshipCollisionRadius = 0.6
            }


            let collisionDistance =
                vectorDistance(
                    spaceshipPosition,
                    asteroidPosition
                )


            if collisionDistance <=
                spaceshipCollisionRadius {

                // ----------------------------------------------------
                // ASTEROID HIT = GAME OVER
                // ----------------------------------------------------

                print(
                    "GAME OVER: \(asteroid.size) ASTEROID hit spaceship"
                )

                print(
                    "  Ship position: \(spaceshipPosition)"
                )

                print(
                    "  Asteroid position: \(asteroidPosition)"
                )

                print(
                    "  Collision distance: \(collisionDistance)"
                )

                print(
                    "  Collision radius: \(spaceshipCollisionRadius)"
                )


                game.spawnExplosion(
                    x: CGFloat(
                        spaceshipPosition.x
                    ),
                    y: CGFloat(
                        spaceshipPosition.y
                    ),
                    z: CGFloat(
                        spaceshipPosition.z
                    ),
                    scale: 1.8
                )


                game.gameOver = true

                game.stopFiring()


                asteroidsToRemove.append(
                    asteroid
                )


                return
            }
        }


        // ============================================================
        // REMOVE DESTROYED / COLLIDED ASTEROIDS
        // ============================================================

        for asteroid in asteroidsToRemove {

            game.asteroids.removeAll {
                $0 === asteroid
            }
        }
        
        // --------------------------------------------------------
        // PLAYER LASERS → SHARKS
        // --------------------------------------------------------

        var sharksToRemove: [Shark] = []

        for laser in game.playerLasers {

            let laserPosition = laser.worldPosition()

            for shark in game.sharks {

                // Do not hit an already destroyed shark.
                if shark.destroyed {
                    continue
                }

                // Shark position is already its ocean world position.
                let sharkPosition = shark.position

                // Collision radius for the shark.
                let collisionRadius: CGFloat = 0.5

                let collisionDistance = vectorDistance(
                    laserPosition,
                    sharkPosition
                )

                if collisionDistance <= collisionRadius {

                    print("LASER HIT SHARK")
                    print("  Laser position: \(laserPosition)")
                    print("  Shark position: \(sharkPosition)")
                    print("  Collision distance: \(collisionDistance)")
                    print("  Collision radius: \(collisionRadius)")

                    // Destroy the shark.
                    shark.destroyed = true

                    // Score for destroying shark.
                    game.score += 100


                    sharksToRemove.append(shark)

                    // This laser has hit something.
                    break
                }
            }
        }

        // Remove destroyed sharks after collision processing.
        for shark in sharksToRemove {
            game.sharks.removeAll { $0 === shark }
        }
        
    }



    // ============================================================
    // SHIP COLLISION
    // ============================================================

    private static func hitsShip(
        angle: Double,
        z: CGFloat,
        shipAngle: Double
    ) -> Bool {

        let angleDifference =
            angularDistance(
                angle,
                shipAngle
            )

        return
            abs(z) < 1.6 &&
            angleDifference < 0.30
    }


    // ============================================================
    // RESET
    // ============================================================

    static func reset() {


        magneticCurrent =
            .zero

        magneticCurrentStrength =
            0.0
    }
}

