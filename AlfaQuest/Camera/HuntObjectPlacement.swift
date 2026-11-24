import Foundation
import simd

enum HuntObjectPlacement {
    /// Choose a world position once; turning the phone must reveal, not move, the object.
    static func position(
        relativeTo camera: simd_float4x4, using generator: inout some RandomNumberGenerator
    ) -> SIMD3<Float> {
        let projectedForward = SIMD3(-camera.columns.2.x, 0, -camera.columns.2.z)
        let fallbackForward = SIMD3(camera.columns.0.z, 0, -camera.columns.0.x)
        let forward = simd_normalize(
            simd_length_squared(projectedForward) > 0.0001 ? projectedForward : fallbackForward)
        let right = SIMD3(-forward.z, 0, forward.x)
        let angle = Float.random(in: 55...95, using: &generator) * .pi / 180
        let signedAngle = Bool.random(using: &generator) ? angle : -angle
        let distance = Float.random(in: 0.9...1.3, using: &generator)
        let height = Float.random(in: -0.25...0.15, using: &generator)
        let origin = SIMD3(camera.columns.3.x, camera.columns.3.y, camera.columns.3.z)
        return origin + (forward * cos(signedAngle) + right * sin(signedAngle)) * distance
            + SIMD3(0, height, 0)
    }
}
