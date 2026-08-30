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
// • Blue stick: lateral + speed
// • Red stick: aim cannon + HOLD to rapid-fire
// • Swarm = alien squid · Flock = deep-ocean alien fish
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
    static let minRadialOffset: CGFloat = 0.18
    static let wallRestitution: CGFloat = 0.72
}

// MARK: - Tube physics

private enum TubePhysics {
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
            if radialVel > 0 { radialVel = -radialVel * Tunnel.wallRestitution }
        } else if radialOffset <= minOffset {
            radialOffset = minOffset
            if radialVel < 0 { radialVel = -radialVel * Tunnel.wallRestitution }
        }
    }

    static func dampAgainstWall(radialOffset: CGFloat, radialVel: inout CGFloat, entityRadius: CGFloat) {
        let maxOffset = max(Tunnel.minRadialOffset, 1.0 - entityRadius / Tunnel.radius)
        if radialOffset >= maxOffset - 0.02 && radialVel > 0 { radialVel *= 0.5 }
    }
}

// MARK: - Asteroid size

enum AsteroidSize {
    case small, medium, large
    var radius: CGFloat {
        switch self {
        case .small: return 0.55
        case .medium: return 0.85
        case .large: return 1.25
        }
    }
    var score: Int {
        switch self {
        case .small: return 50
        case .medium: return 75
        case .large: return 100
        }
    }
}

// MARK: - Laser

struct Laser {
    var lateralAngle: Double
    var elevationAngle: Double
    var z: CGFloat
    var radialOffset: CGFloat
    let isPlayerLaser: Bool
    static let speed: CGFloat = 28.0

    mutating func update(dt: CGFloat, shipSpeed: CGFloat) {
        if isPlayerLaser {
            z += Laser.speed * dt
            let radialSpeed = CGFloat(sin(elevationAngle)) * Laser.speed * 0.045
            radialOffset += radialSpeed * dt
            radialOffset = min(0.98, max(Tunnel.minRadialOffset, radialOffset))
        } else {
            z -= (Laser.speed + shipSpeed) * dt
        }
    }

    func worldPosition() -> SCNVector3 {
        let r = Float(Tunnel.radius * radialOffset)
        return SCNVector3(
            r * Float(cos(lateralAngle)),
            r * Float(sin(lateralAngle)),
            Float(z)
        )
    }
}

// MARK: - Asteroid

final class Asteroid {
    var lateralAngle: Double
    var z: CGFloat
    var size: AsteroidSize
    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double
    var spin: Float = 0

    init(lateralAngle: Double, z: CGFloat, size: AsteroidSize,
         radialOffset: CGFloat = 0.55, radialVel: CGFloat = 0, angularVel: Double = 0) {
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
        TubePhysics.integrateRadial(radialOffset: &radialOffset, radialVel: &radialVel,
                                    entityRadius: size.radius, dt: dt)
        TubePhysics.dampAgainstWall(radialOffset: radialOffset, radialVel: &radialVel,
                                    entityRadius: size.radius)
        angularVel *= 0.998
        radialVel *= 0.999
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * radialOffset)
        return SCNVector3(r * Float(cos(lateralAngle)), r * Float(sin(lateralAngle)), Float(z))
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
        let clamped = max(Tunnel.minSpeed, min(Tunnel.maxSpeed, target))
        let diff = clamped - forwardSpeed
        let step = Tunnel.speedAccel * dt
        if abs(diff) <= step { forwardSpeed = clamped }
        else { forwardSpeed += diff > 0 ? step : -step }
        progress += forwardSpeed * dt
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * Tunnel.shipRadialInset)
        return SCNVector3(r * Float(cos(lateralAngle)), r * Float(sin(lateralAngle)), 0)
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
        return SCNVector3(r * Float(cos(lateralAngle)), r * Float(sin(lateralAngle)), Float(z))
    }
}

// MARK: - Swarm = alien squid

final class SwarmAlien {
    var lateralAngle: Double
    var z: CGFloat
    var destroyed = false
    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double
    var animPhase: Float
    let bodyRadius: CGFloat = 0.32

    init(lateralAngle: Double, z: CGFloat, radialOffset: CGFloat = 0.7,
         radialVel: CGFloat = 0, angularVel: Double = 0) {
        self.lateralAngle = lateralAngle
        self.z = z
        self.radialOffset = radialOffset
        self.radialVel = radialVel
        self.angularVel = angularVel
        self.animPhase = Float.random(in: 0...(Float.pi * 2))
    }

    func update(dt: CGFloat, shipSpeed: CGFloat, playerAngle: Double) {
        guard !destroyed else { return }
        z -= shipSpeed * dt
        animPhase += Float(dt) * 4.5

        var delta = playerAngle - lateralAngle
        while delta > .pi { delta -= 2 * .pi }
        while delta < -.pi { delta += 2 * .pi }
        angularVel += delta * 1.1 * Double(dt)
        angularVel *= 0.94
        lateralAngle += angularVel * Double(dt)

        radialVel += CGFloat.random(in: -0.15...0.15) * dt
        TubePhysics.integrateRadial(radialOffset: &radialOffset, radialVel: &radialVel,
                                    entityRadius: bodyRadius, dt: dt)
        radialVel *= 0.99
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * radialOffset)
        return SCNVector3(r * Float(cos(lateralAngle)), r * Float(sin(lateralAngle)), Float(z))
    }
}

// MARK: - Flock = deep ocean alien fish

final class FlockAlien {
    var lateralAngle: Double
    var z: CGFloat
    var destroyed = false
    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double
    var animPhase: Float
    let bodyRadius: CGFloat = 0.22

    init(lateralAngle: Double, z: CGFloat, radialOffset: CGFloat = 0.65,
         radialVel: CGFloat = 0, angularVel: Double = 0) {
        self.lateralAngle = lateralAngle
        self.z = z
        self.radialOffset = radialOffset
        self.radialVel = radialVel
        self.angularVel = angularVel
        self.animPhase = Float.random(in: 0...(Float.pi * 2))
    }

    func update(dt: CGFloat, shipSpeed: CGFloat, playerAngle: Double, neighbors: [FlockAlien]) {
        guard !destroyed else { return }
        z -= shipSpeed * dt * 1.05
        animPhase += Float(dt) * 5.0

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
                if angDist < 0.22 { sep += d > 0 ? 1.2 : -1.2 }
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
            radialVel += (cohesionRadial / CGFloat(count) - radialOffset) * 0.4 * dt
        }

        angularVel *= 0.93
        lateralAngle += angularVel * Double(dt)
        TubePhysics.integrateRadial(radialOffset: &radialOffset, radialVel: &radialVel,
                                    entityRadius: bodyRadius, dt: dt)
        radialVel *= 0.985
    }

    var position: SCNVector3 {
        let r = Float(Tunnel.radius * radialOffset)
        return SCNVector3(r * Float(cos(lateralAngle)), r * Float(sin(lateralAngle)), Float(z))
    }
}

// MARK: - Managers

final class SwarmManager {
    private(set) var aliens: [SwarmAlien] = []
    private var spawnClock: CGFloat = 0
    private let spawnInterval: CGFloat = 2.8
    private let maxPopulation = 28

    func reset() { aliens.removeAll(); spawnClock = 0 }

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
            aliens.append(SwarmAlien(
                lateralAngle: baseAngle + Double(i) * 0.22 + Double.random(in: -0.08...0.08),
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

    func reset() { aliens.removeAll(); spawnClock = 0 }

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

// MARK: - Creature meshes (squid + fish)

enum CreatureMesh {
    /// Alien squid: mantle + glowing eye + trailing tentacles
    static func makeSquid() -> SCNNode {
        let root = SCNNode()

        // Mantle (head/body)
        let mantle = SCNSphere(radius: 0.22)
        mantle.segmentCount = 16
        mantle.firstMaterial?.diffuse.contents = UIColor(red: 0.45, green: 0.1, blue: 0.55, alpha: 1)
        mantle.firstMaterial?.emission.contents = UIColor(red: 0.35, green: 0.0, blue: 0.5, alpha: 1)
        let mantleNode = SCNNode(geometry: mantle)
        mantleNode.scale = SCNVector3(1.0, 1.15, 1.35)
        root.addChildNode(mantleNode)

        // Eye
        let eye = SCNSphere(radius: 0.07)
        eye.firstMaterial?.diffuse.contents = UIColor.cyan
        eye.firstMaterial?.emission.contents = UIColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1)
        let eyeNode = SCNNode(geometry: eye)
        eyeNode.position = SCNVector3(0, 0.06, 0.18)
        root.addChildNode(eyeNode)

        let pupil = SCNSphere(radius: 0.03)
        pupil.firstMaterial?.diffuse.contents = UIColor.black
        let pupilNode = SCNNode(geometry: pupil)
        pupilNode.position = SCNVector3(0, 0.06, 0.24)
        root.addChildNode(pupilNode)

        // Tentacles (behind body, along -Z)
        let tentacleCount = 6
        for i in 0..<tentacleCount {
            let angle = Float(i) / Float(tentacleCount) * Float.pi * 2
            let tent = SCNCylinder(radius: 0.035, height: 0.55)
            tent.firstMaterial?.diffuse.contents = UIColor(red: 0.55, green: 0.15, blue: 0.7, alpha: 1)
            tent.firstMaterial?.emission.contents = UIColor(red: 0.25, green: 0.0, blue: 0.4, alpha: 1)
            let tNode = SCNNode(geometry: tent)
            tNode.name = "tentacle_\(i)"
            tNode.eulerAngles.x = .pi / 2
            tNode.position = SCNVector3(
                cos(angle) * 0.1,
                sin(angle) * 0.1,
                -0.35
            )
            // Slight outward splay
            tNode.eulerAngles.y = angle * 0.15
            root.addChildNode(tNode)
        }

        // Face forward down the tube (+Z toward player when approaching? enemies come from +Z)
        // Body oriented so tentacles trail opposite travel (travel is -Z toward player)
        root.eulerAngles.x = 0
        return root
    }

    /// Deep-ocean alien fish: long body, fins, bioluminescent spots, forked tail
    static func makeDeepFish() -> SCNNode {
        let root = SCNNode()

        // Body
        let body = SCNCapsule(capRadius: 0.1, height: 0.55)
        body.firstMaterial?.diffuse.contents = UIColor(red: 0.05, green: 0.25, blue: 0.35, alpha: 1)
        body.firstMaterial?.emission.contents = UIColor(red: 0.0, green: 0.2, blue: 0.35, alpha: 1)
        let bodyNode = SCNNode(geometry: body)
        bodyNode.eulerAngles.z = .pi / 2 // long axis along Z
        bodyNode.eulerAngles.y = .pi / 2
        // Capsule height along Y; rotate so length is along Z
        bodyNode.eulerAngles = SCNVector3(Double.pi / 2, 0, 0)
        root.addChildNode(bodyNode)

        // Head bulb
        let head = SCNSphere(radius: 0.12)
        head.firstMaterial?.diffuse.contents = UIColor(red: 0.08, green: 0.3, blue: 0.4, alpha: 1)
        head.firstMaterial?.emission.contents = UIColor(red: 0.0, green: 0.35, blue: 0.45, alpha: 1)
        let headNode = SCNNode(geometry: head)
        headNode.position = SCNVector3(0, 0, 0.28)
        root.addChildNode(headNode)

        // Glowing lure (angler-style)
        let lureStem = SCNCylinder(radius: 0.015, height: 0.2)
        lureStem.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 0.4, blue: 0.5, alpha: 1)
        let stemNode = SCNNode(geometry: lureStem)
        stemNode.position = SCNVector3(0, 0.12, 0.32)
        stemNode.eulerAngles.x = -0.6
        root.addChildNode(stemNode)

        let lure = SCNSphere(radius: 0.045)
        lure.firstMaterial?.diffuse.contents = UIColor(red: 0.3, green: 1.0, blue: 0.7, alpha: 1)
        lure.firstMaterial?.emission.contents = UIColor(red: 0.2, green: 1.0, blue: 0.6, alpha: 1)
        let lureNode = SCNNode(geometry: lure)
        lureNode.name = "lure"
        lureNode.position = SCNVector3(0, 0.2, 0.38)
        root.addChildNode(lureNode)

        // Eyes
        let eyeMat = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1)
        for side: Float in [-1, 1] {
            let eye = SCNSphere(radius: 0.035)
            eye.firstMaterial?.diffuse.contents = eyeMat
            eye.firstMaterial?.emission.contents = eyeMat
            let e = SCNNode(geometry: eye)
            e.position = SCNVector3(side * 0.08, 0.04, 0.32)
            root.addChildNode(e)
        }

        // Side fins
        for side: Float in [-1, 1] {
            let fin = SCNCone(topRadius: 0, bottomRadius: 0.08, height: 0.22)
            fin.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 0.45, blue: 0.55, alpha: 1)
            fin.firstMaterial?.emission.contents = UIColor(red: 0.0, green: 0.25, blue: 0.35, alpha: 1)
            let f = SCNNode(geometry: fin)
            f.name = side < 0 ? "finL" : "finR"
            f.position = SCNVector3(side * 0.14, 0, 0)
            f.eulerAngles.z = side * 0.9
            f.eulerAngles.x = .pi / 2
            root.addChildNode(f)
        }

        // Tail (forked via two cones)
        for side: Float in [-1, 1] {
            let tail = SCNCone(topRadius: 0, bottomRadius: 0.07, height: 0.2)
            tail.firstMaterial?.diffuse.contents = UIColor(red: 0.1, green: 0.5, blue: 0.55, alpha: 1)
            let t = SCNNode(geometry: tail)
            t.name = "tail_\(side < 0 ? "L" : "R")"
            t.position = SCNVector3(side * 0.05, 0, -0.38)
            t.eulerAngles.x = .pi / 2
            t.eulerAngles.y = side * 0.45
            root.addChildNode(t)
        }

        // Bioluminescent spots
        for i in 0..<4 {
            let spot = SCNSphere(radius: 0.02)
            spot.firstMaterial?.emission.contents = UIColor(red: 0.2, green: 0.9, blue: 1.0, alpha: 1)
            spot.firstMaterial?.diffuse.contents = UIColor.cyan
            let s = SCNNode(geometry: spot)
            s.position = SCNVector3(0.06, 0, Float(i) * 0.1 - 0.1)
            root.addChildNode(s)
        }

        return root
    }

    static func animateSquid(_ node: SCNNode, phase: Float) {
        for child in node.childNodes {
            guard let name = child.name, name.hasPrefix("tentacle_") else { continue }
            let idx = Float(name.dropFirst("tentacle_".count)) ?? 0
            let wave = sin(phase + idx * 0.9) * 0.35
            child.eulerAngles.x = .pi / 2 + wave
            child.eulerAngles.z = wave * 0.4
        }
    }

    static func animateFish(_ node: SCNNode, phase: Float) {
        let sway = sin(phase) * 0.25
        if let finL = node.childNode(withName: "finL", recursively: false) {
            finL.eulerAngles.z = -0.9 + sway
        }
        if let finR = node.childNode(withName: "finR", recursively: false) {
            finR.eulerAngles.z = 0.9 - sway
        }
        for child in node.childNodes {
            if let name = child.name, name.hasPrefix("tail_") {
                child.eulerAngles.y = (name.hasSuffix("L") ? -0.45 : 0.45) + sway * 0.5
            }
        }
        if let lure = node.childNode(withName: "lure", recursively: false) {
            let pulse = 0.85 + 0.15 * sin(phase * 2)
            lure.scale = SCNVector3(pulse, pulse, pulse)
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

    var cannonAzimuth: Double = 0
    var cannonElevation: Double = 0
    var joystickVector: CGVector = .zero

    private var fireTimer: Timer?
    private var isFiring = false
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
        playerLasers.append(Laser(
            lateralAngle: spaceShip.lateralAngle + cannonAzimuth,
            elevationAngle: cannonElevation,
            z: 0.55,
            radialOffset: Tunnel.shipRadialInset,
            isPlayerLaser: true
        ))
    }

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
        guard !gameOver else { stopFiring(); return }

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
        for a in asteroids { a.update(dt: dt, shipSpeed: spaceShip.forwardSpeed) }
        asteroids.removeAll { $0.z < -5 }

        if let enemy = enemySpaceShip, !enemy.destroyed {
            enemy.update(dt: dt, shipSpeed: spaceShip.forwardSpeed, playerAngle: spaceShip.lateralAngle)
            if enemy.shootCooldown <= 0 {
                enemy.shootCooldown = CGFloat.random(in: 1.0...2.2)
                enemyLasers.append(Laser(
                    lateralAngle: enemy.lateralAngle,
                    elevationAngle: 0,
                    z: enemy.z - 1.5,
                    radialOffset: Tunnel.shipRadialInset,
                    isPlayerLaser: false
                ))
            }
            if enemy.z < -6 {
                enemySpaceShip = nil
                scheduleEnemy()
            }
        }

        swarmManager.update(dt: dt, shipSpeed: spaceShip.forwardSpeed,
                            playerAngle: spaceShip.lateralAngle, progress: spaceShip.progress)
        flockManager.update(dt: dt, shipSpeed: spaceShip.forwardSpeed,
                            playerAngle: spaceShip.lateralAngle, progress: spaceShip.progress)

        for i in playerLasers.indices { playerLasers[i].update(dt: dt, shipSpeed: spaceShip.forwardSpeed) }
        for i in enemyLasers.indices { enemyLasers[i].update(dt: dt, shipSpeed: spaceShip.forwardSpeed) }
        playerLasers.removeAll { $0.z > 90 || $0.z < -5 }
        enemyLasers.removeAll { $0.z < -5 || $0.z > 90 }

        checkCollisions()
        if checkShipCollision() {
            gameOver = true
            stopFiring()
        }

        if Int(spaceShip.progress) % 10 == 0 && frameTick % 60 == 0 { score += 1 }
        frameTick &+= 1
    }

    private func spawnAsteroid() {
        let size: AsteroidSize = {
            let r = Double.random(in: 0...1)
            if r < 0.45 { return .small }
            if r < 0.8 { return .medium }
            return .large
        }()
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

    private func laserHits(laser: Laser, entityAngle: Double, entityZ: CGFloat, entityRadial: CGFloat,
                           angleTol: Double = 0.32, zTol: CGFloat = 1.6, radialTol: CGFloat = 0.25) -> Bool {
        abs(laser.z - entityZ) < zTol
            && angularDistance(laser.lateralAngle, entityAngle) < angleTol
            && abs(laser.radialOffset - entityRadial) < radialTol
    }

    private func hits(angleA: Double, zA: CGFloat, angleB: Double, zB: CGFloat,
                      angleTol: Double = 0.28, zTol: CGFloat = 1.4) -> Bool {
        abs(zA - zB) < zTol && angularDistance(angleA, angleB) < angleTol
    }

    private func checkCollisions() {
        var removePlayerLaser = Set<Int>()
        var removeEnemyLaser = Set<Int>()
        var removeAsteroid = Set<Int>()
        var addAsteroids: [Asteroid] = []

        for (li, laser) in playerLasers.enumerated() {
            for (ai, asteroid) in asteroids.enumerated() {
                if laserHits(laser: laser, entityAngle: asteroid.lateralAngle,
                             entityZ: asteroid.z, entityRadial: asteroid.radialOffset,
                             angleTol: 0.35, zTol: 1.6, radialTol: 0.28) {
                    removePlayerLaser.insert(li)
                    removeAsteroid.insert(ai)
                    score += asteroid.size.score
                    if asteroid.size == .large {
                        for _ in 0..<2 {
                            addAsteroids.append(Asteroid(
                                lateralAngle: asteroid.lateralAngle + Double.random(in: -0.3...0.3),
                                z: asteroid.z, size: .small, radialOffset: asteroid.radialOffset,
                                radialVel: CGFloat.random(in: -0.8...0.8),
                                angularVel: Double.random(in: -0.8...0.8)
                            ))
                        }
                    }
                    break
                }
            }
            if let enemy = enemySpaceShip, !enemy.destroyed,
               laserHits(laser: laser, entityAngle: enemy.lateralAngle, entityZ: enemy.z,
                         entityRadial: Tunnel.shipRadialInset, angleTol: 0.32, zTol: 1.8, radialTol: 0.3) {
                removePlayerLaser.insert(li)
                enemy.destroyed = true
                score += 500
                enemySpaceShip = nil
                scheduleEnemy()
            }
            for alien in swarmManager.aliens where !alien.destroyed {
                if laserHits(laser: laser, entityAngle: alien.lateralAngle, entityZ: alien.z,
                             entityRadial: alien.radialOffset) {
                    removePlayerLaser.insert(li)
                    alien.destroyed = true
                    score += 75
                    break
                }
            }
            for alien in flockManager.aliens where !alien.destroyed {
                if laserHits(laser: laser, entityAngle: alien.lateralAngle, entityZ: alien.z,
                             entityRadial: alien.radialOffset) {
                    removePlayerLaser.insert(li)
                    alien.destroyed = true
                    score += 60
                    break
                }
            }
        }

        for (li, laser) in enemyLasers.enumerated() {
            if hits(angleA: laser.lateralAngle, zA: laser.z,
                    angleB: spaceShip.lateralAngle, zB: 0, angleTol: 0.3, zTol: 1.4) {
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
            if hits(angleA: sa, zA: 0, angleB: asteroid.lateralAngle, zB: asteroid.z, angleTol: 0.32, zTol: 1.5) {
                if shieldActive { continue }
                return true
            }
        }
        if let enemy = enemySpaceShip, !enemy.destroyed,
           hits(angleA: sa, zA: 0, angleB: enemy.lateralAngle, zB: enemy.z, angleTol: 0.3, zTol: 1.6), !shieldActive {
            return true
        }
        for alien in swarmManager.aliens where !alien.destroyed {
            if hits(angleA: sa, zA: 0, angleB: alien.lateralAngle, zB: alien.z, angleTol: 0.28, zTol: 1.3) {
                if shieldActive { alien.destroyed = true; continue }
                return true
            }
        }
        for alien in flockManager.aliens where !alien.destroyed {
            if hits(angleA: sa, zA: 0, angleB: alien.lateralAngle, zB: alien.z, angleTol: 0.28, zTol: 1.3) {
                if shieldActive { alien.destroyed = true; continue }
                return true
            }
        }
        return false
    }

    func restart() {
        stopFiring()
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
        cannonAzimuth = 0
        cannonElevation = 0
        scheduleEnemy()
    }

    func stopAll() {
        stopFiring()
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
    private let cannonNode = SCNNode()
    private let enemyRoot = SCNNode()
    private let tubeContainer = SCNNode()
    private let asteroidContainer = SCNNode()
    private let alienContainer = SCNNode()
    private let flockContainer = SCNNode()
    private let laserContainer = SCNNode()

    private var tubeSegments: [SCNNode] = []
    private var asteroidNodes: [ObjectIdentifier: SCNNode] = [:]
    private var alienNodes: [ObjectIdentifier: SCNNode] = [:]
    private var flockNodes: [ObjectIdentifier: SCNNode] = [:]
    
    // In SceneWorld properties — keep:
    private let cannonBarrel = SCNNode()

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
        // Pivot at the mount (rotates for aim)
        cannonNode.position = SCNVector3(0, -0.55, 0.9) // lower-center, in front of camera
        camera.addChildNode(cannonNode)

        // Mount / base
        let base = SCNBox(width: 0.35, height: 0.18, length: 0.25, chamferRadius: 0.02)
        base.firstMaterial?.diffuse.contents = UIColor(white: 0.2, alpha: 1)
        base.firstMaterial?.emission.contents = UIColor(white: 0.08, alpha: 1)
        let baseNode = SCNNode(geometry: base)
        baseNode.position = SCNVector3(0, -0.05, 0)
        cannonNode.addChildNode(baseNode)

        // Barrel group (tilts with elevation)
        cannonBarrel.position = SCNVector3(0, 0.05, 0)
        cannonNode.addChildNode(cannonBarrel)

        let barrel = SCNCylinder(radius: 0.06, height: 0.7)
        barrel.firstMaterial?.diffuse.contents = UIColor.red
        barrel.firstMaterial?.emission.contents = UIColor(red: 0.6, green: 0, blue: 0, alpha: 1)
        let barrelNode = SCNNode(geometry: barrel)
        // Cylinder along Y → point forward (+Z in camera space after camera yaw)
        // Camera looks along world +Z; local camera -Z is look direction in default SceneKit,
        // but we rotated camera Y by π so "forward" is world +Z.
        barrelNode.eulerAngles.x = .pi / 2
        barrelNode.position = SCNVector3(0, 0, 0.35)
        cannonBarrel.addChildNode(barrelNode)

        // Muzzle tip (glow)
        let muzzle = SCNSphere(radius: 0.07)
        muzzle.firstMaterial?.diffuse.contents = UIColor.orange
        muzzle.firstMaterial?.emission.contents = UIColor.orange
        let muzzleNode = SCNNode(geometry: muzzle)
        muzzleNode.name = "muzzle"
        muzzleNode.position = SCNVector3(0, 0, 0.72)
        cannonBarrel.addChildNode(muzzleNode)

        // Side brackets
        for side: Float in [-1, 1] {
            let arm = SCNBox(width: 0.06, height: 0.08, length: 0.3, chamferRadius: 0)
            arm.firstMaterial?.diffuse.contents = UIColor.darkGray
            let armNode = SCNNode(geometry: arm)
            armNode.position = SCNVector3(side * 0.16, 0, 0.1)
            cannonNode.addChildNode(armNode)
        }
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

        let cannonGeo = SCNCone(topRadius: 0, bottomRadius: 0.1, height: 0.4)
        cannonGeo.firstMaterial?.diffuse.contents = UIColor.red
        cannonGeo.firstMaterial?.emission.contents = UIColor.red.withAlphaComponent(0.5)
        cannonNode.geometry = cannonGeo
        cannonNode.eulerAngles.x = .pi / 2
        cannonNode.position = SCNVector3(0, 0, 0.5)
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
        cannonNode.eulerAngles.x = .pi / 2 + Float(game.cannonElevation)
        cannonNode.eulerAngles.z = Float(game.cannonAzimuth)

        camera.eulerAngles.z = Float(game.spaceShip.lateralInput) * 0.12
        camera.position.x = shipPos.x * 0.15
        camera.position.y = shipPos.y * 0.15 + 0.25

        if let enemy = game.enemySpaceShip, !enemy.destroyed {
            enemyRoot.isHidden = false
            enemyRoot.position = enemy.position
            enemyRoot.eulerAngles.z = Float(enemy.lateralAngle)
        } else {
            enemyRoot.isHidden = true
        }

        // Asteroids
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

        // Squid swarm
        var seenS = Set<ObjectIdentifier>()
        for alien in game.swarmManager.aliens where !alien.destroyed {
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
            node.position = alien.position
            // Face travel direction (toward player = -Z)
            node.eulerAngles.y = Float(alien.lateralAngle)
            CreatureMesh.animateSquid(node, phase: alien.animPhase)
        }
        for (id, node) in alienNodes where !seenS.contains(id) {
            node.removeFromParentNode()
            alienNodes.removeValue(forKey: id)
        }

        // Deep fish flock
        var seenF = Set<ObjectIdentifier>()
        for alien in game.flockManager.aliens where !alien.destroyed {
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
            node.position = alien.position
            node.eulerAngles.y = Float(alien.lateralAngle)
            CreatureMesh.animateFish(node, phase: alien.animPhase)
        }
        for (id, node) in flockNodes where !seenF.contains(id) {
            node.removeFromParentNode()
            flockNodes.removeValue(forKey: id)
        }

        // Lasers
        laserContainer.childNodes.forEach { $0.removeFromParentNode() }
        for laser in game.playerLasers {
            laserContainer.addChildNode(makeLaserNode(laser, color: .green))
        }
        for laser in game.enemyLasers {
            laserContainer.addChildNode(makeLaserNode(laser, color: .red))
        }
    }

    private func makeLaserNode(_ laser: Laser, color: UIColor) -> SCNNode {
        let geo = SCNCylinder(radius: 0.05, height: 0.75)
        geo.firstMaterial?.diffuse.contents = color
        geo.firstMaterial?.emission.contents = color
        let node = SCNNode(geometry: geo)
        node.eulerAngles.x = .pi / 2
        node.eulerAngles.y = Float(laser.elevationAngle)
        node.position = laser.worldPosition()
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

// MARK: - UI chrome

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
                            startPoint: .topLeading, endPoint: .bottomTrailing
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

struct RadarMapView: View {
    @ObservedObject var game: GameState
    var mapSize: CGFloat = 120
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.55))
            Canvas { context, size in
                let maxZ: CGFloat = 70
                func map(angle: Double, z: CGFloat) -> CGPoint {
                    CGPoint(
                        x: CGFloat(angle / (2 * .pi)) * size.width,
                        y: size.height - (max(0, min(maxZ, z)) / maxZ) * size.height
                    )
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
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 1.5, y: p.y - 1.5, width: 3, height: 3)), with: .color(.teal))
                }
                if let e = game.enemySpaceShip, !e.destroyed {
                    let p = map(angle: e.lateralAngle, z: e.z)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 2.5, y: p.y - 2.5, width: 5, height: 5)), with: .color(.red))
                }
                let shipP = map(angle: game.spaceShip.lateralAngle, z: 0)
                context.fill(Path(ellipseIn: CGRect(x: shipP.x - 2.5, y: shipP.y - 2.5, width: 5, height: 5)), with: .color(.cyan))
            }
            .padding(4)
            RoundedRectangle(cornerRadius: 8).strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
        }
        .frame(width: mapSize, height: mapSize * 0.85)
    }
}

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
            Circle().fill(baseColor.opacity(0.12)).frame(width: diameter, height: diameter)
            Circle().strokeBorder(baseColor.opacity(0.35), lineWidth: 2).frame(width: diameter, height: diameter)
            Circle().fill(baseColor.opacity(active ? 0.55 : 0.35))
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
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) { knobOffset = .zero }
                    onChange(.zero)
                    onEnd()
                }
        )
    }
}

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
                        Text("Game Over").font(.system(size: 40, weight: .bold)).foregroundColor(.red)
                        Text("Score: \(game.score)").font(.system(size: 24)).foregroundColor(.white)
                        Button("Restart") { game.restart() }
                            .padding(.horizontal, 24).padding(.vertical, 10)
                            .background(Color.blue).foregroundColor(.white).cornerRadius(8)
                    }
                }

                VStack {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tube Runner").foregroundColor(.white).font(.system(size: 16, weight: .semibold))
                            Text("Blue: move · Red: aim + hold to fire")
                                .foregroundColor(.white.opacity(0.9)).font(.system(size: 12))
                            Text("Purple squid · Teal deep fish · Shield 2s")
                                .foregroundColor(.cyan).font(.system(size: 12, weight: .bold))
                            Text(String(format: "Speed %.1f  Dist %.0f",
                                         game.spaceShip.forwardSpeed, game.spaceShip.progress))
                                .foregroundColor(.orange).font(.system(size: 12, weight: .medium))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            Button(action: { showVolumeDialog = true }) {
                                Image(systemName: "speaker.wave.2.fill").foregroundColor(.white).font(.system(size: 22))
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
                        JoystickView(
                            diameter: 110,
                            knobDiameter: 48,
                            baseColor: .red,
                            onChange: { v in
                                // Left / right
                                game.cannonAzimuth = Double(v.dx) * 0.85
                                // Up / down (stick up = aim up)
                                game.cannonElevation = max(-0.75, min(0.75, Double(-v.dy) * 0.75))
                                game.startFiring()
                            },
                            onEnd: {
                                // Keep last aim, or reset — pick one:
                                // game.cannonAzimuth = 0
                                // game.cannonElevation = 0
                                game.stopFiring()
                            }
                        )
                            .padding(.leading, 28)
                        Spacer()
                        Text("Score: \(game.score)")
                            .font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                        Spacer()
                        VStack(spacing: 14) {
                            // Fire / aim stick — hold to rapid-fire
                            JoystickView(
                                diameter: 100,
                                knobDiameter: 44,
                                baseColor: .red,
                                onChange: { v in
                                    game.cannonAzimuth = Double(v.dx) * 0.8
                                    game.cannonElevation = max(-0.7, min(0.7, Double(-v.dy) * 0.7))
                                    game.startFiring()
                                },
                                onEnd: {
                                    game.cannonAzimuth = 0
                                    game.cannonElevation = 0
                                    game.stopFiring()
                                }
                            )
                            Button(action: { game.activateShield() }) {
                                ZStack {
                                    Circle().fill(Color.cyan.opacity(game.shieldActive ? 0.5 : 0.25))
                                        .frame(width: 52, height: 52)
                                    Circle().strokeBorder(Color.cyan.opacity(0.7), lineWidth: 2)
                                        .frame(width: 52, height: 52)
                                    Image(systemName: "shield.fill").foregroundColor(.cyan).font(.system(size: 20))
                                }
                            }
                            .disabled(game.shieldActive)
                        }
                        .padding(.trailing, 28)
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showVolumeDialog) { VolumeView(volume: $game.volume) }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }
}

#Preview {
    ContentView()
}
