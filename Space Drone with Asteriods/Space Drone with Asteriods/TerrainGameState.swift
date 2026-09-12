import Foundation
import SceneKit

@MainActor
enum TerrainGameState {

    // =====================================================================
    // ACTIVATION / COLLISION CONSTANTS
    // =====================================================================

    private static let sharkActivationDistance: Float = 180.0
    private static let enemyActivationDistance: Float = 300.0

    private static let sharkCollisionRadius: Float = 0.1
    private static let laserCollisionRadius: Float = 1.5

    // =====================================================================
    // MAIN UPDATE
    // =====================================================================

    static func update(
        gameState: GameState,
        dt: CGFloat
    ) {
        guard dt > 0 else {
            return
        }

        let deltaTime = Float(
            min(
                max(dt, 0),
                0.1
            )
        )

        // The Starship position is the authoritative terrain-game
        // world position.
        let playerPosition = playerWorldPosition(
            from: gameState
        )

        // -------------------------------------------------------------
        // SHARKS
        // -------------------------------------------------------------

        updateSharks(
            gameState: gameState,
            playerPosition: playerPosition,
            dt: deltaTime
        )

        // -------------------------------------------------------------
        // ENEMY SHIP
        // -------------------------------------------------------------

        updateEnemyShip(
            gameState: gameState,
            playerPosition: playerPosition,
            dt: deltaTime
        )

        // -------------------------------------------------------------
        // OTHER AI
        // -------------------------------------------------------------

        updateAI(
            gameState: gameState,
            playerPosition: playerPosition,
            dt: deltaTime
        )

        // -------------------------------------------------------------
        // COLLISIONS / SHARK RECYCLING
        // -------------------------------------------------------------

        checkCollisions(
            gameState: gameState
        )
    }

    // =====================================================================
    // PLAYER WORLD POSITION
    // =====================================================================

    private static func playerWorldPosition(
        from gameState: GameState
    ) -> SCNVector3 {

        return gameState.spaceShip.position
    }

    // =====================================================================
    // SHARK UPDATE
    // =====================================================================

    private static func updateSharks(
        gameState: GameState,
        playerPosition: SCNVector3,
        dt: Float
    ) {

        // Shark movement is handled by SharkManager / TerrainSceneWorld.
        //
        // This function remains here as the terrain-game update hook so
        // that shark-specific game-state behavior can be added without
        // moving the actual cellular-automaton movement system here.

        _ = gameState
        _ = playerPosition
        _ = dt
    }

    // =====================================================================
    // ENEMY SHIP UPDATE
    // =====================================================================

    private static func updateEnemyShip(
        gameState: GameState,
        playerPosition: SCNVector3,
        dt: Float
    ) {

        guard let enemy = gameState.enemySpaceShip else {
            return
        }

        _ = enemy
        _ = playerPosition
        _ = dt
    }

    // =====================================================================
    // AI UPDATE
    // =====================================================================

    private static func updateAI(
        gameState: GameState,
        playerPosition: SCNVector3,
        dt: Float
    ) {

        _ = gameState
        _ = playerPosition
        _ = dt
    }

    // =====================================================================
    // COLLISIONS
    // =====================================================================

    private static func checkCollisions(
        gameState: GameState
    ) {

        // ================================================================
        // PLAYER POSITION
        // ================================================================

        let shipPosition = gameState.spaceShip.position

        // ================================================================
        // LASER → SHARK COLLISION
        // ================================================================

        var sharksHitByLasers: [Shark] = []

        for laser in gameState.playerLasers {

            let laserPosition = laser.worldPosition()

            for shark in gameState.sharks {

                if shark.destroyed {
                    continue
                }

                if sharksHitByLasers.contains(
                    where: { $0 === shark }
                ) {
                    continue
                }

                let sharkPosition = shark.position

                let collisionDistance = distance(
                    from: laserPosition,
                    to: sharkPosition
                )

                if collisionDistance <= laserCollisionRadius {

                    shark.destroyed = true

                    gameState.score += 100

                    gameState.spawnExplosion(
                        x: CGFloat(sharkPosition.x),
                        y: CGFloat(sharkPosition.y),
                        z: CGFloat(sharkPosition.z),
                        scale: 1.0
                    )

                    sharksHitByLasers.append(shark)

                    break
                }
            }
        }

        // ================================================================
        // REMOVE LASER-DESTROYED SHARKS
        // ================================================================

        if !sharksHitByLasers.isEmpty {

            gameState.sharks.removeAll { shark in

                sharksHitByLasers.contains { candidate in
                    candidate === shark
                }
            }
        }

        // ================================================================
        // DO NOT PROCESS SHARK COLLISIONS AFTER GAME OVER
        // ================================================================

        guard !gameState.gameOver else {
            return
        }

        // ================================================================
        // SHARK → PLAYER COLLISION
        // ================================================================
        //
        // IMPORTANT:
        //
        // The collision is checked BEFORE the behind-player test.
        //
        // This prevents a fast-moving shark from crossing from:
        //
        //     shark.z > ship.z
        //
        // to:
        //
        //     shark.z < ship.z
        //
        // in one frame and being deleted without triggering game over.
        //
        // ================================================================

        var sharksBehindPlayer: [Shark] = []

        for shark in gameState.sharks {

            if shark.destroyed {
                continue
            }

            let sharkPosition = shark.position

            // ------------------------------------------------------------
            // FULL 3D COLLISION
            // ------------------------------------------------------------

            let collisionDistance = distance(
                from: sharkPosition,
                to: shipPosition
            )

            print(
                "[TerrainGame] Shark distance=" +
                "\(collisionDistance) " +
                "shark=(" +
                "\(sharkPosition.x), " +
                "\(sharkPosition.y), " +
                "\(sharkPosition.z)" +
                ") " +
                "ship=(" +
                "\(shipPosition.x), " +
                "\(shipPosition.y), " +
                "\(shipPosition.z)" +
                ")"
            )

            // ------------------------------------------------------------
            // SHARK HIT SHIP
            // ------------------------------------------------------------

            if collisionDistance <= sharkCollisionRadius {

                print(
                    "[TerrainGame] GAME OVER — Shark hit ship " +
                    "distance=\(collisionDistance) " +
                    "shark=(" +
                    "\(sharkPosition.x), " +
                    "\(sharkPosition.y), " +
                    "\(sharkPosition.z)" +
                    ") " +
                    "ship=(" +
                    "\(shipPosition.x), " +
                    "\(shipPosition.y), " +
                    "\(shipPosition.z)" +
                    ")"
                )

                shark.destroyed = true

                gameState.gameOver = true

                break
            }

            // ------------------------------------------------------------
            // SHARK IS CLEARLY BEHIND PLAYER
            // ------------------------------------------------------------
            //
            // Only recycle the shark after it is more than the collision
            // radius behind the ship.
            //
            // This gives the collision test a small safety margin.
            //
            // ------------------------------------------------------------

            if sharkPosition.z < shipPosition.z - sharkCollisionRadius {

                shark.destroyed = true

                sharksBehindPlayer.append(shark)

                print(
                    "[TerrainGame] Shark removed behind player " +
                    "sharkZ=\(sharkPosition.z) " +
                    "shipZ=\(shipPosition.z)"
                )
            }
        }

        // ================================================================
        // REMOVE SHARKS THAT PASSED BEHIND PLAYER
        // ================================================================

        if !sharksBehindPlayer.isEmpty {

            gameState.sharks.removeAll { shark in

                sharksBehindPlayer.contains { candidate in
                    candidate === shark
                }
            }
        }

        // ================================================================
        // REMOVE THE SHARK THAT CAUSED GAME OVER
        // ================================================================

        if gameState.gameOver {

            gameState.sharks.removeAll { shark in
                shark.destroyed
            }

            return
        }

        // ================================================================
        // FINAL DESTROYED-SHARK CLEANUP
        // ================================================================

        gameState.sharks.removeAll { shark in
            shark.destroyed
        }
    }

    // =====================================================================
    // 3D DISTANCE
    // =====================================================================

    private static func distance(
        from a: SCNVector3,
        to b: SCNVector3
    ) -> Float {

        let dx = a.x - b.x
        let dy = a.y - b.y
        let dz = a.z - b.z

        return sqrt(
            dx * dx +
            dy * dy +
            dz * dz
        )
    }

    // =====================================================================
    // NORMALIZED 3D DIRECTION
    // =====================================================================

    private static func normalizedDirection(
        from source: SCNVector3,
        to target: SCNVector3
    ) -> SCNVector3 {

        let dx = target.x - source.x
        let dy = target.y - source.y
        let dz = target.z - source.z

        let length = sqrt(
            dx * dx +
            dy * dy +
            dz * dz
        )

        guard length > 0.0001 else {

            return SCNVector3(
                0,
                0,
                1
            )
        }

        return SCNVector3(
            dx / length,
            dy / length,
            dz / length
        )
    }

    // =====================================================================
    // MOVE NODE TOWARD TARGET
    // =====================================================================

    private static func move(
        node: SCNNode,
        toward target: SCNVector3,
        speed: Float,
        dt: Float
    ) {

        let direction = normalizedDirection(
            from: node.presentation.worldPosition,
            to: target
        )

        let movement = speed * dt

        let current = node.position

        node.position = SCNVector3(
            current.x +
                direction.x * movement,

            current.y +
                direction.y * movement,

            current.z +
                direction.z * movement
        )
    }
}
