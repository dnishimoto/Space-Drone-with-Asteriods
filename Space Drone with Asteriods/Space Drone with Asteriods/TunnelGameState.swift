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

        let laserList =
            game.playerLasers

        // --------------------------------------------------------
        // PLAYER LASERS → ASTEROIDS
        // --------------------------------------------------------

        for laser in laserList {

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

                    // Mark for removal by removing the
                    // asteroid from GameState.

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
        
        // --------------------------------------------------------
        // PLAYER LASERS → SQUID
        // --------------------------------------------------------

        for laser in game.playerLasers {

            let laserPosition =
                laser.worldPosition()

            for squid in
                game.swarmManager.squids
                where !squid.destroyed {

                let radius =
                    Tunnel.radius *
                    squid.radialOffset

                let position =
                    SCNVector3(

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

                    game.addPendingExplosion(x:squid.x,y:squid.y,z:squid.z)

                    squid.destroyed = true

                    game.score += 60

                    game.spawnExplosion(
                        x:
                            CGFloat(position.x),
                        y:
                            CGFloat(position.y),
                        z:
                            CGFloat(position.z),
                        scale:
                            0.85
                    )
                }
            }
        }

        // --------------------------------------------------------
        // PLAYER LASERS → FISH
        // --------------------------------------------------------

        for laser in game.playerLasers {

            let laserPosition =
                laser.worldPosition()

            for alien in
                game.flockManager.aliens
                where !alien.destroyed {

                let radius =
                    Tunnel.radius *
                    alien.radialOffset

                let position =
                    SCNVector3(

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

                    game.addPendingExplosion(x:alien.x,y:alien.y,z:alien.z)
                    
                    alien.destroyed = true

                    game.score += 60

                    game.spawnExplosion(
                        x:
                            CGFloat(position.x),
                        y:
                            CGFloat(position.y),
                        z:
                            CGFloat(position.z),
                        scale:
                            0.85
                    )
                }
            }
        }

        // --------------------------------------------------------
        // SHIP → SQUID
        // --------------------------------------------------------

        let shipAngle =
            game.spaceShip.lateralAngle

        for squid in
            game.swarmManager.squids
            where !squid.destroyed {

            if hitsShip(
                angle:
                    squid.lateralAngle,
                z:
                    squid.z,
                shipAngle:
                    shipAngle
            ) {

                if game.shieldActive {
                    

                    squid.destroyed = true
                    
                    game.addPendingExplosion(x:squid.x,y:squid.y,z:squid.z)

                    continue
                }

                game.score =
                    max(
                        0,
                        game.score - 25
                    )

                squid.destroyed = true
            }
        }

        // --------------------------------------------------------
        // SHIP → FISH
        // --------------------------------------------------------

        for alien in
            game.flockManager.aliens
            where !alien.destroyed {

            if hitsShip(
                angle:
                    alien.lateralAngle,
                z:
                    alien.z,
                shipAngle:
                    shipAngle
            ) {

                if game.shieldActive {

                    alien.destroyed = true
                    
                    

                    continue
                }

                game.score =
                    max(
                        0,
                        game.score - 20
                    )

                alien.destroyed = true
            }
        }

        // --------------------------------------------------------
        // SHIP → SHARK
        // --------------------------------------------------------

        for shark in game.sharks
        where !shark.destroyed {

            if hitsShip(
                angle:
                    shark.lateralAngle,
                z:
                    shark.z,
                shipAngle:
                    shipAngle
            ) {

                if game.shieldActive {

                    shark.destroyed = true

                    continue
                }

                // Shark is a major Ocean opponent.
                game.gameOver = true

                game.stopFiring()
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
