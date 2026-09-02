//
//  FlockAlien.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit

final class FlockAlien {

    var lateralAngle: Double

    var x: CGFloat
    var y: CGFloat
    var z: CGFloat

    var destroyed = false

    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double
    var animPhase: Float

    let bodyRadius: CGFloat = 0.22

    init(
        lateralAngle: Double,
        z: CGFloat,
        radialOffset: CGFloat = 0.65,
        radialVel: CGFloat = 0,
        angularVel: Double = 0
    ) {

        self.lateralAngle = lateralAngle

        // x and y are derived from the tunnel position.
        self.x = 0
        self.y = 0

        self.z = z

        self.radialOffset = radialOffset
        self.radialVel = radialVel
        self.angularVel = angularVel

        self.animPhase =
            Float.random(
                in: 0...(Float.pi * 2.0)
            )
    }

    func update(
        dt: CGFloat,
        shipSpeed: CGFloat,
        playerAngle: Double,
        neighbors: [FlockAlien],
        difficulty: Double = 1.0
    ) {

        guard !destroyed else {
            return
        }

        // ----------------------------------------------------
        // Forward movement
        // ----------------------------------------------------

        z -=
            shipSpeed
            * dt
            * 1.05
            * CGFloat(difficulty)

        // ----------------------------------------------------
        // Swimming animation
        // ----------------------------------------------------

        animPhase +=
            Float(dt) * 5.0

        // ----------------------------------------------------
        // FLOCKING
        // ----------------------------------------------------

        var sep: Double = 0

        var cohesionAngle: Double = 0.0

        var cohesionRadial: CGFloat = 0

        var count = 0

        for other in neighbors
        where other !== self && !other.destroyed {

            var d =
                lateralAngle -
                other.lateralAngle

            while d > .pi {
                d -= 2.0 * .pi
            }

            while d < -.pi {
                d += 2.0 * .pi
            }

            let angDist =
                abs(d)

            if
                angDist < 0.4 &&
                abs(z - other.z) < 8
            {

                // ------------------------------------------------
                // Separation
                // ------------------------------------------------

                if angDist < 0.22 {

                    sep +=
                        (d > 0 ? 1.2 : -1.2)
                        * difficulty
                }

                // ------------------------------------------------
                // Cohesion
                // ------------------------------------------------

                cohesionAngle +=
                    other.lateralAngle
                    * difficulty

                cohesionRadial +=
                    other.radialOffset
                    * CGFloat(difficulty)

                count += 1
            }
        }

        // ----------------------------------------------------
        // Seek player
        // ----------------------------------------------------

        var seek =
            playerAngle -
            lateralAngle

        while seek > .pi {
            seek -= 2.0 * .pi
        }

        while seek < -.pi {
            seek += 2.0 * .pi
        }

        angularVel +=
            (
                sep * 0.55 +
                seek * 0.35
            )
            * Double(dt)
            * difficulty

        // ----------------------------------------------------
        // Cohesion
        // ----------------------------------------------------

        if count > 0 {

            let avg =
                cohesionAngle /
                Double(count)

            var toCenter =
                avg -
                lateralAngle

            while toCenter > .pi {
                toCenter -= 2.0 * .pi
            }

            while toCenter < -.pi {
                toCenter += 2.0 * .pi
            }

            angularVel +=
                toCenter
                * 0.25
                * Double(dt)
                * difficulty

            radialVel +=
                (
                    cohesionRadial /
                    CGFloat(count)
                    -
                    radialOffset
                )
                * 0.4
                * dt
                * CGFloat(difficulty)
        }

        // ----------------------------------------------------
        // Apply angular movement
        // ----------------------------------------------------

        angularVel *= 0.93

        lateralAngle +=
            angularVel *
            Double(dt)

        // ----------------------------------------------------
        // Keep alien inside tunnel
        // ----------------------------------------------------

        TubePhysics.integrateRadial(
            radialOffset: &radialOffset,
            radialVel: &radialVel,
            entityRadius: bodyRadius,
            dt: dt
        )

        radialVel *= 0.985

        // ----------------------------------------------------
        // Keep x/y synchronized with tunnel position
        // ----------------------------------------------------

        let r =
            Tunnel.radius *
            radialOffset

        x =
            r *
            CGFloat(cos(lateralAngle))

        y =
            r *
            CGFloat(sin(lateralAngle))
    }

    // --------------------------------------------------------
    // SceneKit position
    // --------------------------------------------------------

    var position: SCNVector3 {

        let r =
            Float(
                Tunnel.radius *
                radialOffset
            )

        return SCNVector3(
            r * Float(cos(lateralAngle)),
            r * Float(sin(lateralAngle)),
            Float(z)
        )
    }
}
