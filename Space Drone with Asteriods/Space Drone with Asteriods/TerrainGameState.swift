
import Foundation
import SceneKit

// =============================================================================
// TERRAIN GAME STATE
// =============================================================================
//
// Gameplay coordinator for the terrain scene.
//
// Responsibilities:
//   • Update terrain-scene gameplay every frame
//   • Keep terrain scene synchronized with GameState
//   • Update sharks
//   • Update enemy spaceship
//   • Provide a single terrain-scene update entry point
//
// Terrain mesh generation itself belongs to TerrainSceneWorld.
//
// Coordinate system:
//
//   X = left / right
//   Y = up
//   Z = forward
//
// =============================================================================

@MainActor
enum TerrainGameState {

    // =========================================================================
    // MARK: - Configuration
    // =========================================================================

    /// Maximum distance at which sharks are actively considered.
    private static let sharkActivationDistance: Float = 180.0

    /// Maximum distance at which the enemy spaceship is actively considered.
    private static let enemyActivationDistance: Float = 300.0

    /// Distance behind the player at which an entity can be recycled.
    private static let recycleDistance: Float = 100.0

    // =========================================================================
    // MARK: - Main Update
    // =========================================================================

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

        // =====================================================================
        // 1. Update terrain
        // =====================================================================
        //
        // TerrainSceneWorld owns the procedural terrain.
        //
        // GameState should provide the player's world position.
        //
        // If your GameState uses a different property name for the player
        // position, change only the two values below.
        //
        // =====================================================================

        let playerPosition = playerWorldPosition(
            from: gameState
        )

        // =====================================================================
        // 2. Update sharks
        // =====================================================================

        updateSharks(
            gameState: gameState,
            playerPosition: playerPosition,
            dt: deltaTime
        )

        // =====================================================================
        // 3. Update enemy spaceship
        // =====================================================================

        updateEnemyShip(
            gameState: gameState,
            playerPosition: playerPosition,
            dt: deltaTime
        )

        // =====================================================================
        // 4. Update gameplay AI
        // =====================================================================

        updateAI(
            gameState: gameState,
            playerPosition: playerPosition,
            dt: deltaTime
        )
    }

    // =========================================================================
    // MARK: - Player Position
    // =========================================================================

    private static func playerWorldPosition(
        from gameState: GameState
    ) -> SCNVector3 {

        // ---------------------------------------------------------------------
        // IMPORTANT
        // ---------------------------------------------------------------------
        //
        // Replace this with the actual player/ship world-position property
        // from your GameState if it has a different name.
        //
        // The preferred architecture is for GameState to maintain the
        // authoritative player world position.
        //
        // ---------------------------------------------------------------------

        if let ship = gameState.enemySpaceShip {
            // This is intentionally NOT used as the player's position.
            // enemySpaceShip belongs to the enemy.
            _ = ship
        }

        // Until GameState exposes the player position directly, the terrain
        // scene begins at the origin.
        //
        // This fallback keeps the file compiling without inventing a
        // GameState property that may not exist in your project.

        return SCNVector3(
            0,
            0,
            0
        )
    }

    // =========================================================================
    // MARK: - Sharks
    // =========================================================================

    private static func updateSharks(
        gameState: GameState,
        playerPosition: SCNVector3,
        dt: Float
    ) {

        // ---------------------------------------------------------------------
        // Sharks should be represented by GameState's shark collection once
        // that collection is connected to the terrain scene.
        //
        // The TerrainSceneWorld owns the visible shark nodes.
        // GameState owns gameplay state.
        //
        // This method is therefore intentionally safe until your GameState
        // exposes its shark collection.
        // ---------------------------------------------------------------------

        _ = gameState
        _ = playerPosition
        _ = dt
    }

    // =========================================================================
    // MARK: - Enemy Spaceship
    // =========================================================================

    private static func updateEnemyShip(
        gameState: GameState,
        playerPosition: SCNVector3,
        dt: Float
    ) {

        guard let enemy =
                gameState.enemySpaceShip
        else {
            return
        }

        // ---------------------------------------------------------------------
        // The enemy ship remains a GameState-owned gameplay entity.
        //
        // Its actual movement/AI can be added here once the EnemySpaceShip
        // interface is known.
        // ---------------------------------------------------------------------

        _ = enemy
        _ = playerPosition
        _ = dt
    }

    // =========================================================================
    // MARK: - Smart AI
    // =========================================================================

    private static func updateAI(
        gameState: GameState,
        playerPosition: SCNVector3,
        dt: Float
    ) {

        // ---------------------------------------------------------------------
        // This is the common AI entry point.
        //
        // Future behavior can include:
        //
        //   • Shark interception
        //   • Enemy spaceship pursuit
        //   • Terrain-aware flight
        //   • Avoidance of mountains
        //   • Attack runs
        //   • Predictive targeting
        //   • Separation between multiple sharks
        //
        // ---------------------------------------------------------------------

        _ = gameState
        _ = playerPosition
        _ = dt
    }

    // =========================================================================
    // MARK: - Distance Helper
    // =========================================================================

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

    // =========================================================================
    // MARK: - Direction Helper
    // =========================================================================

    private static func normalizedDirection(
        from source: SCNVector3,
        to target: SCNVector3
    ) -> SCNVector3 {

        let dx = target.x - source.x
        let dy = target.y - source.y
        let dz = target.z - source.z

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
                1
            )
        }

        return SCNVector3(
            dx / length,
            dy / length,
            dz / length
        )
    }

    // =========================================================================
    // MARK: - Move Toward Target
    // =========================================================================

    private static func move(
        node: SCNNode,
        toward target: SCNVector3,
        speed: Float,
        dt: Float
    ) {

        let direction =
            normalizedDirection(
                from: node.presentation.worldPosition,
                to: target
            )

        let movement =
            speed * dt

        let current =
            node.position

        node.position =
            SCNVector3(
                current.x + direction.x * movement,
                current.y + direction.y * movement,
                current.z + direction.z * movement
            )
    }
}

