//
//  File.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SwiftUI
import SceneKit

final class TunnelSceneWorld {

    let scene = SCNScene()
    let camera = SCNNode()

    // ============================================================
    // CAMERA / HUD MOUNTED CANNON
    // ============================================================

    // This belongs ONLY to the camera.
    private let cockpitCannonNode = SCNNode()

    private let shipRoot = SCNNode()
    private let shipMesh = SCNNode()
    private let thrusterFlame = SCNNode()
    private let shieldNode = SCNNode()

    // Optional separate cannon node.
    private let cannonNode = SCNNode()

    private let enemyRoot = SCNNode()

    private let tubeContainer = SCNNode()
    private let asteroidContainer = SCNNode()
    private let alienContainer = SCNNode()
    private let flockContainer = SCNNode()
    private let laserContainer = SCNNode()

    private var tubeSegments: [SCNNode] = []

    private var asteroidNodes:
        [ObjectIdentifier: SCNNode] = [:]

    private var alienNodes:
        [ObjectIdentifier: SCNNode] = [:]

    private var flockNodes:
        [ObjectIdentifier: SCNNode] = [:]

    // ============================================================
    // COCKPIT CANNON RIG
    // ============================================================

    // Rear-end hinge.
    //
    // IMPORTANT:
    // The barrel rotates around this node.
    //
    // This prevents the barrel from rotating around its center.
    private let cannonBarrelPivot = SCNNode()

    private let cannonBarrel = SCNNode()

    private let muzzleNode = SCNNode()

    // ============================================================
    // INIT
    // ============================================================

    init() {

        scene.background.contents =
            UIColor.black

        scene.fogColor =
            UIColor(
                red: 0.02,
                green: 0.02,
                blue: 0.06,
                alpha: 1
            )

        scene.fogStartDistance = 25
        scene.fogEndDistance = 95

        setupLighting()
        setupTube()
        setupCamera()
        setupShip()
        setupEnemy()

        scene.rootNode.addChildNode(
            tubeContainer
        )

        scene.rootNode.addChildNode(
            asteroidContainer
        )

        scene.rootNode.addChildNode(
            alienContainer
        )

        scene.rootNode.addChildNode(
            flockContainer
        )

        scene.rootNode.addChildNode(
            laserContainer
        )
    }

    // ============================================================
    // LIGHTING
    // ============================================================

    private func setupLighting() {

        let ambient = SCNNode()

        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color =
            UIColor(
                white: 0.28,
                alpha: 1
            )

        scene.rootNode.addChildNode(
            ambient
        )

        let sun = SCNNode()

        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color =
            UIColor(
                white: 0.85,
                alpha: 1
            )

        sun.eulerAngles = SCNVector3(
            -Float.pi / 4,
            Float.pi / 5,
            0
        )

        scene.rootNode.addChildNode(
            sun
        )
    }

    // ============================================================
    // TUBE
    // ============================================================

    private func setupTube() {

        let total =
            Tunnel.segmentsBehind +
            Tunnel.segmentsAhead

        for i in 0..<total {

            let node =
                makeTubeSegment()

            let z =
                CGFloat(
                    i - Tunnel.segmentsBehind
                )
                *
                Tunnel.segmentLength

            node.position =
                SCNVector3(
                    0,
                    0,
                    Float(
                        z +
                        Tunnel.segmentLength * 0.5
                    )
                )

            tubeContainer.addChildNode(
                node
            )

            tubeSegments.append(
                node
            )
        }
    }

    // ============================================================
    // ENTITY SYNCHRONIZATION
    // ============================================================

    private func syncEntities<T: AnyObject>(
        entities: [T],
        nodeMap: inout [ObjectIdentifier: SCNNode],
        createNode: (T) -> SCNNode,
        updateNode: (SCNNode, T) -> Void
    ) {

        var activeIDs =
            Set<ObjectIdentifier>()

        for entity in entities {

            let id =
                ObjectIdentifier(entity)

            activeIDs.insert(id)

            let node: SCNNode

            if let existing =
                nodeMap[id] {

                node = existing

            } else {

                node =
                    createNode(entity)

                scene.rootNode.addChildNode(
                    node
                )

                nodeMap[id] = node
            }

            updateNode(
                node,
                entity
            )
        }

        // Remove nodes for entities
        // that no longer exist.

        for (id, node) in nodeMap
        where !activeIDs.contains(id) {

            node.removeFromParentNode()

            nodeMap.removeValue(
                forKey: id
            )
        }
    }

    // ============================================================
    // TUBE SEGMENT
    // ============================================================

    private func makeTubeSegment() -> SCNNode {

        let geo =
            SCNTube(
                innerRadius:
                    CGFloat(Tunnel.radius) - 0.08,

                outerRadius:
                    CGFloat(Tunnel.radius),

                height:
                    Tunnel.segmentLength
            )

        geo.firstMaterial?.diffuse.contents =
            UIColor(
                red: 0.08,
                green: 0.1,
                blue: 0.16,
                alpha: 1
            )

        geo.firstMaterial?.emission.contents =
            UIColor(
                red: 0.02,
                green: 0.04,
                blue: 0.08,
                alpha: 1
            )

        geo.firstMaterial?.isDoubleSided =
            true

        let node =
            SCNNode(
                geometry: geo
            )

        node.eulerAngles.x =
            .pi / 2

        let ring =
            SCNTorus(
                ringRadius:
                    Tunnel.radius * 0.98,

                pipeRadius:
                    0.06
            )

        ring.firstMaterial?.diffuse.contents =
            UIColor.cyan.withAlphaComponent(
                0.35
            )

        ring.firstMaterial?.emission.contents =
            UIColor.cyan.withAlphaComponent(
                0.2
            )

        let ringNode =
            SCNNode(
                geometry: ring
            )

        ringNode.position =
            SCNVector3(
                0,
                -Tunnel.segmentLength * 0.5 + 0.5,
                0
            )

        node.addChildNode(
            ringNode
        )

        return node
    }

    // ============================================================
    // CAMERA
    // ============================================================

    private func setupCamera() {

        let cam =
            SCNCamera()

        cam.zNear = 0.05
        cam.zFar = 200
        cam.fieldOfView = 72

        camera.camera = cam

        camera.position =
            SCNVector3(
                0,
                0.3,
                -2.8
            )

        // Camera looks down +Z.
        camera.eulerAngles.y =
            .pi

        scene.rootNode.addChildNode(
            camera
        )

        setupCockpitCannon()
    }

    // ============================================================
    // COCKPIT CANNON
    // ============================================================

    private func setupCockpitCannon() {

        // Remove any previous hierarchy.
        //
        // This makes setup safe if it is ever called again.

        cockpitCannonNode.removeFromParentNode()

        cannonBarrelPivot.removeFromParentNode()

        cannonBarrel.removeFromParentNode()

        muzzleNode.removeFromParentNode()

        // ========================================================
        // COCKPIT ROOT
        // ========================================================

        camera.addChildNode(
            cockpitCannonNode
        )

        cockpitCannonNode.position =
            SCNVector3(
                0,
                -0.25,
                -0.9
            )

        cockpitCannonNode.eulerAngles =
            SCNVector3(
                0,
                0,
                0
            )

        // ========================================================
        // REAR-END HINGE
        // ========================================================

        // The pivot is located at the rear
        // end of the cannon barrel.

        cannonBarrelPivot.position =
            SCNVector3(
                0,
                0,
                0
            )

        cannonBarrelPivot.eulerAngles =
            SCNVector3(
                0,
                0,
                0
            )

        cockpitCannonNode.addChildNode(
            cannonBarrelPivot
        )

        // ========================================================
        // BARREL
        // ========================================================

        let barrelLength: Float =
            0.72

        let halfLength =
            barrelLength * 0.5

        let barrelGeometry =
            SCNCylinder(
                radius: 0.055,
                height: CGFloat(
                    barrelLength
                )
            )

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

        // IMPORTANT:
        //
        // No geometry pivot translation.
        // The barrel geometry remains centered
        // on cannonBarrel's own origin.

        cannonBarrel.pivot =
            SCNMatrix4Identity

        // SCNCylinder's long axis is local +Y.
        //
        // Rotate +Y into camera-local -Z.

        cannonBarrel.eulerAngles =
            SCNVector3(
                -Float.pi / 2.0,
                0,
                0
            )

        // The cylinder is centered on its origin.
        //
        // Move its center forward by half its length.
        //
        // This places the rear endpoint exactly
        // at cannonBarrelPivot.

        cannonBarrel.position =
            SCNVector3(
                0,
                0,
                -halfLength
            )

        cannonBarrelPivot.addChildNode(
            cannonBarrel
        )

        // ========================================================
        // MUZZLE
        // ========================================================

        // The muzzle is placed at the forward
        // (+Y) end of the cylinder BEFORE the
        // cylinder's geometry alignment rotation.

        muzzleNode.position =
            SCNVector3(
                0,
                halfLength,
                0
            )

        cannonBarrel.addChildNode(
            muzzleNode
        )
    }

    // ============================================================
    // PLAYER SHIP
    // ============================================================

    private func setupShip() {

        let bodyGeo =
            SCNCone(
                topRadius: 0,
                bottomRadius: 0.28,
                height: 0.9
            )

        bodyGeo.firstMaterial?.diffuse.contents =
            UIColor.white

        bodyGeo.firstMaterial?.emission.contents =
            UIColor(
                white: 0.2,
                alpha: 1
            )

        shipMesh.geometry =
            bodyGeo

        shipMesh.eulerAngles.x =
            .pi / 2

        shipRoot.addChildNode(
            shipMesh
        )

        // ========================================================
        // THRUSTER
        // ========================================================

        let flameGeo =
            SCNCone(
                topRadius: 0,
                bottomRadius: 0.12,
                height: 0.45
            )

        flameGeo.firstMaterial?.diffuse.contents =
            UIColor.orange

        flameGeo.firstMaterial?.emission.contents =
            UIColor.orange

        thrusterFlame.geometry =
            flameGeo

        thrusterFlame.eulerAngles.x =
            -.pi / 2

        thrusterFlame.position =
            SCNVector3(
                0,
                0,
                -0.55
            )

        thrusterFlame.isHidden =
            true

        shipRoot.addChildNode(
            thrusterFlame
        )

        // ========================================================
        // SHIELD
        // ========================================================

        let shieldGeo =
            SCNSphere(
                radius: 0.55
            )

        shieldGeo.firstMaterial?.diffuse.contents =
            UIColor.cyan.withAlphaComponent(
                0.15
            )

        shieldGeo.firstMaterial?.emission.contents =
            UIColor.cyan.withAlphaComponent(
                0.25
            )

        shieldGeo.firstMaterial?.transparency =
            0.5

        shieldNode.geometry =
            shieldGeo

        shieldNode.isHidden =
            true

        shipRoot.addChildNode(
            shieldNode
        )

        // ========================================================
        // SHIP MOUNTED CANNON
        // ========================================================
        //
        // Do NOT attach cockpitCannonNode here.
        //
        // The cockpit cannon belongs ONLY to
        // the camera.
        //
        // A SceneKit node can only have one parent.
        //
        // Reusing the cockpit cannon here would
        // silently reparent it and break the
        // cockpit cannon.

        scene.rootNode.addChildNode(
            shipRoot
        )
    }

    // ============================================================
    // ENEMY
    // ============================================================

    private func setupEnemy() {

        let geo =
            SCNCone(
                topRadius: 0,
                bottomRadius: 0.32,
                height: 1.0
            )

        geo.firstMaterial?.diffuse.contents =
            UIColor.red

        geo.firstMaterial?.emission.contents =
            UIColor(
                red: 0.35,
                green: 0,
                blue: 0,
                alpha: 1
            )

        enemyRoot.geometry =
            geo

        enemyRoot.eulerAngles.x =
            .pi / 2

        enemyRoot.isHidden =
            true

        scene.rootNode.addChildNode(
            enemyRoot
        )
    }

    // ============================================================
    // SYNC
    // ============================================================

    func sync(with game: GameState) {

        // ========================================================
        // TUNNEL
        // ========================================================

        let progress =
            game.spaceShip.progress

        let segmentShift =
            progress.truncatingRemainder(
                dividingBy:
                    Tunnel.segmentLength
            )

        for (i, node)
        in tubeSegments.enumerated() {

            let baseIndex =
                i - Tunnel.segmentsBehind

            let z =
                CGFloat(baseIndex)
                *
                Tunnel.segmentLength
                -
                segmentShift
                +
                Tunnel.segmentLength * 0.5

            node.position.z =
                Float(z)
        }

        // ========================================================
        // PLAYER SHIP
        // ========================================================

        let shipPos =
            game.spaceShip.position

        shipRoot.position =
            shipPos

        shipRoot.eulerAngles.z =
            Float(
                game.spaceShip.lateralAngle
            )

        thrusterFlame.isHidden =
            game.spaceShip.forwardSpeed <
            Tunnel.defaultSpeed + 0.5

        thrusterFlame.scale =
            SCNVector3(
                1,
                1,
                Float(
                    min(
                        1.6,
                        game.spaceShip.forwardSpeed /
                        Tunnel.defaultSpeed
                    )
                )
            )

        shieldNode.isHidden =
            !game.shieldActive

        // ========================================================
        // CAMERA
        // ========================================================

        camera.eulerAngles.z =
            Float(
                game.spaceShip.lateralInput
            ) * 0.12

        camera.position.x =
            shipPos.x * 0.6

        camera.position.y =
            shipPos.y * 0.6 + 0.25

        // ========================================================
        // CANNON AIM
        // ========================================================
        //
        // cannonAzimuth:
        //     left / right
        //
        // cannonElevation:
        //     up / down
        //
        // IMPORTANT:
        //
        // The actual cannon is now controlled by
        // cannonBarrelPivot.
        //
        // The barrel itself retains only its
        // one-time geometry alignment rotation.
        //
        // This means the barrel swings from its
        // rear hinge rather than rotating around
        // its center.
        // ========================================================

        let yaw =
            Float(
                game.cannonAzimuth
            )

        let pitch =
            Float(
                game.cannonElevation
            )

        // ========================================================
        // CANNON REAR HINGE AIM
        // ========================================================

        cannonBarrelPivot.eulerAngles =
            SCNVector3(
                pitch,
                -yaw,
                0
            )

        // DO NOT set cannonBarrel.eulerAngles here.
        //
        // It must retain:
        //
        // -Float.pi / 2
        //
        // from setupCockpitCannon().
        //
        // The pivot supplies the actual aiming
        // rotation.

        // ========================================================
        // OPTIONAL SHIP CANNON
        // ========================================================

        cannonNode.eulerAngles =
            SCNVector3(
                pitch,
                yaw,
                0
            )

        // ========================================================
        // ACTUAL MUZZLE WORLD POSITION
        // ========================================================
        //
        // Use the presentation node so the position
        // represents the rendered cannon transform.

        let renderedMuzzle =
            muzzleNode.presentation

        game.cannonMuzzleWorldPosition =
            renderedMuzzle.worldPosition

        // ========================================================
        // ACTUAL CANNON WORLD DIRECTION
        // ========================================================
        //
        // CRITICAL:
        //
        // Do NOT reconstruct this direction from
        // cannonAzimuth/cannonElevation.
        //
        // Read it from the actual transformed
        // cannon muzzle.
        //
        // The cannon's firing axis is local -Z.
        // ========================================================

        let localForward =
            SCNVector3(
                0,
                0,
                -1
            )

        let worldDirection =
            renderedMuzzle
                .convertVector(
                    localForward,
                    to: nil
                )
                .normalized

        game.cannonWorldDirection =
            worldDirection

  

        // ========================================================
        // ASTEROIDS
        // ========================================================

        var seenA =
            Set<ObjectIdentifier>()

        for asteroid
        in game.asteroids {

            let id =
                ObjectIdentifier(
                    asteroid
                )

            seenA.insert(id)

            let node: SCNNode

            if let existing =
                asteroidNodes[id] {

                node = existing

            } else {

                let geo =
                    SCNSphere(
                        radius:
                            asteroid.size.radius
                    )

                geo.firstMaterial?.diffuse.contents =
                    UIColor.darkGray

                geo.firstMaterial?.emission.contents =
                    UIColor(
                        white: 0.1,
                        alpha: 1
                    )

                node =
                    SCNNode(
                        geometry: geo
                    )

                asteroidContainer.addChildNode(
                    node
                )

                asteroidNodes[id] =
                    node
            }

            node.position =
                asteroid.position

            node.eulerAngles.y =
                asteroid.spin
        }

        for (id, node)
        in asteroidNodes
        where !seenA.contains(id) {

            node.removeFromParentNode()

            asteroidNodes.removeValue(
                forKey: id
            )
        }

        // ========================================================
        // SQUID SWARM
        // ========================================================

        var seenS =
            Set<ObjectIdentifier>()

        for alien
        in game.swarmManager.aliens
        where !alien.destroyed {

            let id =
                ObjectIdentifier(
                    alien
                )

            seenS.insert(id)

            let node: SCNNode

            if let existing =
                alienNodes[id] {

                node = existing

            } else {

                node =
                    CreatureMesh.makeSquid()

                alienContainer.addChildNode(
                    node
                )

                alienNodes[id] =
                    node
            }

            node.position =
                alien.position

            node.eulerAngles.y =
                Float(
                    alien.lateralAngle
                )

            CreatureMesh.animateSquid(
                node,
                phase: alien.animPhase
            )
        }

        for (id, node)
        in alienNodes
        where !seenS.contains(id) {

            node.removeFromParentNode()

            alienNodes.removeValue(
                forKey: id
            )
        }

        // ========================================================
        // DEEP FISH FLOCK
        // ========================================================

        var seenF =
            Set<ObjectIdentifier>()

        for alien
        in game.flockManager.aliens
        where !alien.destroyed {

            let id =
                ObjectIdentifier(
                    alien
                )

            seenF.insert(id)

            let node: SCNNode

            if let existing =
                flockNodes[id] {

                node = existing

            } else {

                node =
                    CreatureMesh.makeDeepFish()

                flockContainer.addChildNode(
                    node
                )

                flockNodes[id] =
                    node
            }

            node.position =
                alien.position

            node.eulerAngles.y =
                Float(
                    alien.lateralAngle
                )

            CreatureMesh.animateFish(
                node,
                phase: alien.animPhase
            )
        }

        for (id, node)
        in flockNodes
        where !seenF.contains(id) {

            node.removeFromParentNode()

            flockNodes.removeValue(
                forKey: id
            )
        }

        // ========================================================
        // LASERS
        // ========================================================

        laserContainer.childNodes.forEach {
            $0.removeFromParentNode()
        }

        // PLAYER LASERS

        for laser
        in game.playerLasers {

            laserContainer.addChildNode(
                makeLaserNode(
                    laser,
                    color: .green
                )
            )
        }

        // ENEMY LASERS

        for laser
        in game.enemyLasers {

            laserContainer.addChildNode(
                makeLaserNode(
                    laser,
                    color: .red
                )
            )
        }

        // ========================================================
        // EXPLOSIONS
        // ========================================================

        processExplosions(
            game
        )
    }

    // ============================================================
    // EXPLOSIONS
    // ============================================================

    private func processExplosions(
        _ game: GameState
    ) {

        guard
            !game.pendingExplosions.isEmpty
        else {
            return
        }

        for explosion
        in game.pendingExplosions {

            // ====================================================
            // EXPLOSION CORE
            // ====================================================

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
                    geometry:
                        coreGeometry
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

            // ====================================================
            // ANIMATION
            // ====================================================

            let scale =
                CGFloat(
                    explosion.scale
                )

            let grow =
                SCNAction.scale(
                    to:
                        3.0 * scale,
                    duration:
                        0.12
                )

            grow.timingMode =
                .easeOut

            let fade =
                SCNAction.fadeOut(
                    duration:
                        0.18
                )

            let wait =
                SCNAction.wait(
                    duration:
                        0.04
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

        // Events have now been consumed.

        game.pendingExplosions.removeAll()
    }

    // ============================================================
    // LASER NODE
    // ============================================================

    private func makeLaserNode(
        _ laser: Laser,
        color: UIColor
    ) -> SCNNode {

        let geo =
            SCNCylinder(
                radius: 0.05,
                height: 0.75
            )

        geo.firstMaterial?.diffuse.contents =
            color

        geo.firstMaterial?.emission.contents =
            color

        let laserNode =
            SCNNode(
                geometry: geo
            )

        // SCNCylinder's long axis is +Y.
        //
        // Rotate the cylinder so its long axis
        // follows local -Z.

        laserNode.eulerAngles.x =
            -.pi / 2.0

        let container =
            SCNNode()

        container.addChildNode(
            laserNode
        )

        // ========================================================
        // LASER STARTING POSITION
        // ========================================================

        container.position =
            laser.worldPosition()

        // ========================================================
        // LASER MOVEMENT DIRECTION
        // ========================================================

        let direction =
            laser.direction.normalized

        guard
            direction.length >
            0.000001
        else {
            return container
        }

        // Point the visual laser in exactly
        // the same direction used by the Laser
        // physics.

        let end =
            SCNVector3(
                container.position.x +
                    direction.x,

                container.position.y +
                    direction.y,

                container.position.z +
                    direction.z
            )

        container.look(
            at: end,
            up:
                SCNVector3(
                    0,
                    1,
                    0
                ),
            localFront:
                SCNVector3(
                    0,
                    0,
                    -1
                )
        )

        return container
    }
}

// ================================================================
// ROTATION HELPER
// ================================================================

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

    // Already pointing in +Y.

    if dot > 0.999999 {

        return SCNQuaternion(
            0,
            0,
            0,
            1
        )
    }

    // Pointing exactly opposite to +Y.

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
