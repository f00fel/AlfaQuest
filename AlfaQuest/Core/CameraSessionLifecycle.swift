import Foundation

/// A run belongs to one visible, active camera. Late work from older runs is ignored.
struct CameraSessionLifecycle {
    enum Phase: Equatable {
        case idle
        case preparing(UUID)
        case running(UUID)
        case interrupted(UUID)
        case failed
    }

    private(set) var phase = Phase.idle
    private(set) var isActive = false
    private var isAttached = false

    mutating func attach() {
        isAttached = true
        phase = .idle
    }

    mutating func detach() {
        isAttached = false
        phase = .idle
    }

    mutating func setActive(_ active: Bool) {
        isActive = active
        if !active { phase = .idle }
    }

    mutating func prepare() -> UUID? {
        guard isAttached, isActive, phase == .idle else { return nil }
        let run = UUID()
        phase = .preparing(run)
        return run
    }

    mutating func start(_ run: UUID) -> Bool {
        guard isAttached, isActive, phase == .preparing(run) else { return false }
        phase = .running(run)
        return true
    }

    func acceptsEvents(from run: UUID) -> Bool {
        isAttached && isActive && phase == .running(run)
    }

    mutating func fail(_ run: UUID) -> Bool {
        guard phase == .preparing(run) || phase == .running(run) || phase == .interrupted(run) else {
            return false
        }
        phase = .failed
        return true
    }

    mutating func interrupt(_ run: UUID) -> Bool {
        guard acceptsEvents(from: run) else { return false }
        phase = .interrupted(run)
        return true
    }

    mutating func resume(_ run: UUID) -> Bool {
        guard isAttached, isActive, phase == .interrupted(run) else { return false }
        phase = .idle
        return true
    }

    mutating func reset() {
        phase = .idle
    }
}
