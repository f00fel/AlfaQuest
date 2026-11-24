import Foundation

enum OfficeZone: String, CaseIterable, Codable, Identifiable, Sendable {
    case coffee, meeting, it, reception, lobby, library, secret, work

    var id: String { rawValue }
    var markerName: String { "marker-\(rawValue)" }

    var title: String {
        switch self {
        case .coffee: return "Кофе-пойнт"
        case .meeting: return "Переговорная"
        case .it: return "IT-отдел"
        case .reception: return "Приёмная"
        case .lobby: return "Ресепшен"
        case .library: return "Библиотека"
        case .secret: return "Секретная точка"
        case .work: return "Рабочая зона"
        }
    }
}
