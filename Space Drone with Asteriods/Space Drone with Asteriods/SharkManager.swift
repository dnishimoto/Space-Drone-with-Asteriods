

import Foundation
import SceneKit

@MainActor
final class SharkManager {

    // MARK: - Spawn Control

    private var spawnClock: CGFloat = 0

    private let spawnInterval: CGFloat = 2.8

    // MARK: - Shark Behavior

    private let minimumSpawnDistance: CGFloat = 35.0
    private let maximumSpawnDistance: CGFloat = 65.0

    private let minimumSpeed: CGFloat = 0.5
    private let maximumSpeed: CGFloat = 2.0

    private let minimumLateralSpeed: CGFloat = -0.45
    private let maximumLateralSpeed: CGFloat = 0.45

    // Ocean bounds
    private let minimumOceanY: CGFloat = 1.5
    private let maximumOceanY: CGFloat = 8.0

    private let minimumOceanX: CGFloat = -7.0
    private let maximumOceanX: CGFloat = 7.0

    // MARK: - Update

    func update(
        game: GameState,
        dt: CGFloat
    ) {
        guard game.currentSection == .ocean else {
            return
        }

        updateSpawning(
            game: game,
            dt: dt
        )

        updateSharks(
            game: game,
            dt: dt
        )

        removeInactiveSharks(
            game: game
        )
    }

    // MARK: - Spawning

    private func updateSpawning(
        game: GameState,
        dt: CGFloat
    ) {
        spawnClock += dt

        guard spawnClock >= spawnInterval else {
            return
        }

        spawnClock -= spawnInterval

        spawnShark(
            game: game
        )
    }

    private func spawnShark(
        game: GameState
    ) {
        let spawnX = CGFloat.random(
            in: minimumOceanX...maximumOceanX
        )

        let spawnY = CGFloat.random(
            in: minimumOceanY...maximumOceanY
        )

        let spawnDistance = CGFloat.random(
            in:
                minimumSpawnDistance...maximumSpawnDistance
        )

        let spawnZ =
            game.spaceShip.position.z +
            SCNFloat(spawnDistance)

        let angle =
            atan2(
                spawnY,
                spawnX
            )

        let shark = Shark(
            position: SCNVector3(
                Float(spawnX),
                Float(spawnY),
                Float(spawnZ)
            ),
            lateralAngle: angle,
            animPhase: Float.random(
                in: 0...(Float.pi * 2.0)
            ),
            destroyed: false,
            forwardSpeed: CGFloat.random(
                in:
                    minimumSpeed...maximumSpeed
            ),
            lateralSpeed: CGFloat.random(
                in:
                    minimumLateralSpeed...maximumLateralSpeed
            ),
            z: CGFloat(spawnZ)
        )

        game.sharks.append(shark)
    }

    // MARK: - Shark Behavior

    private func updateSharks(
        game: GameState,
        dt: CGFloat
    ) {
        let playerAngle =
            game.spaceShip.lateralAngle

        for shark in game.sharks {

            guard !shark.destroyed else {
                continue
            }

            shark.update(
                dt: dt,
                shipSpeed:
                    game.spaceShip.forwardSpeed,
                playerAngle:
                    playerAngle
            )

            applyOceanBounds(
                shark: shark,
                dt: dt
            )

            applyHuntingBehavior(
                shark: shark,
                game: game,
                dt: dt
            )
        }
    }

    // MARK: - Ocean Boundaries

    private func applyOceanBounds(
        shark: Shark,
        dt: CGFloat
    ) {
        var position = shark.position

        // Keep shark inside the left/right ocean boundaries.

        if CGFloat(position.x) < minimumOceanX {
            position.x =
                Float(minimumOceanX)

            shark.lateralSpeed =
                abs(shark.lateralSpeed)
        }

        if CGFloat(position.x) > maximumOceanX {
            position.x =
                Float(maximumOceanX)

            shark.lateralSpeed =
                -abs(shark.lateralSpeed)
        }

        // Keep shark below the cloud ceiling.

        if CGFloat(position.y) > maximumOceanY {
            position.y =
                Float(maximumOceanY)

            shark.position = position
        }

        // Keep shark above the ocean floor/water boundary.

        if CGFloat(position.y) < minimumOceanY {
            position.y =
                Float(minimumOceanY)

            shark.position = position
        }

        shark.position = position
    }

    // MARK: - Hunting Behavior

    private func applyHuntingBehavior(
        shark: Shark,
        game: GameState,
        dt: CGFloat
    ) {
        let shipPosition =
            game.spaceShip.position

        let sharkPosition =
            shark.position

        let dx =
            CGFloat(shipPosition.x) -
            CGFloat(sharkPosition.x)

        let dy =
            CGFloat(shipPosition.y) -
            CGFloat(sharkPosition.y)

        let distance =
            sqrt(
                dx * dx +
                dy * dy
            )

        guard distance > 0.001 else {
            return
        }

        // Normalize direction toward the ship.

        let directionX =
            dx / distance

        let directionY =
            dy / distance

        // Sharks become more aggressive when close.

        let huntingRange: CGFloat = 18.0

        guard distance < huntingRange else {
            return
        }

        let huntingStrength =
            max(
                0.0,
                min(
                    1.0,
                    1.0 -
                    distance / huntingRange
                )
            )

        // Increase lateral movement toward the ship.

        let steering =
            huntingStrength *
            1.8 *
            dt

        shark.position.x +=
            Float(
                directionX *
                steering
            )

        shark.position.y +=
            Float(
                directionY *
                steering
            )

        // A shark that is close to the ship
        // accelerates its attack.

        if distance < 10.0 {

            shark.forwardSpeed +=
                0.8 *
                huntingStrength *
                dt

            shark.forwardSpeed =
                min(
                    shark.forwardSpeed,
                    3.5
                )
        }
    }

    // MARK: - Removal

    private func removeInactiveSharks(
        game: GameState
    ) {
        let shipZ =
            CGFloat(
                game.spaceShip.position.z
            )

        game.sharks.removeAll { shark in

            if shark.destroyed {
                return true
            }

            let sharkZ =
                CGFloat(
                    shark.position.z
                )

            // Shark has passed far behind the ship.

            if sharkZ <
                shipZ - 20.0 {
                return true
            }

            // Shark somehow moved extremely far ahead.

            if sharkZ >
                shipZ + 100.0 {
                return true
            }

            return false
        }
    }

    // MARK: - Reset

    func reset(
        game: GameState
    ) {
        spawnClock = 0

        game.sharks.removeAll()
    }
}
