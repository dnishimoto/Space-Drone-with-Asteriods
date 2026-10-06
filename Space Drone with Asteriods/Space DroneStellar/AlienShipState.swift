
import Foundation
import SceneKit
import ObjectiveC

// ================================================================
// ALIEN SHIP STATE
//
// One alien ship in the battle fleet. All ships are advanced by the
// same cellular-automaton rules, every ship reading the SAME
// previous-generation snapshot of the fleet (no update-order bias).
//
// Ownership of the simulation:
//
//   GameState.update()  ->  AlienShipState.update(gameState:dt:)
//                       ->  AlienShipBattleSceneWorld.step(dt:game:)
//
// The scene world only renders, follows the ship with the camera and
// publishes the cannon muzzle. It never creates a second fleet.
//
// State priority (highest first):
//
//   destroyed   hull <= 0             terminal
//   disabled    hull < 0.25           dead in the water, no weapons
//   retreating  hull < 0.50           flees from the nearest enemy
//   evading     just took damage      timed strafe, then back to normal
//   attacking   enemy inside weaponRange
//   pursuing    enemy inside sensorRange
//   approaching enemy exists but is outside sensorRange
//   idle        no enemy left
// ================================================================

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
    // SNAPSHOT
    //
    // Value copy of what other ships are allowed to see about this
    // ship. Ships are classes, so without a snapshot a ship updated
    // late in the loop would see the already-updated positions of
    // the ships updated before it.
    // ============================================================

    struct Snapshot {
        let fleetID: Int
        let faction: Faction
        let position: SCNVector3
        let destroyed: Bool
    }

    // ============================================================
    // TUNING
    // ============================================================

    static let disabledThreshold: Float = 0.25
    static let retreatThreshold: Float = 0.50

    static let evadeDuration: CGFloat = 1.0

    /// Damage dealt by one player cannon laser.
    static let playerLaserDamage: Float = 0.25

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

    /// fleetID of the enemy this ship is currently focused on.
    var targetID: Int?

    var behavioralState: BehavioralState

    // ============================================================
    // CELLULAR AUTOMATON PARAMETERS
    // ============================================================

    var preferredFormationDistance: Float = 5.0
    var weaponRange: Float = 9.0

    // Movement
    //
    // Steering strengths are tuned per 60 Hz tick (see `tick` in
    // update) so behaviour no longer depends on the frame rate.
    var maxSpeed: Float = 8.0
    var acceleration: Float = 0.25
    var drag: Float = 0.35

    // Weapons
    var laserCooldown: CGFloat = 0.0
    var laserFireInterval: CGFloat = 0.75
    var laserSpeed: Float = 30.0
    var laserDamage: Float = 0.15
    var weaponCostPerShot: Float = 0.10
    var weaponRechargeRate: Float = 0.15

    // Evasion
    var evadeTimer: CGFloat = 0.0
    var evadeDirection: Float = 1.0

    // Collision
    var collisionRadius: Float = 0.75

    var destroyed: Bool {
        behavioralState == .destroyed
    }

    var disabled: Bool {
        behavioralState == .disabled
    }

    var snapshot: Snapshot {
        Snapshot(
            fleetID: fleetID,
            faction: faction,
            position: position,
            destroyed: destroyed
        )
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
        targetID: Int? = nil,
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
        self.targetID = targetID
        self.behavioralState = behavioralState
    }

    // ============================================================
    // HOSTILITY
    // ============================================================

    /// True when a ship of `other` faction is an enemy of this ship.
    func isEnemy(_ other: Faction) -> Bool {
        other != faction &&
        other != .neutral &&
        other != .unknown
    }

    /// True when a projectile fired by `source` hurts a ship of
    /// `target` faction. `.unknown` is the player cannon and hurts
    /// every alien ship.
    static func projectileHurts(
        source: Faction,
        target: Faction
    ) -> Bool {

        if source == .unknown {
            return true
        }

        return source != target &&
               target != .neutral &&
               target != .unknown
    }

    // ============================================================
    // MAIN CELLULAR AUTOMATON STEP
    // ============================================================

    /// Advances this alien ship by one CA generation.
    ///
    /// Moves THIS ship by its own velocity. The scene world must not
    /// integrate `velocity` again; it only adds the convoy motion that
    /// keeps the fleet in the player's frame.
    ///
    /// Projectile hits are resolved by the scene world (it owns the
    /// projectiles and the player lasers and can consume them).
    ///
    /// Returns an alien projectile when the ship fires.
    @discardableResult
    func update(
        allShips: [Snapshot],
        obstacles: [SCNVector3],
        dt: CGFloat
    ) -> Projectile? {

        guard !destroyed else {
            return nil
        }

        let dtF = Float(dt)

        // Steering was tuned per 60 Hz frame; scale so that any
        // frame rate produces the same motion.
        let tick = dtF * 60.0

        // ========================================================
        // 1. HULL STATES (override everything else)
        // ========================================================

        if hullIntegrity <= 0.0 {
            becomeDestroyed()
            return nil
        }

        if hullIntegrity < Self.disabledThreshold {

            behavioralState = .disabled
            velocity = Self.zero
            targetID = nil

            return nil
        }

        // ========================================================
        // 2. SENSORS
        //
        // `detected` = nearest enemy inside sensorRange.
        // `nearest`  = nearest enemy anywhere in the fleet.
        // ========================================================

        var detected: (ship: Snapshot, distance: Float)?
        var nearest: (ship: Snapshot, distance: Float)?

        for other in allShips {

            guard other.fleetID != fleetID,
                  !other.destroyed,
                  isEnemy(other.faction) else {
                continue
            }

            let d = Self.distance(
                position,
                other.position
            )

            if d < (nearest?.distance ?? Float.greatestFiniteMagnitude) {
                nearest = (ship: other, distance: d)
            }

            if d <= sensorRange,
               d < (detected?.distance ?? Float.greatestFiniteMagnitude) {
                detected = (ship: other, distance: d)
            }
        }

        let focus = detected ?? nearest

        targetID = focus?.ship.fleetID

        // ========================================================
        // 3. BEHAVIORAL STATE
        // ========================================================

        if hullIntegrity < Self.retreatThreshold {

            behavioralState = .retreating

        } else if evadeTimer > 0.0 {

            evadeTimer -= dt
            behavioralState = .evading

        } else if let detected {

            behavioralState =
                detected.distance <= weaponRange
                ? .attacking
                : .pursuing

        } else if nearest != nil {

            behavioralState = .approaching

        } else {

            behavioralState = .idle
        }

        // ========================================================
        // 4. LOCAL FLEET FORMATION (separation)
        // ========================================================

        var steering = Self.zero

        for other in allShips
        where other.fleetID != fleetID && !other.destroyed {

            let separation = Self.distance(
                position,
                other.position
            )

            if separation > 0.001 &&
                separation < preferredFormationDistance {

                let away = Self.normalize(
                    Self.subtract(
                        position,
                        other.position
                    )
                )

                steering = Self.add(
                    steering,
                    Self.multiply(
                        away,
                        (preferredFormationDistance - separation) * 0.15
                    )
                )
            }
        }

        // ========================================================
        // 5. STATE-DRIVEN STEERING
        // ========================================================

        if let focus {

            let toFocus = Self.subtract(
                focus.ship.position,
                position
            )

            let direction = Self.normalize(toFocus)

            let thrust = maneuverability * acceleration

            switch behavioralState {

            case .approaching:

                steering = Self.add(
                    steering,
                    Self.multiply(direction, thrust * 0.6)
                )

            case .pursuing:

                steering = Self.add(
                    steering,
                    Self.multiply(direction, thrust)
                )

            case .attacking:

                // Close to firing distance, then hold position.
                if focus.distance > weaponRange * 0.5 {

                    steering = Self.add(
                        steering,
                        Self.multiply(direction, thrust * 0.20)
                    )
                }

            case .evading:

                // Strafe sideways (and a little vertically) across
                // the line to the enemy.
                let strafe = Self.normalize(
                    SCNVector3(
                        -direction.z,
                        0.5,
                        direction.x
                    )
                )

                steering = Self.add(
                    steering,
                    Self.multiply(
                        strafe,
                        thrust * 1.5 * evadeDirection
                    )
                )

            case .retreating:

                steering = Self.add(
                    steering,
                    Self.multiply(direction, -thrust * 1.2)
                )

            default:
                break
            }
        }

        // ========================================================
        // 6. OBSTACLE AVOIDANCE
        // ========================================================

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

                steering = Self.add(
                    steering,
                    Self.multiply(
                        away,
                        (3.0 - d) * 0.20
                    )
                )
            }
        }

        // ========================================================
        // 7. INTEGRATE VELOCITY
        // ========================================================

        velocity = Self.add(
            velocity,
            Self.multiply(steering, tick)
        )

        velocity = Self.multiply(
            velocity,
            max(0.0, 1.0 - drag * dtF)
        )

        let effectiveMaxSpeed =
            maxSpeed * max(maneuverability, 0.1)

        if Self.magnitude(velocity) > effectiveMaxSpeed {

            velocity = Self.multiply(
                Self.normalize(velocity),
                effectiveMaxSpeed
            )
        }

        // ========================================================
        // 8. MOVE SHIP (the only place velocity is integrated)
        // ========================================================

        position = Self.add(
            position,
            Self.multiply(velocity, dtF)
        )

        // ========================================================
        // 9. WEAPONS
        // ========================================================

        laserCooldown = max(laserCooldown - dt, 0.0)

        weaponEnergy = min(
            weaponEnergy + weaponRechargeRate * dtF,
            1.0
        )

        if behavioralState == .attacking,
           let focus,
           focus.distance <= weaponRange,
           laserCooldown <= 0.0,
           weaponEnergy >= weaponCostPerShot {

            laserCooldown = laserFireInterval
            weaponEnergy -= weaponCostPerShot

            return fireLaser(
                towards: focus.ship.position,
                targetID: focus.ship.fleetID
            )
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

        // SHIELD

        if shieldEnergy > 0.0 {

            let absorbed = min(
                shieldEnergy,
                remainingDamage
            )

            shieldEnergy -= absorbed
            remainingDamage -= absorbed
        }

        // HULL

        if remainingDamage > 0.0 {
            hullIntegrity -= remainingDamage
        }

        shieldEnergy = max(shieldEnergy, 0.0)
        hullIntegrity = max(hullIntegrity, 0.0)

        // STATE TRANSITION

        if hullIntegrity <= 0.0 {

            becomeDestroyed()

        } else if hullIntegrity < Self.disabledThreshold {

            behavioralState = .disabled
            velocity = Self.zero
            targetID = nil

        } else if hullIntegrity < Self.retreatThreshold {

            behavioralState = .retreating

        } else {

            // Shield hit or light hull damage: dodge for a moment.
            behavioralState = .evading
            evadeTimer = Self.evadeDuration
            evadeDirection = Bool.random() ? 1.0 : -1.0
        }
    }

    private func becomeDestroyed() {

        hullIntegrity = 0.0
        behavioralState = .destroyed
        velocity = Self.zero
        targetID = nil
    }

    // ============================================================
    // ALIEN LASER
    // ============================================================

    private func fireLaser(
        towards targetPosition: SCNVector3,
        targetID: Int
    ) -> Projectile {

        let direction = Self.normalize(
            Self.subtract(
                targetPosition,
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
            targetID: targetID,
            ownerID: fleetID,
            lifetime: 3.0
        )
    }

    // ============================================================
    // PLAYER LASER FACTORY
    // ============================================================

    static func firePlayerLaser(
        position: SCNVector3,
        direction: SCNVector3,
        speed: Float = 40.0,
        damage: Float = AlienShipState.playerLaserDamage
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
    // Static and internal so the scene world can reuse it for
    // collision tests.
    // ============================================================

    static let zero = SCNVector3(0, 0, 0)

    static func distance(
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> Float {

        return magnitude(
            subtract(a, b)
        )
    }

    static func magnitude(
        _ vector: SCNVector3
    ) -> Float {

        return sqrt(
            vector.x * vector.x +
            vector.y * vector.y +
            vector.z * vector.z
        )
    }

    static func normalize(
        _ vector: SCNVector3
    ) -> SCNVector3 {

        let length =
            magnitude(vector)

        guard length > 0.0001 else {
            return zero
        }

        return SCNVector3(
            vector.x / length,
            vector.y / length,
            vector.z / length
        )
    }

    static func add(
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> SCNVector3 {

        return SCNVector3(
            a.x + b.x,
            a.y + b.y,
            a.z + b.z
        )
    }

    static func subtract(
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> SCNVector3 {

        return SCNVector3(
            a.x - b.x,
            a.y - b.y,
            a.z - b.z
        )
    }

    static func multiply(
        _ vector: SCNVector3,
        _ scalar: Float
    ) -> SCNVector3 {

        return SCNVector3(
            vector.x * scalar,
            vector.y * scalar,
            vector.z * scalar
        )
    }

    /// Shortest distance from point `p` to the segment a -> b.
    /// Used for swept hit tests so fast lasers cannot tunnel through
    /// a ship between two frames.
    static func distanceToSegment(
        _ p: SCNVector3,
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> Float {

        let ab = subtract(b, a)

        let lengthSquared =
            ab.x * ab.x +
            ab.y * ab.y +
            ab.z * ab.z

        guard lengthSquared > 0.00000001 else {
            return distance(p, a)
        }

        let ap = subtract(p, a)

        let dot =
            ap.x * ab.x +
            ap.y * ab.y +
            ap.z * ab.z

        let t = max(
            0.0,
            min(1.0, dot / lengthSquared)
        )

        let closest = add(
            a,
            multiply(ab, t)
        )

        return distance(p, closest)
    }

    // ============================================================
    // GAME STATE UPDATE
    //
    // Called from GameState.update() every frame while the aliens
    // section is active. The fleet itself lives in the scene world
    // (ContentView's `alienWorld`), which registers itself on the
    // GameState from its sync(with:). There is only ever ONE fleet;
    // this no longer creates a second, invisible one.
    // ============================================================

    @MainActor
    static func update(
        gameState: GameState,
        dt: CGFloat
    ) {

        guard let fleetManager =
                gameState.alienFleetManager
        else {
            return
        }

        fleetManager.step(
            dt: dt,
            game: gameState
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

    /// fleetID of the ship that fired it (nil for the player), so a
    /// ship can never be hit by its own shot.
    var ownerID: Int? = nil

    /// Seconds of flight left before the shot expires.
    var lifetime: Float = 3.0
}

