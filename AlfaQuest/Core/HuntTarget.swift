import Foundation

struct HuntTarget: Codable, Equatable, Identifiable {
    let id: String
    let day: String
    let wave: DailyWave
    let zone: OfficeZone
    let reward: FindReward

    static func personalTargets(playerID: UUID, at date: Date, wave: DailyWave, calendar: Calendar)
        -> [HuntTarget]
    {
        let day = GameCalendar.dayKey(date, calendar: calendar)
        let prefix = "\(playerID.uuidString)/\(day)/\(wave.rawValue)"
        var generator = StableRandom(seed: prefix)
        var shuffled = OfficeZone.allCases
        for index in stride(from: shuffled.count - 1, through: 1, by: -1) {
            let other = Int(generator.next() % UInt64(index + 1))
            shuffled.swapAt(index, other)
        }
        let zones = shuffled.prefix(GameRules.objectsPerWave)

        return zones.map { zone in
            let roll = generator.next() % 100
            let reward: FindReward
            switch roll {
            case 0..<80: reward = generator.next() % 4 == 0 ? .rareCoin : .internalCoin
            case 80..<96: reward = .collectionItem
            default: reward = .externalCoin
            }
            return HuntTarget(
                id: "\(prefix)/\(zone.rawValue)", day: day, wave: wave, zone: zone, reward: reward)
        }
    }
}

struct HuntAttempt: Codable, Equatable, Identifiable {
    let id: UUID
    let target: HuntTarget
    let startedAt: Date
    let expiresAt: Date
}

struct FoundObject: Codable, Equatable, Identifiable {
    var id: String { target.id }
    let target: HuntTarget
    let foundAt: Date
    let externalCoins: Int
}

struct CollectionReceipt: Equatable, Identifiable {
    let id: UUID
    let reward: FindReward
    let internalCoins: Int
    let externalCoins: Int
    let points: Int
    let completedMissions: Int
    let externalLimitReached: Bool
}

/// Stable across launches; Swift's randomized hashValue must never choose rewards.
private struct StableRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: String) {
        state = seed.utf8.reduce(UInt64(14_695_981_039_346_656_037)) {
            ($0 ^ UInt64($1)) &* 1_099_511_628_211
        }
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
