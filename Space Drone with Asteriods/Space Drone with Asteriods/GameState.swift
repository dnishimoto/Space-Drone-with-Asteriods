//
//  GameState.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SwiftUI
import SceneKit
import Combine

/// Enum representing the current section of the game scene,
/// supporting multiple game stages for progression and variety.
enum SceneSection {
    case asteroid, ocean, storm, core, finale
}

final class GameState: ObservableObject {
    var cannonMuzzleWorldPosition = SCNVector3(0, 0, 0)
    @Published var cannonLateralAngle: Double = 0.0
    @Published var cannonElevation: Double = 0.0
    var cannonWorldDirection = SCNVector3(0, 0, -1)
    var spaceShip = SpaceShip()
    var enemySpaceShip: EnemySpaceShip? = nil
    var asteroids: [Asteroid] = []
    var playerLasers: [Laser] = []
    var enemyLasers: [Laser] = []
    var sharks: [Shark] = []
    let swarmManager = SwarmManager()
    let flockManager = FlockManager()

    @Published var score = 20000  //dsn
    @Published var gameOver = false
    @Published var volume: Double = 1.0
    @Published private(set) var frameTick: Int = 0
    @Published private(set) var shieldActive = false

    @Published var currentSection: SceneSection = .asteroid

    var cannonAzimuth: Double = 0
    var joystickVector: CGVector = .zero

    /// Live world-space position of the cannon's muzzle tip, pushed in every
    /// frame by SceneWorld.sync(). shootLaser() reads this so lasers visually
    /// originate from wherever the barrel is currently pointing, instead of
    /// a fixed offset from the ship.

    private var fireTimer: Timer?
    private var isFiring = false
    private var gameTimer: Timer?
    private var shieldTimer: Timer?
    private var enemySpawnTimer: Timer?
    private var asteroidSpawnClock: CGFloat = 0
    private let asteroidSpawnInterval: CGFloat = 1.1
    private let dt: CGFloat = 1.0 / 60.0
    static let shieldDuration: TimeInterval = 2.0
    var pendingExplosions: [ExplosionEvent] = []
    
    @Published var playCollisionSound: Bool = true


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
  


    private func makeParticleExplosion(
        at position: SCNVector3,
        in scene: SCNScene,
        color: UIColor = .systemOrange,
        scale: CGFloat = 1.0
    ) {
        let explosionNode = SCNNode()
        explosionNode.position = position
        scene.rootNode.addChildNode(explosionNode)

        let particles = SCNParticleSystem()

        // One short burst.
        particles.birthRate = 1_200
        particles.loops = false
        particles.emissionDuration = 0.03

        particles.particleLifeSpan = 0.65
        particles.particleLifeSpanVariation = 0.20

        // Appearance.
        particles.particleSize = 0.055 * scale
        particles.particleSizeVariation = 0.025 * scale
        particles.particleColor = color
        particles.particleColorVariation = SCNVector4(0.15, 0.08, 0.0, 0.0)
        particles.particleImage = makeGlowParticleImage()

        // Emit a spherical blast in every direction.
        particles.emittingDirection = SCNVector3(0, 1, 0)
        particles.spreadingAngle = 180

        particles.particleVelocity = 5.5 * scale
        particles.particleVelocityVariation = 2.5 * scale

        // Bright glowing visual style.
        particles.blendMode = .additive
        particles.orientationMode = .billboardScreenAligned
        particles.isAffectedByGravity = false
        particles.isAffectedByPhysicsFields = false

        // Make each particle grow slightly, then disappear.
        let sizeAnimation = CAKeyframeAnimation(keyPath: "size")
        sizeAnimation.values = [1.0, 1.25, 0.4, 0.0]
        sizeAnimation.keyTimes = [0.0, 0.12, 0.72, 1.0]
        sizeAnimation.duration = particles.particleLifeSpan
        sizeAnimation.calculationMode = .linear

        particles.particleSize = 0.03

   
        let sizeController = SCNParticlePropertyController(
            animation: sizeAnimation
        )

        var controllers = particles.propertyControllers ?? [:]
        controllers[.size] = sizeController
        particles.propertyControllers = controllers
        explosionNode.addParticleSystem(particles)

        let cleanupDelay = TimeInterval(
            particles.emissionDuration
                + particles.particleLifeSpan
                + particles.particleLifeSpanVariation
                + 0.25
        )

        explosionNode.runAction(
            SCNAction.sequence([
                SCNAction.wait(duration: cleanupDelay),
                SCNAction.removeFromParentNode()
            ])
        )
    }


    private func makeGlowParticleImage(size: CGFloat = 64) -> UIImage {
        let renderSize = CGSize(width: size, height: size)

        let renderer = UIGraphicsImageRenderer(size: renderSize)

        return renderer.image { rendererContext in
            let context = rendererContext.cgContext

            let center = CGPoint(
                x: renderSize.width / 2,
                y: renderSize.height / 2
            )

            let colors = [
                UIColor.white.withAlphaComponent(1.0).cgColor,
                UIColor.white.withAlphaComponent(0.80).cgColor,
                UIColor.white.withAlphaComponent(0.25).cgColor,
                UIColor.white.withAlphaComponent(0.0).cgColor
            ] as CFArray

            let locations: [CGFloat] = [0.0, 0.18, 0.55, 1.0]

            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locations
            ) else {
                return
            }

            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: size / 2,
                options: [.drawsAfterEndLocation]
            )
        }
    }

    private func spawnExplosion(x: CGFloat, y: CGFloat, z: CGFloat, scale: Float = 1.0) {
        pendingExplosions.append(ExplosionEvent(x: x, y: y, z: z, scale: scale))
    }

    // Helpers from ring entities
    private func explosionAt(angle: Double, radial: CGFloat, z: CGFloat, scale: Float = 1.0) {
        let r = Tunnel.radius * radial
        spawnExplosion(
            x: r * CGFloat(cos(angle)),
            y: r * CGFloat(sin(angle)),
            z: z,
            scale: scale
        )
    }

    func shootLaser() {

        guard !gameOver else {
            return
        }

        // ============================================================
        // ACTUAL CANNON WORLD POSITION
        // ============================================================

        let muzzle =
            cannonMuzzleWorldPosition

        // ============================================================
        // ACTUAL CANNON WORLD DIRECTION
        // ============================================================

        let direction =
            cannonWorldDirection.normalized

        guard direction.length > 0.000001 else {
            return
        }

        // ============================================================
        // TUNNEL RADIAL POSITION
        // ============================================================

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

        // ============================================================
        // CREATE LASER
        // ============================================================

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
        guard !gameOver else { return }
        if isFiring { return }
        isFiring = true
        shootLaser()
        fireTimer?.invalidate()
        fireTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
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

        enemySpawnTimer = Timer.scheduledTimer(
            withTimeInterval: 12.0,
            repeats: false
        ) { [weak self] _ in
            guard let self, !self.gameOver else { return }

            self.enemySpaceShip = EnemySpaceShip(
                lateralAngle: Double.random(in: 0.0..<(2.0 * .pi)),
                playerZ: self.spaceShip.z,
                spawnDistance: CGFloat.random(in: 35.0...55.0)
            )
        }
    }

    @MainActor
    private func tick() {

        // ------------------------------------------------------------
        // GAME STATE
        // ------------------------------------------------------------

        guard !gameOver else {
            stopFiring()
            return
        }

        let deltaTime = dt
        let deadzone: CGFloat = 0.12

        // ------------------------------------------------------------
        // JOYSTICK INPUT
        // ------------------------------------------------------------

        let rawX = joystickVector.dx

        spaceShip.lateralInput =
            abs(rawX) > deadzone
            ? Double(max(-1.0, min(1.0, rawX)))
            : 0.0

        // UIKit / SwiftUI joystick Y increases downward.
        // Invert it so:
        // UP   = +1
        // DOWN = -1

        let rawY = -joystickVector.dy

        spaceShip.verticalInput =
            abs(rawY) > deadzone
            ? Double(max(-1.0, min(1.0, rawY)))
            : 0.0

        // ------------------------------------------------------------
        // PLAYER SHIP
        // ------------------------------------------------------------
        // NOTE: SpaceShip.update(dt:) is the ONLY place verticalPosition
        // (and therefore position.y) gets touched. There used to be a
        // second, redundant vertical-position block right here in tick()
        // that nudged spaceShip.verticalPosition again with its own speed
        // and clamp range — but it ran *after* update() had already
        // computed `position` for this frame, so its contribution was
        // always one frame stale, and its own separate ±3.5 clamp fought
        // with update()'s ±6.0 clamp. That mismatch (not a sign error) is
        // what made vertical movement feel unresponsive. Removed.
        spaceShip.update(dt: deltaTime)

        // ------------------------------------------------------------
        // ASTEROID SPAWNING
        // ------------------------------------------------------------

        asteroidSpawnClock += deltaTime

        if asteroidSpawnClock >= asteroidSpawnInterval {

            asteroidSpawnClock -= asteroidSpawnInterval

            spawnAsteroid()
        }

        // ------------------------------------------------------------
        // ASTEROIDS
        // ------------------------------------------------------------

        for asteroid in asteroids {

            asteroid.update(
                dt: deltaTime,
                shipSpeed: spaceShip.forwardSpeed
            )
        }

        asteroids.removeAll { asteroid in
            asteroid.z < -5.0
        }

        // ------------------------------------------------------------
        // ENEMY BOSS
        // ------------------------------------------------------------

        if let enemy = enemySpaceShip,
           !enemy.destroyed {

            enemy.update(
                dt: deltaTime,
                shipSpeed: spaceShip.forwardSpeed,
                playerAngle: spaceShip.lateralAngle
            )

            // --------------------------------------------------------
            // ENEMY LASER FIRE
            // --------------------------------------------------------

            if enemy.shootCooldown <= 0 {

                enemy.shootCooldown = CGFloat.random(
                    in: 1.0...2.2
                )

                let enemyPosition =
                    enemyWorldPosition(enemy)

                let enemyDirection =
                    enemyWorldDirectionTowardPlayer(enemy)

                enemyLasers.append(
                    Laser(
                        lateralAngle: enemy.lateralAngle,
                        elevationAngle: 0.0,

                        z: enemy.z - 1.5,

                        radialOffset: Tunnel.shipRadialInset,

                        origin: enemyPosition,

                        // Use the actual enemy firing direction.
                        direction: enemyDirection,

                        stepSize: 0.1,

                        isPlayerLaser: false
                    )
                )
            }

            // --------------------------------------------------------
            // ENEMY PASSED PLAYER
            // --------------------------------------------------------

            if enemy.z < -6.0 {

                enemySpaceShip = nil

                scheduleEnemy()
            }
        }

        // ------------------------------------------------------------
        // COMPUTE DIFFICULTY BASED ON SCORE
        // ------------------------------------------------------------

        let difficulty = 1.0 + min(Double(score), 400.0) / 400.0 * 2.0

        // ------------------------------------------------------------
        // ALIEN SQUID SWARM
        // ------------------------------------------------------------

        swarmManager.update(
            dt: deltaTime,
            shipSpeed: spaceShip.forwardSpeed,
            playerAngle: spaceShip.lateralAngle,
            progress: spaceShip.progress
        )

        // ------------------------------------------------------------
        // ALIEN FISH FLOCK
        // ------------------------------------------------------------

        flockManager.update(
            dt: deltaTime,
            shipSpeed: spaceShip.forwardSpeed,
            playerAngle: spaceShip.lateralAngle,
            progress: spaceShip.progress,
            difficulty: difficulty
        )

        // ------------------------------------------------------------
        // PLAYER LASERS
        // ------------------------------------------------------------

        for index in playerLasers.indices {

            playerLasers[index].update(
                dt: deltaTime,
                shipSpeed: spaceShip.forwardSpeed
            )
        }

        // ------------------------------------------------------------
        // ENEMY LASERS
        // ------------------------------------------------------------

        for index in enemyLasers.indices {

            enemyLasers[index].update(
                dt: deltaTime,
                shipSpeed: spaceShip.forwardSpeed
            )
        }

        // ------------------------------------------------------------
        // REMOVE OUT-OF-RANGE LASERS
        // ------------------------------------------------------------

        playerLasers.removeAll { laser in
            laser.z > 90.0 || laser.z < -5.0
        }

        enemyLasers.removeAll { laser in
            laser.z > 90.0 || laser.z < -5.0
        }

        // ------------------------------------------------------------
        // COLLISIONS
        // ------------------------------------------------------------

        checkCollisions()

        // ------------------------------------------------------------
        // PLAYER SHIP COLLISION
        // ------------------------------------------------------------

        if checkShipCollision() {

            if !shieldActive {

                gameOver = true

                stopFiring()
            }
        }

        // ------------------------------------------------------------
        // SCORE
        // ------------------------------------------------------------

        if Int(spaceShip.progress) % 10 == 0,
           frameTick % 60 == 0,
           spaceShip.progress > 0 {

            score += 1
        }
        
        // ------------------------------------------------------------
        // GAME STAGE PROGRESSION
        // ------------------------------------------------------------
        // Automatically progress game stages at score milestones.
        // Transitions happen only once.
        
        switch currentSection {
        case .asteroid:
            if score >= 20_000 {
                currentSection = .ocean
            }
        case .ocean:
            if score >= 40_000 {
                currentSection = .storm
            }
        case .storm:
            if score >= 60_000 {
                currentSection = .core
            }
        case .core:
            if score >= 80_000 {
                currentSection = .finale
            }
        case .finale:
            // Final stage reached; no further progression.
            break
        }

        // Add special logic for each stage here (entity spawning, visuals, etc.)
        // switch currentSection {
        // case .asteroid:
        //     // Asteroid stage logic
        // case .ocean:
        //     // Ocean stage logic
        // case .storm:
        //     // Storm stage logic
        // case .core:
        //     // Core stage logic
        // case .finale:
        //     // Finale stage logic
        // }

        // ------------------------------------------------------------
        // FRAME COUNTER
        // ------------------------------------------------------------

        frameTick &+= 1
    }


    private func enemyWorldDirectionTowardPlayer(
        _ enemy: EnemySpaceShip
    ) -> SCNVector3 {

        let origin = enemyWorldPosition(enemy)

        let playerRadius =
            Tunnel.radius * Tunnel.shipRadialInset

        let playerAngle =
            spaceShip.lateralAngle

        let target = SCNVector3(
            Float(
                playerRadius *
                CGFloat(cos(playerAngle))
            ),
            Float(
                playerRadius *
                CGFloat(sin(playerAngle))
            ),
            0
        )

        let dx = target.x - origin.x
        let dy = target.y - origin.y
        let dz = target.z - origin.z

        let length = sqrt(
            dx * dx +
            dy * dy +
            dz * dz
        )

        guard length > 0.0001 else {
            return SCNVector3(0, 0, -1)
        }

        return SCNVector3(
            dx / length,
            dy / length,
            dz / length
        )
    }
    private func enemyWorldPosition(_ enemy: EnemySpaceShip) -> SCNVector3 {

        let radius = Tunnel.radius * Tunnel.shipRadialInset
        let angle = enemy.lateralAngle

        return SCNVector3(
            Float(radius * CGFloat(cos(angle))),
            Float(radius * CGFloat(sin(angle))),
            Float(enemy.z)
        )
    }

    private func spawnAsteroid() {

        // ------------------------------------------------------------
        // CHOOSE ASTEROID SIZE
        // ------------------------------------------------------------

        let size: AsteroidSize = {
            let r = Double.random(in: 0...1)

            if r < 0.45 {
                return .small
            }

            if r < 0.80 {
                return .medium
            }

            return .large
        }()

        // ------------------------------------------------------------
        // RADIAL POSITION
        // ------------------------------------------------------------

        let maxR = max(
            Tunnel.minRadialOffset,
            1.0 - size.radius / Tunnel.radius - 0.05
        )

        let radialOffset = CGFloat.random(
            in: Tunnel.minRadialOffset...maxR
        )

        // ------------------------------------------------------------
        // SPAWN IN FRONT OF THE SHIP
        // ------------------------------------------------------------
        //
        // The asteroid must be inside the visible forward section
        // of the tube.
        //
        let aheadDistance =
        CGFloat(Tunnel.segmentsAhead) * Tunnel.segmentLength * -1.0

        // Start significantly further ahead of the ship so the asteroid
        // is always several units in front.
        let minimumAhead =
            max(15.0, aheadDistance * 0.85)

        let maximumAhead =
            max(minimumAhead + 8.0, aheadDistance * 0.98)

        let spawnDistance = CGFloat.random(
            in: minimumAhead...maximumAhead
        )

        let spawnZ =
            spaceShip.z + spawnDistance

        // ------------------------------------------------------------
        // CREATE ASTEROID
        // ------------------------------------------------------------

        let asteroid = Asteroid(
            lateralAngle: Double.random(
                in: 0..<(2.0 * .pi)
            ),

            z: spawnZ,

            size: size,

            radialOffset: radialOffset,

            radialVel: CGFloat.random(
                in: -0.9...0.9
            ),

            angularVel: Double.random(
                in: -0.6...0.6
            )
        )

        asteroids.append(asteroid)
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
    private func laserHitsWorld(
        laser: Laser,
        target: SCNVector3,
        tolerance: CGFloat
    ) -> Bool {

        let p = laser.worldPosition()

        let dx = CGFloat(p.x - target.x)
        let dy = CGFloat(p.y - target.y)
        let dz = CGFloat(p.z - target.z)

        let distanceSquared =
            dx * dx +
            dy * dy +
            dz * dz

        return distanceSquared <= tolerance * tolerance
    }


    private func checkCollisions() {

        var removePlayerLaser = Set<Int>()
        var removeEnemyLaser = Set<Int>()
        var removeAsteroid = Set<Int>()

        var addAsteroids: [Asteroid] = []

        // ============================================================
        // PLAYER LASERS
        // ============================================================

        for (li, laser) in playerLasers.enumerated() {

            if removePlayerLaser.contains(li) {
                continue
            }

            let laserPosition = laser.worldPosition()

            // ========================================================
            // ASTEROIDS
            // ========================================================

            for (ai, asteroid) in asteroids.enumerated() {

                if removeAsteroid.contains(ai) {
                    continue
                }

                let asteroidRadius =
                    Tunnel.radius * asteroid.radialOffset

                let asteroidPosition = SCNVector3(
                    Float(
                        asteroidRadius *
                        CGFloat(cos(asteroid.lateralAngle))
                    ),
                    Float(
                        asteroidRadius *
                        CGFloat(sin(asteroid.lateralAngle))
                    ),
                    Float(asteroid.z)
                )

                // Larger collision radius makes asteroids easier to hit.
                let collisionRadius: CGFloat

                switch asteroid.size {
                case .small:
                    collisionRadius = 1.1

                case .medium:
                    collisionRadius = 1.5

                case .large:
                    collisionRadius = 2.1
                }

                if vectorDistance(
                    laserPosition,
                    asteroidPosition
                ) <= collisionRadius {

                    removePlayerLaser.insert(li)
                    removeAsteroid.insert(ai)

                    score += asteroid.size.score

                    // Explosion
                    explosionAt(
                        angle: asteroid.lateralAngle,
                        radial: asteroid.radialOffset,
                        z: asteroid.z,
                        scale: {
                            switch asteroid.size {
                            case .small:
                                return 0.7
                            case .medium:
                                return 1.1
                            case .large:
                                return 1.6
                            }
                        }()
                    )

                    // =================================================
                    // LARGE ASTEROID SPLITS
                    // =================================================

                    if asteroid.size == .large {

                        for _ in 0..<2 {

                            addAsteroids.append(
                                Asteroid(
                                    lateralAngle:
                                        asteroid.lateralAngle +
                                        Double.random(in: -0.3...0.3),

                                    z: asteroid.z,

                                    size: .small,

                                    radialOffset:
                                        asteroid.radialOffset,

                                    radialVel:
                                        CGFloat.random(
                                            in: -0.8...0.8
                                        ),

                                    angularVel:
                                        Double.random(
                                            in: -0.8...0.8
                                        )
                                )
                            )
                        }
                    }

                    break
                }
            }

            if removePlayerLaser.contains(li) {
                continue
            }

            // ========================================================
            // ENEMY SHIP
            // ========================================================

            if let enemy = enemySpaceShip,
               !enemy.destroyed {

                let enemyPosition =
                    enemyWorldPosition(enemy)

                if vectorDistance(
                    laserPosition,
                    enemyPosition
                ) <= 1.8 {

                    removePlayerLaser.insert(li)

                    enemy.destroyed = true

                    score += 500

                    explosionAt(
                        angle: enemy.lateralAngle,
                        radial: Tunnel.shipRadialInset,
                        z: enemy.z,
                        scale: 2.0
                    )

                    enemySpaceShip = nil
                    scheduleEnemy()
                }
            }

            if removePlayerLaser.contains(li) {
                continue
            }

            // ========================================================
            // SQUID SWARM
            // ========================================================

            for alien in swarmManager.aliens
            where !alien.destroyed {

                let radius =
                    Tunnel.radius * alien.radialOffset

                let alienPosition = SCNVector3(
                    Float(
                        radius *
                        CGFloat(cos(alien.lateralAngle))
                    ),
                    Float(
                        radius *
                        CGFloat(sin(alien.lateralAngle))
                    ),
                    Float(alien.z)
                )

                if vectorDistance(
                    laserPosition,
                    alienPosition
                ) <= 1.3 {

                    removePlayerLaser.insert(li)

                    alien.destroyed = true

                    score += 75

                    explosionAt(
                        angle: alien.lateralAngle,
                        radial: alien.radialOffset,
                        z: alien.z,
                        scale: 0.9
                    )

                    break
                }
            }

            if removePlayerLaser.contains(li) {
                continue
            }

            // ========================================================
            // FISH FLOCK
            // ========================================================

            for alien in flockManager.aliens
            where !alien.destroyed {

                let radius =
                    Tunnel.radius * alien.radialOffset

                let alienPosition = SCNVector3(
                    Float(
                        radius *
                        CGFloat(cos(alien.lateralAngle))
                    ),
                    Float(
                        radius *
                        CGFloat(sin(alien.lateralAngle))
                    ),
                    Float(alien.z)
                )

                if vectorDistance(
                    laserPosition,
                    alienPosition
                ) <= 1.3 {

                    removePlayerLaser.insert(li)

                    alien.destroyed = true

                    score += 60

                    explosionAt(
                        angle: alien.lateralAngle,
                        radial: alien.radialOffset,
                        z: alien.z,
                        scale: 0.85
                    )

                    break
                }
            }
        }

        // ============================================================
        // ENEMY LASERS → PLAYER
        // ============================================================

        for (li, laser) in enemyLasers.enumerated() {

            if removeEnemyLaser.contains(li) {
                continue
            }

            let laserPosition =
                laser.worldPosition()

            let playerRadius =
                Tunnel.radius * Tunnel.shipRadialInset

            let playerAngle =
                spaceShip.lateralAngle

            let playerPosition = SCNVector3(
                Float(
                    playerRadius *
                    CGFloat(cos(playerAngle))
                ),
                Float(
                    playerRadius *
                    CGFloat(sin(playerAngle))
                ),
                0
            )

            if vectorDistance(
                laserPosition,
                playerPosition
            ) <= 1.0 {

                removeEnemyLaser.insert(li)

                if !shieldActive {

                    explosionAt(
                        angle: spaceShip.lateralAngle,
                        radial: Tunnel.shipRadialInset,
                        z: 0,
                        scale: 1.4
                    )

                    gameOver = true
                    stopFiring()
                }
            }
        }

        // ============================================================
        // REMOVE PLAYER LASERS
        // ============================================================

        playerLasers = playerLasers.enumerated()
            .filter {
                !removePlayerLaser.contains($0.offset)
            }
            .map(\.element)

        // ============================================================
        // REMOVE ENEMY LASERS
        // ============================================================

        enemyLasers = enemyLasers.enumerated()
            .filter {
                !removeEnemyLaser.contains($0.offset)
            }
            .map(\.element)

        // ============================================================
        // REMOVE DESTROYED ASTEROIDS
        // ============================================================

        asteroids = asteroids.enumerated()
            .filter {
                !removeAsteroid.contains($0.offset)
            }
            .map(\.element)

        // ============================================================
        // ADD ASTEROID FRAGMENTS
        // ============================================================

        asteroids.append(contentsOf: addAsteroids)
    }
    private func vectorDistance(_ a: SCNVector3, _ b: SCNVector3) -> CGFloat {
        let dx = CGFloat(a.x - b.x)
        let dy = CGFloat(a.y - b.y)
        let dz = CGFloat(a.z - b.z)

        return (dx * dx + dy * dy + dz * dz).squareRoot()
    }

    private func checkShipCollision() -> Bool {

        let shipAngle = spaceShip.lateralAngle

        // ============================================================
        // ASTEROIDS
        // ASTEROID COLLISION = GAME OVER
        // ============================================================

        for asteroid in asteroids {

            if hits(
                angleA: shipAngle,
                zA: 0,
                angleB: asteroid.lateralAngle,
                zB: asteroid.z,
                angleTol: 0.18,
                zTol: 1.2
            ) {

                if shieldActive {
                    continue
                }

                return true
            }
        }

        // ============================================================
        // ENEMY SHIP
        // ENEMY SHIP COLLISION = GAME OVER
        // ============================================================

        if let enemy = enemySpaceShip,
           !enemy.destroyed,
           hits(
               angleA: shipAngle,
               zA: 0,
               angleB: enemy.lateralAngle,
               zB: enemy.z,
               angleTol: 0.30,
               zTol: 1.6
           ) {

            if shieldActive {
                return false
            }

            return true
        }

        // ============================================================
        // SQUID SWARM
        // COLLISION = DEDUCT POINTS ONLY
        // ============================================================

        for alien in swarmManager.aliens where !alien.destroyed {

            if hits(
                angleA: shipAngle,
                zA: 0,
                angleB: alien.lateralAngle,
                zB: alien.z,
                angleTol: 0.28,
                zTol: 1.3
            ) {

                if shieldActive {
                    alien.destroyed = true
                    continue
                }

                // Deduct points, but DO NOT end the game.
                score = max(0, score - 25)

                // Remove the alien so the same collision cannot
                // deduct points every frame.
                alien.destroyed = true

                explosionAt(
                    angle: alien.lateralAngle,
                    radial: alien.radialOffset,
                    z: alien.z,
                    scale: 0.7
                )
            }
        }

        // ============================================================
        // DEEP-FISH FLOCK
        // COLLISION = DEDUCT POINTS ONLY
        // ============================================================

        for alien in flockManager.aliens where !alien.destroyed {

            if hits(
                angleA: shipAngle,
                zA: 0,
                angleB: alien.lateralAngle,
                zB: alien.z,
                angleTol: 0.28,
                zTol: 1.3
            ) {

                if shieldActive {
                    alien.destroyed = true
                    continue
                }

                // Deduct points, but DO NOT end the game.
                score = max(0, score - 20)

                // Remove the fish so the collision only counts once.
                alien.destroyed = true

                explosionAt(
                    angle: alien.lateralAngle,
                    radial: alien.radialOffset,
                    z: alien.z,
                    scale: 0.65
                )
            }
        }

        // ============================================================
        // ONLY ASTEROID OR ENEMY SHIP COLLISION RETURNS TRUE
        // ============================================================

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
        currentSection = .asteroid
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
struct ExplosionEvent {
    var x: CGFloat
    var y: CGFloat
    var z: CGFloat
    var scale: Float   // 0.5 small · 1.0 normal · 1.6 large
}

