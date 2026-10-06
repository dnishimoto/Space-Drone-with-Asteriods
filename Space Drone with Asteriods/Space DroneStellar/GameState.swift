import Foundation
import SwiftUI
import SceneKit
import Combine

enum SceneSection {
    case tunnel
    case ocean
    case terrain
    case aliens
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

    //@Published var cannonLateralAngle: Double = 0.0
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

    @Published var score = 80_000
    //@Published var score = 0

    @Published var gameOver = false

    @Published var volume: Double = 1.0

    @Published private(set) var frameTick: Int = 0

    @Published private(set) var shieldActive = false

    @Published var currentSection: SceneSection = .tunnel // Default tunnel, allow terrain future support

    @Published var playCollisionSound = true

    // ============================================================
    // TIMERS
    // ============================================================

    private var fireTimer: Timer?
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval?
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
        guard displayLink == nil else {
            return
        }
        lastFrameTimestamp = nil
        displayLink = CADisplayLink(target: self, selector: #selector(frameUpdate))
        displayLink?.add(to: .main, forMode: .default)
    }
    
    func addPendingExplosion(
        x: CGFloat,y: CGFloat,z: CGFloat,
        
    ) {
   
        pendingExplosions.append(
            ExplosionEvent(
                x: CGFloat(x),
                y: CGFloat(y),
                z: CGFloat(z),
                scale: 0.5
            )
        )
    }
    // ============================================================
    // MAIN GAME LOOP
    // ============================================================

    func tick(dt: CGFloat) {
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
        let rawY = -joystickVector.dy

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

        case .terrain:
            TerrainGameState.update(
                gameState: self,
                dt: deltaTime
            )

        case .aliens:
            AlienShipState.update(
                gameState: self,
                dt: deltaTime
            )
        }

        // --------------------------------------------------------
        // PLAYER INPUT
        // --------------------------------------------------------

        spaceShip.lateralInput =
            abs(rawX) > deadzone
            ? Double(max(-1.0, min(1.0, rawX)))
            : 0.0

        spaceShip.verticalInput =
            abs(rawY) > deadzone
            ? Double(max(-1.0, min(1.0, rawY)))
            : 0.0

        spaceShip.update(
            dt: deltaTime,
            currentSection: currentSection
        )

        // --------------------------------------------------------
        // UPDATE PLAYER LASERS
        // --------------------------------------------------------

        for index in playerLasers.indices {
            playerLasers[index].update(
                dt: deltaTime,
                shipSpeed: Float(spaceShip.forwardSpeed)
            )
        }

        // --------------------------------------------------------
        // UPDATE ENEMY LASERS
        // --------------------------------------------------------

        for index in enemyLasers.indices {
            enemyLasers[index].update(
                dt: deltaTime,
                shipSpeed: Float(spaceShip.forwardSpeed)
            )
        }

        // --------------------------------------------------------
        // REMOVE DISTANT LASERS
        // --------------------------------------------------------

        let maxLaserDistance: CGFloat = 500.0

        playerLasers.removeAll { laser in
            laser.distance >= maxLaserDistance
        }

        enemyLasers.removeAll { laser in
            laser.distance >= maxLaserDistance
        }

        // Remove enemy lasers outside the playable depth range.
        enemyLasers.removeAll { laser in
            laser.z > 90.0 || laser.z < -5.0
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
            if score >= 40_000 {
                currentSection = .terrain
            }

        case .terrain:
            if score >= 60_000 {
                currentSection = .aliens
            }

        case .aliens:
            if score >= 80_000 {
                currentSection = .aliens
            }
        }

        // --------------------------------------------------------
        // FRAME COUNTER
        // --------------------------------------------------------

        frameTick &+= 1
    }

    // ============================================================
    // CANNON FIRE
    // ============================================================


    func shootLaser() {
        guard !gameOver else {
            return
        }

        // ============================================================
        // Capture the cannon state AT THE MOMENT OF FIRING.
        //
        // These are already in WORLD SPACE:
        //
        // cannonMuzzleWorldPosition = laser origin
        // cannonWorldDirection      = laser direction
        //
        // The laser must keep these values after it is fired.
        // Moving the ship afterward must not change the laser direction.
        // ============================================================

        let muzzle =
            cannonMuzzleWorldPosition

        let rawDirection =
            cannonWorldDirection

        // ============================================================
        // Normalize the world-space firing direction.
        // ============================================================

        let length =
            sqrt(
                rawDirection.x * rawDirection.x +
                rawDirection.y * rawDirection.y +
                rawDirection.z * rawDirection.z
            )

        guard length > 0.0001 else {
            return
        }

        let direction =
            SCNVector3(
                rawDirection.x / length,
                rawDirection.y / length,
                rawDirection.z / length
            )

        // ============================================================
        // Create the laser.
        //
        // origin and direction are now independent snapshots.
        //
        // DO NOT recalculate direction from cannonAzimuth,
        // cannonElevation, or ship Z after this point.
        // ============================================================

        let laser =
            Laser(
                lateralAngle: cannonAzimuth,
                elevationAngle: cannonElevation,
                z: CGFloat(muzzle.z),
                origin: muzzle,
                direction: direction,
                stepSize: 0.1,
                isPlayerLaser: true
            )

        playerLasers.append(
            laser
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

        displayLink?.invalidate()
        displayLink = nil
        lastFrameTimestamp = nil

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
        
        asteroids.removeAll()
        sharks.removeAll()

  
        pendingExplosions.removeAll()
        
        for (id, node) in asteroidNodes {
                node.removeFromParentNode()
        }
        
        for (id, node) in sharkNodes {
                node.removeFromParentNode()
        }
        for (id, node) in alienNodes {
                node.removeFromParentNode()
        }
        for (id, node) in flockNodes {
                node.removeFromParentNode()
        }

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
        
        currentSection = .tunnel // Default tunnel, keep terrain for future
        
        //currentSection = .ocean

        start()
    }
    
    @objc private func frameUpdate(_ link: CADisplayLink) {
        if lastFrameTimestamp == nil {
            lastFrameTimestamp = link.timestamp
            return
        }
        let dt = CGFloat(link.timestamp - (lastFrameTimestamp ?? link.timestamp))
        lastFrameTimestamp = link.timestamp
        let clampedDT = min(dt, 0.05) // Cap dt to avoid big jumps
        tick(dt: clampedDT)
    }
}

struct ExplosionEvent {

    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
    var scale: Float
}
