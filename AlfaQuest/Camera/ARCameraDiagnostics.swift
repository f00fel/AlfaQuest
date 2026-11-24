import Foundation
import OSLog

@MainActor
final class ARCameraDiagnostics {
    private let logger = Logger(subsystem: "com.alfaquest.demo", category: "ARCamera")
    private let writer = DispatchQueue(label: "com.alfaquest.ar-diagnostics", qos: .utility)
    private var entries: [Entry] = []

    func record(_ event: String) {
        logger.info("\(event, privacy: .public)")
        entries.append(Entry(date: Date(), event: event))
        entries = Array(entries.suffix(60))
        guard let library = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first else {
            return
        }
        let snapshot = entries
        let logger = logger
        writer.async {
            do {
                let directory = library.appendingPathComponent("Logs/ARCamera", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                try encoder.encode(snapshot).write(
                    to: directory.appendingPathComponent("diagnostics.json"), options: .atomic)
            } catch {
                logger.error("Cannot save AR diagnostics: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private struct Entry: Codable, Sendable {
        let date: Date
        let event: String
    }
}
