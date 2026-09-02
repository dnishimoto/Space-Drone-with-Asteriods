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
    private var sharkNodes: [ObjectIdentifier: SCNNode] = [:]

    private var tubeSegments: [SCNNode] = []
    private var asteroidNodes: [ObjectIdentifier: SCNNode] = [:]
    private var alienNodes: [ObjectIdentifier: SCNNode] = [:]
    private var flockNodes: [ObjectIdentifier: SCNNode] = [:]

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
        setupShip()
        //setupEnemy()
        scene.rootNode.addChildNode(asteroidContainer)
        scene.rootNode.addChildNode(alienContainer)
        scene.rootNode.addChildNode(flockContainer)
        scene.rootNode.addChildNode(laserContainer)
        scene.rootNode.addChildNode(sharkContainer) // added shark container to scene
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
    private func makeTubeSegment() -> SCNNode {
        let geo = SCNTube(innerRadius: CGFloat(Tunnel.radius) - 0.08,
                          outerRadius: CGFloat(Tunnel.radius),
                          height: Tunnel.segmentLength)
        geo.firstMaterial?.diffuse.contents = UIColor(red: 0.08, green: 0.1, blue: 0.16, alpha: 1)
        geo.firstMaterial?.emission.contents = UIColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 1)
        geo.firstMaterial?.isDoubleSided = true
        let node = SCNNode(geometry: geo)
        node.eulerAngles.x = .pi / 2

        let ring = SCNTorus(ringRadius: Tunnel.radius * 0.98, pipeRadius: 0.06)
        ring.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.35)
        ring.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.2)
        let ringNode = SCNNode(geometry: ring)
        ringNode.position = SCNVector3(0, -Tunnel.segmentLength * 0.5 + 0.5, 0)
        node.addChildNode(ringNode)
        return node
    }

    private func setupCamera() {
        let cam = SCNCamera()
        cam.zNear = 0.05
        cam.zFar = 200
        cam.fieldOfView = 72
        camera.camera = cam
        camera.position = SCNVector3(0, 0.3, -2.8)
        camera.eulerAngles.y = .pi   // look down +Z
        scene.rootNode.addChildNode(camera)

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

        // NOTE: the ship-mounted cannon indicator that used to live here was
        // removed — it was reusing the same `cannonNode` instance as the
        // camera-mounted cockpit cannon above, which silently reparented
        // that node away from the camera (a node can only have one parent)
        // and broke both its visibility and its aim.

        scene.rootNode.addChildNode(shipRoot)
    }
/*
    private func setupEnemy() {
        let geo = SCNCone(topRadius: 0, bottomRadius: 0.32, height: 1.0)
        geo.firstMaterial?.diffuse.contents = UIColor.red
        geo.firstMaterial?.emission.contents = UIColor(red: 0.35, green: 0, blue: 0, alpha: 1)
        enemyRoot.geometry = geo
        enemyRoot.eulerAngles.x = .pi / 2
        enemyRoot.isHidden = true
        scene.rootNode.addChildNode(enemyRoot)
    }
 */
    func sync(with game: GameState) {

        // Read currentSection first
        let currentSection = game.currentSection

        // ============================================================
        // Scene Background and Fog based on currentSection
        // ============================================================

        if currentSection == .ocean {
            // Deep ocean blue background and fog
            scene.background.contents = UIColor(red: 0.0, green: 0.05, blue: 0.15, alpha: 1)
            scene.fogColor = UIColor(red: 0.0, green: 0.1, blue: 0.25, alpha: 1)
            scene.fogStartDistance = 15
            scene.fogEndDistance = 70

            // Optionally tint or dim the tube segments to bluish
            for segment in tubeSegments {
                if let tube = segment.geometry as? SCNTube {
                    tube.firstMaterial?.diffuse.contents = UIColor(red: 0.02, green: 0.07, blue: 0.12, alpha: 1)
                    tube.firstMaterial?.emission.contents = UIColor(red: 0.01, green: 0.03, blue: 0.06, alpha: 1)
                }
                // Also dim rings if present
                for child in segment.childNodes {
                    if let ring = child.geometry as? SCNTorus {
                        ring.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.2)
                        ring.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.1)
                    }
                }
            }
        } else {
            // Default space background and fog
            scene.background.contents = UIColor.black
            scene.fogColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1)
            scene.fogStartDistance = 25
            scene.fogEndDistance = 95
            // Restore tube segment colors
            for segment in tubeSegments {
                if let tube = segment.geometry as? SCNTube {
                    tube.firstMaterial?.diffuse.contents = UIColor(red: 0.08, green: 0.1, blue: 0.16, alpha: 1)
                    tube.firstMaterial?.emission.contents = UIColor(red: 0.02, green: 0.04, blue: 0.08, alpha: 1)
                }
                for child in segment.childNodes {
                    if let ring = child.geometry as? SCNTorus {
                        ring.firstMaterial?.diffuse.contents = UIColor.cyan.withAlphaComponent(0.35)
                        ring.firstMaterial?.emission.contents = UIColor.cyan.withAlphaComponent(0.2)
                    }
                }
            }
        }

        // ============================================================
        // TUNNEL
        // ============================================================

        let progress = game.spaceShip.progress

        let segmentShift =
            progress.truncatingRemainder(
                dividingBy: Tunnel.segmentLength
            )

        for (i, node) in tubeSegments.enumerated() {

            let baseIndex =
                i - Tunnel.segmentsBehind

            let z =
                CGFloat(baseIndex) * Tunnel.segmentLength
                - segmentShift
                + Tunnel.segmentLength * 0.5

            node.position.z = Float(z)
        }

        // ============================================================
        // PLAYER SHIP
        // ============================================================

        let shipPos = game.spaceShip.position

        shipRoot.position = shipPos

        shipRoot.eulerAngles.z =
            Float(game.spaceShip.lateralAngle)

        thrusterFlame.isHidden =
            game.spaceShip.forwardSpeed < Tunnel.defaultSpeed + 0.5

        thrusterFlame.scale = SCNVector3(
            1,
            1,
            Float(
                min(
                    1.6,
                    game.spaceShip.forwardSpeed
                    / Tunnel.defaultSpeed
                )
            )
        )

        // Set shieldNode visibility based on shield active state
        shieldNode.isHidden =
            !game.shieldActive

        // ============================================================
        // CAMERA
        // ============================================================

        camera.eulerAngles.z =
            Float(game.spaceShip.lateralInput) * 0.12

        camera.position.x =
            shipPos.x * 0.6

        camera.position.y =
            shipPos.y * 0.6 + 0.25

        // ============================================================
        // CANNON AIM
        //
        // cannonAzimuth:
        //     left/right
        //
        // cannonElevation:
        //     up/down
        //
        // IMPORTANT:
        // SceneKit's local -Z is the cannon's forward direction.
        //
        // Do NOT negate yaw here.
        // ============================================================

        let yaw = Float(game.cannonAzimuth)
        let pitch = Float(game.cannonElevation)

        // Keep the camera-mounted cannon root fixed.
        // Do not rotate cockpitCannonNode for aiming.
        cockpitCannonNode.eulerAngles = SCNVector3(
            0,
            0,
            0
        )

        // Rotate the empty rear-end hinge node.
        //
        // cannonBarrelPivot is positioned at the rear endpoint of the
        // cylinder. Because cannonBarrel is offset forward beneath it,
        // the cylinder now swings from that rear endpoint rather than
        // rotating about its own center.
        cannonBarrelPivot.eulerAngles = SCNVector3(
            pitch,
            -yaw,
            0
        )

        // Do NOT set cannonBarrel.eulerAngles here.
        //
        // cannonBarrel keeps its one-time geometry alignment rotation
        // from setupCockpitCannon():
        //
        // cannonBarrel.eulerAngles = SCNVector3(
        //     -Float.pi / 2.0,
        //     0,
        //     0
        // )

        // Optional: keep a separate ship-mounted cannon synchronized.
        // This does not affect cockpitCannonNode / cannonBarrelPivot.
        cannonNode.eulerAngles = SCNVector3(
            pitch,
            yaw,
            0
        )

        // Read the actual transformed muzzle position after applying
        // the pivot rotation.
        let renderedMuzzle = muzzleNode.presentation

        game.cannonMuzzleWorldPosition =
            renderedMuzzle.worldPosition

        // In the completed barrel hierarchy, local -Z is the firing
        // direction. Convert it to a world-space, normalized vector.
        let localForward = SCNVector3(
            0,
            0,
            -1
        )

        let worldDirection = renderedMuzzle
            .convertVector(
                localForward,
                to: nil
            )
            .normalized

        game.cannonWorldDirection =
            worldDirection
    
        // ============================================================
        // ENEMY
        // ============================================================
/*
        if let enemy = game.enemySpaceShip,
           !enemy.destroyed {

            enemyRoot.isHidden = false

            enemyRoot.position =
                enemy.position

            enemyRoot.eulerAngles.z =
                Float(enemy.lateralAngle)

        } else {

            enemyRoot.isHidden = true
        }
*/
        // ============================================================
        // ASTEROIDS
        // ============================================================
        // Show asteroids only in asteroid section,
        // or optionally some sparse debris in ocean section.
        var showAsteroids = false
        if currentSection == .asteroid {
            showAsteroids = true
        } else if currentSection == .ocean {
            // Optionally show a few asteroids as debris in ocean.
            // Here we disable asteroids entirely for ocean.
            showAsteroids = false
        }

        if showAsteroids {
            var seenA = Set<ObjectIdentifier>()

            for asteroid in game.asteroids {

                let id = ObjectIdentifier(asteroid)

                seenA.insert(id)

                let node: SCNNode

                if let existing = asteroidNodes[id] {

                    node = existing

                } else {

                    let geo = SCNSphere(
                        radius: asteroid.size.radius
                    )

                    geo.firstMaterial?.diffuse.contents =
                        UIColor.darkGray

                    geo.firstMaterial?.emission.contents =
                        UIColor(white: 0.1, alpha: 1)

                    node = SCNNode(
                        geometry: geo
                    )

                    asteroidContainer.addChildNode(node)

                    asteroidNodes[id] = node
                }

                node.position =
                    asteroid.position

                node.eulerAngles.y =
                    asteroid.spin
            }

            for (id, node) in asteroidNodes
                where !seenA.contains(id) {

                node.removeFromParentNode()

                asteroidNodes.removeValue(
                    forKey: id
                )
            }
        } else {
            // Remove all asteroid nodes if we are not showing asteroids
            for (_, node) in asteroidNodes {
                node.removeFromParentNode()
            }
            asteroidNodes.removeAll()
        }

        // ============================================================
        // SQUID SWARM
        // ============================================================
        // Show squid swarm in ocean section
        if currentSection == .ocean {
            var seenS = Set<ObjectIdentifier>()

            for alien in game.swarmManager.aliens
                where !alien.destroyed {

                let id = ObjectIdentifier(alien)

                seenS.insert(id)

                let node: SCNNode

                if let existing = alienNodes[id] {

                    node = existing

                } else {

                    node = CreatureMesh.makeSquid()

                    alienContainer.addChildNode(node)

                    alienNodes[id] = node
                }

                node.position =
                    alien.position

                node.eulerAngles.y =
                    Float(alien.lateralAngle)

                CreatureMesh.animateSquid(
                    node,
                    phase: alien.animPhase
                )
            }

            for (id, node) in alienNodes
                where !seenS.contains(id) {

                node.removeFromParentNode()

                alienNodes.removeValue(
                    forKey: id
                )
            }
        } else {
            // Remove squid aliens if not ocean section
            for (_, node) in alienNodes {
                node.removeFromParentNode()
            }
            alienNodes.removeAll()
        }

        // ============================================================
        // DEEP FISH FLOCK
        // ============================================================
        // Show deep fish flock in ocean section
        if currentSection == .ocean {
            var seenF = Set<ObjectIdentifier>()

            for alien in game.flockManager.aliens
                where !alien.destroyed {

                let id = ObjectIdentifier(alien)

                seenF.insert(id)

                let node: SCNNode

                if let existing = flockNodes[id] {

                    node = existing

                } else {

                    node = CreatureMesh.makeDeepFish()

                    flockContainer.addChildNode(node)

                    flockNodes[id] = node
                }

                node.position =
                    alien.position

                node.eulerAngles.y =
                    Float(alien.lateralAngle)

                CreatureMesh.animateFish(
                    node,
                    phase: alien.animPhase
                )
            }

            for (id, node) in flockNodes
                where !seenF.contains(id) {

                node.removeFromParentNode()

                flockNodes.removeValue(
                    forKey: id
                )
            }
        } else {
            // Remove fish flock nodes if not ocean section
            for (_, node) in flockNodes {
                node.removeFromParentNode()
            }
            flockNodes.removeAll()
        }
        
        // ============================================================
        // SHARKS (NEW)
        // ============================================================
        // Show sharks only in ocean section
        if currentSection == .ocean {
            var seenSharks = Set<ObjectIdentifier>()
            for shark in game.sharks where !shark.destroyed {
                let id = ObjectIdentifier(shark)
                seenSharks.insert(id)
                let node: SCNNode
                if let existing = sharkNodes[id] {
                    node = existing
                } else {
                    node = CreatureMesh.makeShark()
                    sharkContainer.addChildNode(node)
                    sharkNodes[id] = node
                }
                node.position = shark.position
                node.eulerAngles.y = Float(shark.lateralAngle)
                CreatureMesh.animateShark(node, phase: shark.animPhase)
            }
            for (id, node) in sharkNodes where !seenSharks.contains(id) {
                node.removeFromParentNode()
                sharkNodes.removeValue(forKey: id)
            }
        } else {
            // Remove sharks if not ocean section
            for (_, node) in sharkNodes {
                node.removeFromParentNode()
            }
            sharkNodes.removeAll()
        }

        // ============================================================
        // LASERS
        // ============================================================

        laserContainer.childNodes.forEach {
            $0.removeFromParentNode()
        }

        for laser in game.playerLasers {

            laserContainer.addChildNode(
                makeLaserNode(
                    laser,
                    color: .green
                )
            )
        }

        for laser in game.enemyLasers {

            laserContainer.addChildNode(
                makeLaserNode(
                    laser,
                    color: .red
                )
            )
        }
        
        // ============================================================
        // OCEAN-SPECIFIC EFFECTS AND ENTITIES
        // ============================================================
        // Future expansion point for ocean scene behaviors, lighting,
        // particle effects, underwater fog variations, and additional
        // oceanic creatures or visuals.

        // ============================================================
        // Explosions
        // ============================================================
          processExplosions(game)
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

    private func makeLaserNode(
        _ laser: Laser,
        color: UIColor
    ) -> SCNNode {

        let geo = SCNCylinder(
            radius: 0.05,
            height: 0.75
        )

        geo.firstMaterial?.diffuse.contents = color
        geo.firstMaterial?.emission.contents = color

        let laserNode = SCNNode(geometry: geo)

        // SCNCylinder's long axis is +Y.
        //
        // Rotate the cylinder so its long axis follows -Z.
        laserNode.eulerAngles.x = -.pi / 2.0

        let container = SCNNode()
        container.addChildNode(laserNode)

        // Laser starting position.
        container.position = laser.worldPosition()

        // --------------------------------------------------
        // Laser movement direction.
        // --------------------------------------------------

        let direction = laser.direction.normalized

        guard direction.length > 0.000001 else {
            return container
        }

        // Point the container in exactly the same direction
        // that the Laser uses for movement.
        let end = SCNVector3(
            container.position.x + direction.x,
            container.position.y + direction.y,
            container.position.z + direction.z
        )

        container.look(
            at: end,
            up: SCNVector3(0, 1, 0),
            localFront: SCNVector3(0, 0, -1)
        )

        return container
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

// MARK: - CreatureMesh Shark extensions (placeholder)


