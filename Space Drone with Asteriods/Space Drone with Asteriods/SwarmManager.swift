//
//  File.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/31/26.
//

import Foundation

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
