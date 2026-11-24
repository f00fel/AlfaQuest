import SceneKit
import UIKit

@MainActor
enum CoinNodeFactory {
    private static let radius: CGFloat = 0.065
    private static let thickness: CGFloat = 0.012

    static func make(reward: FindReward, reduceMotion: Bool) -> SCNNode {
        let root = SCNNode()
        let model =
            reward == .collectionItem ? collectionItem() : coin(kind: reward.coinKind ?? .internalCoin)
        root.addChildNode(model)
        if !reduceMotion {
            model.runAction(.repeatForever(.rotateBy(x: 0, y: .pi * 2, z: 0, duration: 6)))
        }
        let target = SCNNode(geometry: SCNSphere(radius: radius * 1.35))
        let invisible = SCNMaterial()
        invisible.colorBufferWriteMask = []
        invisible.writesToDepthBuffer = false
        target.geometry?.materials = [invisible]
        root.addChildNode(target)
        return root
    }

    static func coin(kind: CoinKind) -> SCNNode {
        let root = SCNNode()
        let color = UIColor(kind.color)
        let body = SCNCylinder(radius: radius, height: thickness)
        body.radialSegmentCount = 64
        body.materials = [metal(color)]
        let disc = SCNNode(geometry: body)
        disc.eulerAngles.x = .pi / 2
        root.addChildNode(disc)

        for side: Float in [-1, 1] {
            let face = SCNNode()
            face.position.z = side * Float(thickness / 2 + 0.001)
            if side < 0 { face.eulerAngles.y = .pi }
            face.addChildNode(ring(color: color))
            face.addChildNode(compass(color: color))
            for index in 0..<8 {
                let angle = CGFloat(index) * .pi / 4
                let dot = SCNNode(geometry: SCNSphere(radius: 0.0012))
                dot.position = SCNVector3(
                    Float(cos(angle) * radius * 0.75), Float(sin(angle) * radius * 0.75), 0.001)
                dot.geometry?.materials = [metal(color, brightness: 1.25)]
                face.addChildNode(dot)
            }
            root.addChildNode(face)
        }

        for index in 0..<48 {
            let angle = Float(index) * .pi * 2 / 48
            let ridge = SCNNode(
                geometry: SCNBox(width: 0.001, height: 0.002, length: thickness * 0.8, chamferRadius: 0.0003))
            ridge.position = SCNVector3(cos(angle) * Float(radius), sin(angle) * Float(radius), 0)
            ridge.eulerAngles.z = angle
            ridge.geometry?.materials = [metal(color, brightness: 1.15)]
            root.addChildNode(ridge)
        }
        return root
    }

    private static func ring(color: UIColor) -> SCNNode {
        let node = SCNNode(geometry: SCNTorus(ringRadius: radius * 0.88, pipeRadius: 0.001))
        node.eulerAngles.x = .pi / 2
        node.geometry?.materials = [metal(color, brightness: 1.3)]
        return node
    }

    private static func compass(color: UIColor) -> SCNNode {
        let node = SCNNode()
        for index in 0..<4 {
            let angle = CGFloat(index) * .pi / 2
            let tip = CGPoint(x: cos(angle) * 0.042, y: sin(angle) * 0.042)
            let left = CGPoint(x: cos(angle - .pi / 4) * 0.012, y: sin(angle - .pi / 4) * 0.012)
            let right = CGPoint(x: cos(angle + .pi / 4) * 0.012, y: sin(angle + .pi / 4) * 0.012)
            for (corner, brightness) in [(left, CGFloat(1.35)), (right, CGFloat(0.85))] {
                let path = UIBezierPath()
                path.move(to: .zero)
                path.addLine(to: corner)
                path.addLine(to: tip)
                path.close()
                let facet = SCNShape(path: path, extrusionDepth: 0.0018)
                facet.materials = [metal(color, brightness: brightness)]
                node.addChildNode(SCNNode(geometry: facet))
            }
        }
        return node
    }

    private static func collectionItem() -> SCNNode {
        let node = SCNNode(geometry: SCNPyramid(width: 0.09, height: 0.13, length: 0.09))
        node.geometry?.materials = [metal(UIColor(red: 0.61, green: 0.4, blue: 0.86, alpha: 1))]
        node.position.y = -0.04
        return node
    }

    private static func metal(_ color: UIColor, brightness: CGFloat = 1) -> SCNMaterial {
        let material = SCNMaterial()
        material.lightingModel = .blinn
        material.diffuse.contents = color
        material.multiply.contents = UIColor(white: brightness, alpha: 1)
        material.specular.contents = UIColor(white: 0.55, alpha: 1)
        material.shininess = 0.8
        return material
    }
}
