
//
//  TerrainSceneWorld.swift
//  Space Drone with Asteriods
//
//  Terrain / Alien Terrain Scene
//

import Foundation
import SwiftUI
import SceneKit
import UIKit

// =============================================================================
// TERRAIN SCENE WORLD
// =============================================================================
//
// The Terrain scene deliberately follows the Ocean scene's cockpit architecture:
//
//      shipRoot
//          └── camera
//                └── cockpitCannonNode
//                      └── cannonBarrelPivot
//                            └── cannonBarrel
//                                  └── muzzleNode
//
// The camera therefore follows the player ship automatically.
//
// The cannon muzzle world position and world direction are calculated from
// the actual rendered SceneKit hierarchy, exactly as in OceanSceneWorld.
// =============================================================================

final class TerrainSceneWorld {

    // =========================================================================
    // MARK: - Scene
    // =========================================================================

    let scene = SCNScene()
    let camera = SCNNode()

    // =========================================================================
    // MARK: - Terrain
    // =========================================================================

    private let terrainContainer = SCNNode()
    private var terrainSegments: [SCNNode] = []

    private let terrainSegmentCount = 10
    private let terrainWidth: Float = 80.0
    private let terrainSegmentLength: Float = 40.0
    private let terrainResolution = 25

    private let terrainSeed: UInt32 = 0xA341316C

    private let terrainBaseHeight: Float = -1.0
    private let terrainAmplitude: Float = 10.0
    private let terrainNoiseScale: Float = 0.055

    // Water / atmospheric reference.
    private let terrainSeaLevel: Float = -1.0

    // Height of the player above terrain.
    private let shipHeightOffset: Float = 2.2

    // =========================================================================
    // MARK: - Player Ship
    // =========================================================================

    private let shipRoot = SCNNode()
    private let shipMesh = SCNNode()
    private let thrusterFlame = SCNNode()
    private let shieldNode = SCNNode()

    // =========================================================================
    // MARK: - Enemy
    // =========================================================================

    private let enemyRoot = SCNNode()

    // =========================================================================
    // MARK: - Creatures
    // =========================================================================

    private let sharkContainer = SCNNode()

    // =========================================================================
    // MARK: - Lasers
    // =========================================================================

    private let laserContainer = SCNNode()

    // =========================================================================
    // MARK: - Ocean-style Cockpit Cannon
    // =========================================================================

    // Camera/HUD-mounted cannon.

    private let cockpitCannonNode = SCNNode()

    private let cannonBarrel = SCNNode()
    private let muzzleNode = SCNNode()
    private let cannonBarrelPivot = SCNNode()

    // =========================================================================
    // MARK: - Timing
    // =========================================================================

    private var lastSyncTime: TimeInterval = CACurrentMediaTime()

    // =========================================================================
    // MARK: - Initialization
    // =========================================================================

    init() {

        scene.background.contents = UIColor(
            red: 0.035,
            green: 0.055,
            blue: 0.075,
            alpha: 1.0
        )

        scene.fogColor = UIColor(
            red: 0.045,
            green: 0.065,
            blue: 0.085,
            alpha: 1.0
        )

        scene.fogStartDistance = 35.0
        scene.fogEndDistance = 170.0

        // -------------------------------------------------------------
        // Lighting
        // -------------------------------------------------------------

        setupLighting()

        // -------------------------------------------------------------
        // Camera
        // -------------------------------------------------------------

        setupCamera()

        // -------------------------------------------------------------
        // Scene containers
        // -------------------------------------------------------------

        scene.rootNode.addChildNode(terrainContainer)
        scene.rootNode.addChildNode(shipRoot)
        scene.rootNode.addChildNode(enemyRoot)
        scene.rootNode.addChildNode(sharkContainer)
        scene.rootNode.addChildNode(laserContainer)

        // -------------------------------------------------------------
        // World
        // -------------------------------------------------------------

        setupTerrain()

        // -------------------------------------------------------------
        // Player
        // -------------------------------------------------------------

        setupShip()

        // -------------------------------------------------------------
        // Enemy
        // -------------------------------------------------------------

        setupEnemy()
    }

    // =========================================================================
    // MARK: - Lighting
    // =========================================================================

    private func setupLighting() {

        let ambient = SCNNode()

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.color = UIColor(
            white: 0.28,
            alpha: 1.0
        )

        ambient.light = ambientLight

        scene.rootNode.addChildNode(ambient)

        // -------------------------------------------------------------

        let sun = SCNNode()

        let sunLight = SCNLight()
        sunLight.type = .directional
        sunLight.color = UIColor(
            white: 0.85,
            alpha: 1.0
        )

        sunLight.castsShadow = true
        sunLight.shadowMode = .deferred

        sun.light = sunLight

        sun.eulerAngles = SCNVector3(
            -Float.pi / 3.0,
            Float.pi / 5.0,
            0
        )

        scene.rootNode.addChildNode(sun)

        // -------------------------------------------------------------
        // Fill light
        // -------------------------------------------------------------

        let fill = SCNNode()

        let fillLight = SCNLight()
        fillLight.type = .omni
        fillLight.color = UIColor(
            red: 0.25,
            green: 0.35,
            blue: 0.45,
            alpha: 1.0
        )

        fillLight.intensity = 250

        fill.light = fillLight
        fill.position = SCNVector3(
            0,
            25,
            -20
        )

        scene.rootNode.addChildNode(fill)
    }

    // =========================================================================
    // MARK: - Camera
    // =========================================================================

    private func setupCamera() {

        let cam = SCNCamera()

        cam.zNear = 0.05
        cam.zFar = 500.0
        cam.fieldOfView = 72.0

        camera.camera = cam

        // EXACT SAME BASIC CAMERA RELATIONSHIP AS OCEAN.
        //
        // This is a LOCAL position because camera is a child of shipRoot.

        camera.position = SCNVector3(
            0,
            0.3,
            -2.8
        )

        // Look down +Z.
        camera.eulerAngles.y = .pi

        // The camera belongs to the ship.
        shipRoot.addChildNode(camera)

        // Build the Ocean-style cockpit cannon.
        setupCockpitCannon()
    }

    // =========================================================================
    // MARK: - Ocean-style Cockpit Cannon
    // =========================================================================

    private func setupCockpitCannon() {

        // -------------------------------------------------------------
        // Remove any previous hierarchy.
        // -------------------------------------------------------------

        cockpitCannonNode.removeFromParentNode()
        cannonBarrelPivot.removeFromParentNode()
        cannonBarrel.removeFromParentNode()
        muzzleNode.removeFromParentNode()

        // =============================================================
        // COCKPIT ROOT
        // =============================================================

        camera.addChildNode(cockpitCannonNode)

        cockpitCannonNode.position = SCNVector3(
            0,
            -0.25,
            -0.9
        )

        cockpitCannonNode.eulerAngles = SCNVector3(
            0,
            0,
            0
        )

        // =============================================================
        // REAR-END HINGE
        // =============================================================

        cannonBarrelPivot.position = SCNVector3(
            0,
            0,
            0
        )

        cannonBarrelPivot.eulerAngles = SCNVector3(
            0,
            0,
            0
        )

        cockpitCannonNode.addChildNode(
            cannonBarrelPivot
        )

        // =============================================================
        // BARREL
        // =============================================================

        let barrelLength: Float = 0.72
        let halfLength = barrelLength * 0.5

        let barrelGeometry = SCNCylinder(
            radius: 0.055,
            height: CGFloat(barrelLength)
        )

        barrelGeometry.radialSegmentCount = 16

        barrelGeometry.firstMaterial?.diffuse.contents =
            UIColor.darkGray

        barrelGeometry.firstMaterial?.emission.contents =
            UIColor.black

        barrelGeometry.firstMaterial?.metalness.contents =
            NSNumber(value: 0.75)

        barrelGeometry.firstMaterial?.roughness.contents =
            NSNumber(value: 0.30)

        cannonBarrel.geometry = barrelGeometry

        // Critical:
        // Keep pivot at identity.
        cannonBarrel.pivot = SCNMatrix4Identity

        // SCNCylinder runs along local +Y.
        //
        // Rotate +Y toward camera-local -Z.

        cannonBarrel.eulerAngles = SCNVector3(
            -Float.pi / 2.0,
            0,
            0
        )

        // Barrel center is half its length forward of the hinge.

        cannonBarrel.position = SCNVector3(
            0,
            0,
            -halfLength
        )

        cannonBarrelPivot.addChildNode(
            cannonBarrel
        )

        // =============================================================
        // MUZZLE
        // =============================================================

        muzzleNode.position = SCNVector3(
            0,
            halfLength,
            0
        )

        muzzleNode.eulerAngles = SCNVector3(
            Float.pi / 2.0,
            0,
            0
        )

        cannonBarrel.addChildNode(
            muzzleNode
        )
    }

    // =========================================================================
    // MARK: - Player Ship
    // =========================================================================

    private func setupShip() {

        // -------------------------------------------------------------
        // Body
        // -------------------------------------------------------------

        let bodyGeometry = SCNCone(
            topRadius: 0,
            bottomRadius: 0.28,
            height: 0.9
        )

        bodyGeometry.firstMaterial?.diffuse.contents =
            UIColor.white

        bodyGeometry.firstMaterial?.emission.contents =
            UIColor(
                white: 0.2,
                alpha: 1.0
            )

        bodyGeometry.firstMaterial?.metalness.contents =
            NSNumber(value: 0.25)

        bodyGeometry.firstMaterial?.roughness.contents =
            NSNumber(value: 0.35)

        shipMesh.geometry = bodyGeometry

        shipMesh.eulerAngles.x =
            Float.pi / 2.0

        // The Ocean scene currently keeps the visible mesh disabled.
        // Preserve that behavior.

        // shipRoot.addChildNode(shipMesh)

        // -------------------------------------------------------------
        // Thruster
        // -------------------------------------------------------------

        let flameGeometry = SCNCone(
            topRadius: 0,
            bottomRadius: 0.12,
            height: 0.45
        )

        flameGeometry.firstMaterial?.diffuse.contents =
            UIColor.orange

        flameGeometry.firstMaterial?.emission.contents =
            UIColor.orange

        thrusterFlame.geometry =
            flameGeometry

        thrusterFlame.eulerAngles.x =
            -Float.pi / 2.0

        thrusterFlame.position =
            SCNVector3(
                0,
                0,
                -0.55
            )

        thrusterFlame.isHidden = true

        // shipRoot.addChildNode(thrusterFlame)

        // -------------------------------------------------------------
        // Shield
        // -------------------------------------------------------------

        let shieldGeometry =
            SCNSphere(radius: 0.55)

        shieldGeometry.firstMaterial?.diffuse.contents =
            UIColor.cyan.withAlphaComponent(0.15)

        shieldGeometry.firstMaterial?.emission.contents =
            UIColor.cyan.withAlphaComponent(0.25)

        shieldGeometry.firstMaterial?.transparency =
            0.5

        shieldNode.geometry =
            shieldGeometry

        shieldNode.isHidden = true

        // shipRoot.addChildNode(shieldNode)

        scene.rootNode.addChildNode(
            shipRoot
        )
    }

    // =========================================================================
    // MARK: - Enemy Spaceship
    // =========================================================================

    private func setupEnemy() {

        enemyRoot.removeAllActions()

        let bodyGeometry = SCNSphere(
            radius: 1.0
        )

        bodyGeometry.segmentCount = 20

        let material = SCNMaterial()

        material.diffuse.contents =
            UIColor(
                red: 0.30,
                green: 0.12,
                blue: 0.35,
                alpha: 1.0
            )

        material.emission.contents =
            UIColor(
                red: 0.08,
                green: 0.02,
                blue: 0.12,
                alpha: 1.0
            )

        material.metalness.contents =
            NSNumber(value: 0.65)

        material.roughness.contents =
            NSNumber(value: 0.25)

        bodyGeometry.materials = [
            material
        ]

        let body = SCNNode(
            geometry: bodyGeometry
        )

        body.scale = SCNVector3(
            1.8,
            0.45,
            1.1
        )

        enemyRoot.addChildNode(body)

        // -------------------------------------------------------------
        // Wings
        // -------------------------------------------------------------

        let wingGeometry = SCNBox(
            width: 3.8,
            height: 0.12,
            length: 0.75,
            chamferRadius: 0.08
        )

        wingGeometry.firstMaterial?.diffuse.contents =
            UIColor(
                red: 0.16,
                green: 0.08,
                blue: 0.22,
                alpha: 1.0
            )

        let wings = SCNNode(
            geometry: wingGeometry
        )

        wings.position = SCNVector3(
            0,
            0,
            0
        )

        enemyRoot.addChildNode(wings)

        // -------------------------------------------------------------
        // Engine glow
        // -------------------------------------------------------------

        let engineGeometry =
            SCNSphere(radius: 0.22)

        engineGeometry.firstMaterial?.diffuse.contents =
            UIColor.red

        engineGeometry.firstMaterial?.emission.contents =
            UIColor.red

        let engineLeft = SCNNode(
            geometry: engineGeometry
        )

        engineLeft.position =
            SCNVector3(
                -0.85,
                0,
                0.55
            )

        enemyRoot.addChildNode(
            engineLeft
        )

        let engineRight = SCNNode(
            geometry: engineGeometry
        )

        engineRight.position =
            SCNVector3(
                0.85,
                0,
                0.55
            )

        enemyRoot.addChildNode(
            engineRight
        )

        enemyRoot.isHidden = true
    }

    // =========================================================================
    // MARK: - Terrain Setup
    // =========================================================================

    private func setupTerrain() {

        terrainSegments.removeAll()

        // Build segments centered on the initial world Z positions.

        for index in 0..<terrainSegmentCount {

            let centerZ =
                (Float(index) - 1.0) *
                terrainSegmentLength

            let segment =
                makeTerrainSegment(
                    centerZ: centerZ
                )

            terrainSegments.append(
                segment
            )

            terrainContainer.addChildNode(
                segment
            )
        }
    }

    // =========================================================================
    // MARK: - Terrain Segment
    // =========================================================================

    private func makeTerrainSegment(
        centerZ: Float
    ) -> SCNNode {

        let geometry =
            makeFractalTerrainGeometry(
                centerZ: centerZ
            )

        let node =
            SCNNode(
                geometry: geometry
            )

        // IMPORTANT:
        //
        // The geometry uses LOCAL Z coordinates centered around zero.
        // Therefore the segment node itself is positioned at centerZ.
        //
        // This fixes the previous world/local Z mismatch.

        node.position = SCNVector3(
            0,
            0,
            centerZ
        )

        node.name =
            "terrainSegment_\(centerZ)"

        return node
    }

    // =========================================================================
    // MARK: - Fractal Terrain Geometry
    // =========================================================================

    private func makeFractalTerrainGeometry(
        centerZ: Float
    ) -> SCNGeometry {

        let count =
            terrainResolution

        let vertexCount =
            count * count

        var vertices:
            [SCNVector3] =
            []

        vertices.reserveCapacity(
            vertexCount
        )

        var normals:
            [SCNVector3] =
            []

        normals.reserveCapacity(
            vertexCount
        )

        var texcoords:
            [CGPoint] =
            []

        texcoords.reserveCapacity(
            vertexCount
        )

        // -------------------------------------------------------------
        // Vertices
        // -------------------------------------------------------------

        for row in 0..<count {

            let zFraction =
                Float(row) /
                Float(count - 1)

            let localZ =
                (zFraction - 0.5) *
                terrainSegmentLength

            for column in 0..<count {

                let xFraction =
                    Float(column) /
                    Float(count - 1)

                let x =
                    (xFraction - 0.5) *
                    terrainWidth

                // Convert local Z back into world Z for noise sampling.

                let worldZ =
                    centerZ + localZ

                let height =
                    terrainHeight(
                        worldX: x,
                        worldZ: worldZ
                    )

                vertices.append(
                    SCNVector3(
                        x,
                        height,
                        localZ
                    )
                )

                // Initial upward normal.
                normals.append(
                    SCNVector3(
                        0,
                        1,
                        0
                    )
                )

                texcoords.append(
                    CGPoint(
                        x: CGFloat(xFraction),
                        y: CGFloat(zFraction)
                    )
                )
            }
        }

        // -------------------------------------------------------------
        // Indices
        // -------------------------------------------------------------

        var indices:
            [Int32] =
            []

        indices.reserveCapacity(
            (count - 1) *
            (count - 1) *
            6
        )

        for row in 0..<(count - 1) {

            for column in 0..<(count - 1) {

                let topLeft =
                    Int32(row * count + column)

                let topRight =
                    Int32(row * count + column + 1)

                let bottomLeft =
                    Int32((row + 1) * count + column)

                let bottomRight =
                    Int32((row + 1) * count + column + 1)

                indices.append(topLeft)
                indices.append(bottomLeft)
                indices.append(topRight)

                indices.append(topRight)
                indices.append(bottomLeft)
                indices.append(bottomRight)
            }
        }

        // -------------------------------------------------------------
        // Sources
        // -------------------------------------------------------------

        let vertexSource =
            SCNGeometrySource(
                vertices: vertices
            )

        let normalSource =
            SCNGeometrySource(
                normals: normals
            )

        let texcoordSource =
            SCNGeometrySource(
                textureCoordinates: texcoords
            )

        let element =
            SCNGeometryElement(
                indices: indices,
                primitiveType: .triangles
            )

        let geometry =
            SCNGeometry(
                sources: [
                    vertexSource,
                    normalSource,
                    texcoordSource
                ],
                elements: [
                    element
                ]
            )

        // -------------------------------------------------------------
        // Terrain material
        // -------------------------------------------------------------

        let material =
            SCNMaterial()

        material.diffuse.contents =
            UIColor(
                red: 0.12,
                green: 0.25,
                blue: 0.10,
                alpha: 1.0
            )

        material.specular.contents =
            UIColor(
                white: 0.18,
                alpha: 1.0
            )

        material.roughness.contents =
            NSNumber(value: 0.90)

        geometry.materials = [
            material
        ]

        return geometry
    }

    // =========================================================================
    // MARK: - Terrain Height
    // =========================================================================

    private func terrainHeight(
        worldX: Float,
        worldZ: Float
    ) -> Float {

        let normalizedX =
            worldX * terrainNoiseScale

        let normalizedZ =
            worldZ * terrainNoiseScale

        // -------------------------------------------------------------
        // Fractal Brownian Motion
        // -------------------------------------------------------------

        var amplitude: Float = 1.0
        var frequency: Float = 1.0

        var value: Float = 0.0
        var normalization: Float = 0.0

        let octaves = 6

        for octave in 0..<octaves {

            let sampleX =
                normalizedX * frequency

            let sampleZ =
                normalizedZ * frequency

            let noise =
                smoothNoise2D(
                    x: sampleX,
                    z: sampleZ,
                    octave: octave
                )

            value +=
                noise * amplitude

            normalization +=
                amplitude

            amplitude *= 0.5
            frequency *= 2.0
        }

        if normalization > 0 {

            value /= normalization
        }

        // Keep the terrain centered around the base height.

        return terrainBaseHeight +
            value * terrainAmplitude
    }

    // =========================================================================
    // MARK: - Deterministic Smooth Noise
    // =========================================================================

    private func smoothNoise2D(
        x: Float,
        z: Float,
        octave: Int
    ) -> Float {

        let x0 =
            floor(x)

        let z0 =
            floor(z)

        let x1 =
            x0 + 1.0

        let z1 =
            z0 + 1.0

        let tx =
            x - x0

        let tz =
            z - z0

        let sx =
            fade(tx)

        let sz =
            fade(tz)

        let n00 =
            latticeValue(
                x: Int32(x0),
                z: Int32(z0),
                octave: octave
            )

        let n10 =
            latticeValue(
                x: Int32(x1),
                z: Int32(z0),
                octave: octave
            )

        let n01 =
            latticeValue(
                x: Int32(x0),
                z: Int32(z1),
                octave: octave
            )

        let n11 =
            latticeValue(
                x: Int32(x1),
                z: Int32(z1),
                octave: octave
            )

        let nx0 =
            n00 +
            (n10 - n00) * sx

        let nx1 =
            n01 +
            (n11 - n01) * sx

        return nx0 +
            (nx1 - nx0) * sz
    }

    // =========================================================================
    // MARK: - Fade
    // =========================================================================

    private func fade(
        _ t: Float
    ) -> Float {

        // Perlin-style smooth interpolation.

        return t * t * (
            3.0 - 2.0 * t
        )
    }

    // =========================================================================
    // MARK: - Lattice Value
    // =========================================================================

    private func latticeValue(
        x: Int32,
        z: Int32,
        octave: Int
    ) -> Float {

        var h =
            UInt64(terrainSeed)

        h &+= UInt64(
            UInt32(bitPattern: x)
        ) &* 0x9E3779B97F4A7C15

        h &+= UInt64(
            UInt32(bitPattern: z)
        ) &* 0xBF58476D1CE4E5B9

        h &+= UInt64(
            octave
        ) &* 0x94D049BB133111EB

        // SplitMix64 finalization.

        h ^= h >> 30
        h &*= 0xBF58476D1CE4E5B9

        h ^= h >> 27
        h &*= 0x94D049BB133111EB

        h ^= h >> 31

        let normalized =
            Double(h) /
            Double(UInt64.max)

        return Float(
            normalized * 2.0 - 1.0
        )
    }

    // =========================================================================
    // MARK: - Terrain Height Query
    // =========================================================================

    private func terrainHeightAt(
        worldX: Float,
        worldZ: Float
    ) -> Float {

        terrainHeight(
            worldX: worldX,
            worldZ: worldZ
        )
    }

    // =========================================================================
    // MARK: - Player Position
    // =========================================================================

    private func updateShipPosition(
        x: Float,
        y: Float,
        z: Float
    ) {
        let terrainY = terrainHeightAt(
            worldX: x,
            worldZ: z
        )

        let minimumShipY = terrainY + shipHeightOffset

        let resolvedY = max(
            y,
            minimumShipY
        )

        shipRoot.position = SCNVector3(
            x,
            resolvedY,
            z
        )

        recycleTerrain(
            aroundZ: z
        )
    }

    // =========================================================================
    // MARK: - Terrain Recycling
    // =========================================================================

    private func recycleTerrain(
        aroundZ shipZ: Float
    ) {

        guard !terrainSegments.isEmpty else {
            return
        }

        // -------------------------------------------------------------
        // Find furthest segment behind the ship.
        // -------------------------------------------------------------

        var furthestBackIndex = 0
        var furthestBackZ =
            terrainSegments[0].position.z

        for index in terrainSegments.indices {

            let z =
                terrainSegments[index].position.z

            if z < furthestBackZ {

                furthestBackZ = z
                furthestBackIndex = index
            }
        }

        // -------------------------------------------------------------
        // If the ship has moved far enough forward, move the oldest
        // segment to the front.
        // -------------------------------------------------------------

        let forwardThreshold =
            terrainSegmentLength * 1.5

        if shipZ - furthestBackZ >
            forwardThreshold {

            var furthestFrontZ =
                terrainSegments[0].position.z

            for segment in terrainSegments {

                furthestFrontZ =
                    max(
                        furthestFrontZ,
                        segment.position.z
                    )
            }

            let newCenterZ =
                furthestFrontZ +
                terrainSegmentLength

            let segment =
                terrainSegments[
                    furthestBackIndex
                ]

            // Regenerate because the noise coordinates are tied to
            // world Z.

            let replacementGeometry =
                makeFractalTerrainGeometry(
                    centerZ: newCenterZ
                )

            segment.geometry =
                replacementGeometry

            segment.position =
                SCNVector3(
                    0,
                    0,
                    newCenterZ
                )
        }
    }

    // =========================================================================
    // MARK: - Enemy Position
    // =========================================================================

    private func updateEnemy(
        gameState: GameState
    ) {

        guard let enemy =
                gameState.enemySpaceShip
        else {
            enemyRoot.isHidden = true
            return
        }

        enemyRoot.isHidden = false

        // EnemySpaceShip position is treated as a WORLD position,
        // matching the coordinate convention used by the rest of
        // the game.

        enemyRoot.position =
            enemy.position

        // Make the enemy hover above the terrain when appropriate.

        let terrainY =
            terrainHeightAt(
                worldX: enemy.position.x,
                worldZ: enemy.position.z
            )

        if enemyRoot.position.y <
            terrainY + 4.0 {

            enemyRoot.position.y =
                terrainY + 4.0
        }

        // Slowly rotate the enemy visually.

        enemyRoot.eulerAngles.y += 0.005
    }

    // =========================================================================
    // MARK: - Cannon Aim
    // =========================================================================

    private func updateCannonAim(
        gameState: GameState
    ) {

        let yaw =
            Float(
                gameState.cannonAzimuth
            )

        let pitch =
            Float(
                gameState.cannonElevation
            )

        // SAME CONVENTION AS OCEAN.

        cannonBarrelPivot.eulerAngles =
            SCNVector3(
                pitch,
                -yaw,
                0
            )

        // =============================================================
        // Actual world muzzle position
        // =============================================================

        let muzzleWorldPosition =
            muzzleNode.presentation.worldPosition

        gameState.cannonMuzzleWorldPosition =
            muzzleWorldPosition

        // =============================================================
        // Actual cannon world direction
        // =============================================================
        //
        // SceneKit forward = -Z.
        //
        // We transform a point one unit along -Z from the actual
        // rendered muzzle node into world coordinates.
        //

        let localForward =
            SCNVector3(
                0,
                0,
                -1
            )

        let worldForward =
            muzzleNode.presentation.convertPosition(
                localForward,
                to: scene.rootNode
            )

        let direction =
            SCNVector3(
                worldForward.x -
                    muzzleWorldPosition.x,

                worldForward.y -
                    muzzleWorldPosition.y,

                worldForward.z -
                    muzzleWorldPosition.z
            )

        let directionLength =
            sqrt(
                direction.x * direction.x +
                direction.y * direction.y +
                direction.z * direction.z
            )

        if directionLength > 0.0001 {

            gameState.cannonWorldDirection =
                SCNVector3(
                    direction.x / directionLength,
                    direction.y / directionLength,
                    direction.z / directionLength
                )
        }
    }

    // =========================================================================
    // MARK: - Sync
    // =========================================================================

    func sync(
        with gameState: GameState
    ) {

        // =====================================================================
        // DELTA TIME
        // =====================================================================

        let now =
            CACurrentMediaTime()

        let rawDT =
            now - lastSyncTime

        lastSyncTime =
            now

        let dt =
            CGFloat(
                min(
                    max(rawDT, 0.0),
                    0.05
                )
            )

        // =====================================================================
        // TERRAIN ENVIRONMENT
        // =====================================================================

        scene.background.contents =
            UIColor(
                red: 0.035,
                green: 0.055,
                blue: 0.075,
                alpha: 1.0
            )

        scene.fogColor =
            UIColor(
                red: 0.045,
                green: 0.065,
                blue: 0.085,
                alpha: 1.0
            )

        scene.fogStartDistance =
            35.0

        scene.fogEndDistance =
            170.0

        // =====================================================================
        // PLAYER SHIP
        // =====================================================================
        //
        // gameState.spaceShip already advances X (lateral input) and Z
        // (forward progress) for the terrain scene -- see
        // SpaceShip.updateTerrain(). Read that position directly instead
        // of recomputing forward progress locally: the previous local
        // `shipPosition.z += terrainSpeed * dt` was never written back
        // into GameState, so the ship's logical Z reset to 0 every
        // frame and terrain forward progress never actually
        // accumulated.
        //
        // This section now runs BEFORE the game managers below so that
        // shark hunting AI (which targets gameState.spaceShip.position)
        // uses this frame's ship position instead of one frame stale.
        //

        let shipPosition =
            gameState.spaceShip.position

        updateShipPosition(
            x: shipPosition.x,
            y: shipPosition.y,
            z: shipPosition.z
        )

        // IMPORTANT:
        //
        // shipRoot is positioned from the terrain height.
        //
        // camera is a CHILD of shipRoot.
        //
        // Therefore camera.worldPosition automatically follows
        // the terrain-following ship.
        //
        // Write the terrain-corrected world position (with the real
        // height-mapped Y) back into GameState so other systems --
        // shark AI, enemy AI, HUD, etc. -- see the ship's true
        // rendered altitude instead of a stale Y left over from
        // whichever scene ran previously.

        gameState.spaceShip.position =
            shipRoot.position

        // =====================================================================
        // GAME MANAGERS
        // =====================================================================
        //
        // These remain owned by GameState.
        //
        // The renderer does not create or simulate sharks itself.
        //

        gameState.sharkManager.update(
            game: gameState,
            dt: dt
        )

        // ---------------------------------------------------------------
        // SHARK TERRAIN FLOOR
        //
        // SharkManager's own bounds are tuned for the Ocean scene's
        // fixed vertical range (-1.5...8) and have no knowledge of the
        // generated terrain height field, so they cannot keep sharks
        // above the ground mesh here. Clamp every shark using the
        // actual terrain height at its own (x, z), so a shark can
        // never sink below the terrain it's flying over.
        // ---------------------------------------------------------------

        let sharkTerrainClearance: Float = 0.6

        for shark in gameState.sharks
        where !shark.destroyed {

            let groundY =
                terrainHeightAt(
                    worldX: shark.position.x,
                    worldZ: shark.position.z
                )

            let minimumSharkY =
                groundY + sharkTerrainClearance

            if shark.position.y < minimumSharkY {

                shark.position.y =
                    minimumSharkY
            }
        }

        gameState.asteroidManager.update(
            game: gameState,
            dt: dt
        )

        // =====================================================================
        // CANNON
        // =====================================================================

        updateCannonAim(
            gameState: gameState
        )

        // =====================================================================
        // ENEMY SPACESHIP
        // =====================================================================

        updateEnemy(
            gameState: gameState
        )

        // =====================================================================
        // SHARKS
        // =====================================================================

        var seenSharks =
            Set<ObjectIdentifier>()

        for shark in gameState.sharks
        where !shark.destroyed {

            let id =
                ObjectIdentifier(shark)

            seenSharks.insert(id)

            let node: SCNNode

            if let existing =
                gameState.sharkNodes[id] {

                node = existing

            } else {

                node =
                    CreatureMesh.makeShark()

                sharkContainer.addChildNode(
                    node
                )

                gameState.sharkNodes[id] =
                    node
            }

            // SharkManager owns the actual WORLD position.

            node.position =
                shark.position

            // Face direction of travel.

            node.eulerAngles.y =
                Float(
                    shark.lateralAngle
                )

            // Swimming animation.

            CreatureMesh.animateShark(
                node,
                phase: shark.animPhase
            )
        }

        // Remove destroyed/removed sharks.

        for (id, node)
        in gameState.sharkNodes {

            if !seenSharks.contains(id) {

                node.removeFromParentNode()

                gameState.sharkNodes.removeValue(
                    forKey: id
                )
            }
        }

        // =====================================================================
        // PLAYER LASERS
        // =====================================================================

        laserContainer.childNodes.forEach {
            $0.removeFromParentNode()
        }

        for laser in gameState.playerLasers {

            let node =
                laser.makeLaserNode(
                    color: .green
                )

            // Laser position is already WORLD SPACE.

            node.position =
                laser.position

            laserContainer.addChildNode(
                node
            )
        }

        // =====================================================================
        // ENEMY LASERS
        // =====================================================================

        for laser in gameState.enemyLasers {

            let node =
                laser.makeLaserNode(
                    color: .red
                )

            // Laser position is WORLD SPACE.

            node.position =
                laser.position

            laserContainer.addChildNode(
                node
            )
        }

        // =====================================================================
        // EXPLOSIONS
        // =====================================================================

        processExplosions(
            gameState
        )
    }

    // =========================================================================
    // MARK: - Explosions
    // =========================================================================

    private func processExplosions(
        _ game: GameState
    ) {

        guard
            !game.pendingExplosions.isEmpty
        else {
            return
        }

        for explosion in
            game.pendingExplosions {

            // -------------------------------------------------------------
            // Core
            // -------------------------------------------------------------

            let coreGeometry =
                SCNSphere(
                    radius: 0.12
                )

            coreGeometry.firstMaterial?.diffuse.contents =
                UIColor.orange

            coreGeometry.firstMaterial?.emission.contents =
                UIColor.yellow

            let explosionNode =
                SCNNode(
                    geometry: coreGeometry
                )

            explosionNode.position =
                SCNVector3(
                    Float(explosion.x),
                    Float(explosion.y),
                    Float(explosion.z)
                )

            explosionNode.scale =
                SCNVector3(
                    0.1,
                    0.1,
                    0.1
                )

            scene.rootNode.addChildNode(
                explosionNode
            )

            // -------------------------------------------------------------
            // Animation
            // -------------------------------------------------------------

            let scale =
                CGFloat(explosion.scale)

            let grow =
                SCNAction.scale(
                    to: 3.0 * scale,
                    duration: 0.12
                )

            grow.timingMode =
                .easeOut

            let fade =
                SCNAction.fadeOut(
                    duration: 0.18
                )

            let wait =
                SCNAction.wait(
                    duration: 0.04
                )

            let remove =
                SCNAction.removeFromParentNode()

            let sequence =
                SCNAction.sequence([
                    grow,
                    wait,
                    fade,
                    remove
                ])

            explosionNode.runAction(
                sequence
            )
        }

        // Events consumed.

        game.pendingExplosions.removeAll()
    }
}

// =============================================================================
// MARK: - Optional Direction Helper
// =============================================================================
//
// Kept here because other SceneKit terrain/creature code may use it.
// =============================================================================

private func rotationFromYAxis(
    to direction: SCNVector3
) -> SCNQuaternion {

    let from =
        SCNVector3(
            0,
            1,
            0
        )

    let to =
        direction.normalizedFunc()

    let dot =
        from.x * to.x +
        from.y * to.y +
        from.z * to.z

    // Already pointing +Y.

    if dot > 0.999999 {

        return SCNQuaternion(
            0,
            0,
            0,
            1
        )
    }

    // Exactly opposite +Y.

    if dot < -0.999999 {

        return SCNQuaternion(
            1,
            0,
            0,
            0
        )
    }

    let axis =
        SCNVector3(
            from.y * to.z -
                from.z * to.y,

            from.z * to.x -
                from.x * to.z,

            from.x * to.y -
                from.y * to.x
        )

    let s =
        sqrt(
            (1.0 + dot) * 2.0
        )

    let inverseS =
        1.0 / s

    return SCNQuaternion(
        axis.x * inverseS,
        axis.y * inverseS,
        axis.z * inverseS,
        s * 0.5
    )
}
