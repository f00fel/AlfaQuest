import Foundation

enum GameRules {
    static let objectsPerWave = 3
    static let dailyFindLimit = 12
    static let externalFindLimitPerWeek = 3
    static let internalBalanceLimit = 100
    static let attemptDuration: TimeInterval = 25
    static let attemptsPerObject = 3
    static let checkInReward = 2
    static let loginPoints = 5
    static let findPoints = 10
    static let missionPoints = 20
    static let missionReward = 1
    static let allMissionsReward = 2
}

enum CoinKind: String, CaseIterable, Codable, Sendable {
    case internalCoin
    case externalCoin
    case superCoin

    var title: String {
        switch self {
        case .internalCoin: return "Внутренние"
        case .externalCoin: return "Внешние"
        case .superCoin: return "Супер"
        }
    }
}

struct Wallet: Codable, Equatable {
    private(set) var internalCoins = 0
    private(set) var externalCoins = 0
    private(set) var superCoins = 0

    var isValid: Bool {
        (0...GameRules.internalBalanceLimit).contains(internalCoins)
            && externalCoins >= 0 && superCoins >= 0
    }

    subscript(kind: CoinKind) -> Int {
        switch kind {
        case .internalCoin: return internalCoins
        case .externalCoin: return externalCoins
        case .superCoin: return superCoins
        }
    }

    @discardableResult
    mutating func creditInternal(_ amount: Int) -> Int {
        let credited = min(max(amount, 0), GameRules.internalBalanceLimit - internalCoins)
        internalCoins += credited
        return credited
    }

    mutating func creditExternal(_ amount: Int) {
        externalCoins += max(amount, 0)
    }
}

enum FindReward: String, Codable, CaseIterable, Sendable {
    case internalCoin
    case rareCoin
    case collectionItem
    case externalCoin

    var title: String {
        switch self {
        case .internalCoin: return "Внутренняя монета"
        case .rareCoin: return "Редкая находка"
        case .collectionItem: return "Предмет коллекции"
        case .externalCoin: return "Внешняя монета"
        }
    }

    var internalCoins: Int {
        switch self {
        case .internalCoin: return 1
        case .rareCoin: return 3
        case .collectionItem, .externalCoin: return 0
        }
    }

    var coinKind: CoinKind? {
        switch self {
        case .internalCoin, .rareCoin: return .internalCoin
        case .externalCoin: return .externalCoin
        case .collectionItem: return nil
        }
    }
}

enum HuntError: Error, Equatable, LocalizedError, Sendable {
    case profileRequired
    case checkInRequired
    case noActiveWave
    case noObjectHere
    case alreadyCollected
    case attemptsExhausted
    case attemptExpired
    case staleAttempt
    case dailyLimit
    case storageUnavailable

    var errorDescription: String? {
        switch self {
        case .profileRequired: return "Сначала заполни профиль."
        case .checkInRequired: return "Сначала отметься в офисе на главной."
        case .noActiveWave: return "Сейчас перерыв между волнами. Следующая охота — по расписанию."
        case .noObjectHere: return "В этой зоне нет твоего объекта в текущей волне."
        case .alreadyCollected: return "Этот объект уже собран. Попробуй другую зону."
        case .attemptsExhausted: return "Три попытки использованы. Новые объекты появятся в следующей волне."
        case .attemptExpired: return "Время вышло. Наведи камеру на постер и попробуй снова."
        case .staleAttempt: return "Эта попытка уже завершена."
        case .dailyLimit: return "Все находки на сегодня собраны. Возвращайся завтра."
        case .storageUnavailable: return "Не удалось сохранить находку. Попробуй ещё раз."
        }
    }
}
