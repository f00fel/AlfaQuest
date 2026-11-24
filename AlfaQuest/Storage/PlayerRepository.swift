import Foundation

enum StorageError: Error, LocalizedError {
    case unreadableProfile
    case newerVersion

    var errorDescription: String? {
        switch self {
        case .unreadableProfile: return "Не удалось прочитать сохранённый профиль. Исходные данные сохранены."
        case .newerVersion: return "Профиль сохранён более новой версией приложения. Обнови приложение."
        }
    }
}

struct PlayerRepository {
    static let key = "alfaquest.player-state.v3"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func load() throws -> PlayerState {
        if let data = defaults.data(forKey: Self.key) {
            do {
                let header = try JSONDecoder().decode(VersionHeader.self, from: data)
                guard header.version == PlayerState.schemaVersion else { throw StorageError.newerVersion }
                let state = try JSONDecoder().decode(PlayerState.self, from: data)
                guard state.hasValidSave else { throw StorageError.unreadableProfile }
                return state
            } catch let error as StorageError {
                throw error
            } catch {
                throw StorageError.unreadableProfile
            }
        }
        guard let data = defaults.data(forKey: "alfaquest.local-profile.v1") else { return PlayerState() }
        do {
            let legacy = try JSONDecoder().decode(LegacyProfile.self, from: data)
            var wallet = Wallet()
            wallet.creditInternal(legacy.coinHunt?.totalCollected ?? 0)
            let profile = PlayerProfile(
                name: legacy.name, department: legacy.department, isRegistered: legacy.hasStarted)
            let migrated = PlayerState(
                profile: profile, wallet: wallet, loginDays: legacy.activeDays ?? [],
                attendanceDays: Set([legacy.checkInDay].compactMap { $0 }),
                legacyFindCount: max(0, legacy.coinHunt?.totalCollected ?? 0))
            try save(migrated)
            return migrated
        } catch {
            throw StorageError.unreadableProfile
        }
    }

    func save(_ state: PlayerState) throws {
        defaults.set(try JSONEncoder().encode(state), forKey: Self.key)
    }
}

private struct VersionHeader: Decodable {
    let version: Int
}

private struct LegacyProfile: Decodable {
    let name: String
    let department: String
    let hasStarted: Bool
    let checkInDay: String?
    let activeDays: Set<String>?
    let coinHunt: LegacyCoins?
}

private struct LegacyCoins: Decodable {
    let totalCollected: Int
}
