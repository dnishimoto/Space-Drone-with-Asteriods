import SwiftUI
import Combine

// MARK: - App Entry Point
// If you don't already have an @main App struct in your project, add this:
//
// @main
// struct SpaceGameApp: App {
//     var body: some Scene {
//         WindowGroup {
//             ContentView()
//         }
//     }
// }

// MARK: - Asteroid Size

enum AsteroidSize {
    case small, medium, large

    var value: CGFloat {
        switch self {
        case .small: return 20.0
        case .large: return 40.0
        case .medium: return 30.0
        }
    }
}

// MARK: - Laser

struct Laser {
    var position: CGPoint
    var angle: Double
    let isPlayerLaser: Bool
    static let speed: CGFloat = 8.0

    mutating func update() {
        position.x += CGFloat(cos(angle)) * Laser.speed
        position.y += CGFloat(sin(angle)) * Laser.speed
    }
}

// MARK: - Asteroid

final class Asteroid {
    var position: CGPoint
    var size: AsteroidSize
    var velocity: CGVector

    init(position: CGPoint, size: AsteroidSize, velocity: CGVector) {
        self.position = position
        self.size = size
        self.velocity = velocity
    }

    func update(gameWidth: CGFloat, gameHeight: CGFloat) {
        position.x += velocity.dx
        position.y += velocity.dy
        if position.x < 0 { position.x = gameWidth }
        if position.x > gameWidth { position.x = 0 }
        if position.y < 0 { position.y = gameHeight }
        if position.y > gameHeight { position.y = 0 }
    }
}

// MARK: - Space Ship

final class SpaceShip {
    var position = CGPoint(x: 200, y: 300)
    var angle: Double = -Double.pi / 2
    var velocity = CGVector(dx: 0, dy: 0)
    /// -1...1 analog thrust strength from the joystick's vertical deflection.
    /// Positive = forward (in the direction the ship is facing), negative = reverse.
    var thrustAmount: Double = 0
    /// -1 = turning counterclockwise, 1 = turning clockwise, 0 = no turn.
    /// Can be fractional for analog joystick input.
    var turnInput: Double = 0

    /// Convenience flag used by the renderer to decide whether to draw a thruster flame.
    var isThrusting: Bool { thrustAmount > 0 }
    var isReversing: Bool { thrustAmount < 0 }

    static let maxSpeed: CGFloat = 4.0
    static let acceleration: CGFloat = 0.05
    static let reverseAcceleration: CGFloat = 0.035
    static let friction: CGFloat = 0.02
    static let turnRate: Double = 0.05

    func update(gameWidth: CGFloat, gameHeight: CGFloat) {
        angle += turnInput * SpaceShip.turnRate

        if thrustAmount != 0 {
            let rate = thrustAmount > 0 ? SpaceShip.acceleration : SpaceShip.reverseAcceleration
            let accel = rate * CGFloat(thrustAmount)
            velocity.dx += CGFloat(cos(angle)) * accel
            velocity.dy += CGFloat(sin(angle)) * accel
        }

        velocity.dx *= (1 - SpaceShip.friction)
        velocity.dy *= (1 - SpaceShip.friction)

        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        if speed > SpaceShip.maxSpeed {
            velocity.dx = velocity.dx / speed * SpaceShip.maxSpeed
            velocity.dy = velocity.dy / speed * SpaceShip.maxSpeed
        }

        position.x += velocity.dx
        position.y += velocity.dy

        if position.x < 0 { position.x = gameWidth }
        if position.x > gameWidth { position.x = 0 }
        if position.y < 0 { position.y = gameHeight }
        if position.y > gameHeight { position.y = 0 }
    }
}

// MARK: - Enemy Space Ship

final class EnemySpaceShip {
    var position = CGPoint(x: 100, y: 100)
    var angle: Double = 0
    var velocity = CGVector(dx: 0, dy: 0)
    var destroyed = false
    var shootCooldown = 60

    static let maxSpeed: CGFloat = 2.5
    static let acceleration: CGFloat = 0.05
    static let friction: CGFloat = 0.02

    func update(asteroids: [Asteroid], playerLasers: [Laser], playerPosition: CGPoint, gameWidth: CGFloat, gameHeight: CGFloat) {
        if destroyed { return }

        let dx = playerPosition.x - position.x
        let dy = playerPosition.y - position.y
        angle = atan2(Double(dy), Double(dx))

        for asteroid in asteroids {
            let distance = hypot(position.x - asteroid.position.x, position.y - asteroid.position.y)
            if distance < 50 {
                let avoidAngle = atan2(Double(position.y - asteroid.position.y), Double(position.x - asteroid.position.x))
                angle += (avoidAngle - angle) * 0.1
            }
        }

        for laser in playerLasers {
            let distance = hypot(position.x - laser.position.x, position.y - laser.position.y)
            if distance < 50 {
                let avoidAngle = atan2(Double(position.y - laser.position.y), Double(position.x - laser.position.x))
                angle += (avoidAngle - angle) * 0.1
            }
        }

        velocity.dx += CGFloat(cos(angle)) * EnemySpaceShip.acceleration
        velocity.dy += CGFloat(sin(angle)) * EnemySpaceShip.acceleration
        velocity.dx *= (1 - EnemySpaceShip.friction)
        velocity.dy *= (1 - EnemySpaceShip.friction)

        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        if speed > EnemySpaceShip.maxSpeed {
            velocity.dx = velocity.dx / speed * EnemySpaceShip.maxSpeed
            velocity.dy = velocity.dy / speed * EnemySpaceShip.maxSpeed
        }

        position.x += velocity.dx
        position.y += velocity.dy

        if position.x < 0 { position.x = gameWidth }
        if position.x > gameWidth { position.x = 0 }
        if position.y < 0 { position.y = gameHeight }
        if position.y > gameHeight { position.y = 0 }

        if shootCooldown <= 0 {
            shootCooldown = 60 + Int.random(in: 0..<60)
        } else {
            shootCooldown -= 1
        }
    }

    func respawn(gameWidth: CGFloat, gameHeight: CGFloat) {
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: gameWidth, y: 0),
            CGPoint(x: 0, y: gameHeight),
            CGPoint(x: gameWidth, y: gameHeight)
        ]
        position = corners.randomElement() ?? .zero
        velocity = .zero
        angle = Double.random(in: 0..<(2 * .pi))
    }

    func destroy() {
        destroyed = true
    }
}

// MARK: - Game State

final class GameState: ObservableObject {

    // Entities are plain (non-Published) so we don't pay diffing costs on
    // every laser/asteroid mutation. `frameTick` is the single Published
    // property that drives view redraws each game loop step.
    var spaceShip = SpaceShip()
    var enemySpaceShip: EnemySpaceShip? = nil
    var asteroids: [Asteroid] = []
    var playerLasers: [Laser] = []
    var enemyLasers: [Laser] = []

    @Published var score = 0
    @Published var gameOver = false
    @Published var volume: Double = 1.0
    @Published private(set) var frameTick: Int = 0

    /// True while the shield is up and the ship is immune to collisions.
    @Published private(set) var shieldActive = false

    var gameWidth: CGFloat = 0
    var gameHeight: CGFloat = 0

    private var gameTimer: Timer?
    private var fireTimer: Timer?
    private var enemyShipDelayTimer: Timer?
    private var enemyShootTimer: Timer?
    private var shieldTimer: Timer?
    private var enemyShipActive = false
    private var enemyCanShoot = false
    private var enemyShootDelayTimer: Timer?
    private var isFiring = false

    static let shieldDuration: TimeInterval = 2.0

    /// Set by the left joystick each drag update. x = turn (-1...1), y = thrust when negative (up).
    var leftJoystickVector: CGVector = .zero

    func start() {
        guard gameTimer == nil else { return }
        spawnAsteroids()
        startGameLoop()
        startEnemyShipDelay()
        startEnemyShootLoop()
    }

    private func startGameLoop() {
        gameTimer?.invalidate()
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func startEnemyShipDelay() {
        enemyShipActive = false
        enemySpaceShip = nil
        enemyShipDelayTimer?.invalidate()
        enemyShipDelayTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.enemySpaceShip = EnemySpaceShip()
            self.enemyShipActive = true
            self.enemyCanShoot = false
            self.enemyShootDelayTimer?.invalidate()
            self.enemyShootDelayTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
                self?.enemyCanShoot = true
            }
        }
    }

    private func startEnemyShootLoop() {
        enemyShootTimer?.invalidate()
        enemyShootTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: true) { [weak self] _ in
            self?.enemyShootLaser()
        }
    }

    private func onEnemyShipDestroyed() {
        enemyShipActive = false
        enemySpaceShip = nil
        startEnemyShipDelay()
    }

    private func spawnAsteroids() {
        asteroids.removeAll()
        guard gameWidth > 0, gameHeight > 0 else { return }
        let numberOfAsteroids = 6 + score / 1000
        for _ in 0..<numberOfAsteroids {
            var spawnPosition: CGPoint
            var attempts = 0
            repeat {
                spawnPosition = CGPoint(
                    x: CGFloat.random(in: 0..<gameWidth),
                    y: CGFloat.random(in: 0..<gameHeight)
                )
                attempts += 1
            } while hypot(spawnPosition.x - spaceShip.position.x, spawnPosition.y - spaceShip.position.y) < 100 && attempts < 50

            let speedMultiplier = 1 + CGFloat(score) / 3000
            asteroids.append(Asteroid(
                position: spawnPosition,
                size: Bool.random() ? .large : .small,
                velocity: CGVector(
                    dx: (CGFloat.random(in: 0..<1) - 0.5) * 2 * speedMultiplier,
                    dy: (CGFloat.random(in: 0..<1) - 0.5) * 2 * speedMultiplier
                )
            ))
        }
    }

    private func tick() {
        guard !gameOver else { return }

        let deadzone: CGFloat = 0.15
        let rawTurn = leftJoystickVector.dx
        spaceShip.turnInput = abs(rawTurn) > deadzone ? Double(max(-1, min(1, rawTurn))) : 0

        // Up on the stick (negative dy) = forward thrust, down (positive dy) = reverse thrust.
        let rawVertical = -leftJoystickVector.dy
        spaceShip.thrustAmount = abs(rawVertical) > deadzone ? Double(max(-1, min(1, rawVertical))) : 0

        spaceShip.update(gameWidth: gameWidth, gameHeight: gameHeight)
        enemySpaceShip?.update(
            asteroids: asteroids,
            playerLasers: playerLasers,
            playerPosition: spaceShip.position,
            gameWidth: gameWidth,
            gameHeight: gameHeight
        )

        for i in playerLasers.indices { playerLasers[i].update() }
        for i in enemyLasers.indices { enemyLasers[i].update() }
        for asteroid in asteroids { asteroid.update(gameWidth: gameWidth, gameHeight: gameHeight) }

        checkCollisions()
        removeOffscreenObjects()

        if asteroids.isEmpty {
            spawnAsteroids()
        }

        if checkShipCollision() {
            gameOver = true
        }

        frameTick &+= 1
    }

    func shootLaser() {
        guard !gameOver else { return }
        let startPosition = CGPoint(
            x: spaceShip.position.x + CGFloat(cos(spaceShip.angle)) * 15,
            y: spaceShip.position.y + CGFloat(sin(spaceShip.angle)) * 15
        )
        playerLasers.append(Laser(position: startPosition, angle: spaceShip.angle, isPlayerLaser: true))
    }

    func startFiring() {
        if isFiring { return }
        isFiring = true
        shootLaser()
        fireTimer?.invalidate()
        fireTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
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
    }

    func activateShield() {
        guard !gameOver, !shieldActive else { return }

        shieldActive = true
        shieldTimer?.invalidate()
        shieldTimer = Timer.scheduledTimer(withTimeInterval: GameState.shieldDuration, repeats: false) { [weak self] _ in
            self?.shieldActive = false
        }
    }

    private func enemyShootLaser() {
        guard !gameOver, enemyCanShoot, let enemy = enemySpaceShip, enemyShipActive, !enemy.destroyed else { return }
        let startPosition = CGPoint(
            x: enemy.position.x + CGFloat(cos(enemy.angle)) * 15,
            y: enemy.position.y + CGFloat(sin(enemy.angle)) * 15
        )
        enemyLasers.append(Laser(position: startPosition, angle: enemy.angle, isPlayerLaser: false))
    }

    private func isCollision(_ position: CGPoint, targetPosition: CGPoint, radius: CGFloat) -> Bool {
        hypot(position.x - targetPosition.x, position.y - targetPosition.y) < radius
    }

    private func checkCollisions() {
        var playerLasersToRemove = Set<Int>()
        var enemyLasersToRemove = Set<Int>()
        var asteroidsToRemove = Set<Int>()
        var asteroidsToAdd: [Asteroid] = []

        for (li, laser) in playerLasers.enumerated() {
            for (ai, asteroid) in asteroids.enumerated() {
                let radius = asteroid.size.value / 2 + 5
                if isCollision(laser.position, targetPosition: asteroid.position, radius: radius) {
                    playerLasersToRemove.insert(li)
                    asteroidsToRemove.insert(ai)
                    score += asteroid.size == .large ? 100 : 50

                    if asteroid.size == .large {
                        for _ in 0..<2 {
                            asteroidsToAdd.append(Asteroid(
                                position: asteroid.position,
                                size: .small,
                                velocity: CGVector(
                                    dx: (CGFloat.random(in: 0..<1) - 0.5) * 3,
                                    dy: (CGFloat.random(in: 0..<1) - 0.5) * 3
                                )
                            ))
                        }
                    }
                    break
                }
            }
            if let enemy = enemySpaceShip, !enemy.destroyed,
               isCollision(laser.position, targetPosition: enemy.position, radius: 15) {
                playerLasersToRemove.insert(li)
                score += 500
                enemySpaceShip?.destroy()
                onEnemyShipDestroyed()
            }
        }

        for (li, laser) in enemyLasers.enumerated() {
            if isCollision(laser.position, targetPosition: spaceShip.position, radius: 15) {
                enemyLasersToRemove.insert(li)
                if !shieldActive {
                    gameOver = true
                }
            }
            for (ai, asteroid) in asteroids.enumerated() {
                let radius = asteroid.size.value / 2 + 5
                if isCollision(laser.position, targetPosition: asteroid.position, radius: radius) {
                    enemyLasersToRemove.insert(li)
                    asteroidsToRemove.insert(ai)
                    break
                }
            }
        }

        playerLasers = playerLasers.enumerated().filter { !playerLasersToRemove.contains($0.offset) }.map { $0.element }
        enemyLasers = enemyLasers.enumerated().filter { !enemyLasersToRemove.contains($0.offset) }.map { $0.element }
        asteroids = asteroids.enumerated().filter { !asteroidsToRemove.contains($0.offset) }.map { $0.element }
        asteroids.append(contentsOf: asteroidsToAdd)
    }

    private func checkShipCollision() -> Bool {
        for asteroid in asteroids {
            let radius = asteroid.size.value / 2 + 5
            if isCollision(spaceShip.position, targetPosition: asteroid.position, radius: radius) {
                if shieldActive { continue }
                return true
            }
            if let enemy = enemySpaceShip, !enemy.destroyed,
               isCollision(enemy.position, targetPosition: asteroid.position, radius: radius) {
                enemySpaceShip?.respawn(gameWidth: gameWidth, gameHeight: gameHeight)
            }
        }
        if let enemy = enemySpaceShip, !enemy.destroyed,
           isCollision(spaceShip.position, targetPosition: enemy.position, radius: 15), !shieldActive {
            return true
        }
        return false
    }

    private func removeOffscreenObjects() {
        playerLasers.removeAll { $0.position.x < 0 || $0.position.x > gameWidth || $0.position.y < 0 || $0.position.y > gameHeight }
        enemyLasers.removeAll { $0.position.x < 0 || $0.position.x > gameWidth || $0.position.y < 0 || $0.position.y > gameHeight }
    }

    func restart() {
        spaceShip = SpaceShip()
        enemySpaceShip = nil
        enemyShipActive = false
        enemyCanShoot = false
        enemyShootDelayTimer?.invalidate()
        startEnemyShipDelay()
        spawnAsteroids()
        playerLasers.removeAll()
        enemyLasers.removeAll()
        score = 0
        gameOver = false
        shieldActive = false
        shieldTimer?.invalidate()
    }

    func stopAll() {
        gameTimer?.invalidate()
        fireTimer?.invalidate()
        enemyShipDelayTimer?.invalidate()
        enemyShootTimer?.invalidate()
        enemyShootDelayTimer?.invalidate()
        shieldTimer?.invalidate()
    }
}

// MARK: - Digital Joystick

/// A reusable on-screen digital joystick. Reports a normalized CGVector
/// (each axis roughly -1...1) as the knob is dragged, and resets to
/// center when released.
struct JoystickView: View {
    var diameter: CGFloat = 110
    var knobDiameter: CGFloat = 54
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

// MARK: - Volume Sheet

struct VolumeView: View {
    @Binding var volume: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Sound Volume")
                .font(.headline)
            Slider(value: $volume, in: 0...1)
                .padding(.horizontal)
            Text("Volume: \(Int(volume * 100))%")
                .foregroundColor(.secondary)
            Button("Close") { dismiss() }
                .padding(.top, 8)
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

                Canvas { context, size in
                    draw(in: context, size: size)
                }
                .ignoresSafeArea()
                .onAppear {
                    game.gameWidth = geo.size.width
                    game.gameHeight = geo.size.height
                    game.start()
                }
                .onChange(of: geo.size) { newSize in
                    game.gameWidth = newSize.width
                    game.gameHeight = newSize.height
                }
                .onDisappear {
                    game.stopAll()
                }

                if game.gameOver {
                    VStack(spacing: 16) {
                        Text("Game Over")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.red)
                        Text("Score: \(game.score)")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                        Button("Restart") {
                            game.restart()
                        }
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
                            Text("Controls:")
                                .foregroundColor(.white)
                                .font(.system(size: 16))
                            Text("Left stick: turn, up to thrust, down to reverse")
                                .foregroundColor(.white)
                                .font(.system(size: 13))
                            Text("Right stick: push to fire")
                                .foregroundColor(.orange)
                                .font(.system(size: 13, weight: .bold))
                            Text("Center: shield (2s)")
                                .foregroundColor(.cyan)
                                .font(.system(size: 13, weight: .bold))
                            Text("Below shield: hold to fire")
                                .foregroundColor(.red)
                                .font(.system(size: 13, weight: .bold))
                        }
                        Spacer()
                        Button(action: { showVolumeDialog = true }) {
                            Image(systemName: "speaker.wave.2.fill")
                                .foregroundColor(.white)
                                .font(.system(size: 26))
                        }
                    }
                    .padding()
                    Spacer()
                }

                VStack {
                    Spacer()
                    HStack {
                        JoystickView(baseColor: .blue, onChange: { vector in
                            game.leftJoystickVector = vector
                        }, onEnd: {
                            game.leftJoystickVector = .zero
                        })
                        .padding(.leading, 32)

                        Spacer()

                        Button(action: { game.activateShield() }) {
                            ZStack {
                                Circle()
                                    .fill(Color.cyan.opacity(game.shieldActive ? 0.5 : 0.25))
                                    .frame(width: 56, height: 56)
                                Circle()
                                    .strokeBorder(Color.cyan.opacity(0.7), lineWidth: 2)
                                    .frame(width: 56, height: 56)
                                Image(systemName: "shield.fill")
                                    .foregroundColor(.cyan)
                                    .font(.system(size: 24))
                            }
                        }
                        .disabled(game.shieldActive)
                        .padding(.bottom, 12)

                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color.red.opacity(0.35))
                                    .frame(width: 56, height: 56)
                                Circle()
                                    .strokeBorder(Color.red.opacity(0.7), lineWidth: 2)
                                    .frame(width: 56, height: 56)
                                Image(systemName: "bolt.fill")
                                    .foregroundColor(.red)
                                    .font(.system(size: 24))
                            }
                        }
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in game.startFiring() }
                                .onEnded { _ in game.stopFiring() }
                        )
                        .padding(.bottom, 30)

                        Spacer()

                        JoystickView(baseColor: .red, onChange: { vector in
                            let magnitude = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
                            if magnitude > 0.3 {
                                game.startFiring()
                            } else {
                                game.stopFiring()
                            }
                        }, onEnd: {
                            game.stopFiring()
                        })
                        .padding(.trailing, 32)
                    }
                    .padding(.bottom, 48)
                }
            }
        }
        .sheet(isPresented: $showVolumeDialog) {
            VolumeView(volume: $game.volume)
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        // Player ship
        var shipContext = context
        shipContext.translateBy(x: game.spaceShip.position.x, y: game.spaceShip.position.y)
        shipContext.rotate(by: .radians(game.spaceShip.angle))
        var shipPath = Path()
        shipPath.move(to: CGPoint(x: 15, y: 0))
        shipPath.addLine(to: CGPoint(x: -15, y: 10))
        shipPath.addLine(to: CGPoint(x: -15, y: -10))
        shipPath.closeSubpath()
        shipContext.stroke(shipPath, with: .color(.white), lineWidth: 2)
        if game.spaceShip.isThrusting {
            var flame = Path()
            flame.move(to: CGPoint(x: -15, y: 0))
            flame.addLine(to: CGPoint(x: -25, y: 0))
            shipContext.stroke(flame, with: .color(.orange), lineWidth: 2)
        }
        if game.spaceShip.isReversing {
            var reverseFlame = Path()
            reverseFlame.move(to: CGPoint(x: 15, y: 0))
            reverseFlame.addLine(to: CGPoint(x: 22, y: 0))
            shipContext.stroke(reverseFlame, with: .color(.cyan), lineWidth: 2)
        }

        // Shield shell
        if game.shieldActive {
            let shieldRadius: CGFloat = 26
            let shieldRect = CGRect(
                x: game.spaceShip.position.x - shieldRadius,
                y: game.spaceShip.position.y - shieldRadius,
                width: shieldRadius * 2,
                height: shieldRadius * 2
            )
            context.fill(Path(ellipseIn: shieldRect), with: .color(.cyan.opacity(0.15)))
            context.stroke(Path(ellipseIn: shieldRect), with: .color(.cyan.opacity(0.8)), lineWidth: 2)
        }

        // Enemy ship
        if let enemy = game.enemySpaceShip, !enemy.destroyed {
            var enemyContext = context
            enemyContext.translateBy(x: enemy.position.x, y: enemy.position.y)
            enemyContext.rotate(by: .radians(enemy.angle))
            var enemyPath = Path()
            enemyPath.move(to: CGPoint(x: 0, y: -15))
            enemyPath.addLine(to: CGPoint(x: 10, y: 15))
            enemyPath.addLine(to: CGPoint(x: -10, y: 15))
            enemyPath.closeSubpath()
            enemyContext.stroke(enemyPath, with: .color(.red), lineWidth: 2)
        }

        // Asteroids
        for asteroid in game.asteroids {
            let radius = asteroid.size.value / 2
            let rect = CGRect(
                x: asteroid.position.x - radius,
                y: asteroid.position.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.stroke(Path(ellipseIn: rect), with: .color(.gray), lineWidth: 2)
        }

        // Lasers
        for laser in game.playerLasers {
            let rect = CGRect(x: laser.position.x - 2, y: laser.position.y - 2, width: 4, height: 4)
            context.fill(Path(ellipseIn: rect), with: .color(.green))
        }
        for laser in game.enemyLasers {
            let rect = CGRect(x: laser.position.x - 2, y: laser.position.y - 2, width: 4, height: 4)
            context.fill(Path(ellipseIn: rect), with: .color(.red))
        }

        // Score
        context.draw(
            Text("Score: \(game.score)")
                .foregroundColor(.white)
                .font(.system(size: 20)),
            at: CGPoint(x: 60, y: 20)
        )
    }
}

#Preview {
    ContentView()
}
