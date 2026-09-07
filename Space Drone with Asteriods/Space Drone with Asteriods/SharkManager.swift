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

// Optional protocol for providing ship Y position, for potential future refactoring
protocol ShipPositionProvider {
    var shipPositionY: CGFloat { get }
}
// Note: This protocol can be adopted for more robust ship position access if needed in the future.

@MainActor
final class SharkManager {

    // ============================================================
    // SPAWN CONTROL
    // ============================================================

    private var spawnClock: CGFloat = 0.0
    private let spawnInterval: CGFloat = 10.8

    // ============================================================
    // SHARK BEHAVIOR
    // ============================================================

    private let minimumSpawnDistance: CGFloat = 35.0
    private let maximumSpawnDistance: CGFloat = 65.0

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

    private let minimumTerrainX: CGFloat = -36.0
    private let maximumTerrainX: CGFloat = 36.0

    private let minimumTerrainY: CGFloat = 0.0
    private let maximumTerrainY: CGFloat = 40.0

    // ============================================================
    // TERRAIN SHARK CLEARANCE
    // ============================================================
    //
    // Sharks must never be allowed to occupy the terrain surface.
    //
    // The terrain-height provider returns the actual terrain Y
    // coordinate for the shark's X/Z position.
    //
    // The shark is maintained this distance above the terrain.
    //
    // ============================================================

    private let terrainSharkClearance: CGFloat = 3.5

    // Fallback terrain surface when TerrainSceneWorld has not
    // supplied an actual terrain-height function.
    private let fallbackTerrainHeight: CGFloat = 0.0

    // ============================================================
    // TERRAIN HEIGHT PROVIDER
    // ============================================================
    //
    // TerrainSceneWorld can provide its actual generated terrain
    // height through this closure.
    //
    // Input:
    //     x = world X
    //     z = world Z
    //
    // Return:
    //     terrain surface Y
    //
    // ============================================================

    private var terrainHeightProvider:
        ((CGFloat, CGFloat) -> CGFloat)?

    // ============================================================
    // CELLULAR AUTOMATA
    // ============================================================

    private let cellSize: CGFloat = 2.0
    private let cellularStepTime: CGFloat = 0.20
    private let huntingRange: CGFloat = 100.0
    private let randomMovementProbability: CGFloat = 0.04

    // ============================================================
    // TERRAIN FEEDING FRENZY
    // ============================================================

    private let frenzyRange: CGFloat = 100.0
    private let attackRange: CGFloat = 20.0
    private let swarmRadius: CGFloat = 18.0
    private let sharkSeparationRadius: CGFloat = 3.0

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

        spawnShark(
            game: game
        )
    }

    // ============================================================
    // SPAWN SHARK
    // ============================================================

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

        // ========================================================
        // DETERMINE SCENE
        // ========================================================

        let isTerrain =
            game.currentSection == .terrain

        // ========================================================
        // RANDOM X
        // ========================================================

        let spawnX =
            CGFloat.random(
                in:
                    isTerrain
                    ? minimumTerrainX...maximumTerrainX
                    : minimumOceanX...maximumOceanX
            )

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
        // RANDOM Y
        // ========================================================

        let spawnY: CGFloat

        if isTerrain {

            // IMPORTANT:
            //
            // Sample the terrain at the shark's ACTUAL
            // X/Z spawn position.
            //
            // Previously this used shipZ, which meant the
            // terrain check was performed at the wrong location.

            let terrainY =
                terrainHeight(
                    x: spawnX,
                    z: spawnZ
                )

            // Keep the shark above the actual terrain
            // and also above the ship's vertical region.

            let terrainMinimumY =
                terrainY +
                terrainSharkClearance

            let shipMinimumY =
                shipY +
                CGFloat.random(
                    in: 1.0...6.0
                )

            spawnY = terrainMinimumY

        } else {

            spawnY =
                CGFloat.random(
                    in:
                        minimumOceanY...maximumOceanY
                )
        }

        // ========================================================
        // CREATE SHARK
        // ========================================================

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

        let actualTerrainY = terrainHeight(
            x: CGFloat(shark.position.x),
            z: CGFloat(shark.position.z)
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
        // FINAL TERRAIN SAFETY CHECK
        //
        // This performs one final check using the shark's
        // actual position before putting it into the game.
        // =============== =========================================

        if isTerrain {

            enforceTerrainClearance(
                shark: shark
            )
        }

        // ========================================================
        // ADD SHARK
        // ========================================================

        game.sharks.append(
            shark
        )

        // ========================================================
        // CELLULAR STATE
        // ========================================================

        let id =
            ObjectIdentifier(
                shark
            )

        cellularTimers[id] =
            0.0

        // ========================================================
        // INITIAL DIRECTION
        // ========================================================

        let direction =
            directionToShip(
                sharkPosition:
                    shark.position,

                shipPosition:
                    shipPosition
            )

        cellularDirections[id] =
            direction
    }
    // ============================================================
    // SHARK BEHAVIOR
    // ============================================================

    private func updateSharks(
        game: GameState,
        dt: CGFloat
    ) {

        let isTerrain =
            game.currentSection == .terrain

        for shark in game.sharks {

            guard !shark.destroyed else {
                continue
            }

            // ====================================================
            // PRIMARY MOVEMENT SYSTEM
            // ====================================================

            updateCellularHunting(
                shark: shark,
                game: game,
                dt: dt
            )

            // ====================================================
            // SCENE BOUNDARIES
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
            ObjectIdentifier(shark)

        var timer =
            cellularTimers[id] ?? 0.0

        timer += dt

        let isTerrain =
            game.currentSection == .terrain

        // ========================================================
        // TERRAIN FEEDING FRENZY
        // ========================================================

        if isTerrain {

            let direction =
                feedingFrenzyDirection(
                    shark: shark,
                    game: game
                )

            cellularDirections[id] =
                direction

            let distance =
                distanceBetween(
                    shark.position,
                    game.spaceShip.position
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
                        distance /
                        frenzyRange
                    )
                )

            // ====================================================
            // BASE SPEED
            // ====================================================

            let baseSpeed =
                max(
                    shark.forwardSpeed,
                    minimumSpeed
                )

            // ====================================================
            // FRENZY SPEED
            // ====================================================

            let frenzySpeed =
                minimumHuntSpeed +
                (
                    maximumHuntSpeed -
                    minimumHuntSpeed
                ) *
                frenzyFactor

            let movementSpeed =
                max(
                    baseSpeed,
                    frenzySpeed
                )

            let distanceStep =
                Float(
                    movementSpeed *
                    dt
                )

            // ====================================================
            // MOVE IN 3D
            // ====================================================

            shark.position.x +=
                direction.x *
                distanceStep

            shark.position.y +=
                direction.y *
                distanceStep

            shark.position.z +=
                direction.z *
                distanceStep

            // ====================================================
            // CELLULAR STATE UPDATE
            // ====================================================

            if timer >= cellularStepTime {

                timer = 0.0

                cellularDirections[id] =
                    feedingFrenzyDirection(
                        shark: shark,
                        game: game
                    )
            }

            cellularTimers[id] =
                timer

            // ====================================================
            // CRITICAL TERRAIN SAFETY
            // ====================================================
            //
            // Movement can carry a shark below a hill or terrain
            // surface between cellular updates.
            //
            // Clamp immediately after movement.
            //
            // ====================================================

            enforceTerrainClearance(
                shark: shark
            )

            return
        }

        // ========================================================
        // OCEAN HUNTING
        // ========================================================

        var direction =
            cellularDirections[id]
            ??
            directionToShip(
                sharkPosition:
                    shark.position,
                shipPosition:
                    game.spaceShip.position
            )

        let distance =
            distanceBetween(
                shark.position,
                game.spaceShip.position
            )

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

        let directTargetDirection =
            directionToShip(
                sharkPosition:
                    shark.position,
                shipPosition:
                    game.spaceShip.position
            )

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

        // ========================================================
        // HUNT SPEED
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
        // MOVE OCEAN SHARK
        // ========================================================

        shark.position.x +=
            direction.x *
            distanceStep

        shark.position.y +=
            direction.y *
            distanceStep

        shark.position.z +=
            direction.z *
            distanceStep

        // ========================================================
        // CELLULAR STATE UPDATE
        // ========================================================

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
    }

    // ============================================================
    // TERRAIN CLEARANCE
    // ============================================================

    // ============================================================
    // TERRAIN CLEARANCE
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

        // Never allow the shark to enter the terrain.

        if CGFloat(position.y) < minimumY {
            position.y =
                Float(minimumY)
        }

        shark.position =
            position
    }
    // ============================================================
    // TERRAIN BOUNDS
    // ============================================================

    // ============================================================
    // TERRAIN BOUNDS
    // ============================================================

    private func applyTerrainBounds(
        shark: Shark
    ) {
        var position =
            shark.position

        // ========================================================
        // X BOUNDS
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
        // IMPORTANT:
        //
        // DO NOT CLAMP Z TO 0...40.
        //
        // The terrain world moves/streams along Z and the ship
        // can be at Z = 100, 200, 300, etc.
        //
        // Sharks must be allowed to follow the ship in Z.
        // ========================================================

        shark.position =
            position

        // ========================================================
        // TERRAIN SURFACE SAFETY
        // ========================================================

        enforceTerrainClearance(
            shark: shark
        )
    }

    // ============================================================
    // TERRAIN FEEDING FRENZY
    // ============================================================

    // ============================================================
    // TERRAIN FEEDING FRENZY
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
        // DIRECT VECTOR TO SHIP
        // ========================================================

        let directDirection =
            directionToShip(
                sharkPosition:
                    sharkPosition,
                shipPosition:
                    shipPosition
            )

        // ========================================================
        // DISTANCE TO SHIP
        // ========================================================

        let distance =
            distanceBetween(
                sharkPosition,
                shipPosition
            )

        // ========================================================
        // FRENZY FACTOR
        //
        // The closer the shark gets, the more aggressively it
        // follows the spaceship.
        // ========================================================

        let frenzyFactor =
            max(
                0.0,
                min(
                    1.0,
                    1.0 -
                    distance /
                    frenzyRange
                )
            )

        // ========================================================
        // CELLULAR NEIGHBOR DIRECTIONS
        // ========================================================

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

        // ========================================================
        // EVALUATE CELLULAR MOVEMENT
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
            // X BOUNDARY
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
            // TERRAIN HEIGHT
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

            // ====================================================
            // DO NOT SELECT A CELL INSIDE TERRAIN
            // ====================================================

            if CGFloat(candidatePosition.y) <
                candidateTerrainY +
                terrainSharkClearance {

                continue
            }

            // ====================================================
            // CANDIDATE DIRECTION
            // ====================================================

            let candidateDirection =
                normalizeDirection(
                    SCNVector3(
                        Float(neighbor.0),
                        Float(neighbor.1),
                        Float(neighbor.2)
                    )
                )

            // ====================================================
            // ALIGNMENT WITH SHIP
            // ====================================================

            let alignment =
                dotProduct(
                    candidateDirection,
                    directDirection
                )

            // ====================================================
            // CLOSING DISTANCE
            // ====================================================

            let candidateDistance =
                distanceBetween(
                    candidatePosition,
                    shipPosition
                )

            // ====================================================
            // SCORE
            // ====================================================

            var score: CGFloat = 0.0

            // Strongly favor movement toward ship.

            score +=
                max(
                    0.0,
                    alignment
                ) *
                (
                    100.0 +
                    frenzyFactor *
                    200.0
                )

            // Strongly penalize movement away.

            score +=
                min(
                    0.0,
                    alignment
                ) *
                (
                    80.0 +
                    frenzyFactor *
                    120.0
                )

            // Favor cells that reduce distance.

            score +=
                (
                    100.0 /
                    (
                        1.0 +
                        candidateDistance
                    )
                ) *
                (
                    1.0 +
                    frenzyFactor
                )

            // Small randomness prevents perfectly mechanical
            // movement while retaining strong pursuit behavior.

            score +=
                CGFloat.random(
                    in:
                        -randomMovementProbability...randomMovementProbability
                )

            if score > bestScore {

                bestScore =
                    score

                bestDirection =
                    candidateDirection
            }
        }

        // ========================================================
        // FINAL DIRECT-HUNT BLEND
        //
        // This guarantees that the cellular automaton cannot
        // cause the shark to wander away from the spaceship.
        // ========================================================

        let cellularWeight =
            0.25

        let directWeight =
            0.75 +
            frenzyFactor *
            0.25

        let finalX =
            CGFloat(bestDirection.x) *
            cellularWeight
            +
            CGFloat(directDirection.x) *
            directWeight

        let finalY =
            CGFloat(bestDirection.y) *
            cellularWeight
            +
            CGFloat(directDirection.y) *
            directWeight

        let finalZ =
            CGFloat(bestDirection.z) *
            cellularWeight
            +
            CGFloat(directDirection.z) *
            directWeight

        return normalizeDirection(
            SCNVector3(
                Float(finalX),
                Float(finalY),
                Float(finalZ)
            )
        )
    }

    // ============================================================
    // OCEAN CELLULAR AUTOMATA RULE
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

        let distance =
            distanceBetween(
                sharkPosition,
                shipPosition
            )

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

        let cellMinimumX =
            minimumOceanX

        let cellMaximumX =
            maximumOceanX

        let cellMinimumY =
            minimumOceanY

        let cellMaximumY =
            maximumOceanY

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

            if CGFloat(candidatePosition.x)
                < cellMinimumX {

                continue
            }

            if CGFloat(candidatePosition.x)
                > cellMaximumX {

                continue
            }

            if CGFloat(candidatePosition.y)
                < cellMinimumY {

                continue
            }

            if CGFloat(candidatePosition.y)
                > cellMaximumY {

                continue
            }

            let candidateDirection =
                SCNVector3(
                    Float(neighbor.0),
                    Float(neighbor.1),
                    Float(neighbor.2)
                )

            let alignment =
                dotProduct(
                    candidateDirection,
                    directDirection
                )

            var score: CGFloat =
                0.0

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

            let candidateDistance =
                distanceBetween(
                    candidatePosition,
                    shipPosition
                )

            score +=
                1.0 /
                (
                    1.0 +
                    candidateDistance
                ) *
                10.0

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

            let randomAmount =
                CGFloat.random(
                    in:
                        -randomMovementProbability...randomMovementProbability
                )

            score +=
                randomAmount

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

    // ============================================================
    // DIRECTION TO SHIP
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
                0,
                0,
                -1
            )
        }

        return SCNVector3(
            Float(dx / length),
            Float(dy / length),
            Float(dz / length)
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
    // WORLD → CELL
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
    // CELL → WORLD
    // ============================================================
    //
    // Cell centers are calculated consistently around world zero.
    //
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
            ) *
            cellSize

        let worldY =
            (
                CGFloat(cell.y) +
                0.5
            ) *
            cellSize

        let worldZ =
            (
                CGFloat(cell.z) +
                0.5
            ) *
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
                0,
                0,
                -1
            )
        }

        return SCNVector3(
            Float(x / length),
            Float(y / length),
            Float(z / length)
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

        if CGFloat(position.x)
            < minimumOceanX {

            position.x =
                Float(
                    minimumOceanX
                )
        }

        if CGFloat(position.x)
            > maximumOceanX {

            position.x =
                Float(
                    maximumOceanX
                )
        }

        if CGFloat(position.y)
            < minimumOceanY {

            position.y =
                Float(
                    minimumOceanY
                )
        }

        if CGFloat(position.y)
            > maximumOceanY {

            position.y =
                Float(
                    maximumOceanY
                )
        }

        shark.position =
            position
    }

    // ============================================================
    // REMOVAL
    // ============================================================

    private func removeInactiveSharks(
        game: GameState
    ) {
        game.sharks.removeAll { shark in

            let id =
                ObjectIdentifier(
                    shark
                )

            // ====================================================
            // DESTROYED
            // ====================================================

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

            // ====================================================
            // KEEP SHARK
            //
            // Sharks are no longer removed simply because they
            // are more than 120 units from the spaceship.
            // ====================================================

            return false
        }
    }

    // ============================================================
    // RESET
    // ============================================================

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

