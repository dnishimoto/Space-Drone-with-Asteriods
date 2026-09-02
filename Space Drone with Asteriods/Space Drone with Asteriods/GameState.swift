import Foundation
import SwiftUI
import SceneKit
import Combine

enum SceneSection {
    case tunnel
    case ocean
}

@MainActor
final class GameState: ObservableObject {
    
    var enemySpaceShip: EnemySpaceShip? = nil
    var asteroids: [Asteroid] = []
    var playerLasers: [Laser] = []
    var enemyLasers: [Laser] = []
    var sharks: [Shark] = []
    @Published var  swarmManager : SwarmManager = SwarmManager()
    @Published var  flockManager : FlockManager = FlockManager()
    @Published var  sharkManager : SharkManager = SharkManager()
    @Published var  asteroidManager : AsteroidManager = AsteroidManager()

    @Published var sharkNodes: [ObjectIdentifier: SCNNode] = [:]
    @Published var asteroidNodes: [ObjectIdentifier: SCNNode] = [:]
    @Published var alienNodes: [ObjectIdentifier: SCNNode] = [:]
    @Published var flockNodes: [ObjectIdentifier: SCNNode] = [:]

    // ============================================================
    // CANNON
    // ============================================================

    var cannonMuzzleWorldPosition =
        SCNVector3(0, 0, 0)

    @Published var cannonLateralAngle: Double = 0.0
    @Published var cannonElevation: Double = 0.0

    var cannonAzimuth: Double = 0.0

    // Actual rendered cannon direction.
    var cannonWorldDirection =
        SCNVector3(0, 0, -1)

    // ============================================================
    // PLAYER
    // ============================================================

    var spaceShip = SpaceShip()

    var joystickVector: CGVector = .zero

 
    // ============================================================
    // GAME
    // ============================================================

    //@Published var score = 20_000
    @Published var score = 0

    @Published var gameOver = false

    @Published var volume: Double = 1.0

    @Published private(set) var frameTick: Int = 0

    @Published private(set) var shieldActive = false

    @Published var currentSection: SceneSection = .tunnel

    @Published var playCollisionSound = true

    // ============================================================
    // TIMERS
    // ============================================================

    private var fireTimer: Timer?
    private var gameTimer: Timer?
    private var shieldTimer: Timer?

    private let dt: CGFloat = 1.0 / 60.0

    static let shieldDuration: TimeInterval = 2.0

    // ============================================================
    // EXPLOSIONS
    // ============================================================

    var pendingExplosions: [ExplosionEvent] = []

    // ============================================================
    // START
    // ============================================================

    func start() {
        guard gameTimer == nil else {
            return
        }

        gameTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0 / 60.0,
            repeats: true
        ) { [weak self] _ in

            Task { @MainActor in
                self?.tick()
            }
        }
    }

    // ============================================================
    // MAIN GAME LOOP
    // ============================================================

    func tick() {

        guard !gameOver else {
            stopFiring()
            return
        }

        let deltaTime = dt

        let deadzone: CGFloat = 0.12

        // --------------------------------------------------------
        // JOYSTICK
        // --------------------------------------------------------

        let rawX = joystickVector.dx

        spaceShip.lateralInput =
            abs(rawX) > deadzone
            ? Double(max(-1.0, min(1.0, rawX)))
            : 0.0

        let rawY = -joystickVector.dy

        spaceShip.verticalInput =
            abs(rawY) > deadzone
            ? Double(max(-1.0, min(1.0, rawY)))
            : 0.0

        // --------------------------------------------------------
        // PLAYER
        // --------------------------------------------------------

        spaceShip.update(dt: deltaTime)

        // --------------------------------------------------------
        // SECTION-SPECIFIC GAMEPLAY
        // --------------------------------------------------------

        switch currentSection {

        case .tunnel:
            TunnelGameState.update(
                gameState: self,
                dt: deltaTime
            )

        case .ocean:
            OceanGameState.update(
                gameState: self,
                dt: deltaTime
            )

 
        }

        // --------------------------------------------------------
        // PLAYER LASERS
        // --------------------------------------------------------

        for index in playerLasers.indices {

            playerLasers[index].update(
                dt: deltaTime,
                shipSpeed: spaceShip.forwardSpeed
            )
        }

        // --------------------------------------------------------
        // LASER RANGE
        // --------------------------------------------------------

        playerLasers.removeAll { laser in
            laser.z > 90.0 ||
            laser.z < -5.0
        }

        enemyLasers.removeAll { laser in
            laser.z > 90.0 ||
            laser.z < -5.0
        }

        // --------------------------------------------------------
        // SCORE
        // --------------------------------------------------------

        if Int(spaceShip.progress) % 10 == 0,
           frameTick % 60 == 0,
           spaceShip.progress > 0 {

            score += 1
        }

        // --------------------------------------------------------
        // STAGE PROGRESSION
        // --------------------------------------------------------

        switch currentSection {

        case .tunnel:

            if score >= 20_000 {
                currentSection = .ocean
            }

        case .ocean:

            if score >= 60_000 {
                
            }

      
        default:
            
            currentSection = .tunnel
        }

        frameTick &+= 1
    }

    // ============================================================
    // CANNON FIRE
    // ============================================================

    func shootLaser() {

        guard !gameOver else {
            return
        }

        let muzzle =
            cannonMuzzleWorldPosition

        let direction =
            cannonWorldDirection.normalized

        guard direction.length > 0.000001 else {
            return
        }

        let radial = hypot(
            CGFloat(muzzle.x),
            CGFloat(muzzle.y)
        )

        let normalizedRadial = max(
            Tunnel.minRadialOffset,
            min(
                0.98,
                radial / Tunnel.radius
            )
        )

        playerLasers.append(
            Laser(
                lateralAngle: cannonAzimuth,
                elevationAngle: cannonElevation,
                z: CGFloat(muzzle.z),
                radialOffset: normalizedRadial,
                origin: muzzle,
                direction: direction,
                stepSize: 0.1,
                isPlayerLaser: true
            )
        )
    }

    func startFiring() {

        guard !gameOver else {
            return
        }

        guard fireTimer == nil else {
            return
        }

        shootLaser()

        fireTimer = Timer.scheduledTimer(
            withTimeInterval: 0.06,
            repeats: true
        ) { [weak self] _ in

            Task { @MainActor in

                guard let self,
                      !self.gameOver
                else {
                    self?.stopFiring()
                    return
                }

                self.shootLaser()
            }
        }
    }

    func stopFiring() {

        fireTimer?.invalidate()
        fireTimer = nil
    }

    // ============================================================
    // SHIELD
    // ============================================================

    func activateShield() {

        guard !gameOver,
              !shieldActive
        else {
            return
        }

        shieldActive = true

        shieldTimer?.invalidate()

        shieldTimer = Timer.scheduledTimer(
            withTimeInterval: GameState.shieldDuration,
            repeats: false
        ) { [weak self] _ in

            Task { @MainActor in
                self?.shieldActive = false
            }
        }
    }

    // ============================================================
    // EXPLOSION
    // ============================================================

    func spawnExplosion(
        x: CGFloat,
        y: CGFloat,
        z: CGFloat,
        scale: Float = 1.0
    ) {

        pendingExplosions.append(
            ExplosionEvent(
                x: x,
                y: y,
                z: z,
                scale: scale
            )
        )
    }

    func stopAll() {

        stopFiring()

        gameTimer?.invalidate()
        gameTimer = nil

        shieldTimer?.invalidate()
        shieldTimer = nil
    }

    // ============================================================
    // RESTART
    // ============================================================

    func restart() {

        stopAll()

        spaceShip = SpaceShip()

        playerLasers.removeAll()
        enemyLasers.removeAll()

        pendingExplosions.removeAll()

        score = 0

        gameOver = false
        shieldActive = false

        cannonAzimuth = 0
        cannonElevation = 0

        cannonMuzzleWorldPosition =
            SCNVector3(0, 0, 0)

        cannonWorldDirection =
            SCNVector3(0, 0, -1)


        frameTick = 0

        start()
    }
}

struct ExplosionEvent {

    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
    var scale: Float
}
