//
//  OceanGameState.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 9/2/26.
//
import Foundation
import SceneKit

@MainActor
enum OceanGameState {

    // ============================================================
    // OCEAN STATE
    // ============================================================

    static var sharks: [Shark] = []

    // Magnetic current affecting the ship.
    static var magneticCurrent =
        CGVector(dx: 0, dy: 0)

    // Current strength.
    static var magneticCurrentStrength:
        CGFloat = 0.0

    // ============================================================
    // UPDATE
    // ============================================================

    static func update(
        game: GameState,
        dt: CGFloat
    ) {

        // --------------------------------------------------------
        // MAGNETIC CURRENT
        // --------------------------------------------------------

        updateMagneticCurrent(
            game: game,
            dt: dt
        )

        // --------------------------------------------------------
        // SQUIDS
        // --------------------------------------------------------

        game.swarmManager.update(
            dt: dt,
            shipSpeed:
                game.spaceShip.forwardSpeed,
            playerAngle:
                game.spaceShip.lateralAngle,
            progress:
                game.spaceShip.progress
        )

        // --------------------------------------------------------
        // FISH
        // --------------------------------------------------------

        let difficulty =
            1.0 +
            min(
                Double(game.score),
                400.0
            ) /
            400.0 *
            2.0

        game.flockManager.update(
            dt: dt,
            shipSpeed:
                game.spaceShip.forwardSpeed,
            playerAngle:
                game.spaceShip.lateralAngle,
            progress:
                game.spaceShip.progress,
            difficulty:
                difficulty
        )

        // --------------------------------------------------------
        // SHARKS
        // --------------------------------------------------------

        updateSharks(
            game: game,
            dt: dt
        )

        // --------------------------------------------------------
        // OCEAN COLLISIONS
        // --------------------------------------------------------

        checkCollisions(
            game: game
        )
    }

    // ============================================================
    // MAGNETIC CURRENT
    // ============================================================

    private static func updateMagneticCurrent(
        game: GameState,
        dt: CGFloat
    ) {

        let time =
            CGFloat(game.frameTick) * dt

        // Oscillating electromagnetic turbulence.
        let horizontal =
            sin(time * 1.7)

        let vertical =
            cos(time * 1.3)

        magneticCurrentStrength =
            0.35 +
            0.20 *
            abs(sin(time * 0.8))

        magneticCurrent =
            CGVector(

                dx:
                    horizontal *
                    magneticCurrentStrength,

                dy:
                    vertical *
                    magneticCurrentStrength
            )

        // --------------------------------------------------------
        // PUSH SHIP
        // --------------------------------------------------------

        // Magnetic currents physically push the ship
        // while it crosses the Alien Ocean.

        game.spaceShip.verticalPosition +=
            Double(
                magneticCurrent.dy *
                dt *
                4.0
            )

        game.spaceShip.lateralAngle +=
            Double(
                magneticCurrent.dx *
                dt *
                0.25
            )
    }

    // ============================================================
    // SHARKS
    // ============================================================

    private static func updateSharks(
        game: GameState,
        dt: CGFloat
    ) {

        for shark in sharks {

            shark.update(
                dt: dt,
                shipSpeed:
                    game.spaceShip.forwardSpeed,
                playerAngle:
                    game.spaceShip.lateralAngle
            )
        }

        sharks.removeAll {
            $0.z < -10.0
        }
    }

    // ============================================================
    // COLLISIONS
    // ============================================================

    private static func checkCollisions(
        game: GameState
    ) {

        // --------------------------------------------------------
        // PLAYER LASERS → SQUIDS
        // --------------------------------------------------------

        for laser in game.playerLasers {

            let laserPosition =
                laser.worldPosition()

            for alien in
                game.swarmManager.aliens
                where !alien.destroyed {

                let radius =
                    Tunnel.radius *
                    alien.radialOffset

                let position =
                    SCNVector3(

                        Float(
                            radius *
                            CGFloat(
                                cos(
                                    alien.lateralAngle
                                )
                            )
                        ),

                        Float(
                            radius *
                            CGFloat(
                                sin(
                                    alien.lateralAngle
                                )
                            )
                        ),

                        Float(alien.z)
                    )

                if distance(
                    laserPosition,
                    position
                ) <= 1.3 {

                    alien.destroyed = true

                    game.score += 75

                    game.spawnExplosion(
                        x:
                            CGFloat(position.x),
                        y:
                            CGFloat(position.y),
                        z:
                            CGFloat(position.z),
                        scale:
                            0.9
                    )
                }
            }
        }

        // --------------------------------------------------------
        // PLAYER LASERS → FISH
        // --------------------------------------------------------

        for laser in game.playerLasers {

            let laserPosition =
                laser.worldPosition()

            for alien in
                game.flockManager.aliens
                where !alien.destroyed {

                let radius =
                    Tunnel.radius *
                    alien.radialOffset

                let position =
                    SCNVector3(

                        Float(
                            radius *
                            CGFloat(
                                cos(
                                    alien.lateralAngle
                                )
                            )
                        ),

                        Float(
                            radius *
                            CGFloat(
                                sin(
                                    alien.lateralAngle
                                )
                            )
                        ),

                        Float(alien.z)
                    )

                if distance(
                    laserPosition,
                    position
                ) <= 1.3 {

                    alien.destroyed = true

                    game.score += 60

                    game.spawnExplosion(
                        x:
                            CGFloat(position.x),
                        y:
                            CGFloat(position.y),
                        z:
                            CGFloat(position.z),
                        scale:
                            0.85
                    )
                }
            }
        }

        // --------------------------------------------------------
        // SHIP → SQUID
        // --------------------------------------------------------

        let shipAngle =
            game.spaceShip.lateralAngle

        for alien in
            game.swarmManager.aliens
            where !alien.destroyed {

            if hitsShip(
                angle:
                    alien.lateralAngle,
                z:
                    alien.z,
                shipAngle:
                    shipAngle
            ) {

                if game.shieldActive {

                    alien.destroyed = true

                    continue
                }

                game.score =
                    max(
                        0,
                        game.score - 25
                    )

                alien.destroyed = true
            }
        }

        // --------------------------------------------------------
        // SHIP → FISH
        // --------------------------------------------------------

        for alien in
            game.flockManager.aliens
            where !alien.destroyed {

            if hitsShip(
                angle:
                    alien.lateralAngle,
                z:
                    alien.z,
                shipAngle:
                    shipAngle
            ) {

                if game.shieldActive {

                    alien.destroyed = true

                    continue
                }

                game.score =
                    max(
                        0,
                        game.score - 20
                    )

                alien.destroyed = true
            }
        }

        // --------------------------------------------------------
        // SHIP → SHARK
        // --------------------------------------------------------

        for shark in sharks
        where !shark.destroyed {

            if hitsShip(
                angle:
                    shark.lateralAngle,
                z:
                    shark.z,
                shipAngle:
                    shipAngle
            ) {

                if game.shieldActive {

                    shark.destroyed = true

                    continue
                }

                // Shark is a major Ocean opponent.
                game.gameOver = true

                game.stopFiring()
            }
        }
    }

    // ============================================================
    // SHIP COLLISION
    // ============================================================

    private static func hitsShip(
        angle: Double,
        z: CGFloat,
        shipAngle: Double
    ) -> Bool {

        let angleDifference =
            angularDistance(
                angle,
                shipAngle
            )

        return
            abs(z) < 1.6 &&
            angleDifference < 0.30
    }

    // ============================================================
    // ANGULAR DISTANCE
    // ============================================================

    private static func angularDistance(
        _ a: Double,
        _ b: Double
    ) -> Double {

        var d =
            abs(a - b)

        while d > .pi {
            d =
                abs(
                    d -
                    2.0 * .pi
                )
        }

        return d
    }

    // ============================================================
    // VECTOR DISTANCE
    // ============================================================

    private static func distance(
        _ a: SCNVector3,
        _ b: SCNVector3
    ) -> CGFloat {

        let dx =
            CGFloat(a.x - b.x)

        let dy =
            CGFloat(a.y - b.y)

        let dz =
            CGFloat(a.z - b.z)

        return (
            dx * dx +
            dy * dy +
            dz * dz
        ).squareRoot()
    }

    // ============================================================
    // RESET
    // ============================================================

    static func reset() {

        sharks.removeAll()

        magneticCurrent =
            .zero

        magneticCurrentStrength =
            0.0
    }
}
