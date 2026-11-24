import Foundation

enum GameCalendar {
    static var local: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func dayKey(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func sameWeek(_ first: Date, _ second: Date, calendar: Calendar) -> Bool {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        return iso.isDate(first, equalTo: second, toGranularity: .weekOfYear)
    }

    static func streak(days: Set<String>, through date: Date, calendar: Calendar) -> (
        count: Int, start: String
    ) {
        guard let earliest = days.min() else { return (0, "") }
        var cursor = calendar.startOfDay(for: date)
        var count = 0
        var skippedDay = false
        var start = ""

        while dayKey(cursor, calendar: calendar) >= earliest {
            let day = dayKey(cursor, calendar: calendar)
            let weekday = calendar.component(.weekday, from: cursor)
            if weekday != 1 && weekday != 7 {
                if days.contains(day) {
                    count += 1
                    start = day
                } else if !skippedDay {
                    skippedDay = true
                } else {
                    break
                }
            }
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return (count, start)
    }
}

enum DailyWave: Int, CaseIterable, Codable, Identifiable, Sendable {
    case morning = 10
    case afternoon = 13
    case evening = 16

    var id: Int { rawValue }
    var title: String { String(format: "%02d:00", rawValue) }
    var endTitle: String { String(format: "%02d:00", rawValue + 2) }

    func interval(on date: Date, calendar: Calendar) -> DateInterval? {
        guard let start = calendar.date(bySettingHour: rawValue, minute: 0, second: 0, of: date),
            let end = calendar.date(bySettingHour: rawValue + 2, minute: 0, second: 0, of: date)
        else { return nil }
        return DateInterval(start: start, end: end)
    }

    static func active(at date: Date, calendar: Calendar) -> DailyWave? {
        allCases.first { wave in
            guard let interval = wave.interval(on: date, calendar: calendar) else { return false }
            return date >= interval.start && date < interval.end
        }
    }

    func status(at date: Date, calendar: Calendar) -> String {
        guard let interval = interval(on: date, calendar: calendar) else { return "Недоступна" }
        if date < interval.start { return "Впереди" }
        return date < interval.end ? "Сейчас" : "Завершена"
    }
}
