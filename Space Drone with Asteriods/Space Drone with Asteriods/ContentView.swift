import SwiftUI
import SceneKit
import Combine

// MARK: - App Entry (uncomment if needed)
//
// @main
// struct SpaceGameApp: App {
//     var body: some Scene {
//         WindowGroup { ContentView() }
//     }
// }

// =====================================================================
// TUBE RUNNER
// • Infinite tube along +Z; ship near z ≈ 0; world scrolls toward player
// • Joystick X = slide on circumference; Y = forward speed
// • Manual FIRE + SHIELD + CANNON AIM
// • Asteroids / swarm / flock stay inside the tube and BOUNCE off walls
// =====================================================================

// MARK: - Tunnel

enum Tunnel {
    static let radius: CGFloat = 8.0
    static let segmentLength: CGFloat = 40.0
    static let segmentsAhead = 8
    static let segmentsBehind = 2
    static let shipRadialInset: CGFloat = 0.82
    static let minSpeed: CGFloat = 2.5
    static let maxSpeed: CGFloat = 16.0
    static let defaultSpeed: CGFloat = 6.0
    static let lateralSpeed: Double = 2.4
    static let speedAccel: CGFloat = 12.0

    /// Soft inner floor so entities don't sit on the axis forever.
    static let minRadialOffset: CGFloat = 0.18
    /// Bounce energy retained (0…1).
    static let wallRestitution: CGFloat = 0.72
}

// MARK: - Shared radial / wall helpers

private enum TubePhysics {
    /// Integrate radial offset and bounce off outer wall + soft inner limit.
    static func integrateRadial(
        radialOffset: inout CGFloat,
        radialVel: inout CGFloat,
        entityRadius: CGFloat,
        dt: CGFloat
    ) {
        radialOffset += radialVel * dt

        let maxOffset = max(Tunnel.minRadialOffset, 1.0 - entityRadius / Tunnel.radius)
        let minOffset = Tunnel.minRadialOffset

        if radialOffset >= maxOffset {
            radialOffset = maxOffset
            if radialVel > 0 {
                radialVel = -radialVel * Tunnel.wallRestitution
            }
        } else if radialOffset <= minOffset {
            radialOffset = minOffset
            if radialVel < 0 {
                radialVel = -radialVel * Tunnel.wallRestitution
            }
        }
    }

    /// Optional light “slide along wall” damping when pressed against outer wall.
    static func dampAgainstWall(radialOffset: CGFloat, radialVel: inout CGFloat, entityRadius: CGFloat) {
        let maxOffset = max(Tunnel.minRadialOffset, 1.0 - entityRadius / Tunnel.radius)
        if radialOffset >= maxOffset - 0.02 && radialVel > 0 {
            radialVel *= 0.5
        }
    }
}

// MARK: - Asteroid size

enum AsteroidSize {
    case small, medium, large

    var radius: CGFloat {
        switch self {
        case .small:  return 0.55
        case .medium: return 0.85
        case .large:  return 1.25
        }
    }

    var score: Int {
        switch self {
        case .small:  return 50
        case .medium: return 75
        case .large:  return 100
        }
    }
}

// MARK: - Laser

struct Laser {
    var lateralAngle: Double
    var elevationAngle: Double = 0 // Added elevation angle for vertical aiming
    var z: CGFloat
    let isPlayerLaser: Bool
    static let speed: CGFloat = 28.0

    mutating func update(dt: CGFloat, shipSpeed: CGFloat) {
        if isPlayerLaser {
            z += Laser.speed * dt
        } else {
            z -= (Laser.speed + shipSpeed) * dt
        }
    }

    /// Player lasers ride the same ring as the ship (cone tip), with elevation.
    func crossSectionPosition(radiusScale: CGFloat = Tunnel.shipRadialInset) -> SCNVector3 {
        let r = Float(Tunnel.radius * radiusScale)
        // Calculate lateral position on circle and apply elevation as vertical offset
        let x = r * Float(cos(lateralAngle)) * Float(cos(elevationAngle))
        let y = r * Float(sin(elevationAngle))
        let zPos = Float(z) + r * Float(sin(lateralAngle)) * Float(cos(elevationAngle))
        return SCNVector3(x, y, zPos)
    }
}

// MARK: - Asteroid (bounces off tube wall)

final class Asteroid {
    var lateralAngle: Double
    var z: CGFloat
    var size: AsteroidSize
    /// 0…1 fraction of Tunnel.radius
    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double
    var spin: Float = 0

    init(
        lateralAngle: Double,
        z: CGFloat,
        size: AsteroidSize,
        radialOffset: CGFloat = 0.55,
        radialVel: CGFloat = 0,
        angularVel: Double = 0
    ) {
        self.lateralAngle = lateralAngle
        self.z = z
        self.size = size
        self.radialOffset = radialOffset
        self.radialVel = radialVel
        self.angularVel = angularVel
    }

    func update(dt: CGFloat, shipSpeed: CGFloat) {
        z -= shipSpeed * dt
        spin += Float(dt) * 1.2

        lateralAngle += angularVel * Double(dt)

        TubePhysics.integrateRadial(
            radialOffset: &radialOffset,
            radialVel: &radialVel,
            entityRadius: size.radius,
            dt: dt
        )
        TubePhysics.dampAgainstWall(
            radialOffset: radialOffset,
            radialVel: &radialVel,
            entityRadius: size.radius
        )

        // Mild friction so they don't orbit forever at full speed
        angularVel *= 0.998
        radialVel *= 0.999
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * radialOffset)
        return SCNVector3(
            r * Float(cos(lateralAngle)),
            r * Float(sin(lateralAngle)),
            Float(z)
        )
    }
}

// MARK: - Space Ship

final class SpaceShip {
    var lateralAngle: Double = 0
    var forwardSpeed: CGFloat = Tunnel.defaultSpeed
    var progress: CGFloat = 0

    var lateralInput: Double = 0
    var speedInput: Double = 0

    func update(dt: CGFloat) {
        lateralAngle += lateralInput * Tunnel.lateralSpeed * Double(dt)

        let target = Tunnel.defaultSpeed
            + CGFloat(speedInput) * (Tunnel.maxSpeed - Tunnel.minSpeed) * 0.5
        let clampedTarget = max(Tunnel.minSpeed, min(Tunnel.maxSpeed, target))
        let diff = clampedTarget - forwardSpeed
        let step = Tunnel.speedAccel * dt
        if abs(diff) <= step {
            forwardSpeed = clampedTarget
        } else {
            forwardSpeed += diff > 0 ? step : -step
        }

        progress += forwardSpeed * dt
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * Tunnel.shipRadialInset)
        return SCNVector3(
            r * Float(cos(lateralAngle)),
            r * Float(sin(lateralAngle)),
            0
        )
    }
}

// MARK: - Enemy boss

final class EnemySpaceShip {
    var lateralAngle: Double
    var z: CGFloat
    var destroyed = false
    var shootCooldown: CGFloat = 1.5

    init(lateralAngle: Double, z: CGFloat) {
        self.lateralAngle = lateralAngle
        self.z = z
    }

    func update(dt: CGFloat, shipSpeed: CGFloat, playerAngle: Double) {
        guard !destroyed else { return }
        z -= shipSpeed * dt * 0.85
        var delta = playerAngle - lateralAngle
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        lateralAngle += delta * 0.6 * Double(dt)
        shootCooldown -= dt
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * Tunnel.shipRadialInset)
        return SCNVector3(
            r * Float(cos(lateralAngle)),
            r * Float(sin(lateralAngle)),
            Float(z)
        )
    }
}

// MARK: - Swarm alien (CA cluster + wall bounce)

final class SwarmAlien {
    var lateralAngle: Double
    var z: CGFloat
    var destroyed = false
    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double
    let bodyRadius: CGFloat = 0.28

    init(
        lateralAngle: Double,
        z: CGFloat,
        radialOffset: CGFloat = 0.7,
        radialVel: CGFloat = 0,
        angularVel: Double = 0
    ) {
        self.lateralAngle = lateralAngle
        self.z = z
        self.radialOffset = radialOffset
        self.radialVel = radialVel
        self.angularVel = angularVel
    }

    func update(dt: CGFloat, shipSpeed: CGFloat, playerAngle: Double) {
        guard !destroyed else { return }
        z -= shipSpeed * dt

        // Seek player in angle
        var delta = playerAngle - lateralAngle
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        angularVel += delta * 1.1 * Double(dt)
        angularVel *= 0.94
        lateralAngle += angularVel * Double(dt)

        // Mild radial wander + bounce
        radialVel += CGFloat.random(in: -0.15...0.15) * dt
        TubePhysics.integrateRadial(
            radialOffset: &radialOffset,
            radialVel: &radialVel,
            entityRadius: bodyRadius,
            dt: dt
        )
        radialVel *= 0.99
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * radialOffset)
        return SCNVector3(
            r * Float(cos(lateralAngle)),
            r * Float(sin(lateralAngle)),
            Float(z)
        )
    }
}

// MARK: - Flock alien (boid-ish + wall bounce)

final class FlockAlien {
    var lateralAngle: Double
    var z: CGFloat
    var destroyed = false
    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double
    let bodyRadius: CGFloat = 0.2

    init(
        lateralAngle: Double,
        z: CGFloat,
        radialOffset: CGFloat = 0.65,
        radialVel: CGFloat = 0,
        angularVel: Double = 0
    ) {
        self.lateralAngle = lateralAngle
        self.z = z
        self.radialOffset = radialOffset
        self.radialVel = radialVel
        self.angularVel = angularVel
    }

    func update(dt: CGFloat, shipSpeed: CGFloat, playerAngle: Double, neighbors: [FlockAlien]) {
        guard !destroyed else { return }
        z -= shipSpeed * dt * 1.05

        var sep: Double = 0
        var cohesionAngle = 0.0
        var cohesionRadial: CGFloat = 0
        var count = 0

        for other in neighbors where other !== self && !other.destroyed {
            var d = lateralAngle - other.lateralAngle
            while d > .pi { d -= 2 * .pi }
            while d < -.pi { d += 2 * .pi }
            let angDist = abs(d)
            if angDist < 0.4 && abs(z - other.z) < 8 {
                if angDist < 0.22 {
                    sep += d > 0 ? 1.2 : -1.2
                }
                cohesionAngle += other.lateralAngle
                cohesionRadial += other.radialOffset
                count += 1
            }
        }

        var seek = playerAngle - lateralAngle
        while seek > .pi { seek -= 2 * .pi }
        while seek < -.pi { seek += 2 * .pi }

        angularVel += (sep * 0.55 + seek * 0.35) * Double(dt)
        if count > 0 {
            var avg = cohesionAngle / Double(count)
            var toCenter = avg - lateralAngle
            while toCenter > .pi { toCenter -= 2 * .pi }
            while toCenter < -.pi { toCenter += 2 * .pi }
            angularVel += toCenter * 0.25 * Double(dt)

            let avgR = cohesionRadial / CGFloat(count)
            radialVel += (avgR - radialOffset) * 0.4 * dt
        }

        angularVel *= 0.93
        lateralAngle += angularVel * Double(dt)

        TubePhysics.integrateRadial(
            radialOffset: &radialOffset,
            radialVel: &radialVel,
            entityRadius: bodyRadius,
            dt: dt
        )
        radialVel *= 0.985
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * radialOffset)
        return SCNVector3(
            r * Float(cos(lateralAngle)),
            r * Float(sin(lateralAngle)),
            Float(z)
        )
    }
}

// MARK: - Managers

final class SwarmManager {
    private(set) var aliens: [SwarmAlien] = []
    private var spawnClock: CGFloat = 0
    private let spawnInterval: CGFloat = 2.8
    private let maxPopulation = 28

    func reset() {
        aliens.removeAll()
        spawnClock = 0
    }

    func update(dt: CGFloat, shipSpeed: CGFloat, playerAngle: Double, progress: CGFloat) {
        spawnClock += dt
        if spawnClock >= spawnInterval && aliens.count < maxPopulation {
            spawnClock = 0
            spawnWave()
        }
        for a in aliens where !a.destroyed {
            a.update(dt: dt, shipSpeed: shipSpeed, playerAngle: playerAngle)
        }
        aliens.removeAll { $0.destroyed || $0.z < -4 }
    }

    private func spawnWave() {
        let count = Int.random(in: 4...8)
        let baseZ = CGFloat.random(in: 45...70)
        let baseAngle = Double.random(in: 0..<(2 * .pi))
        for i in 0..<count {
            let angle = baseAngle + Double(i) * 0.22 + Double.random(in: -0.08...0.08)
            aliens.append(SwarmAlien(
                lateralAngle: angle,
                z: baseZ + CGFloat.random(in: -4...8),
                radialOffset: CGFloat.random(in: 0.45...0.8),
                radialVel: CGFloat.random(in: -0.4...0.4),
                angularVel: Double.random(in: -0.3...0.3)
            ))
        }
    }
}

final class FlockManager {
    private(set) var aliens: [FlockAlien] = []
    private var spawnClock: CGFloat = 0
    private let spawnInterval: CGFloat = 3.4
    private let maxPopulation = 16

    func reset() {
        aliens.removeAll()
        spawnClock = 0
    }

    func update(dt: CGFloat, shipSpeed: CGFloat, playerAngle: Double, progress: CGFloat) {
        spawnClock += dt
        if spawnClock >= spawnInterval && aliens.count < maxPopulation {
            spawnClock = 0
            spawnWave()
        }
        let living = aliens.filter { !$0.destroyed }
        for a in living {
            a.update(dt: dt, shipSpeed: shipSpeed, playerAngle: playerAngle, neighbors: living)
        }
        aliens.removeAll { $0.destroyed || $0.z < -4 }
    }

    private func spawnWave() {
        let count = Int.random(in: 5...9)
        let baseZ = CGFloat.random(in: 50...75)
        let baseAngle = Double.random(in: 0..<(2 * .pi))
        for i in 0..<count {
            aliens.append(FlockAlien(
                lateralAngle: baseAngle + Double(i) * 0.18,
                z: baseZ + CGFloat(i) * 1.2,
                radialOffset: CGFloat.random(in: 0.4...0.75),
                radialVel: CGFloat.random(in: -0.35...0.35),
                angularVel: Double.random(in: -0.4...0.4)
            ))
        }
    }
}

// MARK: - Game State

final class GameState: ObservableObject {
    var spaceShip = SpaceShip()
    var enemySpaceShip: EnemySpaceShip? = nil
    var asteroids: [Asteroid] = []
    var playerLasers: [Laser] = []
    var enemyLasers: [Laser] = []
    let swarmManager = SwarmManager()
    let flockManager = FlockManager()

    @Published var score = 0
    @Published var gameOver = false
    @Published var volume: Double = 1.0
    @Published private(set) var frameTick: Int = 0
    @Published private(set) var shieldActive = false

    // Cannon aim properties (Added)
    var cannonAzimuth: Double = 0 // left/right (relative to ship facing)
    var cannonElevation: Double = 0 // up/down, clamp e.g. -0.7...0.7 radians

    private var fireTimer: Timer?
    private var isFiring = false

    var joystickVector: CGVector = .zero

    private var gameTimer: Timer?
    private var shieldTimer: Timer?
    private var enemySpawnTimer: Timer?
    private var asteroidSpawnClock: CGFloat = 0
    private let asteroidSpawnInterval: CGFloat = 1.1
    private let dt: CGFloat = 1.0 / 60.0

    static let shieldDuration: TimeInterval = 2.0

    func start() {
        guard gameTimer == nil else { return }
        startGameLoop()
        scheduleEnemy()
    }

    private func startGameLoop() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }
    func shootLaser() {
        guard !gameOver else { return }

        // Cone height is 0.9, tip points +Z → nose is ~0.45–0.55 in front of ship center
        let noseZ: CGFloat = 0.55

        playerLasers.append(Laser(
            lateralAngle: spaceShip.lateralAngle + cannonAzimuth,
            elevationAngle: cannonElevation,
            z: noseZ,
            isPlayerLaser: true
        ))
    }

    /// Begin rapid fire (long-press / hold). First shot is immediate.
    func startFiring() {
        guard !gameOver else { return }
        if isFiring { return }
        isFiring = true
        shootLaser()
        fireTimer?.invalidate()
        fireTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            guard let self = self, self.isFiring, !self.gameOver else {
                self?.fireTimer?.invalidate()
                return
            }
            self.shootLaser()
        }
    }

    func stopFiring() {
        isFiring = false
        fireTimer?.invalidate()
        fireTimer = nil
    }
    private func scheduleEnemy() {
        enemySpaceShip = nil
        enemySpawnTimer?.invalidate()
        enemySpawnTimer = Timer.scheduledTimer(withTimeInterval: 12.0, repeats: false) { [weak self] _ in
            guard let self = self, !self.gameOver else { return }
            self.enemySpaceShip = EnemySpaceShip(
                lateralAngle: Double.random(in: 0..<(2 * .pi)),
                z: 55
            )
        }
    }

    private func tick() {
        guard !gameOver else { return }

        let deadzone: CGFloat = 0.12
        let rawX = joystickVector.dx
        spaceShip.lateralInput = abs(rawX) > deadzone ? Double(max(-1, min(1, rawX))) : 0
        let rawY = -joystickVector.dy
        spaceShip.speedInput = abs(rawY) > deadzone ? Double(max(-1, min(1, rawY))) : 0

        spaceShip.update(dt: dt)

        asteroidSpawnClock += dt
        if asteroidSpawnClock >= asteroidSpawnInterval {
            asteroidSpawnClock = 0
            spawnAsteroid()
        }
        for a in asteroids {
            a.update(dt: dt, shipSpeed: spaceShip.forwardSpeed)
        }
        asteroids.removeAll { $0.z < -5 }

        if let enemy = enemySpaceShip, !enemy.destroyed {
            enemy.update(dt: dt, shipSpeed: spaceShip.forwardSpeed, playerAngle: spaceShip.lateralAngle)
            if enemy.shootCooldown <= 0 {
                enemy.shootCooldown = CGFloat.random(in: 1.0...2.2)
                enemyLasers.append(Laser(
                    lateralAngle: enemy.lateralAngle,
                    z: enemy.z - 1.5,
                    isPlayerLaser: false
                ))
            }
            if enemy.z < -6 {
                enemySpaceShip = nil
                scheduleEnemy()
            }
        }

        swarmManager.update(
            dt: dt,
            shipSpeed: spaceShip.forwardSpeed,
            playerAngle: spaceShip.lateralAngle,
            progress: spaceShip.progress
        )
        flockManager.update(
            dt: dt,
            shipSpeed: spaceShip.forwardSpeed,
            playerAngle: spaceShip.lateralAngle,
            progress: spaceShip.progress
        )

        for i in playerLasers.indices {
            playerLasers[i].update(dt: dt, shipSpeed: spaceShip.forwardSpeed)
        }
        for i in enemyLasers.indices {
            enemyLasers[i].update(dt: dt, shipSpeed: spaceShip.forwardSpeed)
        }
        playerLasers.removeAll { $0.z > 90 || $0.z < -5 }
        enemyLasers.removeAll { $0.z < -5 || $0.z > 90 }

        checkCollisions()
        if checkShipCollision() {
            gameOver = true
        }

        if Int(spaceShip.progress) % 10 == 0 && frameTick % 60 == 0 {
            score += 1
        }

        frameTick &+= 1
        
        if gameOver {
            stopFiring()
            return
        }
    }

    private func spawnAsteroid() {
        let size: AsteroidSize = {
            let r = Double.random(in: 0...1)
            if r < 0.45 { return .small }
            if r < 0.8 { return .medium }
            return .large
        }()
        // Leave room so large rocks don't spawn already intersecting the wall
        let maxR = max(Tunnel.minRadialOffset, 1.0 - size.radius / Tunnel.radius - 0.05)
        asteroids.append(Asteroid(
            lateralAngle: Double.random(in: 0..<(2 * .pi)),
            z: CGFloat.random(in: 40...80),
            size: size,
            radialOffset: CGFloat.random(in: Tunnel.minRadialOffset...maxR),
            radialVel: CGFloat.random(in: -0.9...0.9),
            angularVel: Double.random(in: -0.6...0.6)
        ))
    }


    func activateShield() {
        guard !gameOver, !shieldActive else { return }
        shieldActive = true
        shieldTimer?.invalidate()
        shieldTimer = Timer.scheduledTimer(withTimeInterval: GameState.shieldDuration, repeats: false) { [weak self] _ in
            self?.shieldActive = false
        }
    }

    private func angularDistance(_ a: Double, _ b: Double) -> Double {
        var d = abs(a - b)
        while d > .pi { d = abs(d - 2 * .pi) }
        return d
    }

    private func hits(
        angleA: Double, zA: CGFloat,
        angleB: Double, zB: CGFloat,
        angleTol: Double = 0.28,
        zTol: CGFloat = 1.4
    ) -> Bool {
        abs(zA - zB) < zTol && angularDistance(angleA, angleB) < angleTol
    }

    private func checkCollisions() {
        var removePlayerLaser = Set<Int>()
        var removeEnemyLaser = Set<Int>()
        var removeAsteroid = Set<Int>()
        var addAsteroids: [Asteroid] = []

        for (li, laser) in playerLasers.enumerated() {
            for (ai, asteroid) in asteroids.enumerated() {
                if hits(
                    angleA: laser.lateralAngle, zA: laser.z,
                    angleB: asteroid.lateralAngle, zB: asteroid.z,
                    angleTol: 0.35, zTol: 1.6
                ) {
                    removePlayerLaser.insert(li)
                    removeAsteroid.insert(ai)
                    score += asteroid.size.score
                    if asteroid.size == .large {
                        for _ in 0..<2 {
                            addAsteroids.append(Asteroid(
                                lateralAngle: asteroid.lateralAngle + Double.random(in: -0.3...0.3),
                                z: asteroid.z,
                                size: .small,
                                radialOffset: asteroid.radialOffset,
                                radialVel: CGFloat.random(in: -0.8...0.8),
                                angularVel: Double.random(in: -0.8...0.8)
                            ))
                        }
                    }
                    break
                }
            }

            if let enemy = enemySpaceShip, !enemy.destroyed,
               hits(angleA: laser.lateralAngle, zA: laser.z,
                    angleB: enemy.lateralAngle, zB: enemy.z,
                    angleTol: 0.32, zTol: 1.8) {
                removePlayerLaser.insert(li)
                enemy.destroyed = true
                score += 500
                enemySpaceShip = nil
                scheduleEnemy()
            }

            for alien in swarmManager.aliens where !alien.destroyed {
                if hits(angleA: laser.lateralAngle, zA: laser.z,
                        angleB: alien.lateralAngle, zB: alien.z,
                        angleTol: 0.3, zTol: 1.5) {
                    removePlayerLaser.insert(li)
                    alien.destroyed = true
                    score += 75
                    break
                }
            }
            for alien in flockManager.aliens where !alien.destroyed {
                if hits(angleA: laser.lateralAngle, zA: laser.z,
                        angleB: alien.lateralAngle, zB: alien.z,
                        angleTol: 0.3, zTol: 1.5) {
                    removePlayerLaser.insert(li)
                    alien.destroyed = true
                    score += 60
                    break
                }
            }
        }

        for (li, laser) in enemyLasers.enumerated() {
            if hits(angleA: laser.lateralAngle, zA: laser.z,
                    angleB: spaceShip.lateralAngle, zB: 0,
                    angleTol: 0.3, zTol: 1.4) {
                removeEnemyLaser.insert(li)
                if !shieldActive { gameOver = true }
            }
        }

        playerLasers = playerLasers.enumerated().filter { !removePlayerLaser.contains($0.offset) }.map(\.element)
        enemyLasers = enemyLasers.enumerated().filter { !removeEnemyLaser.contains($0.offset) }.map(\.element)
        asteroids = asteroids.enumerated().filter { !removeAsteroid.contains($0.offset) }.map(\.element)
        asteroids.append(contentsOf: addAsteroids)
    }

    private func checkShipCollision() -> Bool {
        let sa = spaceShip.lateralAngle
        for asteroid in asteroids {
            if hits(angleA: sa, zA: 0, angleB: asteroid.lateralAngle, zB: asteroid.z,
                    angleTol: 0.32, zTol: 1.5) {
                if shieldActive { continue }
                return true
            }
        }
        if let enemy = enemySpaceShip, !enemy.destroyed,
           hits(angleA: sa, zA: 0, angleB: enemy.lateralAngle, zB: enemy.z,
                angleTol: 0.3, zTol: 1.6), !shieldActive {
            return true
        }
        for alien in swarmManager.aliens where !alien.destroyed {
            if hits(angleA: sa, zA: 0, angleB: alien.lateralAngle, zB: alien.z,
                    angleTol: 0.28, zTol: 1.3) {
                if shieldActive { alien.destroyed = true; continue }
                return true
            }
        }
        for alien in flockManager.aliens where !alien.destroyed {
            if hits(angleA: sa, zA: 0, angleB: alien.lateralAngle, zB: alien.z,
                    angleTol: 0.28, zTol: 1.3) {
                if shieldActive { alien.destroyed = true; continue }
                return true
            }
        }
        return false
    }

    func restart() {
        spaceShip = SpaceShip()
        enemySpaceShip = nil
        asteroids.removeAll()
        playerLasers.removeAll()
        enemyLasers.removeAll()
        swarmManager.reset()
        flockManager.reset()
        score = 0
        gameOver = false
        shieldActive = false
        shieldTimer?.invalidate()
        asteroidSpawnClock = 0
        scheduleEnemy()
    }

    func stopAll() {
        gameTimer?.invalidate()
        gameTimer = nil
        shieldTimer?.invalidate()
        enemySpawnTimer?.invalidate()
    }
}

// MARK: - SceneKit World

final class SceneWorld {
    let scene = SCNScene()
    let camera = SCNNode()

    private let shipRoot = SCNNode()
    private let shipMesh = SCNNode()
    private let thrusterFlame = SCNNode()
    private let shieldNode = SCNNode()
    private let enemyRoot = SCNNode()
    private let tubeContainer = SCNNode()
    private let asteroidContainer = SCNNode()
    private let alienContainer = SCNNode()
    private let flockContainer = SCNNode()
    private let laserContainer = SCNNode()

    private let cannonNode = SCNNode() // Added cannon node

    private var tubeSegments: [SCNNode] = []
    private var asteroidNodes: [ObjectIdentifier: SCNNode] = [:]
    private var alienNodes: [ObjectIdentifier: SCNNode] = [:]
    private var flockNodes: [ObjectIdentifier: SCNNode] = [:]

    init() {
        scene.background.contents = UIColor.black
        scene.fogColor = UIColor(red: 0.02, green: 0.02, blue: 0.06, alpha: 1)
        scene.fogStartDistance = 25
        scene.fogEndDistance = 95
        setupLighting()
        setupTube()
        setupCamera()
        setupShip()
        setupEnemy()
        scene.rootNode.addChildNode(tubeContainer)
        scene.rootNode.addChildNode(asteroidContainer)
        scene.rootNode.addChildNode(alienContainer)
        scene.rootNode.addChildNode(flockContainer)
        scene.rootNode.addChildNode(laserContainer)
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

    private func setupTube() {
        let total = Tunnel.segmentsBehind + Tunnel.segmentsAhead
        for i in 0..<total {
            let node = makeTubeSegment()
            let z = CGFloat(i - Tunnel.segmentsBehind) * Tunnel.segmentLength
            node.position = SCNVector3(0, 0, Float(z + Tunnel.segmentLength * 0.5))
            tubeContainer.addChildNode(node)
            tubeSegments.append(node)
        }
    }

    private func makeTubeSegment() -> SCNNode {
        let geo = SCNTube(
            innerRadius: CGFloat(Tunnel.radius) - 0.08,
            outerRadius: CGFloat(Tunnel.radius),
            height: Tunnel.segmentLength
        )
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
        cam.zNear = 0.1
        cam.zFar = 200
        cam.fieldOfView = 72
        camera.camera = cam
        camera.position = SCNVector3(0, 0.3, -2.8)
        camera.eulerAngles.y = .pi
        scene.rootNode.addChildNode(camera)
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

        // Setup cannon node
        let cannonGeo = SCNCone(topRadius: 0, bottomRadius: 0.12, height: 0.48)
        cannonGeo.firstMaterial?.diffuse.contents = UIColor.red
        cannonGeo.firstMaterial?.emission.contents = UIColor.red
        cannonNode.geometry = cannonGeo
        cannonNode.eulerAngles.x = .pi / 2
        cannonNode.position = SCNVector3(0, 0, 0.45) // tip in front of ship mesh
        shipRoot.addChildNode(cannonNode)

        scene.rootNode.addChildNode(shipRoot)
    }

    private func setupEnemy() {
        let geo = SCNCone(topRadius: 0, bottomRadius: 0.32, height: 1.0)
        geo.firstMaterial?.diffuse.contents = UIColor.red
        geo.firstMaterial?.emission.contents = UIColor(red: 0.35, green: 0, blue: 0, alpha: 1)
        enemyRoot.geometry = geo
        enemyRoot.eulerAngles.x = .pi / 2
        enemyRoot.isHidden = true
        scene.rootNode.addChildNode(enemyRoot)
    }

    func sync(with game: GameState) {
        let progress = game.spaceShip.progress
        let segmentShift = progress.truncatingRemainder(dividingBy: Tunnel.segmentLength)
        for (i, node) in tubeSegments.enumerated() {
            let baseIndex = i - Tunnel.segmentsBehind
            let z = CGFloat(baseIndex) * Tunnel.segmentLength - segmentShift + Tunnel.segmentLength * 0.5
            node.position.z = Float(z)
        }

        let shipPos = game.spaceShip.position
        shipRoot.position = shipPos
        shipRoot.eulerAngles.z = Float(game.spaceShip.lateralAngle)
        thrusterFlame.isHidden = game.spaceShip.forwardSpeed < Tunnel.defaultSpeed + 0.5
        thrusterFlame.scale = SCNVector3(1, 1, Float(min(1.6, game.spaceShip.forwardSpeed / Tunnel.defaultSpeed)))
        shieldNode.isHidden = !game.shieldActive

        camera.eulerAngles.z = Float(game.spaceShip.lateralInput) * 0.12
        camera.position.x = shipPos.x * 0.15
        camera.position.y = shipPos.y * 0.15 + 0.25

        // Update cannon orientation based on cannonAzimuth and cannonElevation + ship lateralAngle
        cannonNode.eulerAngles.z = Float(game.cannonAzimuth + game.spaceShip.lateralAngle)
        cannonNode.eulerAngles.y = Float(game.cannonElevation)

        if let enemy = game.enemySpaceShip, !enemy.destroyed {
            enemyRoot.isHidden = false
            enemyRoot.position = enemy.position
            enemyRoot.eulerAngles.z = Float(enemy.lateralAngle)
        } else {
            enemyRoot.isHidden = true
        }

        var seenA = Set<ObjectIdentifier>()
        for asteroid in game.asteroids {
            let id = ObjectIdentifier(asteroid)
            seenA.insert(id)
            let node: SCNNode
            if let existing = asteroidNodes[id] {
                node = existing
            } else {
                let geo = SCNSphere(radius: asteroid.size.radius)
                geo.firstMaterial?.diffuse.contents = UIColor.darkGray
                geo.firstMaterial?.emission.contents = UIColor(white: 0.1, alpha: 1)
                node = SCNNode(geometry: geo)
                asteroidContainer.addChildNode(node)
                asteroidNodes[id] = node
            }
            node.position = asteroid.position
            node.eulerAngles.y = asteroid.spin
        }
        for (id, node) in asteroidNodes where !seenA.contains(id) {
            node.removeFromParentNode()
            asteroidNodes.removeValue(forKey: id)
        }

        var seenS = Set<ObjectIdentifier>()
        for alien in game.swarmManager.aliens where !alien.destroyed {
            let id = ObjectIdentifier(alien)
            seenS.insert(id)
            let node: SCNNode
            if let existing = alienNodes[id] {
                node = existing
            } else {
                let geo = SCNSphere(radius: 0.28)
                geo.firstMaterial?.diffuse.contents = UIColor.purple
                geo.firstMaterial?.emission.contents = UIColor(red: 0.5, green: 0, blue: 0.65, alpha: 1)
                node = SCNNode(geometry: geo)
                alienContainer.addChildNode(node)
                alienNodes[id] = node
            }
            node.position = alien.position
        }
        for (id, node) in alienNodes where !seenS.contains(id) {
            node.removeFromParentNode()
            alienNodes.removeValue(forKey: id)
        }

        var seenF = Set<ObjectIdentifier>()
        for alien in game.flockManager.aliens where !alien.destroyed {
            let id = ObjectIdentifier(alien)
            seenF.insert(id)
            let node: SCNNode
            if let existing = flockNodes[id] {
                node = existing
            } else {
                let geo = SCNCone(topRadius: 0, bottomRadius: 0.14, height: 0.4)
                geo.firstMaterial?.diffuse.contents = UIColor.orange
                geo.firstMaterial?.emission.contents = UIColor(red: 0.6, green: 0.3, blue: 0, alpha: 1)
                node = SCNNode(geometry: geo)
                node.eulerAngles.x = .pi / 2
                flockContainer.addChildNode(node)
                flockNodes[id] = node
            }
            node.position = alien.position
            node.eulerAngles.z = Float(alien.lateralAngle)
        }
        for (id, node) in flockNodes where !seenF.contains(id) {
            node.removeFromParentNode()
            flockNodes.removeValue(forKey: id)
        }

        laserContainer.childNodes.forEach { $0.removeFromParentNode() }
        for laser in game.playerLasers {
            laserContainer.addChildNode(makeLaserNode(laser, color: .green))
        }
        for laser in game.enemyLasers {
            laserContainer.addChildNode(makeLaserNode(laser, color: .red))
        }
    }

    private func makeLaserNode(_ laser: Laser, color: UIColor) -> SCNNode {
        let geo = SCNCylinder(radius: 0.06, height: 0.9)
        geo.firstMaterial?.diffuse.contents = color
        geo.firstMaterial?.emission.contents = color
        let node = SCNNode(geometry: geo)
        node.eulerAngles.x = .pi / 2
        node.position = laser.crossSectionPosition()
        return node
    }
}

// MARK: - SceneKit container

struct SceneKitContainerView: UIViewRepresentable {
    @ObservedObject var game: GameState

    func makeCoordinator() -> SceneWorld { SceneWorld() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = context.coordinator.scene
        view.pointOfView = context.coordinator.camera
        view.backgroundColor = .black
        view.antialiasingMode = .multisampling2X
        view.autoenablesDefaultLighting = false
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        context.coordinator.sync(with: game)
    }
}

// MARK: - Cockpit overlay

struct CockpitWindowOverlay: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                RadialGradient(
                    colors: [Color.clear, Color.black.opacity(0.55)],
                    center: .center,
                    startRadius: min(geo.size.width, geo.size.height) * 0.3,
                    endRadius: max(geo.size.width, geo.size.height) * 0.65
                )
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color(white: 0.3), Color.black, Color(white: 0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 22
                    )
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .ultraLight))
                    .foregroundColor(.white.opacity(0.28))
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - Radar

struct RadarMapView: View {
    @ObservedObject var game: GameState
    var mapSize: CGFloat = 120

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.55))
            Canvas { context, size in
                let maxZ: CGFloat = 70
                func map(angle: Double, z: CGFloat) -> CGPoint {
                    let x = CGFloat(angle / (2 * .pi)) * size.width
                    let y = size.height - (max(0, min(maxZ, z)) / maxZ) * size.height
                    return CGPoint(x: x, y: y)
                }
                for a in game.asteroids {
                    let p = map(angle: a.lateralAngle, z: a.z)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 2, y: p.y - 2, width: 4, height: 4)), with: .color(.gray))
                }
                for a in game.swarmManager.aliens where !a.destroyed {
                    let p = map(angle: a.lateralAngle, z: a.z)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)), with: .color(.purple))
                }
                for a in game.flockManager.aliens where !a.destroyed {
                    let p = map(angle: a.lateralAngle, z: a.z)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)), with: .color(.orange))
                }
                if let e = game.enemySpaceShip, !e.destroyed {
                    let p = map(angle: e.lateralAngle, z: e.z)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(.red))
                }
                let shipP = map(angle: game.spaceShip.lateralAngle, z: 0)
                context.fill(Path(ellipseIn: CGRect(x: shipP.x - 2.5, y: shipP.y - 2.5, width: 5, height: 5)), with: .color(.cyan))
            }
            .padding(4)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        }
        .frame(width: mapSize, height: mapSize * 0.85)
    }
}

// MARK: - Joystick

struct JoystickView: View {
    var diameter: CGFloat = 120
    var knobDiameter: CGFloat = 56
    var baseColor: Color = .white
    var onChange: (CGVector) -> Void
    var onEnd: () -> Void

    @State private var knobOffset: CGSize = .zero
    @State private var active = false

    var body: some View {
        ZStack {
            Circle()
                .fill(baseColor.opacity(0.12))
                .frame(width: diameter, height: diameter)
            Circle()
                .strokeBorder(baseColor.opacity(0.35), lineWidth: 2)
                .frame(width: diameter, height: diameter)
            Circle()
                .fill(baseColor.opacity(active ? 0.55 : 0.35))
                .frame(width: knobDiameter, height: knobDiameter)
                .offset(knobOffset)
        }
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    active = true
                    let maxDistance = (diameter - knobDiameter) / 2
                    var dx = value.translation.width
                    var dy = value.translation.height
                    let distance = sqrt(dx * dx + dy * dy)
                    if distance > maxDistance && distance > 0 {
                        dx = dx / distance * maxDistance
                        dy = dy / distance * maxDistance
                    }
                    knobOffset = CGSize(width: dx, height: dy)
                    onChange(CGVector(dx: dx / maxDistance, dy: dy / maxDistance))
                }
                .onEnded { _ in
                    active = false
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                        knobOffset = .zero
                    }
                    onChange(.zero)
                    onEnd()
                }
        )
    }
}

// MARK: - Volume

struct VolumeView: View {
    @Binding var volume: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Sound Volume").font(.headline)
            Slider(value: $volume, in: 0...1).padding(.horizontal)
            Text("Volume: \(Int(volume * 100))%").foregroundColor(.secondary)
            Button("Close") { dismiss() }.padding(.top, 8)
        }
        .padding()
        .presentationDetents([.height(220)])
    }
}

// MARK: - Content View

struct ContentView: View {
    @StateObject private var game = GameState()
    @State private var showVolumeDialog = false

    // Added cannon joystick state
    @State private var showCannonJoystick = false
    @State private var cannonJoystickVector = CGVector.zero

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color.black.ignoresSafeArea()

                SceneKitContainerView(game: game)
                    .ignoresSafeArea()
                    .onAppear { game.start() }
                    .onDisappear { game.stopAll() }

                CockpitWindowOverlay()

                if game.gameOver {
                    VStack(spacing: 16) {
                        Text("Game Over")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.red)
                        Text("Score: \(game.score)")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                        Button("Restart") { game.restart() }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                }

                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tube Runner")
                                .foregroundColor(.white)
                                .font(.system(size: 16, weight: .semibold))
                            Text("Stick: left/right slide · up/down speed")
                                .foregroundColor(.white.opacity(0.9))
                                .font(.system(size: 12))
                            Text("Hold Fire to rapid-fire · Shield 2s")
                                .foregroundColor(.cyan)
                                .font(.system(size: 12, weight: .bold))
                            Text("Purple = swarm · Orange = flock")
                                .foregroundColor(.white.opacity(0.65))
                                .font(.system(size: 11))
                            Text(String(format: "Speed %.1f  Dist %.0f", game.spaceShip.forwardSpeed, game.spaceShip.progress))
                                .foregroundColor(.orange)
                                .font(.system(size: 12, weight: .medium))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            Button(action: { showVolumeDialog = true }) {
                                Image(systemName: "speaker.wave.2.fill")
                                    .foregroundColor(.white)
                                    .font(.system(size: 22))
                            }
                            RadarMapView(game: game)
                        }
                    }
                    .padding()
                    Spacer()
                }

                VStack {
                    Spacer()
                    HStack(alignment: .bottom) {
                        JoystickView(baseColor: .blue, onChange: { v in
                            game.joystickVector = v
                        }, onEnd: {
                            game.joystickVector = .zero
                        })
                        .padding(.leading, 28)

                        Spacer()

                        Text("Score: \(game.score)")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)

                        Spacer()

                        VStack(spacing: 14) {
                            // FIRE — tap = one shot, hold = rapid fire
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.35))
                                    .frame(width: 64, height: 64)
                                Circle()
                                    .strokeBorder(Color.red.opacity(0.85), lineWidth: 2)
                                    .frame(width: 64, height: 64)
                                Text("FIRE")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)

                                // Cannon joystick shown above fire button when active
                                if showCannonJoystick {
                                    JoystickView(
                                        diameter: 100,
                                        knobDiameter: 40,
                                        baseColor: .red,
                                        onChange: { v in
                                            cannonJoystickVector = v
                                        },
                                        onEnd: {
                                            cannonJoystickVector = .zero
                                        }
                                    )
                                    .frame(width: 100, height: 100)
                                    .offset(x: 0, y: -130)
                                    .zIndex(2)
                                }
                            }
                            .contentShape(Circle())
                            .gesture(
                                DragGesture(minimumDistance: 0)
                                    .onChanged { _ in
                                        if !showCannonJoystick {
                                            showCannonJoystick = true
                                        }
                                    }
                                    .onEnded { _ in
                                        showCannonJoystick = false
                                        game.shootLaser()
                                    }
                            )

                            Button(action: { game.activateShield() }) {
                                ZStack {
                                    Circle()
                                        .fill(Color.cyan.opacity(game.shieldActive ? 0.5 : 0.25))
                                        .frame(width: 52, height: 52)
                                    Circle()
                                        .strokeBorder(Color.cyan.opacity(0.7), lineWidth: 2)
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "shield.fill")
                                        .foregroundColor(.cyan)
                                        .font(.system(size: 20))
                                }
                            }
                            .disabled(game.shieldActive)
                        }
                        .padding(.trailing, 28)
                    }
                    .padding(.bottom, 40)
                }
            }
            // Update cannon aiming based on joystick vector changes
            .onChange(of: cannonJoystickVector) { v in
                game.cannonAzimuth = Double(v.dx) * 0.8 // limit turn left/right
                game.cannonElevation = max(-0.7, min(0.7, Double(-v.dy) * 0.7)) // up/down clamp (-0.7 to 0.7 rad)
            }
        }
        .sheet(isPresented: $showVolumeDialog) {
            VolumeView(volume: $game.volume)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
}

#Preview {
    ContentView()
}
