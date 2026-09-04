//
//  SharkManager.swift
//  Space Drone with Asteroids
//
//  ALIEN OCEAN
//
//  Cellular-Automata Shark Hunting
//

import Foundation
import SceneKit

@MainActor
final class SharkManager {

    // MARK: - Spawn Control

    private var spawnClock: CGFloat = 0.0

    private let spawnInterval: CGFloat = 10.8

    // MARK: - Shark Behavior

    private let minimumSpawnDistance: CGFloat = 35.0
    private let maximumSpawnDistance: CGFloat = 65.0

    private let minimumSpeed: CGFloat = 0.5
    private let maximumSpeed: CGFloat = 2.0

    private let minimumLateralSpeed: CGFloat = -0.45
    private let maximumLateralSpeed: CGFloat = 0.45

    // ================================================================
    // IMMEDIATE HUNT SPEED
    //
    // Sharks accelerate as they approach the spaceship.
    // ================================================================

    private let minimumHuntSpeed: CGFloat = 2.0
    private let maximumHuntSpeed: CGFloat = 5.0

    // MARK: - Ocean Bounds

    private let minimumOceanY: CGFloat = 1.5
    private let maximumOceanY: CGFloat = 8.0

    private let minimumOceanX: CGFloat = -7.0
    private let maximumOceanX: CGFloat = 7.0

    // MARK: - Cellular Automata

    // Size of each hunting cell.
    private let cellSize: CGFloat = 2.0

    // ================================================================
    // FASTER CELLULAR UPDATES
    //
    // The previous value was 0.65 seconds.
    //
    // That made the shark wait too long before correcting its course.
    // ================================================================

    private let cellularStepTime: CGFloat = 0.20

    // Active hunting range.
    private let huntingRange: CGFloat = 100.0

    // ================================================================
    // RANDOMNESS
    //
    // Kept low because this shark is a predator.
    // It should seek the spaceship immediately.
    // ================================================================

    private let randomMovementProbability: CGFloat = 0.04

    // MARK: - Cellular State

    private var cellularTimers:
        [ObjectIdentifier: CGFloat] = [:]

    private var cellularDirections:
        [ObjectIdentifier: SCNVector3] = [:]

    // MARK: - Update

    func update(
        game: GameState,
        dt: CGFloat
    ) {

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

        spawnClock = 0.0

        spawnShark(
            game: game
        )
    }

    // MARK: - Spawn Shark

    private func spawnShark(
        game: GameState
    ) {

        let shipPosition =
            game.spaceShip.position

        let shipX =
            CGFloat(shipPosition.x)

        let shipY =
            CGFloat(shipPosition.y)

        let shipZ =
            CGFloat(shipPosition.z)

        // ============================================================
        // RANDOM SPAWN POSITION
        // ============================================================

        let spawnX =
            CGFloat.random(
                in:
                    minimumOceanX...maximumOceanX
            )

        let spawnY =
            CGFloat.random(
                in:
                    minimumOceanY...maximumOceanY
            )

        let spawnDistance =
            CGFloat.random(
                in:
                    minimumSpawnDistance...maximumSpawnDistance
            )

        // ============================================================
        // SHARK ALWAYS SPAWNS IN FRONT OF SHIP
        //
        // Positive Z = ahead
        // Negative Z = toward spaceship
        // ============================================================

        let spawnZ =
            shipZ + spawnDistance

        // ============================================================
        // CREATE SHARK
        // ============================================================

        let angle =
            atan2(
                spawnY,
                spawnX
            )

        let shark =
            Shark(
                position:
                    SCNVector3(
                        Float(spawnX),
                        Float(spawnY),
                        Float(spawnZ)
                    ),

                lateralAngle:
                    angle,

                animPhase:
                    Float.random(
                        in:
                            0...(Float.pi * 2.0)
                    ),

                destroyed:
                    false,

                forwardSpeed:
                    CGFloat.random(
                        in:
                            minimumSpeed...maximumSpeed
                    ),

                lateralSpeed:
                    CGFloat.random(
                        in:
                            minimumLateralSpeed...maximumLateralSpeed
                    ),

                z:
                    spawnZ
            )

        game.sharks.append(
            shark
        )

        // ============================================================
        // CELLULAR STATE
        // ============================================================

        let id =
            ObjectIdentifier(shark)

        cellularTimers[id] =
            0.0

        // ============================================================
        // IMPORTANT:
        //
        // DO NOT START THE SHARK MOVING STRAIGHT -Z ONLY.
        //
        // Calculate the actual direction from the shark's spawn
        // position directly toward the spaceship.
        // ============================================================

        let direction =
            directionToShip(
                sharkPosition:
                    shark.position,
                shipPosition:
                    shipPosition
            )

        cellularDirections[id] =
            direction

        // ============================================================
        // DEBUG
        // ============================================================

        let distance =
            distanceBetween(
                shark.position,
                shipPosition
            )

        print(
            "================================================"
        )

        print(
            "SHARK SPAWNED"
        )

        print(
            "Ship Position: \(shipPosition)"
        )

        print(
            "Shark Position: \(shark.position)"
        )

        print(
            "Distance: \(distance)"
        )

        print(
            "Initial Hunt Direction: " +
            "(\(direction.x), " +
            "\(direction.y), " +
            "\(direction.z))"
        )

        print(
            "================================================"
        )
    }

    // MARK: - Shark Behavior

    private func updateSharks(
        game: GameState,
        dt: CGFloat
    ) {

        for shark in game.sharks {

            guard !shark.destroyed else {
                continue
            }

            // ========================================================
            // CELLULAR HUNTING
            //
            // This is now the primary movement system.
            // ========================================================

            updateCellularHunting(
                shark: shark,
                game: game,
                dt: dt
            )

            // ========================================================
            // OCEAN BOUNDARIES
            // ========================================================

            applyOceanBounds(
                shark: shark
            )
        }
    }

    // MARK: - Cellular Hunting

    private func updateCellularHunting(
        shark: Shark,
        game: GameState,
        dt: CGFloat
    ) {

        let id =
            ObjectIdentifier(shark)

        var timer =
            cellularTimers[id] ?? 0.0

        timer += dt

        // ============================================================
        // CURRENT HUNTING DIRECTION
        // ============================================================

        var direction =
            cellularDirections[id]
            ??
            directionToShip(
                sharkPosition:
                    shark.position,
                shipPosition:
                    game.spaceShip.position
            )

        // ============================================================
        // CURRENT DISTANCE TO SPACESHIP
        // ============================================================

        let distance =
            distanceBetween(
                shark.position,
                game.spaceShip.position
            )

        // ============================================================
        // HUNTING FACTOR
        //
        // 0 = far away
        // 1 = very close
        // ============================================================

        let huntingFactor =
            max(
                0.0,
                min(
                    1.0,
                    1.0 -
                    distance /
                    huntingRange
                )
            )

        // ============================================================
        // IMMEDIATE TARGET CORRECTION
        //
        // The shark always knows where the spaceship is.
        //
        // This prevents the shark from drifting away between
        // cellular state changes.
        // ============================================================

        let directTargetDirection =
            directionToShip(
                sharkPosition:
                    shark.position,
                shipPosition:
                    game.spaceShip.position
            )

        // ============================================================
        // BLEND CURRENT CELL WITH TARGET
        //
        // As the shark gets closer, the direct target direction
        // becomes dominant.
        // ============================================================

        let targetStrength =
            0.65 +
            huntingFactor *
            0.35

        direction =
            blendDirections(
                current:
                    direction,
                target:
                    directTargetDirection,
                targetWeight:
                    targetStrength
            )

        cellularDirections[id] =
            direction

        // ============================================================
        // SPEED
        //
        // Shark becomes faster while hunting.
        // ============================================================

        let huntSpeed =
            minimumHuntSpeed +
            (
                maximumHuntSpeed -
                minimumHuntSpeed
            ) *
            huntingFactor

        let baseSpeed =
            max(
                shark.forwardSpeed,
                minimumSpeed
            )

        let movementSpeed =
            max(
                baseSpeed,
                huntSpeed
            )

        // ============================================================
        // MOVE SHARK
        // ============================================================

        shark.position.x +=
            direction.x *
            Float(
                movementSpeed *
                dt
            )

        shark.position.y +=
            direction.y *
            Float(
                movementSpeed *
                dt
            )

        shark.position.z +=
            direction.z *
            Float(
                movementSpeed *
                dt
            )

        // ============================================================
        // CELLULAR STATE UPDATE
        // ============================================================

        if timer >= cellularStepTime {

            timer = 0.0

            let newDirection =
                chooseNextCellularDirection(
                    shark:
                        shark,
                    game:
                        game
                )

            cellularDirections[id] =
                newDirection

            direction =
                newDirection
        }

        cellularTimers[id] =
            timer

        // ============================================================
        // ATTACK DEBUG
        // ============================================================

        if distance < 15.0 {

            print(
                "SHARK ATTACK RANGE | " +
                "Distance: \(distance) | " +
                "Hunt Factor: \(huntingFactor)"
            )
        }
    }

    // MARK: - Cellular Automata Rule

    private func chooseNextCellularDirection(
        shark: Shark,
        game: GameState
    ) -> SCNVector3 {

        let sharkPosition =
            shark.position

        let shipPosition =
            game.spaceShip.position

        let directDirection =
            directionToShip(
                sharkPosition:
                    sharkPosition,
                shipPosition:
                    shipPosition
            )

        let distance =
            distanceBetween(
                sharkPosition,
                shipPosition
            )

        // ============================================================
        // SIX CELLULAR NEIGHBORS
        // ============================================================

        let neighbors:
            [(Int, Int, Int)] = [

                ( 1, 0, 0),
                (-1, 0, 0),

                ( 0, 1, 0),
                ( 0,-1, 0),

                ( 0, 0, 1),
                ( 0, 0,-1)
            ]

        let currentCell =
            worldToCell(
                sharkPosition
            )

        var bestDirection =
            directDirection

        var bestScore =
            -CGFloat.greatestFiniteMagnitude

        // ============================================================
        // HUNTING FACTOR
        // ============================================================

        let huntingFactor =
            max(
                0.0,
                min(
                    1.0,
                    1.0 -
                    distance /
                    huntingRange
                )
            )

        // ============================================================
        // EVALUATE CELLS
        // ============================================================

        for neighbor in neighbors {

            let nextCell =
                (
                    currentCell.x +
                        neighbor.0,

                    currentCell.y +
                        neighbor.1,

                    currentCell.z +
                        neighbor.2
                )

            let candidatePosition =
                cellToWorld(
                    nextCell
                )

            // ========================================================
            // OCEAN BOUNDS
            // ========================================================

            if CGFloat(
                candidatePosition.x
            ) < minimumOceanX {

                continue
            }

            if CGFloat(
                candidatePosition.x
            ) > maximumOceanX {

                continue
            }

            if CGFloat(
                candidatePosition.y
            ) < minimumOceanY {

                continue
            }

            if CGFloat(
                candidatePosition.y
            ) > maximumOceanY {

                continue
            }

            // ========================================================
            // CELL DIRECTION
            // ========================================================

            let candidateDirection =
                SCNVector3(
                    Float(neighbor.0),
                    Float(neighbor.1),
                    Float(neighbor.2)
                )

            // ========================================================
            // ALIGNMENT WITH SHIP
            // ========================================================

            let alignment =
                dotProduct(
                    candidateDirection,
                    directDirection
                )

            // ========================================================
            // DISTANCE FROM CELL TO SHIP
            // ========================================================

            let candidateDistance =
                distanceBetween(
                    candidatePosition,
                    shipPosition
                )

            // ========================================================
            // SCORE
            // ========================================================

            var score =
                0.0

            // Strong reward for moving toward ship.
            score +=
                max(
                    0.0,
                    alignment
                ) *
                (
                    10.0 +
                    huntingFactor *
                    30.0
                )

            // Strong penalty for moving away.
            score +=
                min(
                    0.0,
                    alignment
                ) *
                (
                    8.0 +
                    huntingFactor *
                    25.0
                )

            // Prefer cells closer to ship.
            score +=
                1.0 /
                (
                    1.0 +
                    candidateDistance
                ) *
                10.0

            // ========================================================
            // CLOSE ATTACK BONUS
            // ========================================================

            if distance < 20.0 {

                score +=
                    max(
                        0.0,
                        alignment
                    ) *
                    30.0
            }

            if distance < 10.0 {

                score +=
                    max(
                        0.0,
                        alignment
                    ) *
                    60.0
            }

            if distance < 5.0 {

                score +=
                    max(
                        0.0,
                        alignment
                    ) *
                    100.0
            }

            // ========================================================
            // VERY SMALL RANDOM COMPONENT
            //
            // The shark remains somewhat unpredictable,
            // but it does NOT abandon the spaceship.
            // ========================================================

            let randomAmount =
                CGFloat.random(
                    in:
                        -randomMovementProbability...randomMovementProbability
                )

            score +=
                randomAmount

            // ========================================================
            // BEST CELL
            // ========================================================

            if score > bestScore {

                bestScore =
                    score

                bestDirection =
                    candidateDirection
            }
        }

        return normalizeDirection(
            bestDirection
        )
    }

    // MARK: - Direction To Ship

    private func directionToShip(
        sharkPosition: SCNVector3,
        shipPosition: SCNVector3
    ) -> SCNVector3 {

        let dx =
            CGFloat(shipPosition.x) -
            CGFloat(sharkPosition.x)

        let dy =
            CGFloat(shipPosition.y) -
            CGFloat(sharkPosition.y)

        let dz =
            CGFloat(shipPosition.z) -
            CGFloat(sharkPosition.z)

        let length =
            sqrt(
                dx * dx +
                dy * dy +
                dz * dz
            )

        guard length > 0.001 else {

            return SCNVector3(
                0,
                0,
                -1
            )
        }

        return SCNVector3(

            Float(
                dx / length
            ),

            Float(
                dy / length
            ),

            Float(
                dz / length
            )
        )
    }

    // MARK: - Blend Directions

    private func blendDirections(
        current: SCNVector3,
        target: SCNVector3,
        targetWeight: CGFloat
    ) -> SCNVector3 {

        let currentWeight =
            max(
                0.0,
                1.0 -
                targetWeight
            )

        let x =
            CGFloat(current.x) *
            currentWeight
            +
            CGFloat(target.x) *
            targetWeight

        let y =
            CGFloat(current.y) *
            currentWeight
            +
            CGFloat(target.y) *
            targetWeight

        let z =
            CGFloat(current.z) *
            currentWeight
            +
            CGFloat(target.z) *
            targetWeight

        return normalizeDirection(
            SCNVector3(
                Float(x),
                Float(y),
                Float(z)
            )
        )
    }

    // MARK: - Distance

    private func distanceBetween(
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> CGFloat {

        let dx =
            CGFloat(a.x) -
            CGFloat(b.x)

        let dy =
            CGFloat(a.y) -
            CGFloat(b.y)

        let dz =
            CGFloat(a.z) -
            CGFloat(b.z)

        return sqrt(
            dx * dx +
            dy * dy +
            dz * dz
        )
    }

    // MARK: - Dot Product

    private func dotProduct(
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> CGFloat {

        return
            CGFloat(a.x) *
            CGFloat(b.x)
            +
            CGFloat(a.y) *
            CGFloat(b.y)
            +
            CGFloat(a.z) *
            CGFloat(b.z)
    }

    // MARK: - World → Cell

    private func worldToCell(
        _ position: SCNVector3
    ) -> (
        x: Int,
        y: Int,
        z: Int
    ) {

        return (

            Int(
                floor(
                    CGFloat(position.x) /
                    cellSize
                )
            ),

            Int(
                floor(
                    CGFloat(position.y) /
                    cellSize
                )
            ),

            Int(
                floor(
                    CGFloat(position.z) /
                    cellSize
                )
            )
        )
    }

    // MARK: - Cell → World

    private func cellToWorld(
        _ cell: (
            x: Int,
            y: Int,
            z: Int
        )
    ) -> SCNVector3 {

        return SCNVector3(

            Float(
                (
                    CGFloat(cell.x) +
                    0.5
                ) *
                cellSize
            ),

            Float(
                (
                    CGFloat(cell.y) +
                    0.5
                ) *
                cellSize
            ),

            Float(
                (
                    CGFloat(cell.z) +
                    0.5
                ) *
                cellSize
            )
        )
    }

    // MARK: - Normalize Direction

    private func normalizeDirection(
        _ direction: SCNVector3
    ) -> SCNVector3 {

        let x =
            CGFloat(direction.x)

        let y =
            CGFloat(direction.y)

        let z =
            CGFloat(direction.z)

        let length =
            sqrt(
                x * x +
                y * y +
                z * z
            )

        guard length > 0.001 else {

            return SCNVector3(
                0,
                0,
                -1
            )
        }

        return SCNVector3(

            Float(
                x / length
            ),

            Float(
                y / length
            ),

            Float(
                z / length
            )
        )
    }

    // MARK: - Ocean Bounds

    private func applyOceanBounds(
        shark: Shark
    ) {

        var position =
            shark.position

        if CGFloat(position.x) <
            minimumOceanX {

            position.x =
                Float(
                    minimumOceanX
                )
        }

        if CGFloat(position.x) >
            maximumOceanX {

            position.x =
                Float(
                    maximumOceanX
                )
        }

        if CGFloat(position.y) <
            minimumOceanY {

            position.y =
                Float(
                    minimumOceanY
                )
        }

        if CGFloat(position.y) >
            maximumOceanY {

            position.y =
                Float(
                    maximumOceanY
                )
        }

        shark.position =
            position
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

            let id =
                ObjectIdentifier(
                    shark
                )

            if shark.destroyed {

                cellularTimers.removeValue(
                    forKey:
                        id
                )

                cellularDirections.removeValue(
                    forKey:
                        id
                )

                return true
            }

            let sharkZ =
                CGFloat(
                    shark.position.z
                )

            // ========================================================
            // SHARK HAS PASSED THE SHIP
            // ========================================================

            if sharkZ <
                shipZ - 20.0 {

                cellularTimers.removeValue(
                    forKey:
                        id
                )

                cellularDirections.removeValue(
                    forKey:
                        id
                )

                return true
            }

            // ========================================================
            // SHARK IS TOO FAR AHEAD
            // ========================================================

            if sharkZ >
                shipZ + 100.0 {

                cellularTimers.removeValue(
                    forKey:
                        id
                )

                cellularDirections.removeValue(
                    forKey:
                        id
                )

                return true
            }

            return false
        }
    }

    // MARK: - Reset

    func reset(
        game: GameState
    ) {

        spawnClock =
            0.0

        cellularTimers.removeAll()

        cellularDirections.removeAll()

        game.sharks.removeAll()
    }
}
