import Foundation

struct PlayerProfile: Codable, Equatable {
    let id: UUID
    var name: String
    var department: String
    var isRegistered: Bool

    init(id: UUID = UUID(), name: String = "", department: String = "", isRegistered: Bool = false) {
        self.id = id
        self.name = name
        self.department = department
        self.isRegistered = isRegistered
    }

    var firstName: String { name.split(separator: " ").first.map(String.init) ?? "друг" }
    var initials: String { String(name.prefix(1)).uppercased() }
}

struct PlayerState: Codable, Equatable {
    static let schemaVersion = 3

    private(set) var version = schemaVersion
    private(set) var profile: PlayerProfile
    private(set) var wallet: Wallet
    private(set) var loginDays: Set<String>
    private(set) var attendanceDays: Set<String>
    private(set) var finds: [FoundObject] = []
    private(set) var attemptCounts: [String: Int] = [:]
    private(set) var activeAttempt: HuntAttempt?
    private(set) var claimedMissions: [String: Set<DailyMission>] = [:]
    private(set) var claimedDailyBonuses: Set<String> = []
    private(set) var claimedStreakBonuses: Set<String> = []
    private(set) var points = 0
    private(set) var legacyFindCount: Int

    init(
        profile: PlayerProfile = PlayerProfile(), wallet: Wallet = Wallet(), loginDays: Set<String> = [],
        attendanceDays: Set<String> = [], legacyFindCount: Int = 0
    ) {
        self.profile = profile
        self.wallet = wallet
        self.loginDays = loginDays
        self.attendanceDays = attendanceDays
        self.legacyFindCount = legacyFindCount
    }

    var totalFinds: Int { legacyFindCount + finds.count }

    var hasValidSave: Bool {
        wallet.isValid && points >= 0 && legacyFindCount >= 0
            && Set(finds.map(\.id)).count == finds.count
            && attemptCounts.values.allSatisfy { (1...GameRules.attemptsPerObject).contains($0) }
            && finds.allSatisfy { (0...1).contains($0.externalCoins) }
    }

    func isCheckedIn(at date: Date, calendar: Calendar) -> Bool {
        attendanceDays.contains(GameCalendar.dayKey(date, calendar: calendar))
    }

    func finds(on date: Date, calendar: Calendar) -> [FoundObject] {
        let day = GameCalendar.dayKey(date, calendar: calendar)
        return finds.filter { $0.target.day == day }
    }

    func targets(at date: Date, calendar: Calendar) -> [HuntTarget] {
        guard let wave = DailyWave.active(at: date, calendar: calendar) else { return [] }
        return HuntTarget.personalTargets(playerID: profile.id, at: date, wave: wave, calendar: calendar)
    }

    func hasCollected(_ target: HuntTarget) -> Bool {
        finds.contains { $0.id == target.id }
    }

    func attemptsRemaining(for target: HuntTarget) -> Int {
        max(0, GameRules.attemptsPerObject - attemptCounts[target.id, default: 0])
    }

    mutating func updateProfile(name: String, department: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let department = department.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !department.isEmpty, name.count <= 60, department.count <= 60 else {
            return false
        }
        profile.name = name
        profile.department = department
        profile.isRegistered = true
        return true
    }

    @discardableResult
    mutating func recordLogin(at date: Date, calendar: Calendar) -> Bool {
        guard profile.isRegistered else { return false }
        let day = GameCalendar.dayKey(date, calendar: calendar)
        guard loginDays.insert(day).inserted else { return false }
        points += GameRules.loginPoints
        let streak = GameCalendar.streak(days: loginDays, through: date, calendar: calendar)
        for threshold in [5, 20] where streak.count >= threshold {
            let key = "\(streak.start)/\(threshold)"
            guard claimedStreakBonuses.insert(key).inserted else { continue }
            if threshold == 5 { wallet.creditInternal(10) }
            if threshold == 20 { wallet.creditExternal(5) }
        }
        // Only current-day attempts are needed; the find ledger keeps award history.
        attemptCounts = attemptCounts.filter { $0.key.contains("/\(day)/") }
        return true
    }

    @discardableResult
    mutating func checkIn(at date: Date, calendar: Calendar) -> Bool {
        guard profile.isRegistered else { return false }
        let day = GameCalendar.dayKey(date, calendar: calendar)
        guard attendanceDays.insert(day).inserted else { return false }
        wallet.creditInternal(GameRules.checkInReward)
        return true
    }

    mutating func beginAttempt(in zone: OfficeZone, at date: Date, calendar: Calendar) throws -> HuntAttempt {
        try requireHuntAccess(at: date, calendar: calendar)
        guard let target = targets(at: date, calendar: calendar).first(where: { $0.zone == zone }) else {
            throw HuntError.noObjectHere
        }
        guard !hasCollected(target) else { throw HuntError.alreadyCollected }
        if let activeAttempt, activeAttempt.expiresAt > date {
            guard activeAttempt.target.id == target.id else { throw HuntError.staleAttempt }
            return activeAttempt
        }
        guard attemptsRemaining(for: target) > 0 else { throw HuntError.attemptsExhausted }
        attemptCounts[target.id, default: 0] += 1
        let attempt = HuntAttempt(
            id: UUID(), target: target, startedAt: date,
            expiresAt: date.addingTimeInterval(GameRules.attemptDuration))
        activeAttempt = attempt
        return attempt
    }

    mutating func collect(attemptID: UUID, at date: Date, calendar: Calendar) throws -> CollectionReceipt {
        try requireHuntAccess(at: date, calendar: calendar)
        guard let attempt = activeAttempt, attempt.id == attemptID else { throw HuntError.staleAttempt }
        guard date >= attempt.startedAt, date < attempt.expiresAt else { throw HuntError.attemptExpired }
        guard targets(at: date, calendar: calendar).contains(attempt.target) else {
            throw HuntError.staleAttempt
        }
        guard !hasCollected(attempt.target) else { throw HuntError.alreadyCollected }

        let externalFinds = finds.filter { GameCalendar.sameWeek($0.foundAt, date, calendar: calendar) }
            .reduce(0) { $0 + $1.externalCoins }
        let limitReached =
            attempt.target.reward == .externalCoin && externalFinds >= GameRules.externalFindLimitPerWeek
        let externalCoins = attempt.target.reward == .externalCoin && !limitReached ? 1 : 0
        let beforeInternal = wallet.internalCoins
        let beforePoints = points

        wallet.creditInternal(attempt.target.reward.internalCoins)
        wallet.creditExternal(externalCoins)
        points += GameRules.findPoints
        finds.append(FoundObject(target: attempt.target, foundAt: date, externalCoins: externalCoins))
        activeAttempt = nil

        let day = GameCalendar.dayKey(date, calendar: calendar)
        let todayFinds = finds(on: date, calendar: calendar)
        let completed = Set(DailyMission.allCases.filter { $0.progress(in: todayFinds) == $0.target })
        let previous = claimedMissions[day, default: []]
        let newlyCompleted = completed.subtracting(previous)
        claimedMissions[day] = previous.union(completed)
        wallet.creditInternal(newlyCompleted.count * GameRules.missionReward)
        points += newlyCompleted.count * GameRules.missionPoints
        if completed.count == DailyMission.allCases.count, claimedDailyBonuses.insert(day).inserted {
            wallet.creditInternal(GameRules.allMissionsReward)
        }

        return CollectionReceipt(
            id: attempt.id, reward: attempt.target.reward,
            internalCoins: wallet.internalCoins - beforeInternal,
            externalCoins: externalCoins, points: points - beforePoints,
            completedMissions: newlyCompleted.count, externalLimitReached: limitReached)
    }

    mutating func cancelAttempt(id: UUID? = nil) {
        if let id, activeAttempt?.id != id { return }
        activeAttempt = nil
    }

    private func requireHuntAccess(at date: Date, calendar: Calendar) throws {
        guard profile.isRegistered else { throw HuntError.profileRequired }
        guard isCheckedIn(at: date, calendar: calendar) else { throw HuntError.checkInRequired }
        guard DailyWave.active(at: date, calendar: calendar) != nil else { throw HuntError.noActiveWave }
        guard finds(on: date, calendar: calendar).count < GameRules.dailyFindLimit else {
            throw HuntError.dailyLimit
        }
    }
}
