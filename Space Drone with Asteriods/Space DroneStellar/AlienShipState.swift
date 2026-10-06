
import Foundation
import SceneKit
import ObjectiveC

final class AlienShipState {

    // ============================================================
    // BEHAVIORAL STATE
    // ============================================================

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

    // ============================================================
    // FACTION
    // ============================================================

    enum Faction: String, Codable {
        case alpha
        case beta
        case neutral
        case unknown
    }

    // ============================================================
    // SHIP STATE
    // ============================================================

    var fleetID: Int

    var position: SCNVector3
    var velocity: SCNVector3

    var hullIntegrity: Float
    var shieldEnergy: Float
    var weaponEnergy: Float

    var sensorRange: Float
    var maneuverability: Float

    var faction: Faction

    var target: AlienShipState?

    var behavioralState: BehavioralState

    // ============================================================
    // CELLULAR AUTOMATON PARAMETERS
    // ============================================================

    var preferredFormationDistance: Float = 5.0
    var weaponRange: Float = 9.0

    // Movement
    var maxSpeed: Float = 8.0
    var acceleration: Float = 0.25

    // Weapons
    var laserCooldown: CGFloat = 0.0
    var laserFireInterval: CGFloat = 0.75
    var laserSpeed: Float = 30.0
    var laserDamage: Float = 0.15

    // Collision
    var collisionRadius: Float = 0.75

    var destroyed: Bool {
        behavioralState == .destroyed
    }

    // ============================================================
    // INITIALIZATION
    // ============================================================

    init(
        fleetID: Int,
        position: SCNVector3,
        velocity: SCNVector3 = SCNVector3(0, 0, 0),
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

    // ============================================================
    // MAIN CELLULAR AUTOMATON STEP
    // ============================================================

    /// Advances this alien ship by one CA generation.
    ///
    /// Returns an alien projectile when the ship fires.
    @discardableResult
    func update(
        allShips: [AlienShipState],
        obstacles: [SCNVector3],
        projectiles: [Projectile],
        debris: [SCNVector3],
        dt: CGFloat
    ) -> Projectile? {

        guard !destroyed else {
            return nil
        }

        // ========================================================
        // 1. LOCAL NEIGHBORHOOD
        // ========================================================

        let nearbyShips = allShips.filter { ship in

            guard ship.fleetID != fleetID,
                  !ship.destroyed else {
                return false
            }

            return Self.distance(
                position,
                ship.position
            ) <= sensorRange
        }

        // ========================================================
        // 2. SENSOR DETECTION
        // ========================================================

        var detectedEnemy: AlienShipState?

        for ship in nearbyShips {

            if ship.faction != faction &&
                ship.faction != .neutral &&
                ship.faction != .unknown {

                detectedEnemy = ship
                break
            }
        }

        // ========================================================
        // 3. TARGET SELECTION
        // ========================================================

        if let detectedEnemy {

            target = detectedEnemy

            let targetDistance = Self.distance(
                position,
                detectedEnemy.position
            )

            // ====================================================
            // 4. BEHAVIORAL STATE
            // ====================================================

            if targetDistance <= weaponRange {

                behavioralState = .attacking

            } else if targetDistance <= sensorRange {

                behavioralState = .pursuing

            } else {

                behavioralState = .approaching
            }

        } else if behavioralState != .disabled &&
                  behavioralState != .retreating {

            behavioralState = .idle
            target = nil
        }

        // ========================================================
        // 5. PLAYER LASER COLLISION
        // ========================================================

        for projectile in projectiles {

            // Current design:
            // .unknown represents a player projectile.
            guard projectile.sourceFaction == .unknown else {
                continue
            }

            let hitDistance = Self.distance(
                position,
                projectile.position
            )

            guard hitDistance <= collisionRadius else {
                continue
            }

            applyDamage(projectile.damage)

            break
        }

        // ========================================================
        // 6. DAMAGE STATE CHECK
        // ========================================================

        if destroyed {

            velocity = SCNVector3(0, 0, 0)
            target = nil

            return nil
        }

        if hullIntegrity <= 0.0 {

            hullIntegrity = 0.0
            behavioralState = .destroyed

            velocity = SCNVector3(
                0,
                0,
                0
            )

            target = nil

            return nil
        }

        if hullIntegrity < 0.25 {

            behavioralState = .disabled

            velocity = SCNVector3(
                0,
                0,
                0
            )

            return nil
        }

        // ========================================================
        // 7. LOCAL FLEET FORMATION
        // ========================================================

        var formationForce =
            SCNVector3(0, 0, 0)

        for ship in nearbyShips {

            let separation = Self.distance(
                position,
                ship.position
            )

            if separation > 0.001 &&
                separation < preferredFormationDistance {

                let away = Self.normalize(
                    Self.subtract(
                        position,
                        ship.position
                    )
                )

                formationForce = Self.add(
                    formationForce,
                    Self.multiply(
                        away,
                        (
                            preferredFormationDistance
                            - separation
                        ) * 0.15
                    )
                )
            }
        }

        // ========================================================
        // 8. TARGET PURSUIT
        // ========================================================

        var pursuitForce =
            SCNVector3(0, 0, 0)

        if let target,
           !target.destroyed {

            let toTarget = Self.subtract(
                target.position,
                position
            )

            let targetDistance =
                Self.magnitude(toTarget)

            if targetDistance > weaponRange {

                pursuitForce = Self.multiply(
                    Self.normalize(toTarget),
                    maneuverability * acceleration
                )

            } else {

                pursuitForce = Self.multiply(
                    Self.normalize(toTarget),
                    maneuverability * acceleration * 0.20
                )
            }
        }

        // ========================================================
        // 9. OBSTACLE AVOIDANCE
        // ========================================================

        var avoidanceForce =
            SCNVector3(0, 0, 0)

        for obstacle in obstacles {

            let d = Self.distance(
                position,
                obstacle
            )

            if d > 0.001 && d < 3.0 {

                let away = Self.normalize(
                    Self.subtract(
                        position,
                        obstacle
                    )
                )

                avoidanceForce = Self.add(
                    avoidanceForce,
                    Self.multiply(
                        away,
                        Float(3.0 - d) * 0.20
                    )
                )
            }
        }

        // ========================================================
        // 10. COMBINE CA FORCES
        // ========================================================

        let accelerationForce = Self.add(
            Self.add(
                formationForce,
                pursuitForce
            ),
            avoidanceForce
        )

        velocity = Self.add(
            velocity,
            accelerationForce
        )

        // ========================================================
        // 11. LIMIT VELOCITY
        // ========================================================

        let effectiveMaxSpeed =
            maxSpeed * max(
                maneuverability,
                0.1
            )

        let currentSpeed =
            Self.magnitude(velocity)

        if currentSpeed > effectiveMaxSpeed {

            velocity = Self.multiply(
                Self.normalize(velocity),
                effectiveMaxSpeed
            )
        }

        // ========================================================
        // 12. MOVE SHIP
        // ========================================================

        position = Self.add(
            position,
            Self.multiply(
                velocity,
                Float(dt)
            )
        )

        // ========================================================
        // 13. ALIEN LASER FIRE
        // ========================================================

        laserCooldown -= dt

        if behavioralState == .attacking,
           let target,
           !target.destroyed,
           laserCooldown <= 0.0,
           weaponEnergy > 0.0 {

            let toTarget = Self.subtract(
                target.position,
                position
            )

            let targetDistance =
                Self.magnitude(toTarget)

            if targetDistance <= weaponRange {

                laserCooldown =
                    laserFireInterval

                weaponEnergy = max(
                    weaponEnergy - 0.10,
                    0.0
                )

                return fireLaser(
                    at: target
                )
            }
        }

        return nil
    }

    // ============================================================
    // DAMAGE / SHIELD TRANSITION
    // ============================================================

    func applyDamage(
        _ damage: Float
    ) {

        guard !destroyed else {
            return
        }

        var remainingDamage = max(
            damage,
            0.0
        )

        // ========================================================
        // SHIELD
        // ========================================================

        if shieldEnergy > 0.0 {

            let absorbed = min(
                shieldEnergy,
                remainingDamage
            )

            shieldEnergy -= absorbed
            remainingDamage -= absorbed
        }

        // ========================================================
        // HULL
        // ========================================================

        if remainingDamage > 0.0 {

            hullIntegrity -= remainingDamage
        }

        shieldEnergy = max(
            shieldEnergy,
            0.0
        )

        hullIntegrity = max(
            hullIntegrity,
            0.0
        )

        // ========================================================
        // STATE TRANSITION
        // ========================================================

        if hullIntegrity <= 0.0 {

            behavioralState = .destroyed

            velocity = SCNVector3(
                0,
                0,
                0
            )

            target = nil

        } else if hullIntegrity < 0.25 {

            behavioralState = .disabled

            velocity = SCNVector3(
                0,
                0,
                0
            )

        } else if hullIntegrity < 0.50 {

            behavioralState = .retreating

        } else {

            behavioralState = .evading
        }
    }

    // ============================================================
    // ALIEN LASER
    // ============================================================

    private func fireLaser(
        at target: AlienShipState
    ) -> Projectile {

        let direction = Self.normalize(
            Self.subtract(
                target.position,
                position
            )
        )

        let muzzleOffset: Float = 0.8

        let laserPosition = Self.add(
            position,
            Self.multiply(
                direction,
                muzzleOffset
            )
        )

        return Projectile(
            position: laserPosition,
            velocity: Self.multiply(
                direction,
                laserSpeed
            ),
            damage: laserDamage,
            sourceFaction: faction,
            targetID: target.fleetID
        )
    }

    // ============================================================
    // PLAYER LASER FACTORY
    // ============================================================

    static func firePlayerLaser(
        position: SCNVector3,
        direction: SCNVector3,
        speed: Float = 40.0,
        damage: Float = 0.25
    ) -> Projectile {

        let normalizedDirection =
            Self.normalize(direction)

        return Projectile(
            position: position,
            velocity: Self.multiply(
                normalizedDirection,
                speed
            ),
            damage: damage,
            sourceFaction: .unknown,
            targetID: nil
        )
    }

    // ============================================================
    // VECTOR MATH
    //
    // Static so it can safely be used by:
    //
    // 1. AlienShipState.step()
    // 2. fireLaser()
    // 3. firePlayerLaser()
    //
    // ============================================================

    private static func distance(
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> Float {

        return magnitude(
            subtract(a, b)
        )
    }

    private static func magnitude(
        _ vector: SCNVector3
    ) -> Float {

        return sqrt(
            vector.x * vector.x +
            vector.y * vector.y +
            vector.z * vector.z
        )
    }

    private static func normalize(
        _ vector: SCNVector3
    ) -> SCNVector3 {

        let length =
            magnitude(vector)

        guard length > 0.0001 else {

            return SCNVector3(
                0,
                0,
                0
            )
        }

        return SCNVector3(
            vector.x / length,
            vector.y / length,
            vector.z / length
        )
    }

    private static func add(
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> SCNVector3 {

        return SCNVector3(
            a.x + b.x,
            a.y + b.y,
            a.z + b.z
        )
    }

    private static func subtract(
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> SCNVector3 {

        return SCNVector3(
            a.x - b.x,
            a.y - b.y,
            a.z - b.z
        )
    }

    private static func multiply(
        _ vector: SCNVector3,
        _ scalar: Float
    ) -> SCNVector3 {

        return SCNVector3(
            vector.x * scalar,
            vector.y * scalar,
            vector.z * scalar
        )
    }

    // ============================================================
    // GAME STATE UPDATE
    // ============================================================

    @MainActor
    static func update(
        gameState: GameState,
        dt: CGFloat
    ) {

        if gameState.alienFleetManager == nil {

            gameState.alienFleetManager =
                AlienShipBattleSceneWorld(
                    fleetSize: 8
                )
        }

        guard let fleetManager =
                gameState.alienFleetManager
        else {
            return
        }

        fleetManager.update(
            dt: dt,
            playerAngle: Double(
                gameState.spaceShip.lateralAngle
            ),
            shipSpeed:
                gameState.spaceShip.forwardSpeed
        )
    }
}

// ================================================================
// GAME STATE ASSOCIATED FLEET
// ================================================================

private var alienFleetManagerKey: UInt8 = 0

extension GameState {

    var alienFleetManager:
        AlienShipBattleSceneWorld? {

        get {

            objc_getAssociatedObject(
                self,
                &alienFleetManagerKey
            ) as? AlienShipBattleSceneWorld
        }

        set {

            objc_setAssociatedObject(
                self,
                &alienFleetManagerKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }
}

// ================================================================
// PROJECTILE STATE
// ================================================================

struct Projectile {

    var position: SCNVector3

    var velocity: SCNVector3

    var damage: Float

    var sourceFaction:
        AlienShipState.Faction

    var targetID: Int?
}

