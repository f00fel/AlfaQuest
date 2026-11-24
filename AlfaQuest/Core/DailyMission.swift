import Foundation

enum DailyMission: String, CaseIterable, Codable, Identifiable, Sendable {
    case threeFinds, newZone, rareFind

    var id: String { rawValue }
    var target: Int { self == .threeFinds ? 3 : 1 }

    var title: String {
        switch self {
        case .threeFinds: return "Маленькая охота"
        case .newZone: return "Новое место"
        case .rareFind: return "Удачная находка"
        }
    }

    var summary: String {
        switch self {
        case .threeFinds: return "Собери 3 объекта в течение дня."
        case .newZone: return "Найди объект в зоне, где сегодня ещё не был."
        case .rareFind: return "Найди редкую монету с наградой 3."
        }
    }

    func progress(in finds: [FoundObject]) -> Int {
        switch self {
        case .threeFinds: return min(finds.count, target)
        case .newZone: return finds.isEmpty ? 0 : 1
        case .rareFind: return finds.contains { $0.target.reward == .rareCoin } ? 1 : 0
        }
    }
}
