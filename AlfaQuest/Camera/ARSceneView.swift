import ARKit
import SwiftUI

struct ARSceneView: UIViewRepresentable {
    let controller: ARHuntController
    let begin: (OfficeZone) -> Result<HuntAttempt, HuntError>
    let collect: (UUID) -> Result<CollectionReceipt, HuntError>
    let cancel: (UUID?) -> Void

    func makeCoordinator() -> ARHuntController { controller }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.scene = HuntSceneLighting.makeScene()
        view.automaticallyUpdatesLighting = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 30
        controller.connect(view, begin: begin, collect: collect, cancel: cancel)
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {}

    static func dismantleUIView(_ view: ARSCNView, coordinator: ARHuntController) {
        coordinator.disconnect(view)
    }

}

@MainActor
enum HuntSceneLighting {
    private static let keyName = "coinKeyLight"

    static func makeScene() -> SCNScene {
        let scene = SCNScene()
        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 250
        scene.rootNode.addChildNode(ambient)

        let light = SCNNode()
        light.name = keyName
        light.light = SCNLight()
        light.light?.type = .omni
        light.light?.intensity = 700
        light.position = SCNVector3(-0.5, 1, 0.5)
        scene.rootNode.addChildNode(light)

        return scene
    }

    static func update(for camera: SCNNode, in scene: SCNScene) {
        camera.camera?.zNear = 0.01
        let position = camera.simdWorldTransform * SIMD4<Float>(-0.5, 1, 0.5, 1)
        scene.rootNode.childNode(withName: keyName, recursively: false)?.simdPosition = SIMD3(
            position.x, position.y, position.z)
    }
}
