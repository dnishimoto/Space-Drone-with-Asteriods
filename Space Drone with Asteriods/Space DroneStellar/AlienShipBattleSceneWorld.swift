//
//  AlienShipBattleSceneWorld.swift
//
//  Alien fleet cellular-automaton battle world.
//
//  Responsibilities:
//  - Owns the single alien fleet and the alien projectiles
//  - Steps the fleet from GameState.update() (see step(dt:game:))
//  - Follows the player ship with the camera
//  - Aims the cockpit cannon and publishes its muzzle position and
//    world direction to GameState so shootLaser() fires from the
//    end of the barrel
//  - Resolves player cannon lasers against the aliens
//  - Renders ships and projectiles (cached nodes, no per-frame rebuild)
//
//  Coordinates:
//  Everything is in WORLD space, the same space as
//  gameState.spaceShip.position and gameState.playerLasers. The
//  camera looks down +Z, exactly like the Terrain scene.
//

import Foundation
import SceneKit
import UIKit
import simd

@MainActor
final class AlienShipBattleSceneWorld {


    let scene = SCNScene()

    let camera = SCNNode()

    private let fleetContainer = SCNNode()

    private let projectileContainer = SCNNode()

    /// World-space container for the player's cannon lasers.
    private let playerLaserContainer = SCNNode()

    // ============================================================
    // Player tracking
    // ============================================================
    private(set) var playerLife: Int = 3
    private var playerKillCount: Int = 0

    // ============================================================
    // TUNING
    // ============================================================

    /// Same camera relationship as the Terrain scene
    /// (camera sits just behind and above the ship position).
    private let cameraOffset = SCNVector3(0, 0.3, -2.8)

    /// Fraction of the player's forward speed the fleet keeps, so the
    /// battle stays in front of the player instead of being flown
    /// through in a few seconds. Disabled ships do not keep pace and
    /// are left behind.
    private static let convoyFactor: Float = 0.85

    /// Ships further than this behind the player are removed.
    private static let cullBehind: Float = 10.0

    /// Ships further than this ahead are stale (e.g. after a restart).
    private static let cullAhead: Float = 120.0

    /// Seconds between a finished battle and the next wave.
    private static let waveDelay: CGFloat = 2.0

    // ============================================================
    // COCKPIT CANNON
    // ============================================================

    private let cockpitCannonNode = SCNNode()

    private let cannonBarrelPivot = SCNNode()

    private let cannonBarrel = SCNNode()

    private let muzzleNode = SCNNode()

    // ============================================================
    // FLEET
    // ============================================================

    private(set) var fleet: [AlienShipState] = []

    private(set) var projectiles: [Projectile] = []

    private var nextFleetID: Int = 0

    private var waveTimer: CGFloat = 0.0

    private var hasAnchored = false

    let maxFleetSize: Int

    // ============================================================
    // RENDER CACHES
    // ============================================================

    private var shipNodes: [Int: SCNNode] = [:]

    private var shipVisualState:
        [Int: AlienShipState.BehavioralState] = [:]

    private var projectileNodes: [SCNNode] = []

    private var playerLaserNodes: [SCNNode] = []

    /// One shared beam geometry for every player laser (same size and
    /// look as Laser.makeLaserNode, but not rebuilt per laser per frame).
    private lazy var playerLaserGeometry: SCNCylinder = {

        let geometry = SCNCylinder(
            radius: 0.05,
            height: 0.75
        )

        geometry.firstMaterial?.diffuse.contents = UIColor.green
        geometry.firstMaterial?.emission.contents = UIColor.green
        geometry.firstMaterial?.isDoubleSided = true

        return geometry
    }()

    private lazy var alphaLaserGeometry =
        makeLaserGeometry(color: .magenta)

    private lazy var betaLaserGeometry =
        makeLaserGeometry(color: .orange)

    private lazy var neutralLaserGeometry =
        makeLaserGeometry(color: .white)

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(fleetSize: Int = 8) {

        self.maxFleetSize = max(
            1,
            fleetSize
        )

        // CAMERA

        let cam = SCNCamera()

        cam.zNear = 0.05
        cam.zFar = 200.0
        cam.fieldOfView = 72.0

        camera.camera = cam

        camera.position = cameraOffset

        // Look down +Z.
        camera.eulerAngles = SCNVector3(
            0,
            Float.pi,
            0
        )

        scene.rootNode.addChildNode(camera)

        // CONTAINERS

        scene.rootNode.addChildNode(
            fleetContainer
        )

        scene.rootNode.addChildNode(
            projectileContainer
        )

        scene.rootNode.addChildNode(
            playerLaserContainer
        )

        // COCKPIT CANNON

        setupCockpitCannon()

        // INITIAL FLEET
        //
        // The ship position is not known yet; the first sync(with:)
        // re-anchors the fleet around the real ship position.

        spawnFleet(
            around: SCNVector3(0, 0, 0)
        )

        renderFleet()
    }
    func renderFleet() {

        var live = Set<Int>()

        // ============================================================
        // RENDER LIVE ALIEN SHIPS
        // ============================================================

        for ship in fleet
        where !ship.destroyed {

            live.insert(ship.fleetID)

            let node =
                shipNodes[ship.fleetID]
                ?? makeShipNode(for: ship)

            node.position = ship.position

            updateAppearance(
                of: node,
                for: ship
            )
        }

        // ============================================================
        // REMOVE NODES THAT ARE NO LONGER LIVE
        // ============================================================

        for (id, node) in shipNodes
        where !live.contains(id) {

            node.removeFromParentNode()
        }

        // ============================================================
        // CLEAN NODE CACHE
        // ============================================================

        shipNodes = shipNodes.filter {
            live.contains($0.key)
        }

        // ============================================================
        // CLEAN APPEARANCE STATE
        // ============================================================

        shipVisualState = shipVisualState.filter {
            live.contains($0.key)
        }
    }
    // ============================================================
    // COCKPIT CANNON
    //
    // Same hierarchy as the Terrain and Ocean scenes:
    //
    //   camera
    //    └── cockpitCannonNode
    //         └── cannonBarrelPivot   (rear hinge, rotated by aim)
    //              └── cannonBarrel   (cylinder, rotated -90° about X)
    //                   └── muzzleNode (barrel tip, rotated +90° back)
    // ============================================================

    private func setupCockpitCannon() {

        cockpitCannonNode.removeFromParentNode()
        cannonBarrelPivot.removeFromParentNode()
        cannonBarrel.removeFromParentNode()
        muzzleNode.removeFromParentNode()

        // COCKPIT ROOT

        camera.addChildNode(
            cockpitCannonNode
        )

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

        // REAR-END HINGE

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

        // BARREL

        let barrelLength: Float = 0.72

        let halfLength =
            barrelLength * 0.5

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

        cannonBarrel.geometry =
            barrelGeometry

        cannonBarrel.pivot =
            SCNMatrix4Identity

        // SCNCylinder extends along local +Y.
        // Rotate +Y toward camera-forward (-Z).

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

        // MUZZLE
        //
        // The muzzle sits at the TIP of the barrel (local +Y of the
        // cylinder) and is rotated +90° about X to cancel the
        // barrel's -90°, so the muzzle's local -Z is the true
        // firing direction.
        //
        // (It used to sit at local -Z with no rotation, which put it
        // mid-barrel and pointing straight down.)

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

    // ============================================================
    // CANNON AIM
    //
    // Same convention as the Terrain scene. Publishes the muzzle
    // position and world-space direction that
    // GameState.shootLaser() captures when it fires.
    //
    // Model-tree transforms are used (not .presentation) so the
    // values reflect the camera and aim set this very frame.
    // ============================================================

    private func updateCannonAim(
        game: GameState
    ) {

        let yaw =
            Float(game.cannonAzimuth)

        let pitch =
            Float(game.cannonElevation)

        cannonBarrelPivot.eulerAngles =
            SCNVector3(
                pitch,
                -yaw,
                0
            )

        game.cannonMuzzleWorldPosition =
            muzzleNode.worldPosition

        let worldDirection =
            muzzleNode.simdWorldOrientation.act(
                SIMD3<Float>(0, 0, -1)
            )

        let length = sqrt(
            worldDirection.x * worldDirection.x +
            worldDirection.y * worldDirection.y +
            worldDirection.z * worldDirection.z
        )

        guard length > 0.0001 else {
            return
        }

        game.cannonWorldDirection =
            SCNVector3(
                worldDirection.x / length,
                worldDirection.y / length,
                worldDirection.z / length
            )
    }

    // ============================================================
    // MUZZLE ACCESSORS
    // ============================================================

    var muzzleWorldPosition: SCNVector3 {

        muzzleNode.worldPosition
    }

    var muzzleWorldDirection: SCNVector3 {

        let d = muzzleNode.simdWorldOrientation.act(
            SIMD3<Float>(0, 0, -1)
        )

        let length = sqrt(
            d.x * d.x +
            d.y * d.y +
            d.z * d.z
        )

        guard length > 0.0001 else {
            return SCNVector3(0, 0, 1)
        }

        return SCNVector3(
            d.x / length,
            d.y / length,
            d.z / length
        )
    }

    // ============================================================
    // CAMERA FOLLOWS THE PLAYER SHIP
    // ============================================================

    private func updateCamera(
        game: GameState
    ) {

        let ship = game.spaceShip.position

        camera.position = SCNVector3(
            ship.x + cameraOffset.x,
            ship.y + cameraOffset.y,
            ship.z + cameraOffset.z
        )
    }

    // ============================================================
    // SPAWN FLEET
    //
    // Spawns a fresh wave ahead of `anchor` (the player ship), half
    // alpha and half beta so the two factions fight each other.
    // ============================================================

    func spawnFleet(
        around anchor: SCNVector3
    ) {

        fleet.removeAll(
            keepingCapacity: true
        )

        projectiles.removeAll(
            keepingCapacity: true
        )

        for index in 0..<maxFleetSize {

            let angle =
                Float.random(
                    in: 0..<(2.0 * .pi)
                )

            let radius =
                Float.random(
                    in: 8.0...18.0
                )

            let position = SCNVector3(
                anchor.x + cos(angle) * radius,
                anchor.y + sin(angle) * radius,
                anchor.z + Float.random(in: 35.0...60.0)
            )

            let velocity = SCNVector3(
                Float.random(in: (-0.5)...0.5),
                Float.random(in: (-0.5)...0.5),
                Float.random(in: (-1.5)...(-0.5))
            )

            let faction:
                AlienShipState.Faction =
                index % 2 == 0
                ? .alpha
                : .beta

            // fleetID is never reused, so projectile ownerIDs and
            // cached render nodes can never alias an older ship.

            let ship =
                AlienShipState(
                    fleetID: nextFleetID,
                    position: position,
                    velocity: velocity,
                    faction: faction,
                    behavioralState: .approaching
                )

            nextFleetID += 1

            fleet.append(
                ship
            )
        }

        waveTimer = 0.0
    }

    // ============================================================
    // STEP
    //
    // Called every frame from GameState.update() through
    // AlienShipState.update(gameState:dt:).
    // ============================================================

    func step(
        dt: CGFloat,
        game: GameState
    ) {

        guard dt > 0 else {
            return
        }

        let dtF = Float(dt)

        let shipPosition =
            game.spaceShip.position

        let shipSpeed =
            Float(game.spaceShip.forwardSpeed)

        // ========================================================
        // 1. CELLULAR AUTOMATON GENERATION
        //
        // Every ship reads the same snapshot of the previous
        // generation, then updates only itself.
        // ========================================================

        let snapshot = fleet.map {
            $0.snapshot
        }

        for ship in fleet
        where !ship.destroyed {

            if let shot = ship.update(
                allShips: snapshot,
                obstacles: [],
                dt: dt
            ) {
                projectiles.append(shot)
            }
        }

        // ========================================================
        // 2. CONVOY MOTION
        //
        // The ship's own velocity was already integrated inside
        // AlienShipState.update. This only adds the part that keeps
        // the fleet in the player's frame. Disabled ships are dead
        // in the water and get left behind.
        // ========================================================

        for ship in fleet
        where !ship.destroyed && !ship.disabled {

            ship.position.z +=
                shipSpeed * dtF * Self.convoyFactor
        }

        // ========================================================
        // 3. HITS
        // ========================================================

        advanceAlienProjectiles(dt: dtF, game: game)

        resolvePlayerLasers(
            game: game,
            dt: dtF
        )

        // ========================================================
        // 4. CLEAN UP
        // ========================================================

        let minimumZ = shipPosition.z - Self.cullBehind
        let maximumZ = shipPosition.z + Self.cullAhead

        fleet.removeAll { ship in

            ship.destroyed ||
            ship.position.z < minimumZ ||
            ship.position.z > maximumZ
        }

        projectiles.removeAll { shot in

            shot.position.z < minimumZ ||
            shot.position.z > maximumZ
        }

        // ========================================================
        // 5. NEXT WAVE
        //
        // The battle is over when fewer than two factions still have
        // an active (not disabled) ship. Disabled hulks do not keep
        // a battle alive.
        // ========================================================

        var activeFactions = Set<AlienShipState.Faction>()

        for ship in fleet
        where !ship.destroyed && !ship.disabled {

            activeFactions.insert(ship.faction)
        }

        if activeFactions.count < 2 {

            waveTimer += dt

            if waveTimer >= Self.waveDelay {

                spawnFleet(
                    around: shipPosition
                )
            }

        } else {

            waveTimer = 0.0
        }
    }

    // ============================================================
    // ALIEN PROJECTILES
    //
    // Moves every alien shot and resolves it against enemy ships
    // with a swept (segment vs sphere) test so fast shots cannot
    // tunnel through a ship between frames.
    // Also alien projectiles can hit the player.
    // ============================================================

    private func advanceAlienProjectiles(
        dt: Float,
        game: GameState
    ) {

        var survivors: [Projectile] = []

        for var shot in projectiles {

            let start = shot.position

            shot.position = AlienShipState.add(
                start,
                AlienShipState.multiply(
                    shot.velocity,
                    dt
                )
            )

            shot.lifetime -= dt

            guard shot.lifetime > 0.0 else {
                continue
            }

            var consumed = false

            // Check hits on alien ships
            for ship in fleet
            where !ship.destroyed &&
                  ship.fleetID != shot.ownerID &&
                  AlienShipState.projectileHurts(
                    source: shot.sourceFaction,
                    target: ship.faction
                  ) {

                let miss =
                    AlienShipState.distanceToSegment(
                        ship.position,
                        start,
                        shot.position
                    )

                if miss <= ship.collisionRadius {

                    ship.applyDamage(shot.damage)

                    consumed = true

                    break
                }
            }

            if consumed {
                // Alien projectile hit an alien ship
                continue
            }

            // ====================================================
            // Alien projectiles can hit the player
            // ====================================================

            if shot.targetID == nil || shot.targetID == -1 {
                // Check swept collision with player ship at radius 1.0
                let missToPlayer = AlienShipState.distanceToSegment(
                    game.spaceShip.position,
                    start,
                    shot.position
                )
                if missToPlayer <= 1.0 {
                    // Player hit by alien projectile
                    playerLife -= 1
                    game.setPlayerLives(playerLife) // Update UI

                    // Create explosion at hit position (approximate with shot.position)
                    createAlienDestructionBurst(at: shot.position)

                    if playerLife <= 0 {
                        game.gameOver = true
                    }

                    consumed = true
                    // Break after hit
                }
            }

            if !consumed {
                survivors.append(shot)
            }
        }

        projectiles = survivors
    }

    private func resolvePlayerLasers(
        game: GameState,
        dt: Float
    ) {
        guard !game.playerLasers.isEmpty else {
            return
        }

        let travel = Float(Laser.speed) * dt

        var consumedIndices: Set<Int> = []
        var shipsToRemove: [AlienShipState] = []

        // Detect laser collisions.
        for index in game.playerLasers.indices {

            let laser = game.playerLasers[index]

            guard laser.isPlayerLaser else {
                continue
            }

            let end = laser.worldPosition()

            let start = AlienShipState.subtract(
                end,
                AlienShipState.multiply(
                    laser.direction,
                    travel
                )
            )

            for ship in fleet where !ship.destroyed {

                let miss =
                    AlienShipState.distanceToSegment(
                        ship.position,
                        start,
                        end
                    )

                guard miss <= ship.collisionRadius + 0.15 else {
                    continue
                }

                // One player laser hit destroys the alien.
                ship.applyPlayerLaserHit()

                consumedIndices.insert(index)

                if ship.destroyed {
                    shipsToRemove.append(ship)

                    // Player kill count increment and extra life every 3 kills
                    playerKillCount += 1
                    if playerKillCount == 3 {
                        playerLife += 1
                        game.setPlayerLives(playerLife) // Update UI
                        playerKillCount = 0
                        // Player gains an extra life every 3 kills
                    }
                }

                break
            }
        }

        // Remove consumed player lasers.
        for index in consumedIndices.sorted(by: >) {
            guard game.playerLasers.indices.contains(index) else {
                continue
            }

            game.playerLasers.remove(at: index)
        }

        // ---------------------------------------------------------
        // CLEANUP ONLY THE ALIENS COLLECTED IN shipsToRemove.
        // ---------------------------------------------------------

        guard !shipsToRemove.isEmpty else {
            return
        }

        for ship in shipsToRemove {

            // Capture the exact destruction location.
            let destructionPosition = ship.position

            // CREATE THE BURST HERE.
            createAlienDestructionBurst(
                at: destructionPosition
            )

            // Remove alien from fleet.
            if let fleetIndex = fleet.firstIndex(where: {
                $0 === ship
            }) {
                fleet.remove(at: fleetIndex)
            }

            // Remove alien's SceneKit node.
            if let node = shipNodes.removeValue(
                forKey: ship.fleetID
            ) {
                node.removeFromParentNode()
            }

            // Remove cached visual state.
            shipVisualState.removeValue(
                forKey: ship.fleetID
            )
        }
    }
    private func createAlienDestructionBurst(at position: SCNVector3) {
        let burstNode = SCNNode()
        burstNode.position = position

        let particles = SCNParticleSystem()

        // One-shot emission.
        particles.birthRate = 2500
        particles.birthRateVariation = 0
        particles.loops = false
        particles.emissionDuration = 0.05
        particles.emissionDurationVariation = 0
        particles.warmupDuration = 0

        // Particle lifetime and size.
        particles.particleLifeSpan = 0.45
        particles.particleLifeSpanVariation = 0.20

        particles.particleSize = 0.08
        particles.particleSizeVariation = 0.06

        // SceneKit uses geometry to define the emitter.
        particles.emitterShape = SCNSphere(radius: 0.12)
        particles.birthLocation = .surface
        particles.birthDirection = .random
        particles.spreadingAngle = 180

        // Burst motion.
        particles.particleVelocity = 5.0
        particles.particleVelocityVariation = 3.0
        particles.acceleration = SCNVector3(0, -1.5, 0)

        // Appearance.
        particles.blendMode = .additive
        particles.particleColor = .white
        particles.particleColorVariation = SCNVector4(
            1.0,
            0.5,
            0.2,
            0.0
        )

        burstNode.addParticleSystem(particles)
        scene.rootNode.addChildNode(burstNode)

        // Leave time for the emitted particles to expire.
        burstNode.runAction(
            SCNAction.sequence([
                SCNAction.wait(duration: 1.0),
                SCNAction.removeFromParentNode()
            ])
        )
    }

    private func makeShipNode(
        for ship: AlienShipState
    ) -> SCNNode {

        // =========================================================
        // POLYGONAL ALIEN SHIP
        // =========================================================

        let segments = 10

        // Hull profile:
        //
        //             _________
        //          __/         \__
        //       __/               \__
        //     _/                     \_
        //    /                         \
        //    \_________________________/

        let rings: [
            (radius: Float, y: Float)
        ] = [
            (0.16,  0.22),   // top center
            (0.30,  0.18),   // upper dome
            (0.50,  0.10),   // upper shoulder
            (0.68,  0.00),   // widest point
            (0.54, -0.10),   // lower shoulder
            (0.28, -0.16),   // underside
            (0.16, -0.18)    // bottom
        ]

        // =========================================================
        // CREATE VERTICES
        // =========================================================

        var vertices: [SCNVector3] = []

        for ring in rings {

            for i in 0..<segments {

                let angle =
                    (Float(i) / Float(segments)) *
                    Float.pi * 2.0

                let x =
                    cos(angle) * ring.radius

                let z =
                    sin(angle) * ring.radius

                vertices.append(
                    SCNVector3(
                        x,
                        ring.y,
                        z
                    )
                )
            }
        }

        // =========================================================
        // CREATE TRIANGULAR POLYGON FACES
        // =========================================================

        var indices: [UInt32] = []

        for ringIndex in 0..<(rings.count - 1) {

            let currentStart =
                ringIndex * segments

            let nextStart =
                (ringIndex + 1) * segments

            for i in 0..<segments {

                let next =
                    (i + 1) % segments

                let a =
                    UInt32(currentStart + i)

                let b =
                    UInt32(currentStart + next)

                let c =
                    UInt32(nextStart + i)

                let d =
                    UInt32(nextStart + next)

                // Triangle 1
                indices.append(a)
                indices.append(c)
                indices.append(b)

                // Triangle 2
                indices.append(b)
                indices.append(c)
                indices.append(d)
            }
        }

        // =========================================================
        // CREATE SCENE KIT GEOMETRY
        // =========================================================

        let vertexSource =
            SCNGeometrySource(
                vertices: vertices
            )

        let indexData =
            indices.withUnsafeBufferPointer {
                Data(buffer: $0)
            }

        let element =
            SCNGeometryElement(
                data: indexData,
                primitiveType: .triangles,
                primitiveCount: indices.count / 3,
                bytesPerIndex: MemoryLayout<UInt32>.size
            )

        let geometry =
            SCNGeometry(
                sources: [
                    vertexSource
                ],
                elements: [
                    element
                ]
            )

        // =========================================================
        // FACTION COLOR
        // =========================================================

        let factionColor: UIColor

        switch ship.faction {

        case .alpha:
            factionColor = .magenta

        case .beta:
            factionColor = .orange

        case .neutral:
            factionColor = .gray

        case .unknown:
            factionColor = .white
        }

        // =========================================================
        // DARK METALLIC HULL
        // =========================================================

        let hullMaterial =
            SCNMaterial()

        hullMaterial.diffuse.contents =
            UIColor(
                white: 0.12,
                alpha: 1.0
            )

        hullMaterial.metalness.contents =
            0.85

        hullMaterial.roughness.contents =
            0.28

        geometry.materials = [
            hullMaterial
        ]

        // =========================================================
        // MAIN SHIP NODE
        // =========================================================

        let node =
            SCNNode(
                geometry: geometry
            )

        // =========================================================
        // RAISED POLYGONAL COMMAND MODULE
        // =========================================================

        let commandGeometry =
            SCNCylinder(
                radius: 0.27,
                height: 0.09
            )

        commandGeometry.radialSegmentCount =
            10

        let commandMaterial =
            SCNMaterial()

        commandMaterial.diffuse.contents =
            UIColor(
                white: 0.16,
                alpha: 1.0
            )

        commandMaterial.metalness.contents =
            0.90

        commandMaterial.roughness.contents =
            0.22

        commandGeometry.materials = [
            commandMaterial
        ]

        let commandNode =
            SCNNode(
                geometry: commandGeometry
            )

        commandNode.position =
            SCNVector3(
                0,
                0.20,
                0
            )

        node.addChildNode(
            commandNode
        )

        // =========================================================
        // TOP ENERGY CORE
        //
        // Emission creates the visual glow but does NOT create
        // a light that illuminates other objects in the scene.
        // =========================================================

        let glowMaterial =
            SCNMaterial()

        glowMaterial.diffuse.contents =
            factionColor

        glowMaterial.emission.contents =
            factionColor

        glowMaterial.emission.intensity =
            4.0

        let topGlowGeometry =
            SCNCylinder(
                radius: 0.18,
                height: 0.018
            )

        topGlowGeometry.radialSegmentCount =
            10

        topGlowGeometry.materials = [
            glowMaterial
        ]

        let topGlowNode =
            SCNNode(
                geometry: topGlowGeometry
            )

        topGlowNode.position =
            SCNVector3(
                0,
                0.253,
                0
            )

        node.addChildNode(
            topGlowNode
        )

        // =========================================================
        // PERIMETER ENERGY PANELS
        // =========================================================

        for i in 0..<segments {

            let angle =
                (Float(i) / Float(segments)) *
                Float.pi * 2.0

            let panelGeometry =
                SCNBox(
                    width: 0.24,
                    height: 0.035,
                    length: 0.035,
                    chamferRadius: 0.008
                )

            panelGeometry.materials = [
                glowMaterial
            ]

            let panelNode =
                SCNNode(
                    geometry: panelGeometry
                )

            let radius: Float =
                0.61

            panelNode.position =
                SCNVector3(
                    cos(angle) * radius,
                    -0.005,
                    sin(angle) * radius
                )

            panelNode.eulerAngles =
                SCNVector3(
                    0,
                    -angle,
                    0
                )

            node.addChildNode(
                panelNode
            )
        }

        // =========================================================
        // UNDERSIDE ENGINE
        // =========================================================

        let engineGeometry =
            SCNCylinder(
                radius: 0.38,
                height: 0.025
            )

        engineGeometry.radialSegmentCount =
            10

        engineGeometry.materials = [
            glowMaterial
        ]

        let engineNode =
            SCNNode(
                geometry: engineGeometry
            )

        engineNode.position =
            SCNVector3(
                0,
                -0.19,
                0
            )

        node.addChildNode(
            engineNode
        )

        // =========================================================
        // NO SCNLight
        //
        // The previous engineLight / engineLightNode has been
        // intentionally removed.
        //
        // The ship still appears illuminated because the
        // materials use emission, but it does not cast light
        // onto the rest of the SceneKit world.
        // =========================================================

        // =========================================================
        // LARGE SHIP
        // =========================================================

        node.scale =
            SCNVector3(
                2.5,
                2.5,
                2.5
            )

        // =========================================================
        // EXISTING FLEET INTEGRATION
        // =========================================================

        fleetContainer.addChildNode(
            node
        )

        shipNodes[ship.fleetID] =
            node

        return node
    }

    /// Color shows faction; brightness shows what the ship is doing.
    private func updateAppearance(
        of node: SCNNode,
        for ship: AlienShipState
    ) {

        guard shipVisualState[ship.fleetID]
                != ship.behavioralState,
              let material =
                node.geometry?.firstMaterial
        else {
            return
        }

        shipVisualState[ship.fleetID] =
            ship.behavioralState

        let base: UIColor

        switch ship.faction {

        case .alpha:
            base = .purple

        case .beta:
            base = .red

        case .neutral:
            base = .gray

        case .unknown:
            base = .white
        }

        switch ship.behavioralState {

        case .disabled:

            material.diffuse.contents = UIColor.darkGray
            material.emission.contents = UIColor.black
            material.emission.intensity = 0.0

        case .attacking:

            material.diffuse.contents = base
            material.emission.contents = base
            material.emission.intensity = 0.60

        case .evading:

            material.diffuse.contents = base
            material.emission.contents = UIColor.white
            material.emission.intensity = 0.80

        case .retreating:

            material.diffuse.contents = base
            material.emission.contents = base
            material.emission.intensity = 0.08

        default:

            material.diffuse.contents = base
            material.emission.contents = base
            material.emission.intensity = 0.20
        }
    }

    // ============================================================
    // RENDER PROJECTILES
    //
    // Small pool of nodes, one per live alien shot.
    // ============================================================

    private func makeLaserGeometry(
        color: UIColor
    ) -> SCNSphere {

        let geometry =
            SCNSphere(
                radius: 0.12
            )

        let material =
            SCNMaterial()

        material.diffuse.contents = color
        material.emission.contents = color
        material.emission.intensity = 1.0

        geometry.materials = [
            material
        ]

        return geometry
    }

    func renderProjectiles() {

        while projectileNodes.count < projectiles.count {

            let node = SCNNode()

            projectileContainer.addChildNode(
                node
            )

            projectileNodes.append(
                node
            )
        }

        for (index, node) in projectileNodes.enumerated() {

            guard index < projectiles.count else {

                node.isHidden = true

                continue
            }

            let shot = projectiles[index]

            node.isHidden = false

            node.position = shot.position

            switch shot.sourceFaction {

            case .alpha:
                node.geometry = alphaLaserGeometry

            case .beta:
                node.geometry = betaLaserGeometry

            default:
                node.geometry = neutralLaserGeometry
            }
        }
    }

    // ============================================================
    // RENDER PLAYER LASERS
    //
    // The cannon fires through GameState.shootLaser(), which fills
    // gameState.playerLasers. Other worlds draw those lasers; this
    // one did not, so shots were fired and could hit, but were
    // invisible.
    //
    // Laser position and direction are WORLD space and the direction
    // never changes after firing, so each pooled node just copies
    // them every frame. The pool grows to the peak number of lasers
    // in flight and then reuses its nodes.
    // ============================================================

    private func renderPlayerLasers(
        game: GameState
    ) {

        let lasers = game.playerLasers

        while playerLaserNodes.count < lasers.count {

            let node = SCNNode(
                geometry: playerLaserGeometry
            )

            playerLaserContainer.addChildNode(
                node
            )

            playerLaserNodes.append(
                node
            )
        }

        for (index, node) in playerLaserNodes.enumerated() {

            guard index < lasers.count else {

                node.isHidden = true

                continue
            }

            let laser = lasers[index]

            node.isHidden = false

            node.position = laser.position

            // The cylinder's long axis is local +Y; point it along
            // the laser's direction of travel.

            let length = sqrt(
                laser.direction.x * laser.direction.x +
                laser.direction.y * laser.direction.y +
                laser.direction.z * laser.direction.z
            )

            if length > 0.000001 {

                node.simdOrientation = simd_quatf(
                    from: SIMD3<Float>(0, 1, 0),
                    to: SIMD3<Float>(
                        Float(laser.direction.x / length),
                        Float(laser.direction.y / length),
                        Float(laser.direction.z / length)
                    )
                )
            }
        }
    }

    // ============================================================
    // SYNCHRONIZE WITH GAME STATE (render side)
    //
    // Does NOT simulate. It registers this world as THE fleet for
    // the GameState, follows the ship with the camera, aims the
    // cannon and draws the current state.
    // ============================================================

    func sync(
        with game: GameState
    ) {

        if game.alienFleetManager !== self {

            game.alienFleetManager = self
        }

        if !hasAnchored {

            hasAnchored = true

            spawnFleet(
                around: game.spaceShip.position
            )
        }

        updateCamera(game: game)

        updateCannonAim(game: game)

        renderFleet()

        renderProjectiles()

        renderPlayerLasers(game: game)

        displayPlayerLives()
    }

    // ============================================================
    // PLAYER LIVES DISPLAY
    // ============================================================

    private func displayPlayerLives() {
        print("Player Lives: \(playerLife)")
    }
}

