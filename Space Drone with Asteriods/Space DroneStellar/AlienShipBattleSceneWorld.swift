
//
// AlienShipBattleScene.swift
//
// Manages a fleet of AlienShipState enemy ships.
// The fleet is updated using cellular-automaton rules.
//

//
//  AlienShipBattleScene.swift
//
//  Alien fleet cellular-automaton battle world.
//  Includes:
//  - 3D alien fleet
//  - Local CA state updates
//  - Fleet spawning
//  - Alien movement
//  - Cockpit cannon
//  - Muzzle node for projectile firing
//

import Foundation
import SceneKit
import UIKit

@MainActor
final class AlienShipBattleSceneWorld {

    private var lastSyncTime: TimeInterval = CACurrentMediaTime()
    
    let scene = SCNScene()

    let camera = SCNNode()

    private let fleetContainer = SCNNode()

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

    private var nextFleetID: Int = 0

    let maxFleetSize: Int

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(fleetSize: Int = 8) {

        self.maxFleetSize = max(
            1,
            fleetSize
        )

        // ========================================================
        // CAMERA
        // ========================================================

        let cam = SCNCamera()

        cam.zNear = 0.05
        cam.zFar = 200.0
        cam.fieldOfView = 72.0

        camera.camera = cam

        camera.position = SCNVector3(
            0,
            0.3,
            -2.8
        )

        camera.eulerAngles = SCNVector3(
            0,
            Double.pi,
            0
        )

        scene.rootNode.addChildNode(camera)

        // ========================================================
        // FLEET CONTAINER
        // ========================================================

        scene.rootNode.addChildNode(
            fleetContainer
        )

        // ========================================================
        // COCKPIT CANNON
        // ========================================================

        setupCockpitCannon()

        // ========================================================
        // INITIAL FLEET
        // ========================================================

        spawnFleet()

        renderFleet()
    }

    // ============================================================
    // COCKPIT CANNON
    // ============================================================

    private func setupCockpitCannon() {

        // ========================================================
        // REMOVE EXISTING CANNON NODES
        // ========================================================

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

        // ========================================================
        // REAR-END HINGE
        // ========================================================

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

        // ========================================================
        // BARREL
        // ========================================================

        let barrelLength: Float = 0.72

        let halfLength =
            barrelLength * 0.5

        let barrelGeometry = SCNCylinder(
            radius: 0.055,
            height: CGFloat(barrelLength)
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

        // ========================================================
        // RESET PIVOT
        // ========================================================

        cannonBarrel.pivot =
            SCNMatrix4Identity

        // ========================================================
        // BARREL ORIENTATION
        // ========================================================

        // SCNCylinder extends along local Y.
        //
        // Rotate +Y toward camera-forward (-Z).

        cannonBarrel.eulerAngles = SCNVector3(
            -Float.pi / 2.0,
            0,
            0
        )

        // ========================================================
        // BARREL POSITION
        // ========================================================

        cannonBarrel.position = SCNVector3(
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

        muzzleNode.position = SCNVector3(
            0,
            0,
            -halfLength
        )

        muzzleNode.eulerAngles = SCNVector3(
            0,
            0,
            0
        )

        cannonBarrel.addChildNode(
            muzzleNode
        )
    }

    // ============================================================
    // MUZZLE POSITION
    // ============================================================

    var muzzleWorldPosition: SCNVector3 {

        muzzleNode.worldPosition
    }

    // ============================================================
    // MUZZLE DIRECTION
    // ============================================================

    var muzzleWorldDirection: SCNVector3 {

        let origin =
            muzzleNode.presentation.worldPosition

        let forwardPoint =
            muzzleNode.presentation.convertPosition(
                SCNVector3(
                    0,
                    0,
                    -1
                ),
                to: nil
            )

        let dx =
            forwardPoint.x - origin.x

        let dy =
            forwardPoint.y - origin.y

        let dz =
            forwardPoint.z - origin.z

        let length = sqrt(
            dx * dx +
            dy * dy +
            dz * dz
        )

        guard length > 0.0001 else {
            return SCNVector3(
                0,
                0,
                -1
            )
        }

        return SCNVector3(
            dx / length,
            dy / length,
            dz / length
        )
    }

    // ============================================================
    // SPAWN FLEET
    // ============================================================

    func spawnFleet() {

        fleet.removeAll(
            keepingCapacity: true
        )

        nextFleetID = 0

        for _ in 0..<maxFleetSize {

            // ====================================================
            // RANDOM FORMATION POSITION
            // ====================================================

            let angle =
                Float.random(
                    in: 0..<(2.0 * .pi)
                )

            let radius =
                Float.random(
                    in: 8.0...18.0
                )

            let x =
                cos(angle) * radius

            let y =
                sin(angle) * radius

            let z =
                Float.random(
                    in: 35.0...60.0
                )

            // ====================================================
            // INITIAL VELOCITY
            // ====================================================

            let velocity = SCNVector3(
                Float.random(
                    in: (-0.5)...0.5
                ),
                Float.random(
                    in: (-0.5)...0.5
                ),
                Float.random(
                    in: (-1.5)...(-0.5)
                )
            )

            // ====================================================
            // FACTION
            // ====================================================

            let faction:
                AlienShipState.Faction =
                nextFleetID % 2 == 0
                ? .alpha
                : .beta

            // ====================================================
            // CREATE SHIP
            // ====================================================

            let ship =
                AlienShipState(
                    fleetID: nextFleetID,

                    position: SCNVector3(
                        x,
                        y,
                        z
                    ),

                    velocity: velocity,

                    hullIntegrity: 1.0,

                    shieldEnergy: 1.0,

                    weaponEnergy: 1.0,

                    sensorRange: 15.0,

                    maneuverability: 1.0,

                    faction: faction,

                    target: nil,

                    behavioralState: .approaching
                )

            nextFleetID += 1

            fleet.append(
                ship
            )
        }
    }

    // ============================================================
    // CELLULAR AUTOMATON UPDATE
    // ============================================================

    func update(
        dt: CGFloat,
        playerAngle: Double,
        shipSpeed: CGFloat
    ) {

        guard dt > 0 else {
            return
        }

        // ========================================================
        // SYNCHRONOUS CA SNAPSHOT
        // ========================================================

        // Every alien evaluates the same previous-generation
        // fleet state. This prevents update-order bias.

        let currentFleet = fleet

        // ========================================================
        // LOCAL CA RULES
        // ========================================================

        for ship in currentFleet
        where !ship.destroyed {

            ship.update(
                allShips: currentFleet,
                obstacles: [],
                projectiles: [],
                debris: []
            )
        }

        // ========================================================
        // MOVEMENT
        // ========================================================

        for ship in fleet
        where !ship.destroyed {

            // Player/world forward motion.

            ship.position.z -=
                Float(
                    shipSpeed *
                    dt *
                    0.85
                )

            // Alien lateral movement.

            ship.position.x +=
                ship.velocity.x *
                Float(dt)

            // Alien vertical movement.

            ship.position.y +=
                ship.velocity.y *
                Float(dt)

            // Alien forward/backward movement.

            ship.position.z +=
                ship.velocity.z *
                Float(dt)
        }

        // ========================================================
        // REMOVE DESTROYED / PASSED SHIPS
        // ========================================================

        fleet.removeAll { ship in

            ship.destroyed ||
            ship.position.z < -10.0
        }

        // ========================================================
        // REINFORCEMENT
        // ========================================================

        if fleet.isEmpty {

            spawnFleet()
        }

        // ========================================================
        // RENDER
        // ========================================================

        renderFleet()
    }

    // ============================================================
    // RENDER FLEET
    // ============================================================

    func renderFleet() {

        // Remove previous visual representation.

        fleetContainer.childNodes.forEach {
            $0.removeFromParentNode()
        }

        // ========================================================
        // CREATE SHIP VISUALS
        // ========================================================

        for ship in fleet
        where !ship.destroyed {

            // ====================================================
            // SHIP BODY
            // ====================================================

            let geometry =
                SCNSphere(
                    radius: 0.5
                )

            let material =
                SCNMaterial()

            // ====================================================
            // FACTION APPEARANCE
            // ====================================================

            switch ship.faction {

            case .alpha:

                material.diffuse.contents =
                    UIColor.purple

            case .beta:

                material.diffuse.contents =
                    UIColor.red

            case .neutral:

                material.diffuse.contents =
                    UIColor.gray

            case .unknown:

                material.diffuse.contents =
                    UIColor.white
            }

            material.emission.contents =
                material.diffuse.contents

            material.emission.intensity =
                0.20

            geometry.materials = [
                material
            ]

            // ====================================================
            // NODE
            // ====================================================

            let shipNode =
                SCNNode(
                    geometry: geometry
                )

            shipNode.position =
                ship.position

            fleetContainer.addChildNode(
                shipNode
            )
        }
    }

    // ============================================================
    // SYNCHRONIZE WITH GAME STATE
    // ============================================================

    func sync(
        with game: GameState
    ) {

        let now = CACurrentMediaTime()
        
        let rawDT = now - lastSyncTime
        lastSyncTime = now

        let dt =
            CGFloat(
                min(
                    max(rawDT, 0.0),
                    0.05
                )
            )
        
        update(
            dt: dt,

            playerAngle:
                Double(
                    game.spaceShip.lateralAngle
                ),

            shipSpeed:
                game.spaceShip.forwardSpeed
        )
    }
}
