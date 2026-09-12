//
//  FlockManager.swift
//  Space Drone with Asteriods
//
//  Created by David Nishimoto on 8/30/26.
//

import Foundation

final class FlockManager {
    private(set) var aliens: [FlockAlien] = []
    private var spawnClock: CGFloat = 0
    private let spawnInterval: CGFloat = 3.4
    private let maxPopulation = 16

    func reset() { aliens.removeAll(); spawnClock = 0 }

    func update(dt: CGFloat, shipSpeed: CGFloat, playerAngle: Double, progress: CGFloat, difficulty: Double = 1.0) {
        spawnClock += dt
        if spawnClock >= spawnInterval && aliens.count < maxPopulation {
            spawnClock = 0
            spawnWave(difficulty: difficulty)
        }
        let living = aliens.filter { !$0.destroyed }
        for a in living {
            a.update(dt: dt, shipSpeed: shipSpeed, playerAngle: playerAngle, neighbors: living, difficulty: difficulty)
        }
        aliens.removeAll { $0.destroyed || $0.z < -4 }
    }

    private func spawnWave(difficulty: Double) {
        let baseCount = Int.random(in: 5...9)
        let count = min(maxPopulation, Int(Double(baseCount) * (0.9 + difficulty * 0.5)))
        let baseZ = CGFloat.random(in: 50...75) * CGFloat(0.9 + difficulty * 0.5)
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
