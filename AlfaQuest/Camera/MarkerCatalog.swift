import ARKit
import UIKit

@MainActor
final class MarkerCatalog {
    private var cached: Set<ARReferenceImage>?

    func images(diagnostics: ARCameraDiagnostics) async throws -> Set<ARReferenceImage> {
        if let cached { return cached }
        var validated: Set<ARReferenceImage> = []
        for zone in OfficeZone.allCases {
            try Task.checkCancellation()
            guard let image = UIImage(named: "zone-\(zone.rawValue)")?.cgImage else {
                diagnostics.record("Missing marker: \(zone.rawValue)")
                continue
            }
            // Build on the device so reference processing matches its ARKit version.
            let reference = ARReferenceImage(image, orientation: .up, physicalWidth: 0.12)
            reference.name = zone.markerName
            do {
                try await reference.validate()
                validated.insert(reference)
            } catch {
                let error = error as NSError
                diagnostics.record(
                    "Rejected marker \(zone.rawValue): \(error.domain)/\(error.code), \(error.localizedDescription)"
                )
            }
        }
        try Task.checkCancellation()
        guard !validated.isEmpty else {
            throw NSError(domain: ARErrorDomain, code: ARError.Code.invalidReferenceImage.rawValue)
        }
        cached = validated
        diagnostics.record("Validated markers: \(validated.count)/\(OfficeZone.allCases.count)")
        return validated
    }
}
