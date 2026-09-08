import Foundation
import SceneKit

@MainActor
enum TunnelGameState {

    // ============================================================
    // TUNNEL TIMERS
    // ============================================================

    private static var enemySpawnTimer: Timer?

    private static var asteroidSpawnClock: CGFloat = 0

    private static let asteroidSpawnInterval: CGFloat = 1.1

    // ============================================================
    // UPDATE
    // ============================================================

    static func update(
        gameState: GameState,
        dt: CGFloat
    ) {

        // ============================================================
        // TUNNEL ONLY
        // ============================================================

        guard gameState.currentSection == .tunnel else {
            return
        }

        // ============================================================
        // ASTEROID SPAWNING
        // ============================================================

        asteroidSpawnClock += dt

        if asteroidSpawnClock >= asteroidSpawnInterval {

            asteroidSpawnClock -= asteroidSpawnInterval

            spawnAsteroid(game: gameState)
        }

        // ============================================================
        // UPDATE TUNNEL ASTEROIDS
        // ============================================================

        for asteroid in gameState.asteroids {

            asteroid.updateTunnel(
                dt: dt,
                shipSpeed: gameState.spaceShip.forwardSpeed
            )
        }

        // ============================================================
        // REMOVE ASTEROIDS THAT PASSED THE PLAYER
        // ============================================================

        gameState.asteroids.removeAll { asteroid in
            asteroid.z < -5.0
        }

        // ============================================================
        // ENEMY SPACECRAFT
        // ============================================================

        if let enemy = gameState.enemySpaceShip,
           !enemy.destroyed {

            enemy.update(
                dt: dt,
                shipSpeed: gameState.spaceShip.forwardSpeed,
                playerAngle: gameState.spaceShip.lateralAngle
            )

            // --------------------------------------------------------
            // ENEMY FIRING
            // --------------------------------------------------------

            if enemy.shootCooldown <= 0 {

                enemy.shootCooldown =
                    CGFloat.random(
                        in: 1.0...2.2
                    )

                let origin =
                    enemyWorldPosition(enemy)

                let direction =
                    enemyWorldDirectionTowardPlayer(
                        enemy,
                        game: gameState
                    )

                gameState.enemyLasers.append(
                    Laser(
                        lateralAngle:
                            enemy.lateralAngle,

                        elevationAngle:
                            0.0,

                        z:
                            enemy.z - 1.5,


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

            // --------------------------------------------------------
            // ENEMY PASSED PLAYER
            // --------------------------------------------------------

            if enemy.z < -6.0 {

                gameState.enemySpaceShip = nil

                scheduleEnemy(
                    game: gameState
                )
            }
        }
        
        gameState.sharkManager.update(game: gameState, dt: dt)
        
        gameState.swarmManager.update(
            dt: dt,
            shipSpeed: gameState.spaceShip.forwardSpeed, playerAngle: gameState.spaceShip.lateralAngle, progress: gameState.spaceShip.progress
           )
        
        gameState.flockManager.update(dt:dt,
                                      shipSpeed: gameState.spaceShip.forwardSpeed, playerAngle: gameState.spaceShip.lateralAngle, progress: gameState.spaceShip.progress)

         
        // ============================================================
        // TUNNEL COLLISIONS
        // ============================================================

        checkCollisions(
            game: gameState
        )
    }

    // ============================================================
    // START / SCHEDULE ENEMY
    // ============================================================

    static func scheduleEnemy(
        game: GameState
    ) {

        game.enemySpaceShip = nil

        enemySpawnTimer?.invalidate()

        enemySpawnTimer =
            Timer.scheduledTimer(
                withTimeInterval: 12.0,
                repeats: false
            ) { _ in

                Task { @MainActor in

                    guard !game.gameOver else {
                        return
                    }

                    game.enemySpaceShip =
                        EnemySpaceShip(
                            lateralAngle:
                                Double.random(
                                    in: 0.0..<(2.0 * .pi)
                                ),
                            playerZ:
                                0.0,
                            spawnDistance:
                                CGFloat.random(
                                    in: 35.0...55.0
                                )
                        )
                }
            }
    }

    // ============================================================
    // ASTEROID SPAWN
    // ============================================================

    private static func spawnAsteroid(
        game: GameState
    ) {

        // --------------------------------------------------------
        // ASTEROID SIZE
        // --------------------------------------------------------

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

        // --------------------------------------------------------
        // RADIAL POSITION
        // --------------------------------------------------------

        let maxR =
            max(
                Tunnel.minRadialOffset,
                1.0 -
                size.radius /
                Tunnel.radius -
                0.05
            )

        let radialOffset =
            CGFloat.random(
                in:
                    Tunnel.minRadialOffset...maxR
            )

        // --------------------------------------------------------
        // FORWARD SPAWN DISTANCE
        // --------------------------------------------------------

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
            spawnDistance

        // --------------------------------------------------------
        // CREATE ASTEROID
        // --------------------------------------------------------

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

        // --------------------------------------------------------
        // GAMESTATE OWNS THE ASTEROID
        // --------------------------------------------------------

        game.asteroids.append(
            asteroid
        )
    }

    // ============================================================
    // ENEMY WORLD POSITION
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
            target.x -
            origin.x

        let dy =
            target.y -
            origin.y

        let dz =
            target.z -
            origin.z

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

        // ============================================================
        // AUTHORITATIVE SHIP COLLISION POSITION
        // ============================================================

        let shipRadius =
            Tunnel.radius * Tunnel.shipRadialInset

        let shipAngle =
            game.spaceShip.lateralAngle

        let shipPosition = SCNVector3(
            Float(
                shipRadius *
                CGFloat(cos(shipAngle))
            ),
            Float(
                shipRadius *
                CGFloat(sin(shipAngle))
            ),
            0
        )

        // ============================================================
        // PLAYER LASERS → ASTEROIDS
        // ============================================================

        for laser in game.playerLasers {

            let laserPosition =
                laser.worldPosition()

            for asteroid in game.asteroids {

                let asteroidPosition =
                    asteroid.tunnelPosition

                let collisionRadius: CGFloat

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

                if distance <= collisionRadius {

                    game.score +=
                        asteroid.size.score

                    game.spawnExplosion(
                        x: CGFloat(asteroidPosition.x),
                        y: CGFloat(asteroidPosition.y),
                        z: CGFloat(asteroidPosition.z),
                        scale:
                            asteroid.size == .large
                            ? 1.6
                            : 1.0
                    )

                    if let index =
                        game.asteroids.firstIndex(
                            where: {
                                $0 === asteroid
                            }
                        ) {

                        game.asteroids.remove(
                            at: index
                        )
                    }

                    break
                }
            }
        }

        // ============================================================
        // ASTEROIDS → SHIP
        // ============================================================

        for asteroid in game.asteroids {

            let asteroidPosition =
                asteroid.tunnelPosition

            let collisionRadius: CGFloat

            switch asteroid.size {
            case .small:
                collisionRadius = 1.4

            case .medium:
                collisionRadius = 1.8

            case .large:
                collisionRadius = 2.4
            }

            let collisionDistance =
                vectorDistance(
                    shipPosition,
                    asteroidPosition
                )

            if collisionDistance <= collisionRadius {

                // ----------------------------------------------------
                // SHIELD ACTIVE
                // ----------------------------------------------------

                if game.shieldActive {

                    game.spawnExplosion(
                        x: CGFloat(asteroidPosition.x),
                        y: CGFloat(asteroidPosition.y),
                        z: CGFloat(asteroidPosition.z),
                        scale:
                            asteroid.size == .large
                            ? 1.6
                            : 1.0
                    )

                    if let index =
                        game.asteroids.firstIndex(
                            where: {
                                $0 === asteroid
                            }
                        ) {

                        game.asteroids.remove(
                            at: index
                        )
                    }

                    continue
                }

                // ----------------------------------------------------
                // ASTEROID HIT = GAME OVER
                // ----------------------------------------------------

                game.spawnExplosion(
                    x: CGFloat(shipPosition.x),
                    y: CGFloat(shipPosition.y),
                    z: CGFloat(shipPosition.z),
                    scale: 1.5
                )

                game.gameOver = true
                game.stopFiring()

                return
            }
        }

        // ============================================================
        // PLAYER LASERS → SQUID
        // ============================================================

        for laser in game.playerLasers {

            let laserPosition =
                laser.worldPosition()

            for squid in game.swarmManager.squids
            where !squid.destroyed {

                let radius =
                    Tunnel.radius *
                    squid.radialOffset

                let position = SCNVector3(
                    Float(
                        radius *
                        CGFloat(
                            cos(
                                squid.lateralAngle
                            )
                        )
                    ),
                    Float(
                        radius *
                        CGFloat(
                            sin(
                                squid.lateralAngle
                            )
                        )
                    ),
                    Float(squid.z)
                )

                if distance(
                    laserPosition,
                    position
                ) <= 1.3 {

                    game.addPendingExplosion(
                        x: squid.x,
                        y: squid.y,
                        z: squid.z
                    )

                    squid.destroyed = true

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
        // PLAYER LASERS → FISH
        // ============================================================

        for laser in game.playerLasers {

            let laserPosition =
                laser.worldPosition()

            for alien in game.flockManager.aliens
            where !alien.destroyed {

                let radius =
                    Tunnel.radius *
                    alien.radialOffset

                let position = SCNVector3(
                    Float(
                        radius *
                        CGFloat(
                            cos(
                                alien.lateralAngle
                            )
                        )
                    ),
                    Float(
                        radius *
                        CGFloat(
                            sin(
                                alien.lateralAngle
                            )
                        )
                    ),
                    Float(alien.z)
                )

                if distance(
                    laserPosition,
                    position
                ) <= 1.3 {

                    game.addPendingExplosion(
                        x: alien.x,
                        y: alien.y,
                        z: alien.z
                    )

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
        // SHIP → SQUID
        // ============================================================

        for squid in game.swarmManager.squids
        where !squid.destroyed {

            if hitsShip(
                angle: squid.lateralAngle,
                z: squid.z,
                shipAngle: shipAngle
            ) {

                // ----------------------------------------------------
                // SHIELD
                // ----------------------------------------------------

                if game.shieldActive {

                    squid.destroyed = true

                    game.addPendingExplosion(
                        x: squid.x,
                        y: squid.y,
                        z: squid.z
                    )

                    continue
                }

                // ----------------------------------------------------
                // SQUID HIT
                // ----------------------------------------------------

                game.score =
                    max(
                        0,
                        game.score - 25
                    )

                squid.destroyed = true
            }
        }

        // ============================================================
        // SHIP → FISH
        // ============================================================

        for alien in game.flockManager.aliens
        where !alien.destroyed {

            if hitsShip(
                angle: alien.lateralAngle,
                z: alien.z,
                shipAngle: shipAngle
            ) {

                // ----------------------------------------------------
                // SHIELD
                // ----------------------------------------------------

                if game.shieldActive {

                    alien.destroyed = true

                    game.addPendingExplosion(
                        x: alien.x,
                        y: alien.y,
                        z: alien.z
                    )

                    continue
                }

                // ----------------------------------------------------
                // FISH HIT
                // ----------------------------------------------------

                game.score =
                    max(
                        0,
                        game.score - 20
                    )

                alien.destroyed = true
            }
        }

        // ============================================================
        // SHIP → SHARK
        // ============================================================
        //
        // IMPORTANT:
        //
        // The shark has its own radialOffset, lateralAngle and z.
        // Therefore calculate its actual tunnel-space position.
        //
        // Do NOT depend on a SceneKit node position.
        // ============================================================

        let shipCollisionRadius: CGFloat = 0.85
        let sharkCollisionRadius: CGFloat = 0.50


        for shark in game.sharks
        where !shark.destroyed {

            // --------------------------------------------------------
            // SHARK ACTUAL WORLD POSITION
            // --------------------------------------------------------

            let sharkPosition = shark.position

            // --------------------------------------------------------
            // TRUE 3-D DISTANCE BETWEEN SHARK AND SHIP
            // --------------------------------------------------------

            let collisionDistance =
                vectorDistance(
                    shipPosition,
                    sharkPosition
                )

            let requiredDistance =
                shipCollisionRadius +
                sharkCollisionRadius
            
            // --------------------------------------------------------
            // SHARK COLLISION
            // --------------------------------------------------------

            if collisionDistance <= requiredDistance {

                // ----------------------------------------------------
                // SHIELD ACTIVE
                // ----------------------------------------------------

                if game.shieldActive {

                    shark.destroyed = true

                    game.addPendingExplosion(
                        x: CGFloat(sharkPosition.x),
                        y: CGFloat(sharkPosition.y),
                        z: CGFloat(sharkPosition.z)
                    )

                    continue
                }

                // ----------------------------------------------------
                // SHARK HIT = GAME OVER
                // ----------------------------------------------------

                game.addPendingExplosion(
                    x: CGFloat(shipPosition.x),
                    y: CGFloat(shipPosition.y),
                    z: CGFloat(shipPosition.z)
                )

                game.gameOver = true
                game.stopFiring()

                return
            }
        }



        // ============================================================
        // PLAYER LASERS → SHARKS
        // ============================================================

        var sharksToRemove: [Shark] = []

        for laser in game.playerLasers {

            let laserPosition =
                laser.worldPosition()

            for shark in game.sharks {

                if shark.destroyed {
                    continue
                }

                let sharkPosition =
                    shark.position

                let collisionRadius: CGFloat = 0.5

                let collisionDistance =
                    vectorDistance(
                        laserPosition,
                        sharkPosition
                    )

                if collisionDistance <= collisionRadius {

                    shark.destroyed = true

                    game.score += 100

                    sharksToRemove.append(
                        shark
                    )

                    break
                }
            }
        }

        // ============================================================
        // REMOVE DESTROYED SHARKS
        // ============================================================

        for shark in sharksToRemove {

            game.sharks.removeAll {
                $0 === shark
            }
        }

        // ============================================================
        // ENEMY LASERS → PLAYER
        // ============================================================

        for laser in game.enemyLasers {

            if vectorDistance(
                laser.worldPosition(),
                shipPosition
            ) <= 1.0 {

                if !game.shieldActive {

                    game.gameOver = true

                    game.stopFiring()

                    return
                }
            }
        }
    }
   
   
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

    static func reset(
        game: GameState
    ) {

        // GameState owns the asteroid collection.

        game.asteroids.removeAll()

        // GameState owns the enemy.

        game.enemySpaceShip = nil

        enemySpawnTimer?.invalidate()

        enemySpawnTimer = nil

        asteroidSpawnClock = 0
    }
}
