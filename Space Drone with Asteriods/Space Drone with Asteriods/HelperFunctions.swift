//
//  File.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 9/2/26.
//

import Foundation
import SwiftUI
import SceneKit


// ============================================================
// ANGULAR DISTANCE
// ============================================================

func angularDistance(
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

func vectorDistance(
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
func distance(
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
