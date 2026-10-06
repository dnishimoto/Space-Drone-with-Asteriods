// AlienShipState.swift
// State for an individual alien ship in a fleet.
//
// This is modeled after EnemySpaceShip, but with possible extensions for fleet management.

import Foundation
import SceneKit

final class AlienShipState {
    enum BehavioralState: String, Codable {
        case idle
        case approaching
        case attacking
        case evading
        case pursuing
        case defending
        case retreating
        case disabled
        case destroyed
    }
    
    enum Faction: String, Codable {
        case alpha, beta, neutral, unknown
    }

    var fleetID: Int // Unique identifier within the fleet
    var position: SCNVector3
    var velocity: SCNVector3
    var hullIntegrity: Float
    var shieldEnergy: Float
    var weaponEnergy: Float
    var sensorRange: Float
    var maneuverability: Float
    var faction: Faction
    var target: AlienShipState? // Optional reference to another ship
    var behavioralState: BehavioralState

    // For CA rules
    var preferredFormationDistance: Float = 5.0
    var weaponRange: Float = 9.0
    var destroyed: Bool { behavioralState == .destroyed }

    init(
        fleetID: Int,
        position: SCNVector3,
        velocity: SCNVector3 = SCNVector3(0,0,0),
        hullIntegrity: Float = 1.0,
        shieldEnergy: Float = 1.0,
        weaponEnergy: Float = 1.0,
        sensorRange: Float = 15.0,
        maneuverability: Float = 1.0,
        faction: Faction = .alpha,
        target: AlienShipState? = nil,
        behavioralState: BehavioralState = .idle
    ) {
        self.fleetID = fleetID
        self.position = position
        self.velocity = velocity
        self.hullIntegrity = hullIntegrity
        self.shieldEnergy = shieldEnergy
        self.weaponEnergy = weaponEnergy
        self.sensorRange = sensorRange
        self.maneuverability = maneuverability
        self.faction = faction
        self.target = target
        self.behavioralState = behavioralState
    }

    /*
    func update(
        dt: CGFloat,
        shipSpeed: CGFloat,
        playerAngle: Double
    ) {
        guard !destroyed else { return }
        z -= shipSpeed * dt * 0.85
        var delta = playerAngle - lateralAngle
        while delta > .pi { delta -= 2.0 * .pi }
        while delta < -.pi { delta += 2.0 * .pi }
        lateralAngle += delta * 0.6 * Double(dt)
        shootCooldown -= dt
    }
    */

    // Main cellular automaton update for this frame
    func step(allShips: [AlienShipState], obstacles: [SCNVector3], projectiles: [Projectile], debris: [SCNVector3]) {
        // Implement local cellular rules and state transitions here.
        // (Rule stubs can be added in future steps)
    }

    /// Static update for use by GameState in the .aliens section
    /// (Manages a fleet of alien ships; for now, stores the fleet on GameState via associated object)
    @MainActor
    static func update(gameState: GameState, dt: CGFloat) {
        // Attach or create the fleet manager
        if gameState.alienFleetManager == nil {
            gameState.alienFleetManager = AlienShipBattleSceneWorld(fleetSize: 8)
        }
        guard let fleetManager = gameState.alienFleetManager else { return }

        // Run the fleet automaton for this frame
        fleetManager.update(dt: dt, playerAngle: Double(gameState.spaceShip.lateralAngle), shipSpeed: gameState.spaceShip.forwardSpeed)
    }
}

import ObjectiveC

private var alienFleetManagerKey: UInt8 = 0

extension GameState {
    var alienFleetManager: AlienShipBattleSceneWorld? {
        get {
            objc_getAssociatedObject(self, &alienFleetManagerKey) as? AlienShipBattleSceneWorld
        }
        set {
            objc_setAssociatedObject(self, &alienFleetManagerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

struct Projectile {
    var position: SCNVector3
    var velocity: SCNVector3
    var damage: Float
    var sourceFaction: AlienShipState.Faction
    var targetID: Int? // If guided
}
