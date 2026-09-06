import Foundation
import SwiftUI
import SceneKit

final class TerrainSceneWorld {
    // The main SceneKit scene
    let scene = SCNScene()
    let camera = SCNNode()
    
    // Terrain and entity containers
    private let terrainContainer = SCNNode()
    private let shipRoot = SCNNode()
    private let enemyRoot = SCNNode()
    private let sharkContainer = SCNNode()
    private let laserContainer = SCNNode()
    
    // Terrain generation tracking
    private var lastShipZ: Float = 0.0
    private var terrainSegments: [SCNNode] = []
    
    // Camera/cockpit setup (replicate essentials from TunnelSceneWorld)
    // ... (add as needed)

    init() {
        scene.background.contents = UIColor.black
        scene.fogColor = UIColor(
            red: 0.08, green: 0.12, blue: 0.16, alpha: 1
        )
        scene.fogStartDistance = 30
        scene.fogEndDistance = 140

        setupLighting()
        setupCamera()
        setupTerrain()
        setupShip()
        setupEnemy()

        scene.rootNode.addChildNode(terrainContainer)
        scene.rootNode.addChildNode(shipRoot)
        scene.rootNode.addChildNode(enemyRoot)
        scene.rootNode.addChildNode(sharkContainer)
        scene.rootNode.addChildNode(laserContainer)
    }

    // MARK: - Lighting
    private func setupLighting() {
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.color = UIColor(white: 0.2, alpha: 1)
        scene.rootNode.addChildNode(ambient)

        let sun = SCNNode()
        sun.light = SCNLight()
        sun.light?.type = .directional
        sun.light?.color = UIColor(white: 0.9, alpha: 1)
        sun.eulerAngles = SCNVector3(-Float.pi / 5, Float.pi / 4, 0)
        scene.rootNode.addChildNode(sun)
    }

    // MARK: - Camera Setup
    private func setupCamera() {
        let cam = SCNCamera()
        cam.zNear = 0.1
        cam.zFar = 200
        cam.fieldOfView = 74
        camera.camera = cam
        camera.position = SCNVector3(0, 2.5, -8.0)
        scene.rootNode.addChildNode(camera)
    }

    // MARK: - Terrain Setup
    private func setupTerrain() {
        // Generate initial terrain segment(s)
        for i in 0..<8 {
            let z = Float(i) * 10.0
            let segment = makeTerrainSegment(z: z)
            segment.position = SCNVector3(0, 0, z)
            terrainContainer.addChildNode(segment)
            terrainSegments.append(segment)
        }
    }

    private func makeTerrainSegment(z: Float) -> SCNNode {
        // This is a placeholder: replace with fractal mesh later
        // For now: a bumpy plane
        let width: CGFloat = 18.0
        let length: CGFloat = 10.0
        let geometry = SCNPlane(width: width, height: length)
        geometry.firstMaterial?.diffuse.contents = UIColor.brown
        geometry.firstMaterial?.isDoubleSided = true
        let node = SCNNode(geometry: geometry)
        node.position = SCNVector3(0, -1.5, z)
        node.eulerAngles.x = -.pi / 2
        return node
    }

    // MARK: - Ship
    private func setupShip() {
        // Minimal placeholder
        let bodyGeo = SCNCapsule(capRadius: 0.35, height: 1.8)
        bodyGeo.firstMaterial?.diffuse.contents = UIColor.white
        let shipMesh = SCNNode(geometry: bodyGeo)
        shipRoot.addChildNode(shipMesh)
        shipRoot.position = SCNVector3(0, 0, 0)
    }

    // MARK: - Enemy
    private func setupEnemy() {
        let geo = SCNCone(topRadius: 0, bottomRadius: 0.45, height: 1.2)
        geo.firstMaterial?.diffuse.contents = UIColor.red
        enemyRoot.geometry = geo
        enemyRoot.position = SCNVector3(3, 0, 20)
    }

    // MARK: - Sync/Update with GameState
    func sync(with gameState: GameState) {
        // TODO: Update positions and add logic for dynamic terrain extension
        // (to be filled in future steps)
    }
}
