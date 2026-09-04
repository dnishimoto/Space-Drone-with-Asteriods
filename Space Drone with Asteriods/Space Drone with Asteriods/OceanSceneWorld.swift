//
//  File.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

// This class manages the ALIEN OCEAN scene and ocean-stage visuals, creatures, and effects.

import Foundation
import SwiftUI
import SceneKit

final class OceanSceneWorld {
    let scene = SCNScene()
    let camera = SCNNode()
    private let cloudCeilingY: Float = 8.0
    private let oceanSurfaceY: Float = 1.0
    private var lastSyncTime: TimeInterval = CACurrentMediaTime()

    // Camera/HUD-mounted cannon.
    // This belongs ONLY to camera.
    private let cockpitCannonNode = SCNNode()

    private let shipRoot = SCNNode()
    private let shipMesh = SCNNode()
    private let thrusterFlame = SCNNode()
    private let shieldNode = SCNNode()
    private let cannonNode = SCNNode()
    //private let enemyRoot = SCNNode()
    //private let tubeContainer = SCNNode()
    private let asteroidContainer = SCNNode()
    private let alienContainer = SCNNode()
    private let flockContainer = SCNNode()
    private let laserContainer = SCNNode()
    
    // Added shark container and dictionary
    private let sharkContainer = SCNNode()


    private var tubeSegments: [SCNNode] = []

    // Camera-mounted cockpit cannon rig.
    private let cannonBarrel = SCNNode()
    private let muzzleNode = SCNNode()
    private let cannonBarrelPivot = SCNNode()


        init() {
            scene.background.contents = UIColor.black
            scene.fogColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1)
            scene.fogStartDistance = 25
            scene.fogEndDistance = 95
            setupLighting()
            setupCamera()
            setupOcean()
            setupShip()
            setupClouds()
            //setupEnemy()
            scene.rootNode.addChildNode(asteroidContainer)
            scene.rootNode.addChildNode(alienContainer)
            scene.rootNode.addChildNode(flockContainer)
            // laserContainer is a child of the cannon barrel (built inside
            // setupCamera() -> setupCockpitCannon()), so fired lasers spawn
            // relative to the gun. Per-laser world position is still
            // preserved every frame via coordinate conversion in
            // makeLaserNode(), so shots still travel correctly through
            // world space even as the cannon aims.
            scene.rootNode.addChildNode(laserContainer)
            scene.rootNode.addChildNode(sharkContainer) // added shark container to scene
        }

    private func makeCloud() -> SCNNode {
        let cloudNode = SCNNode()

        let cloudMaterial = SCNMaterial()
        cloudMaterial.diffuse.contents = UIColor(
            white: 0.92,
            alpha: 0.92
        )
        cloudMaterial.specular.contents = UIColor.white
        cloudMaterial.shininess = 5

        let cloudParts: [(radius: CGFloat, x: Float, y: Float, z: Float)] = [
            (2.2, -2.2, 0.0, 0.0),
            (2.8,  0.0, 0.25, 0.0),
            (2.4,  2.2, 0.0, 0.0),
            (1.8, -1.0, 0.8, 0.2),
            (2.0,  1.0, 0.7, 0.1),
            (1.5,  0.0, 1.1, 0.0)
        ]

        for part in cloudParts {
            let sphere = SCNSphere(radius: part.radius)
            sphere.segmentCount = 16
            sphere.materials = [cloudMaterial]

            let node = SCNNode(geometry: sphere)

            node.position = SCNVector3(
                part.x,
                part.y,
                part.z
            )

            // Slightly flatten each cloud vertically.
            node.scale = SCNVector3(
                1.0,
                0.65,
                0.75
            )

            cloudNode.addChildNode(node)
        }

        return cloudNode
    }
    private func setupClouds() {
        let cloudContainer = SCNNode()

        for _ in 0..<25 {
            let cloud = makeCloud()

            cloud.position = SCNVector3(
                Float.random(in: -45...45),
                cloudCeilingY + Float.random(in: -1.0...1.5),
                Float.random(in: -120...40)
            )

            cloudContainer.addChildNode(cloud)
        }

        scene.rootNode.addChildNode(cloudContainer)
    }
    private func setupOcean() {
        let water = SCNPlane(width: 120, height: 200)

        let material = SCNMaterial()
        material.diffuse.contents = UIColor(
            red: 0.02,
            green: 0.18,
            blue: 0.28,
            alpha: 1.0
        )
        material.specular.contents = UIColor.white
        material.shininess = 80

        water.materials = [material]

        let waterNode = SCNNode(geometry: water)

        waterNode.eulerAngles.x = -.pi / 2

        waterNode.position = SCNVector3(
            0,
            oceanSurfaceY,
            -40
        )

        scene.rootNode.addChildNode(waterNode)
    }
    private func setupLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.28, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color = UIColor(white: 0.85, alpha: 1)
        sun.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 5, 0)
        scene.rootNode.addChildNode(sun)
    }

   
    private func syncEntities<T: AnyObject>(
        entities: [T],
        nodeMap: inout [ObjectIdentifier: SCNNode],
        createNode: (T) -> SCNNode,
        updateNode: (SCNNode, T) -> Void
    ) {
        var activeIDs = Set<ObjectIdentifier>()

        for entity in entities {
            let id = ObjectIdentifier(entity)
            activeIDs.insert(id)

            let node: SCNNode
            if let existing = nodeMap[id] {
                node = existing
            } else {
                node = createNode(entity)
                scene.rootNode.addChildNode(node)
                nodeMap[id] = node
            }
            updateNode(node, entity)
        }

        // Remove nodes for entities that no longer exist
        for (id, node) in nodeMap where !activeIDs.contains(id) {
            node.removeFromParentNode()
            nodeMap.removeValue(forKey: id)
        }
    }
  
    private func setupCamera() {
           let cam = SCNCamera()
           cam.zNear = 0.05
           cam.zFar = 200
           cam.fieldOfView = 72
           camera.camera = cam
           camera.position = SCNVector3(0, 0.3, -2.8)
           camera.eulerAngles.y = .pi   // look down +Z

           // The camera is a child of the ship root, so it automatically
           // inherits the ship's world position/rotation every frame
           // without needing to be manually re-synced in sync(). This
           // position (0, 0.3, -2.8) is now a fixed LOCAL offset from
           // the ship, not a world position.
           shipRoot.addChildNode(camera)

           setupCockpitCannon()
       }
    private func setupCockpitCannon() {
        cockpitCannonNode.removeFromParentNode()
        cannonBarrelPivot.removeFromParentNode()
        cannonBarrel.removeFromParentNode()
        muzzleNode.removeFromParentNode()

        // ============================================================
        // COCKPIT ROOT
        // ============================================================

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

        // ============================================================
        // REAR-END HINGE
        // ============================================================

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

        cockpitCannonNode.addChildNode(cannonBarrelPivot)

        // ============================================================
        // BARREL
        // ============================================================

        let barrelLength: Float = 0.72
        let halfLength = barrelLength * 0.5

        let barrelGeometry = SCNCylinder(
            radius: 0.055,
            height: CGFloat(barrelLength)
        )

        barrelGeometry.firstMaterial?.diffuse.contents = UIColor.darkGray
        barrelGeometry.firstMaterial?.emission.contents = UIColor.black
        barrelGeometry.firstMaterial?.metalness.contents = NSNumber(value: 0.75)
        barrelGeometry.firstMaterial?.roughness.contents = NSNumber(value: 0.30)

        cannonBarrel.geometry = barrelGeometry

        // Critical: remove any pivot transform you may have assigned
        // while experimenting with SCNMatrix4MakeTranslation.
        cannonBarrel.pivot = SCNMatrix4Identity

        // SCNCylinder length runs along local Y.
        // Rotate its +Y direction to camera-local forward (-Z).
        cannonBarrel.eulerAngles = SCNVector3(
            -Float.pi / 2.0,
            0,
            0
        )

        // Geometry is centered on cannonBarrel's local origin.
        //
        // Its center sits half the barrel length forward of the parent hinge.
        // Therefore its rear endpoint is exactly at cannonBarrelPivot origin.
        cannonBarrel.position = SCNVector3(
            0,
            0,
            -halfLength
        )

        cannonBarrelPivot.addChildNode(cannonBarrel)

        // ============================================================
        // MUZZLE
        // ============================================================

        // Muzzle is at the forward (+Y) end in the cylinder's
        // unrotated local coordinate system.
        muzzleNode.position = SCNVector3(
            0,
            halfLength,
            0
        )

        cannonBarrel.addChildNode(muzzleNode)
    }


    private func setupShip() {
        let bodyGeo = SCNCone(topRadius: 0, bottomRadius: 0.28, height: 0.9)
        bodyGeo.firstMaterial?.diffuse.contents = UIColor.white
        bodyGeo.firstMaterial?.emission.contents = UIColor(white: 0.2, alpha: 1)
        shipMesh.geometry = bodyGeo
        shipMesh.eulerAngles.x = .pi / 2
        shipRoot.addChildNode(shipMesh)

        let flameGeo = SCNCone(topRadius: 0, bottomRadius: 0.12, height: 0.45)
        flameGeo.firstMaterial?.diffuse.contents = UIColor.orange
        flameGeo.firstMaterial?.emission.contents = UIColor.orange
        thrusterFlame.geometry = flameGeo
        thrusterFlame.eulerAngles.x = -.pi / 2
        thrusterFlame.position = SCNVector3(0, 0, -0.55)
        thrusterFlame.isHidden = true
        shipRoot.addChildNode(thrusterFlame)

        let shieldGeo = SCNSphere(radius: 0.55)
        shieldGeo.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.15)
        shieldGeo.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.25)
        shieldGeo.firstMaterial?.transparency = 0.5
        shieldNode.geometry = shieldGeo
        shieldNode.isHidden = true
        shipRoot.addChildNode(shieldNode)

        scene.rootNode.addChildNode(shipRoot)
    }


    func sync(with gameState: GameState) {

        // MARK: - Delta Time
        //
        // SharkManager needs a frame delta for spawning and movement.
        // Clamp the value so a pause/background transition does not
        // create a giant movement or spawn jump.

        let now = CACurrentMediaTime()

        let rawDT = now - lastSyncTime

        lastSyncTime = now

        let dt = CGFloat(
            min(
                max(rawDT, 0.0),
                0.05
            )
        )
        
        // Ensure asteroids are created and updated by the AsteroidManager
        gameState.asteroidManager.update(game: gameState, dt: dt)


        // MARK: - Current Section

        let currentSection = gameState.currentSection


        // MARK: - Update Shark Manager
        //
        // SharkManager is the ONLY system that creates and updates
        // sharks.
        //
        // It writes directly into:
        //
        //     game.sharks
        //
        // This renderer does not create sharks itself.


            gameState.sharkManager.update(
                game: gameState,
                dt: dt
            )
 
        // MARK: - Ocean / Tunnel Environment

   
            // Deep ocean environment.
            scene.background.contents = UIColor(
                red: 0.005,
                green: 0.025,
                blue: 0.055,
                alpha: 1.0
            )

            scene.fogColor = UIColor(
                red: 0.005,
                green: 0.025,
                blue: 0.055,
                alpha: 1.0
            )

            scene.fogStartDistance = 20.0
            scene.fogEndDistance = 110.0


            // The ocean is NOT a tube.
            //
            // Hide every tunnel segment while the ship is in
            // the Alien Ocean.

            for segment in tubeSegments {
                segment.isHidden = true
            }



        // MARK: - Position Tunnel Segments
        //
        // Keep tunnel geometry positioned so it is ready when the
        // game returns to the tunnel.
        //
        // They remain hidden during the ocean.

        let shipZ = CGFloat(
            gameState.spaceShip.position.z
        )

        for (index, segment) in tubeSegments.enumerated() {

            let segmentOffset =
                CGFloat(index) *
                Tunnel.segmentLength

            segment.position = SCNVector3(
                0,
                0,
                Float(
                    shipZ +
                    segmentOffset -
                    Tunnel.segmentLength
                )
            )
        }


        // MARK: - Ship Position

        let shipPosition =
            gameState.spaceShip.position

        shipRoot.position = shipPosition


        // Ship rotation around the tunnel is retained for
        // compatibility with the tunnel section.

        //shipRoot.eulerAngles.z =
         //   Float(
        //        gameState.spaceShip.lateralAngle
        //    )
   
     
            // Ocean camera stays level.

           // camera.eulerAngles.x = 0
          //  camera.eulerAngles.y = .pi
         //   camera.eulerAngles.z = 0

         //   camera.position = SCNVector3(
        //        0,
       //         0.3,
        //        -2.8
        //    )

    

        // MARK: - Cannon Aim

        let yaw =
            Float(
                gameState.cannonAzimuth
            )

        let pitch =
            Float(
                gameState.cannonElevation
            )

        cannonBarrelPivot.eulerAngles =
            SCNVector3(
                pitch,
                -yaw,
                0
            )


        // MARK: - Actual Cannon Muzzle Position
        //
        // IMPORTANT:
        // Use presentation.worldPosition so the muzzle position
        // follows the actual rendered cannon hierarchy.

        let muzzleWorldPosition =
            muzzleNode.presentation.worldPosition

        gameState.cannonMuzzleWorldPosition =
            muzzleWorldPosition


        // MARK: - Actual Cannon Direction
        //
        // Convert the cannon's local forward vector into world space.
        //
        // SceneKit's forward direction is -Z.

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


        // MARK: - Asteroids

        var seenAsteroids =
            Set<ObjectIdentifier>()

        for asteroid in gameState.asteroids {

            let id =
                ObjectIdentifier(asteroid)

            seenAsteroids.insert(id)

            let node: SCNNode

            if let existing =
                gameState.asteroidNodes[id] {

                node = existing

            } else {

                node =
                    makeAsteroidNode(
                        asteroid: asteroid
                    )

                asteroidContainer.addChildNode(
                    node
                )

                gameState.asteroidNodes[id] = node
            }


            // Ocean asteroids use true 3D ocean coordinates.
            //
            // Tunnel asteroids use cylindrical tunnel coordinates.

   
                node.position =
                    asteroid.oceanPosition

         

            // Rotate asteroid.

            node.eulerAngles.x =
                asteroid.spin

            node.eulerAngles.y =
                asteroid.spin * 0.73

            node.eulerAngles.z =
                asteroid.spin * 0.41
        }


        // Remove asteroid nodes that no longer exist.

        for (id, node) in gameState.asteroidNodes {

            if !seenAsteroids.contains(id) {

                node.removeFromParentNode()

                gameState.asteroidNodes.removeValue(
                    forKey: id
                )
            }
        }


        // MARK: - Squid Swarm

        var seenAliens =
            Set<ObjectIdentifier>()

        for squid in gameState.swarmManager.squids {

            let id =
                ObjectIdentifier(squid)

            seenAliens.insert(id)

            let node: SCNNode

            if let existing =
                gameState.alienNodes[id] {

                node = existing

            } else {

                node =
                    CreatureMesh.makeSquid()

                alienContainer.addChildNode(
                    node
                )

                gameState.alienNodes[id] = node
            }


            node.position =
                squid.position

            CreatureMesh.animateSquid(
                node,
                phase: squid.animPhase
            )
        }


        // Remove old squid nodes.

        for (id, node) in gameState.alienNodes {

            if !seenAliens.contains(id) {

                node.removeFromParentNode()

                gameState.alienNodes.removeValue(
                    forKey: id
                )
            }
        }


        // MARK: - Fish Flock

        var seenFish =
            Set<ObjectIdentifier>()

        for fish in gameState.flockManager.aliens
        where !fish.destroyed {

            let id =
                ObjectIdentifier(fish)

            seenFish.insert(id)

            let node: SCNNode

            if let existing =
                gameState.flockNodes[id] {

                node = existing

            } else {

                node =
                    CreatureMesh.makeDeepFish()

                flockContainer.addChildNode(
                    node
                )

                gameState.flockNodes[id] =
                    node
            }

            node.position =
                fish.position

            node.eulerAngles.y =
                Float(fish.lateralAngle)

            CreatureMesh.animateFish(
                node,
                phase: fish.animPhase
            )
        }

        // Remove old fish nodes.

        for (id, node) in gameState.flockNodes {

            if !seenFish.contains(id) {

                node.removeFromParentNode()

                gameState.flockNodes.removeValue(
                    forKey: id
                )
            }
        }


 

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

                    gameState.sharkNodes[id] = node
                }


                // SharkManager owns the shark's actual world position.

                node.position =
                    shark.position


                // Face the direction of travel.

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


            // Remove shark nodes whose Shark objects
            // were destroyed or removed by SharkManager.

            for (id, node) in gameState.sharkNodes {

                if !seenSharks.contains(id) {

                    node.removeFromParentNode()

                    gameState.sharkNodes.removeValue(
                        forKey: id
                    )
                }
            }


 
        laserContainer.childNodes.forEach {
            $0.removeFromParentNode()
        }

        // ========================================================
        // PLAYER LASERS
        // ========================================================

        for laser
                in gameState.playerLasers {

            laserContainer.addChildNode(
                laser.makeLaserNode(
                    color: .green
                )
            )
        }

        // ========================================================
        // ENEMY LASERS
        // ========================================================

        for laser
        in gameState.enemyLasers {

            laserContainer.addChildNode(
                laser.makeLaserNode(
                    color: .red
                )
            )
        }

        processExplosions(
            gameState
        )
        /*
        print("""
        [OCEAN SYNC]
        Game Ship Position:
            x = \(gameState.spaceShip.position.x)
            y = \(gameState.spaceShip.position.y)
            z = \(gameState.spaceShip.position.z)
        """)
         */
    }



    private func processExplosions(_ game: GameState) {

        guard !game.pendingExplosions.isEmpty else {
            return
        }

        for explosion in game.pendingExplosions {

            // --------------------------------------------------------
            // EXPLOSION CORE
            // --------------------------------------------------------

            let coreGeometry = SCNSphere(radius: 0.12)

            coreGeometry.firstMaterial?.diffuse.contents = UIColor.orange
            coreGeometry.firstMaterial?.emission.contents = UIColor.yellow

            let explosionNode = SCNNode(
                geometry: coreGeometry
            )

            explosionNode.position = SCNVector3(
                Float(explosion.x),
                Float(explosion.y),
                Float(explosion.z)
            )

            explosionNode.scale = SCNVector3(
                0.1,
                0.1,
                0.1
            )

            scene.rootNode.addChildNode(explosionNode)

            // --------------------------------------------------------
            // ANIMATION
            // --------------------------------------------------------

            let scale = CGFloat(explosion.scale)

            let grow = SCNAction.scale(
                to: 3.0 * scale,
                duration: 0.12
            )

            grow.timingMode = .easeOut

            let fade = SCNAction.fadeOut(
                duration: 0.18
            )

            let wait = SCNAction.wait(
                duration: 0.04
            )

            let remove = SCNAction.removeFromParentNode()

            let sequence = SCNAction.sequence([
                grow,
                wait,
                fade,
                remove
            ])

            explosionNode.runAction(sequence)
        }

        // ------------------------------------------------------------
        // EVENTS HAVE NOW BEEN CONSUMED
        // ------------------------------------------------------------

        game.pendingExplosions.removeAll()
    }
    private func makeAsteroidNode(
        asteroid: Asteroid
    ) -> SCNNode {

        let node = SCNNode()

        let radius = asteroid.size.radius

        // ========================================================
        // KYROTON METALLIC ASTEROID
        // ========================================================

        let geometry = SCNSphere(
            radius: radius
        )

        geometry.segmentCount = 12

        let material = SCNMaterial()

        // Deep Kyroton metallic body
        material.diffuse.contents = UIColor(
            red: 0.16,
            green: 0.20,
            blue: 0.23,
            alpha: 1.0
        )

        // Subtle cold metallic glow
        material.emission.contents = UIColor(
            red: 0.025,
            green: 0.045,
            blue: 0.06,
            alpha: 1.0
        )

        // Highly metallic surface
        material.metalness.contents = NSNumber(
            value: 0.95
        )

        // Low roughness gives the asteroid a hard,
        // polished extraterrestrial-metal appearance.
        material.roughness.contents = NSNumber(
            value: 0.18
        )

        // Reflect the surrounding ocean/sky environment.
        material.reflective.contents = UIColor(
            white: 0.8,
            alpha: 1.0
        )

        material.reflective.contents = UIColor(
            white: 0.8,
            alpha: 1.0
        )

        geometry.materials = [
            material
        ]

        node.geometry = geometry

        // ========================================================
        // IRREGULAR KYROTON SHAPE
        // ========================================================

        node.scale = SCNVector3(
            1.0,
            0.82,
            1.12
        )

        // Stable initial rotation
        node.eulerAngles = SCNVector3(
            Float.random(in: 0...(Float.pi * 2)),
            Float.random(in: 0...(Float.pi * 2)),
            Float.random(in: 0...(Float.pi * 2))
        )

        node.name = "kyrotonAsteroid"

        return node
    }
  
}
private func rotationFromYAxis(to direction: SCNVector3) -> SCNQuaternion {

    let from = SCNVector3(0, 1, 0)
    let to = direction.normalizedFunc()

    let dot = from.x * to.x +
              from.y * to.y +
              from.z * to.z

    // Already pointing in +Y.
    if dot > 0.999999 {
        return SCNQuaternion(0, 0, 0, 1)
    }

    // Pointing exactly opposite to +Y.
    if dot < -0.999999 {
        return SCNQuaternion(1, 0, 0, 0)
    }

    let axis = SCNVector3(
        from.y * to.z - from.z * to.y,
        from.z * to.x - from.x * to.z,
        from.x * to.y - from.y * to.x
    )

    let s = sqrt((1.0 + dot) * 2.0)
    let inverseS = 1.0 / s

    return SCNQuaternion(
        axis.x * inverseS,
        axis.y * inverseS,
        axis.z * inverseS,
        s * 0.5
    )
}

