// TunnelSceneWorld.swift

import Foundation
import SceneKit

/// TunnelSceneWorld is responsible for rendering and managing
/// the tunnel and related entities such as asteroids, the default tube visuals, etc.
class TunnelSceneWorld {
    
    /// The main scene for the tunnel world
    let scene: SCNScene
    
    /// The root node of the tunnel
    let tunnelNode = SCNNode()
    
    /// Array holding asteroid nodes
    var asteroids: [SCNNode] = []
    
    /// Initializes the tunnel scene world and sets up tunnel and asteroid nodes
    init() {
        scene = SCNScene()
        setupTunnel()
        setupAsteroids()
    }
    
    /// Sets up the tunnel visuals including the default tube
    private func setupTunnel() {
        // Create a tube geometry for the tunnel
        let tube = SCNTube(innerRadius: 1.0, outerRadius: 1.2, height: 50.0)
        tube.firstMaterial?.diffuse.contents = UIColor.gray
        
        let tubeNode = SCNNode(geometry: tube)
        tubeNode.position = SCNVector3(0, 0, -25)
        
        // Add tube node to tunnel root
        tunnelNode.addChildNode(tubeNode)
        
        // Add tunnel root to the scene
        scene.rootNode.addChildNode(tunnelNode)
    }
    
    /// Sets up asteroids inside the tunnel
    private func setupAsteroids() {
        // For example, add 10 asteroids randomly positioned inside the tunnel
        for _ in 0..<10 {
            let asteroid = createAsteroid()
            asteroids.append(asteroid)
            tunnelNode.addChildNode(asteroid)
        }
    }
    
    /// Creates a single asteroid node with geometry and material
    private func createAsteroid() -> SCNNode {
        let sphere = SCNSphere(radius: 0.2)
        sphere.firstMaterial?.diffuse.contents = UIColor.brown
        
        let asteroidNode = SCNNode(geometry: sphere)
        asteroidNode.position = SCNVector3(
            Float.random(in: -0.8...0.8),
            Float.random(in: -0.8...0.8),
            Float.random(in: -25...25)
        )
        
        return asteroidNode
    }
    
    /// Updates the tunnel scene world (e.g., animating asteroids or tunnel)
    func update(deltaTime: TimeInterval) {
        for asteroid in asteroids {
            // Example animation: rotate each asteroid
            asteroid.eulerAngles.y += Float(deltaTime)
        }
    }
    
}
