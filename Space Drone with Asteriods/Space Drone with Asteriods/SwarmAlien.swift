//
//  SwarmAlien.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation
import SceneKit

//
//  SwarmAlien.swift
//  Space Drone with Asteriods
//

import Foundation
import SceneKit

final class SwarmAlien {

    var lateralAngle: Double

    var x: CGFloat
    var y: CGFloat
    var z: CGFloat

    var destroyed = false

    var radialOffset: CGFloat
    var radialVel: CGFloat
    var angularVel: Double

    var animPhase: Float

    let bodyRadius: CGFloat = 0.32

    init(
        lateralAngle: Double,
        z: CGFloat,
        radialOffset: CGFloat = 0.7,
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
            * CGFloat(difficulty)

        // ----------------------------------------------------
        // Animation
        // ----------------------------------------------------

        animPhase +=
            Float(dt)
            * 4.5
            * Float(difficulty)

        // ----------------------------------------------------
        // Seek toward player
        // ----------------------------------------------------

        var delta =
            playerAngle -
            lateralAngle

        while delta > .pi {
            delta -= 2.0 * .pi
        }

        while delta < -.pi {
            delta += 2.0 * .pi
        }

        angularVel +=
            delta
            * 1.1
            * Double(dt)
            * difficulty

        // ----------------------------------------------------
        // Angular damping
        // ----------------------------------------------------

        angularVel *=
            pow(
                0.94,
                difficulty
            )

        // ----------------------------------------------------
        // Apply angular movement
        // ----------------------------------------------------

        lateralAngle +=
            angularVel *
            Double(dt)

        // ----------------------------------------------------
        // Random radial movement
        // ----------------------------------------------------

        radialVel +=
            CGFloat.random(
                in: -0.15...0.15
            )
            * dt
            * CGFloat(difficulty)

        // ----------------------------------------------------
        // Tunnel boundary physics
        // ----------------------------------------------------

        TubePhysics.integrateRadial(
            radialOffset: &radialOffset,
            radialVel: &radialVel,
            entityRadius: bodyRadius,
            dt: dt
        )

        // ----------------------------------------------------
        // Radial damping
        // ----------------------------------------------------

        radialVel *=
            pow(
                0.99,
                CGFloat(difficulty)
            )

        // ----------------------------------------------------
        // Keep x/y synchronized with tunnel position
        // ----------------------------------------------------

        let radius =
            Tunnel.radius *
            radialOffset

        x =
            radius *
            CGFloat(
                cos(lateralAngle)
            )

        y =
            radius *
            CGFloat(
                sin(lateralAngle)
            )
    }

    // --------------------------------------------------------
    // SceneKit world position
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
