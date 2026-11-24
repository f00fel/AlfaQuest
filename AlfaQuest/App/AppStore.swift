import Combine
import Foundation

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state: PlayerState
    @Published private(set) var recoveryRequired = false
    @Published var message: String?

    let calendar: Calendar
    private let repository: PlayerRepository
    private let clock: () -> Date

    init(
        defaults: UserDefaults = .standard, calendar: Calendar = GameCalendar.local,
        clock: @escaping () -> Date = Date.init
    ) {
        repository = PlayerRepository(defaults: defaults)
        self.calendar = calendar
        self.clock = clock
        do {
            state = try repository.load()
        } catch {
            state = PlayerState()
            recoveryRequired = true
            message = error.localizedDescription
        }
        if !recoveryRequired {
            refresh()
        }
    }

    var now: Date { clock() }

    func saveProfile(name: String, department: String) {
        commit { state in
            guard state.updateProfile(name: name, department: department) else { return }
            state.recordLogin(at: now, calendar: calendar)
        }
    }

    func refresh() {
        guard !recoveryRequired else { return }
        commit { state in
            state.cancelAttempt()
            state.recordLogin(at: now, calendar: calendar)
        }
    }

    func checkIn() {
        let date = now
        commit { state in
            state.recordLogin(at: date, calendar: calendar)
            state.checkIn(at: date, calendar: calendar)
        }
    }

    func beginAttempt(in zone: OfficeZone) -> Result<HuntAttempt, HuntError> {
        do {
            let attempt = try transaction { try $0.beginAttempt(in: zone, at: now, calendar: calendar) }
            return .success(attempt)
        } catch let error as HuntError {
            return .failure(error)
        } catch {
            message = error.localizedDescription
            return .failure(.storageUnavailable)
        }
    }

    func collect(attemptID: UUID) -> Result<CollectionReceipt, HuntError> {
        do {
            return .success(
                try transaction { try $0.collect(attemptID: attemptID, at: now, calendar: calendar) })
        } catch let error as HuntError {
            return .failure(error)
        } catch {
            message = error.localizedDescription
            return .failure(.storageUnavailable)
        }
    }

    func cancelAttempt(id: UUID? = nil) {
        guard state.activeAttempt != nil else { return }
        commit { $0.cancelAttempt(id: id) }
    }

    func reset() {
        do {
            let fresh = PlayerState()
            try repository.save(fresh)
            state = fresh
            recoveryRequired = false
            message = nil
        } catch {
            message = error.localizedDescription
        }
    }

    private func commit(_ update: (inout PlayerState) -> Void) {
        do {
            try transaction(update)
        } catch {
            message = error.localizedDescription
        }
    }

    @discardableResult
    private func transaction<Value>(_ update: (inout PlayerState) throws -> Value) throws -> Value {
        guard !recoveryRequired else { throw StorageError.unreadableProfile }
        var next = state
        let value = try update(&next)
        guard next != state else { return value }
        try repository.save(next)
        state = next
        return value
    }
}
