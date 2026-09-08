//
//  SharkManager.swift
//  Space Drone with Asteroids
//
//  ALIEN OCEAN / TERRAIN
//
//  Cellular-Automata Shark Hunting
//  Terrain Feeding-Frenzy Cellular Automaton
//

import Foundation
import SceneKit

// ============================================================
// OPTIONAL SHIP POSITION PROVIDER
// ============================================================

protocol ShipPositionProvider {
    var shipPositionY: CGFloat { get }
}

// ============================================================
// SHARK MANAGER
// ============================================================

@MainActor
final class SharkManager {

    // ============================================================
    // SPAWN CONTROL
    // ============================================================

    private var spawnClock: CGFloat = 0.0
    private let spawnInterval: CGFloat = 5.8

    // ============================================================
    // SHARK BEHAVIOR
    // ============================================================

    private let minimumSpawnDistance: CGFloat = 65.0
    private let maximumSpawnDistance: CGFloat = 95.0

    private let minimumSpeed: CGFloat = 0.5
    private let maximumSpeed: CGFloat = 2.0

    private let minimumLateralSpeed: CGFloat = -0.45
    private let maximumLateralSpeed: CGFloat = 0.45

    // ============================================================
    // IMMEDIATE HUNT SPEED
    // ============================================================

    private let minimumHuntSpeed: CGFloat = 2.0
    private let maximumHuntSpeed: CGFloat = 5.0

    // ============================================================
    // OCEAN BOUNDS
    // ============================================================

    private let minimumOceanY: CGFloat = -1.5
    private let maximumOceanY: CGFloat = 8.0

    private let minimumOceanX: CGFloat = -7.0
    private let maximumOceanX: CGFloat = 7.0

    // ============================================================
    // TERRAIN BOUNDS
    // ============================================================
    //
    // IMPORTANT:
    //
    // X is bounded because the terrain has a finite width.
    //
    // Z IS NOT BOUNDED.
    //
    // The terrain extends forward with the ship, so sharks must
    // be able to travel continuously along Z.
    //
    // ============================================================

    private let minimumTerrainX: CGFloat = -36.0
    private let maximumTerrainX: CGFloat = 36.0

    // Retained for compatibility.
    // These are NOT used as terrain movement limits.
    private let minimumTerrainY: CGFloat = 0.0
    private let maximumTerrainY: CGFloat = 40.0

    // ============================================================
    // TERRAIN SHARK CLEARANCE
    // ============================================================

    private let terrainSharkClearance: CGFloat = 3.5
    private let fallbackTerrainHeight: CGFloat = 0.0

    // ============================================================
    // TERRAIN HEIGHT PROVIDER
    // ============================================================

    private var terrainHeightProvider:
        ((CGFloat, CGFloat) -> CGFloat)?

    // ============================================================
    // CELLULAR AUTOMATA
    // ============================================================

    private let cellSize: CGFloat = 2.0
    private let cellularStepTime: CGFloat = 0.20
    private let huntingRange: CGFloat = 200.0
    private let randomMovementProbability: CGFloat = 0.04

    // ============================================================
    // TERRAIN FEEDING FRENZY
    // ============================================================

    private let frenzyRange: CGFloat = 200.0
    private let attackRange: CGFloat = 50.0
    private let swarmRadius: CGFloat = 58.0
    private let sharkSeparationRadius: CGFloat = 3.0

    // ============================================================
    // CELLULAR ATTACK RADII
    // ============================================================

    private let hardPursuitRadius: CGFloat = 50.0
    private let convergenceRadius: CGFloat = 45.0
    private let pursuitRadius: CGFloat = 60.0

    // ============================================================
    // VERTICAL ATTACK CONTROL
    // ============================================================
    //
    // These values control how strongly the cellular automaton
    // responds to the ship's vertical position.
    //
    // A positive vertical error means the ship is above the shark.
    //
    // A negative vertical error means the ship is below the shark.
    //
    // ============================================================

    private let verticalAttackDistance: CGFloat = 8.0
    private let verticalAttackWeight: CGFloat = 1.0

    // ============================================================
    // CELLULAR STATE
    // ============================================================

    private var cellularTimers:
        [ObjectIdentifier: CGFloat] = [:]

    private var cellularDirections:
        [ObjectIdentifier: SCNVector3] = [:]

    // ============================================================
    // TERRAIN HEIGHT CONFIGURATION
    // ============================================================

    func setTerrainHeightProvider(
        _ provider: @escaping (CGFloat, CGFloat) -> CGFloat
    ) {
        terrainHeightProvider = provider
    }

    func clearTerrainHeightProvider() {
        terrainHeightProvider = nil
    }

    // ============================================================
    // GET TERRAIN HEIGHT
    // ============================================================

    private func terrainHeight(
        x: CGFloat,
        z: CGFloat
    ) -> CGFloat {

        if let provider = terrainHeightProvider {
            let height = provider(x, z)

            if height.isFinite {
                return height
            }
        }

        return fallbackTerrainHeight
    }

    // ============================================================
    // UPDATE
    // ============================================================

    func update(
        game: GameState,
        dt: CGFloat
    ) {

        guard dt.isFinite, dt > 0.0 else {
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

    // ============================================================
    // SPAWNING
    // ============================================================

    private func updateSpawning(
        game: GameState,
        dt: CGFloat
    ) {

        spawnClock += dt

        guard spawnClock >= spawnInterval else {
            return
        }

        spawnClock = 0.0

        let isTerrain =
            game.currentSection == .terrain

        if isTerrain {

            for _ in 0..<20 {
                spawnShark(
                    game: game
                )
            }

        } else {

            spawnShark(
                game: game
            )
        }
    }

    // ============================================================
    // SPAWN SHARK
    // ============================================================

    private func spawnShark(
        game: GameState
    ) {

        let shipPosition =
            game.spaceShip.position

        let shipY =
            CGFloat(shipPosition.y)

        let shipZ =
            CGFloat(shipPosition.z)

        let isTerrain =
            game.currentSection == .terrain

        // ========================================================
        // RANDOM X
        // ========================================================

        let spawnX: CGFloat

        if isTerrain {

            spawnX = CGFloat.random(
                in:
                    minimumTerrainX...maximumTerrainX
            )

        } else {

            spawnX = CGFloat.random(
                in:
                    minimumOceanX...maximumOceanX
            )
        }

        // ========================================================
        // SPAWN DISTANCE
        // ========================================================

        let spawnDistance =
            CGFloat.random(
                in:
                    minimumSpawnDistance...maximumSpawnDistance
            )

        // ========================================================
        // SHARK SPAWN Z
        //
        // Positive Z is ahead of the ship.
        // ========================================================

        let spawnZ =
            shipZ +
            spawnDistance

        // ========================================================
        // SPAWN Y
        // ========================================================

        let spawnY: CGFloat

        if isTerrain {

            // ====================================================
            // SAMPLE TERRAIN AT ACTUAL SHARK LOCATION
            // ====================================================

            let terrainY =
                terrainHeight(
                    x: spawnX,
                    z: spawnZ
                )

            let terrainMinimumY =
                terrainY +
                terrainSharkClearance

            // ====================================================
            // SPAWN ABOVE THE SHIP'S CURRENT HEIGHT
            //
            // This prevents terrain sharks from initially spawning
            // underneath the ship.
            // ====================================================

            let shipMinimumY =
                shipY +
                CGFloat.random(
                    in: 1.0...6.0
                )

            spawnY =
                max(
                    terrainMinimumY,
                    shipMinimumY
                )

        } else {

            spawnY =
                CGFloat.random(
                    in:
                        minimumOceanY...maximumOceanY
                )
        }

        // ========================================================
        // INITIAL ANGLE
        // ========================================================

        let angle =
            atan2(
                spawnY,
                spawnX
            )

        // ========================================================
        // CREATE SHARK
        // ========================================================

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
                            0.0...(Float.pi * 2.0)
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

        // ========================================================
        // FINAL TERRAIN CLEARANCE
        // ========================================================

        if isTerrain {
            enforceTerrainClearance(
                shark: shark
            )
        }

        // ========================================================
        // DEBUG INFORMATION
        // ========================================================

        let actualTerrainY =
            terrainHeight(
                x:
                    CGFloat(
                        shark.position.x
                    ),
                z:
                    CGFloat(
                        shark.position.z
                    )
            )

        print(
            """
            [SharkManager] SPAWN
              Shark:   x=\(shark.position.x), y=\(shark.position.y), z=\(shark.position.z)
              Ship:    x=\(shipPosition.x), y=\(shipPosition.y), z=\(shipPosition.z)
              Terrain: y=\(actualTerrainY)
              Clearance: \(terrainSharkClearance)
              Shark above terrain: \(CGFloat(shark.position.y) >= actualTerrainY + terrainSharkClearance)
              Terrain section: \(isTerrain)
            """
        )

        // ========================================================
        // ADD SHARK
        // ========================================================

        game.sharks.append(
            shark
        )

        // ========================================================
        // INITIAL CELLULAR STATE
        // ========================================================

        let id =
            ObjectIdentifier(
                shark
            )

        cellularTimers[id] = 0.0

        let initialDirection =
            directionToShip(
                sharkPosition:
                    shark.position,
                shipPosition:
                    shipPosition
            )

        cellularDirections[id] =
            initialDirection
    }

    // ============================================================
    // UPDATE ALL SHARKS
    // ============================================================

    private func updateSharks(
        game: GameState,
        dt: CGFloat
    ) {

        let isTerrain =
            game.currentSection == .terrain

        let shipPosition =
            game.spaceShip.position

        for shark in game.sharks {

            guard !shark.destroyed else {
                continue
            }

            // ====================================================
            // UPDATE MOVEMENT
            // ====================================================

            updateCellularHunting(
                shark: shark,
                game: game,
                dt: dt
            )

            // ====================================================
            // SCENE BOUNDS
            // ====================================================

            if isTerrain {

                applyTerrainBounds(
                    shark: shark
                )

            } else {

                applyOceanBounds(
                    shark: shark
                )
            }

            // ====================================================
            // FINAL COLLISION CHECK
            //
            // This check occurs AFTER movement so a shark cannot
            // move through the ship and wait until the next frame
            // to register the collision.
            // ====================================================

            let collisionRadius: CGFloat = 2.5

            let distanceToShip =
                distanceBetween(
                    shark.position,
                    shipPosition
                )

            if distanceToShip <= collisionRadius {

                print(
                    """
                    [SharkManager] SHARK HIT SHIP
                      Shark:
                        x=\(shark.position.x)
                        y=\(shark.position.y)
                        z=\(shark.position.z)

                      Ship:
                        x=\(shipPosition.x)
                        y=\(shipPosition.y)
                        z=\(shipPosition.z)

                      Distance:
                        \(distanceToShip)
                    """
                )

                shark.destroyed = true
            }
        }
    }

    // ============================================================
    // CELLULAR HUNTING
    // ============================================================

    private func updateCellularHunting(
        shark: Shark,
        game: GameState,
        dt: CGFloat
    ) {

        let id =
            ObjectIdentifier(
                shark
            )

        var timer =
            cellularTimers[id] ?? 0.0

        timer += dt

        let shipPosition =
            game.spaceShip.position

        let distanceToShip =
            distanceBetween(
                shark.position,
                shipPosition
            )

        // ========================================================
        // TERRAIN CELLULAR HUNTING
        // ========================================================

        if game.currentSection == .terrain {

            // ====================================================
            // UPDATE CELLULAR DECISION
            // ====================================================

            if timer >= cellularStepTime {

                timer = 0.0

                cellularDirections[id] =
                    feedingFrenzyDirection(
                        shark: shark,
                        game: game
                    )
            }

            // ====================================================
            // GET CURRENT CELLULAR DIRECTION
            // ====================================================

            let cellularDirection =
                cellularDirections[id]
                ?? directionToShip(
                    sharkPosition:
                        shark.position,
                    shipPosition:
                        shipPosition
                )

            // ====================================================
            // ALWAYS APPLY CURRENT 3D ATTACK CORRECTION
            //
            // This is important.
            //
            // The cellular direction is allowed to determine
            // local movement, but the ship remains the target.
            //
            // This prevents the shark from selecting a cellular
            // direction that causes it to pass underneath or
            // above the ship.
            // ====================================================

            let finalDirection =
                attackCorrectedDirection(
                    cellularDirection:
                        cellularDirection,
                    sharkPosition:
                        shark.position,
                    shipPosition:
                        shipPosition,
                    distanceToShip:
                        distanceToShip
                )

            // ====================================================
            // FRENZY FACTOR
            // ====================================================

            let frenzyFactor =
                max(
                    0.0,
                    min(
                        1.0,
                        1.0 -
                        distanceToShip /
                        frenzyRange
                    )
                )

            // ====================================================
            // SPEED
            // ====================================================

            let baseSpeed =
                max(
                    shark.forwardSpeed,
                    minimumSpeed
                )

            let huntSpeed =
                minimumHuntSpeed +
                (
                    maximumHuntSpeed -
                    minimumHuntSpeed
                ) *
                frenzyFactor

            let movementSpeed =
                max(
                    baseSpeed,
                    huntSpeed
                )

            let distanceStep =
                Float(
                    movementSpeed *
                    dt
                )

            // ====================================================
            // MOVE X
            // ====================================================

            shark.position.x +=
                finalDirection.x *
                distanceStep

            // ====================================================
            // MOVE Y
            //
            // This is the important vertical attack movement.
            // ====================================================

            shark.position.y +=
                finalDirection.y *
                distanceStep

            // ====================================================
            // MOVE Z
            // ====================================================

            shark.position.z +=
                finalDirection.z *
                distanceStep

            // ====================================================
            // TERRAIN CLEARANCE
            // ====================================================

            enforceTerrainClearance(
                shark: shark
            )

            cellularTimers[id] =
                timer

            return
        }

        // ========================================================
        // OCEAN CELLULAR HUNTING
        // ========================================================

        if timer >= cellularStepTime {

            timer = 0.0

            cellularDirections[id] =
                chooseNextCellularDirection(
                    shark: shark,
                    game: game
                )
        }

        let cellularDirection =
            cellularDirections[id]
            ?? directionToShip(
                sharkPosition:
                    shark.position,
                shipPosition:
                    shipPosition
            )

        // ========================================================
        // DIRECT 3D SHIP PURSUIT
        // ========================================================

        let directDirection =
            directionToShip(
                sharkPosition:
                    shark.position,
                shipPosition:
                    shipPosition
            )

        // ========================================================
        // TARGET STRENGTH
        // ========================================================

        let huntingFactor =
            max(
                0.0,
                min(
                    1.0,
                    1.0 -
                    distanceToShip /
                    huntingRange
                )
            )

        let targetStrength =
            0.65 +
            huntingFactor *
            0.35

        // ========================================================
        // BLEND CELLULAR DIRECTION WITH DIRECT 3D TARGET
        // ========================================================

        let finalDirection =
            blendDirections(
                current:
                    cellularDirection,
                target:
                    directDirection,
                targetWeight:
                    targetStrength
            )

        // ========================================================
        // SPEED
        // ========================================================

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

        let distanceStep =
            Float(
                movementSpeed *
                dt
            )

        // ========================================================
        // MOVE X
        // ========================================================

        shark.position.x +=
            finalDirection.x *
            distanceStep

        // ========================================================
        // MOVE Y
        // ========================================================

        shark.position.y +=
            finalDirection.y *
            distanceStep

        // ========================================================
        // MOVE Z
        // ========================================================

        shark.position.z +=
            finalDirection.z *
            distanceStep

        cellularTimers[id] =
            timer
    }

    // ============================================================
    // ATTACK CORRECTION
    //
    // This guarantees vertical convergence toward the ship.
    //
    // The cellular automaton still supplies the base direction.
    // The attack correction bends that direction toward the ship.
    // ============================================================

    private func attackCorrectedDirection(
        cellularDirection: SCNVector3,
        sharkPosition: SCNVector3,
        shipPosition: SCNVector3,
        distanceToShip: CGFloat
    ) -> SCNVector3 {

        let directDirection =
            directionToShip(
                sharkPosition:
                    sharkPosition,
                shipPosition:
                    shipPosition
            )

        // ========================================================
        // HARD ATTACK
        // ========================================================

        if distanceToShip <= attackRange {
            return directDirection
        }

        // ========================================================
        // PURSUIT WEIGHT
        // ========================================================

        let pursuitWeight: CGFloat

        if distanceToShip <= hardPursuitRadius {

            pursuitWeight = 0.98

        } else if distanceToShip <= convergenceRadius {

            let t =
                (
                    distanceToShip -
                    hardPursuitRadius
                )
                /
                (
                    convergenceRadius -
                    hardPursuitRadius
                )

            pursuitWeight =
                0.98 -
                (
                    0.13 *
                    t
                )

        } else if distanceToShip <= pursuitRadius {

            let t =
                (
                    distanceToShip -
                    convergenceRadius
                )
                /
                (
                    pursuitRadius -
                    convergenceRadius
                )

            pursuitWeight =
                0.85 -
                (
                    0.20 *
                    t
                )

        } else {

            pursuitWeight = 0.65
        }

        // ========================================================
        // NORMAL CELLULAR/TARGET BLEND
        // ========================================================

        let blended =
            blendDirections(
                current:
                    cellularDirection,
                target:
                    directDirection,
                targetWeight:
                    pursuitWeight
            )

        // ========================================================
        // EXPLICIT VERTICAL CORRECTION
        //
        // This is the critical addition.
        //
        // If:
        //
        // ship Y > shark Y
        //
        // verticalError is positive and the shark climbs.
        //
        // If:
        //
        // ship Y < shark Y
        //
        // verticalError is negative and the shark descends.
        // ========================================================

        let verticalError =
            CGFloat(shipPosition.y) -
            CGFloat(sharkPosition.y)

        let normalizedVerticalError =
            max(
                -1.0,
                min(
                    1.0,
                    verticalError /
                    verticalAttackDistance
                )
            )

        // ========================================================
        // VERTICAL CORRECTION STRENGTH
        // ========================================================

        let verticalCorrectionStrength =
            verticalAttackWeight *
            (
                0.35 +
                0.65 *
                pursuitWeight
            )

        let correctedY =
            CGFloat(blended.y) +
            normalizedVerticalError *
            verticalCorrectionStrength

        let corrected =
            SCNVector3(
                blended.x,
                Float(correctedY),
                blended.z
            )

        return normalizeDirection(
            corrected
        )
    }

    // ============================================================
    // TERRAIN FEEDING FRENZY
    //
    // CELLULAR AUTOMATON + 3D SHIP ATTACK
    // ============================================================

    private func feedingFrenzyDirection(
        shark: Shark,
        game: GameState
    ) -> SCNVector3 {

        let sharkPosition =
            shark.position

        let shipPosition =
            game.spaceShip.position

        // ========================================================
        // DIRECT 3D VECTOR
        // ========================================================

        let directDirection =
            directionToShip(
                sharkPosition:
                    sharkPosition,
                shipPosition:
                    shipPosition
            )

        let shipDistance =
            distanceBetween(
                sharkPosition,
                shipPosition
            )

        // ========================================================
        // HARD ATTACK
        // ========================================================

        if shipDistance <= attackRange {
            return directDirection
        }

        // ========================================================
        // CELLULAR GRID
        // ========================================================

        let currentCell =
            worldToCell(
                sharkPosition
            )

        let neighborOffsets:
            [(Int, Int, Int)] = [
                ( 1,  0,  0),
                (-1,  0,  0),
                ( 0,  1,  0),
                ( 0, -1,  0),
                ( 0,  0,  1),
                ( 0,  0, -1)
            ]

        var bestDirection =
            directDirection

        var bestScore =
            -CGFloat.greatestFiniteMagnitude

        // ========================================================
        // PURSUIT WEIGHT
        // ========================================================

        let pursuitWeight: CGFloat

        if shipDistance <= hardPursuitRadius {

            pursuitWeight = 0.98

        } else if shipDistance <= convergenceRadius {

            let t =
                (
                    shipDistance -
                    hardPursuitRadius
                )
                /
                (
                    convergenceRadius -
                    hardPursuitRadius
                )

            pursuitWeight =
                0.98 -
                (
                    0.13 *
                    t
                )

        } else if shipDistance <= pursuitRadius {

            let t =
                (
                    shipDistance -
                    convergenceRadius
                )
                /
                (
                    pursuitRadius -
                    convergenceRadius
                )

            pursuitWeight =
                0.85 -
                (
                    0.20 *
                    t
                )

        } else {

            pursuitWeight = 0.65
        }

        let cellularWeight =
            1.0 -
            pursuitWeight

        // ========================================================
        // CURRENT VERTICAL ERROR
        // ========================================================

        let currentVerticalError =
            abs(
                CGFloat(shipPosition.y) -
                CGFloat(sharkPosition.y)
            )

        // ========================================================
        // EVALUATE SIX CELLULAR NEIGHBORS
        // ========================================================

        for offset in neighborOffsets {

            let nextCell = (
                currentCell.x +
                    offset.0,
                currentCell.y +
                    offset.1,
                currentCell.z +
                    offset.2
            )

            let candidatePosition =
                cellToWorld(
                    nextCell
                )

            // ====================================================
            // TERRAIN X LIMIT
            // ====================================================

            if CGFloat(candidatePosition.x) <
                minimumTerrainX {

                continue
            }

            if CGFloat(candidatePosition.x) >
                maximumTerrainX {

                continue
            }

            // ====================================================
            // TERRAIN CLEARANCE
            // ====================================================

            let candidateTerrainY =
                terrainHeight(
                    x:
                        CGFloat(
                            candidatePosition.x
                        ),
                    z:
                        CGFloat(
                            candidatePosition.z
                        )
                )

            let minimumCandidateY =
                candidateTerrainY +
                terrainSharkClearance

            if CGFloat(candidatePosition.y) <
                minimumCandidateY {

                continue
            }

            // ====================================================
            // CANDIDATE DIRECTION
            // ====================================================

            let candidateDirection =
                normalizeDirection(
                    SCNVector3(
                        candidatePosition.x -
                            sharkPosition.x,
                        candidatePosition.y -
                            sharkPosition.y,
                        candidatePosition.z -
                            sharkPosition.z
                    )
                )

            // ====================================================
            // SHIP ALIGNMENT
            // ====================================================

            let alignment =
                dotProduct(
                    candidateDirection,
                    directDirection
                )

            // ====================================================
            // CANDIDATE DISTANCE
            // ====================================================

            let candidateDistance =
                distanceBetween(
                    candidatePosition,
                    shipPosition
                )

            let distanceImprovement =
                shipDistance -
                candidateDistance

            // ====================================================
            // VERTICAL ERROR
            // ====================================================

            let candidateVerticalError =
                abs(
                    CGFloat(shipPosition.y) -
                    CGFloat(candidatePosition.y)
                )

            let verticalImprovement =
                currentVerticalError -
                candidateVerticalError

            // ====================================================
            // VERTICAL DIRECTION SCORE
            // ====================================================
            //
            // This explicitly rewards cells that move the shark
            // toward the ship's altitude.
            //
            // ====================================================

            let verticalScore =
                verticalImprovement *
                (
                    15.0 +
                    40.0 *
                    pursuitWeight
                ) *
                verticalAttackWeight

            // ====================================================
            // ATTACK ALIGNMENT SCORE
            // ====================================================

            let attackScore =
                alignment *
                (
                    30.0 +
                    70.0 *
                    pursuitWeight
                )

            // ====================================================
            // POSITIVE ALIGNMENT BONUS
            // ====================================================

            let positiveAlignment =
                max(
                    0.0,
                    alignment
                )

            let pursuitScore =
                pow(
                    positiveAlignment,
                    2.0
                )
                *
                50.0
                *
                pursuitWeight

            // ====================================================
            // DISTANCE CONVERGENCE
            // ====================================================

            let convergenceScore: CGFloat

            if distanceImprovement > 0.0 {

                convergenceScore =
                    distanceImprovement *
                    10.0

            } else {

                convergenceScore =
                    distanceImprovement *
                    25.0
            }

            // ====================================================
            // SWARM SCORE
            // ====================================================

            var swarmScore: CGFloat = 0.0

            for otherShark in game.sharks {

                if otherShark === shark ||
                    otherShark.destroyed {

                    continue
                }

                let otherDistance =
                    distanceBetween(
                        candidatePosition,
                        otherShark.position
                    )

                // =================================================
                // COHESION
                // =================================================

                if otherDistance < swarmRadius {

                    let cohesion =
                        (
                            swarmRadius -
                            otherDistance
                        )
                        /
                        swarmRadius

                    swarmScore +=
                        cohesion *
                        1.5
                }

                // =================================================
                // SEPARATION
                // =================================================

                if otherDistance <
                    sharkSeparationRadius {

                    let separation =
                        sharkSeparationRadius -
                        otherDistance

                    swarmScore -=
                        separation *
                        3.0
                }
            }

            // ====================================================
            // RANDOM CELLULAR VARIATION
            // ====================================================

            var randomScore: CGFloat = 0.0

            if CGFloat.random(in: 0.0...1.0) <
                randomMovementProbability {

                randomScore =
                    CGFloat.random(
                        in:
                            -1.0...1.0
                    )
            }

            // ====================================================
            // TOTAL CELL SCORE
            // ====================================================

            let score =
                attackScore +
                pursuitScore +
                convergenceScore +
                verticalScore +
                swarmScore +
                randomScore

            // ====================================================
            // BEST CELL
            // ====================================================

            if score > bestScore {

                bestScore =
                    score

                bestDirection =
                    candidateDirection
            }
        }

        // ========================================================
        // CELLULAR + DIRECT SHIP BLEND
        // ========================================================

        let blended =
            blendDirections(
                current:
                    bestDirection,
                target:
                    directDirection,
                targetWeight:
                    pursuitWeight
            )

        // ========================================================
        // FINAL EXPLICIT VERTICAL CORRECTION
        // ========================================================

        let verticalError =
            CGFloat(shipPosition.y) -
            CGFloat(sharkPosition.y)

        let normalizedVerticalError =
            max(
                -1.0,
                min(
                    1.0,
                    verticalError /
                    verticalAttackDistance
                )
            )

        let verticalCorrectionStrength =
            verticalAttackWeight *
            (
                0.30 +
                0.70 *
                pursuitWeight
            )

        let correctedY =
            CGFloat(blended.y) +
            normalizedVerticalError *
            verticalCorrectionStrength

        return normalizeDirection(
            SCNVector3(
                blended.x,
                Float(correctedY),
                blended.z
            )
        )
    }

    // ============================================================
    // OCEAN CELLULAR AUTOMATON
    // ============================================================

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

        let distanceToShip =
            distanceBetween(
                sharkPosition,
                shipPosition
            )

        // ========================================================
        // HARD ATTACK
        // ========================================================

        if distanceToShip <= attackRange {
            return directDirection
        }

        // ========================================================
        // CURRENT CELL
        // ========================================================

        let currentCell =
            worldToCell(
                sharkPosition
            )

        let neighbors:
            [(Int, Int, Int)] = [
                ( 1,  0,  0),
                (-1,  0,  0),
                ( 0,  1,  0),
                ( 0, -1,  0),
                ( 0,  0,  1),
                ( 0,  0, -1)
            ]

        var bestDirection =
            directDirection

        var bestScore =
            -CGFloat.greatestFiniteMagnitude

        // ========================================================
        // PURSUIT WEIGHT
        // ========================================================

        let pursuitWeight: CGFloat

        if distanceToShip <= hardPursuitRadius {

            pursuitWeight = 0.98

        } else if distanceToShip <= convergenceRadius {

            let t =
                (
                    distanceToShip -
                    hardPursuitRadius
                )
                /
                (
                    convergenceRadius -
                    hardPursuitRadius
                )

            pursuitWeight =
                0.98 -
                (
                    0.13 *
                    t
                )

        } else {

            pursuitWeight = 0.75
        }

        // ========================================================
        // CURRENT VERTICAL ERROR
        // ========================================================

        let currentVerticalError =
            abs(
                CGFloat(shipPosition.y) -
                CGFloat(sharkPosition.y)
            )

        // ========================================================
        // CELLULAR NEIGHBORS
        // ========================================================

        for neighbor in neighbors {

            let nextCell = (
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

            // ====================================================
            // OCEAN X BOUNDS
            // ====================================================

            if CGFloat(candidatePosition.x) <
                minimumOceanX {

                continue
            }

            if CGFloat(candidatePosition.x) >
                maximumOceanX {

                continue
            }

            // ====================================================
            // OCEAN Y BOUNDS
            // ====================================================

            if CGFloat(candidatePosition.y) <
                minimumOceanY {

                continue
            }

            if CGFloat(candidatePosition.y) >
                maximumOceanY {

                continue
            }

            // ====================================================
            // CANDIDATE DIRECTION
            // ====================================================

            let candidateDirection =
                normalizeDirection(
                    SCNVector3(
                        candidatePosition.x -
                            sharkPosition.x,
                        candidatePosition.y -
                            sharkPosition.y,
                        candidatePosition.z -
                            sharkPosition.z
                    )
                )

            // ====================================================
            // ALIGNMENT
            // ====================================================

            let alignment =
                dotProduct(
                    candidateDirection,
                    directDirection
                )

            // ====================================================
            // DISTANCE
            // ====================================================

            let candidateDistance =
                distanceBetween(
                    candidatePosition,
                    shipPosition
                )

            let distanceImprovement =
                distanceToShip -
                candidateDistance

            // ====================================================
            // VERTICAL IMPROVEMENT
            // ====================================================

            let candidateVerticalError =
                abs(
                    CGFloat(shipPosition.y) -
                    CGFloat(candidatePosition.y)
                )

            let verticalImprovement =
                currentVerticalError -
                candidateVerticalError

            // ====================================================
            // ATTACK SCORE
            // ====================================================

            let attackScore =
                alignment *
                (
                    30.0 +
                    70.0 *
                    pursuitWeight
                )

            // ====================================================
            // CONVERGENCE
            // ====================================================

            let convergenceScore: CGFloat

            if distanceImprovement > 0.0 {

                convergenceScore =
                    distanceImprovement *
                    10.0

            } else {

                convergenceScore =
                    distanceImprovement *
                    25.0
            }

            // ====================================================
            // VERTICAL ATTACK SCORE
            // ====================================================

            let verticalScore =
                verticalImprovement *
                (
                    15.0 +
                    40.0 *
                    pursuitWeight
                ) *
                verticalAttackWeight

            // ====================================================
            // POSITIVE ALIGNMENT
            // ====================================================

            let positiveAlignment =
                max(
                    0.0,
                    alignment
                )

            let pursuitScore =
                pow(
                    positiveAlignment,
                    2.0
                )
                *
                50.0
                *
                pursuitWeight

            // ====================================================
            // CLOSE-RANGE BONUS
            // ====================================================

            var closeRangeBonus:
                CGFloat = 0.0

            if distanceToShip < 30.0 {

                closeRangeBonus +=
                    max(
                        0.0,
                        alignment
                    )
                    *
                    50.0
            }

            if distanceToShip < 15.0 {

                closeRangeBonus +=
                    max(
                        0.0,
                        alignment
                    )
                    *
                    100.0
            }

            // ====================================================
            // RANDOM CELLULAR COMPONENT
            // ====================================================

            let randomScore =
                CGFloat.random(
                    in:
                        -0.10...0.10
                )

            // ====================================================
            // TOTAL SCORE
            // ====================================================

            let score =
                attackScore +
                pursuitScore +
                convergenceScore +
                verticalScore +
                closeRangeBonus +
                randomScore

            // ====================================================
            // BEST CELL
            // ====================================================

            if score > bestScore {

                bestScore =
                    score

                bestDirection =
                    candidateDirection
            }
        }

        // ========================================================
        // CELLULAR + DIRECT 3D ATTACK
        // ========================================================

        return blendDirections(
            current:
                bestDirection,
            target:
                directDirection,
            targetWeight:
                pursuitWeight
        )
    }

    // ============================================================
    // DIRECTION TO SHIP
    //
    // FULL 3D VECTOR
    //
    // X = horizontal
    // Y = vertical
    // Z = forward/backward
    // ============================================================

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
                0.0,
                0.0,
                -1.0
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

    // ============================================================
    // BLEND DIRECTIONS
    // ============================================================

    private func blendDirections(
        current: SCNVector3,
        target: SCNVector3,
        targetWeight: CGFloat
    ) -> SCNVector3 {

        let safeTargetWeight =
            max(
                0.0,
                min(
                    1.0,
                    targetWeight
                )
            )

        let currentWeight =
            1.0 -
            safeTargetWeight

        let x =
            CGFloat(current.x) *
            currentWeight
            +
            CGFloat(target.x) *
            safeTargetWeight

        let y =
            CGFloat(current.y) *
            currentWeight
            +
            CGFloat(target.y) *
            safeTargetWeight

        let z =
            CGFloat(current.z) *
            currentWeight
            +
            CGFloat(target.z) *
            safeTargetWeight

        return normalizeDirection(
            SCNVector3(
                Float(x),
                Float(y),
                Float(z)
            )
        )
    }

    // ============================================================
    // DISTANCE
    // ============================================================

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

    // ============================================================
    // DOT PRODUCT
    // ============================================================

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

    // ============================================================
    // WORLD TO CELL
    // ============================================================

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

    // ============================================================
    // CELL TO WORLD
    // ============================================================

    private func cellToWorld(
        _ cell: (
            x: Int,
            y: Int,
            z: Int
        )
    ) -> SCNVector3 {

        let worldX =
            (
                CGFloat(cell.x) +
                0.5
            )
            *
            cellSize

        let worldY =
            (
                CGFloat(cell.y) +
                0.5
            )
            *
            cellSize

        let worldZ =
            (
                CGFloat(cell.z) +
                0.5
            )
            *
            cellSize

        return SCNVector3(
            Float(worldX),
            Float(worldY),
            Float(worldZ)
        )
    }

    // ============================================================
    // NORMALIZE DIRECTION
    // ============================================================

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
                0.0,
                0.0,
                -1.0
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

    // ============================================================
    // TERRAIN CLEARANCE
    //
    // IMPORTANT:
    //
    // This only prevents the shark from going THROUGH the terrain.
    //
    // It does NOT limit the shark's height above the terrain.
    //
    // Therefore a shark can climb toward a ship above it.
    // ============================================================

    private func enforceTerrainClearance(
        shark: Shark
    ) {

        var position =
            shark.position

        let x =
            CGFloat(position.x)

        let z =
            CGFloat(position.z)

        let terrainY =
            terrainHeight(
                x: x,
                z: z
            )

        let minimumY =
            terrainY +
            terrainSharkClearance

        if CGFloat(position.y) < minimumY {

            position.y =
                Float(
                    minimumY
                )
        }

        shark.position =
            position
    }

    // ============================================================
    // TERRAIN BOUNDS
    //
    // X ONLY
    //
    // Z IS INTENTIONALLY UNBOUNDED.
    // ============================================================

    private func applyTerrainBounds(
        shark: Shark
    ) {

        var position =
            shark.position

        // ========================================================
        // X
        // ========================================================

        if CGFloat(position.x) <
            minimumTerrainX {

            position.x =
                Float(
                    minimumTerrainX
                )
        }

        if CGFloat(position.x) >
            maximumTerrainX {

            position.x =
                Float(
                    maximumTerrainX
                )
        }

        // ========================================================
        // NO Z CLAMP
        // ========================================================
        //
        // DO NOT add:
        //
        // position.z = max(...)
        //
        // DO NOT add:
        //
        // position.z = min(...)
        //
        // Sharks need to follow the ship forward.
        // ========================================================

        shark.position =
            position

        // ========================================================
        // TERRAIN CLEARANCE
        // ========================================================

        enforceTerrainClearance(
            shark: shark
        )
    }

    // ============================================================
    // OCEAN BOUNDS
    // ============================================================

    private func applyOceanBounds(
        shark: Shark
    ) {

        var position =
            shark.position

        // ========================================================
        // X
        // ========================================================

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

        // ========================================================
        // Y
        // ========================================================

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

    // ============================================================
    // REMOVE INACTIVE SHARKS
    // ============================================================

    private func removeInactiveSharks(
        game: GameState
    ) {

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

            return false
        }
    }

    // ============================================================
    // RESET
    // ============================================================

    func reset(
        game: GameState
    ) {

        spawnClock = 0.0

        cellularTimers.removeAll()

        cellularDirections.removeAll()

        game.sharks.removeAll()
    }
}
