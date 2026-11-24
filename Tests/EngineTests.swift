import Foundation
import simd

@main
struct EngineTests {
    @MainActor private static var passed = 0
    private static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 18_000) ?? .gmt
        return value
    }
    private static let morning = date("2026-11-12T05:00:00Z")

    @MainActor
    static func main() throws {
        try test("wave boundaries are start-inclusive and end-exclusive") {
            let cases: [(String, DailyWave?)] = [
                ("2026-11-12T04:59:59Z", nil), ("2026-11-12T05:00:00Z", .morning),
                ("2026-11-12T06:59:59Z", .morning), ("2026-11-12T07:00:00Z", nil),
                ("2026-11-12T08:00:00Z", .afternoon), ("2026-11-12T10:00:00Z", nil),
                ("2026-11-12T11:00:00Z", .evening), ("2026-11-12T13:00:00Z", nil),
            ]
            for (text, expected) in cases {
                expect(DailyWave.active(at: date(text), calendar: calendar) == expected)
            }
        }

        try test("personal objects are reproducible and occupy distinct zones") {
            let state = player()
            let first = state.targets(at: morning, calendar: calendar)
            expect(first == state.targets(at: morning.addingTimeInterval(60), calendar: calendar))
            expect(first.map(\.zone) == [.coffee, .reception, .it])
            expect(first.map(\.reward) == [.collectionItem, .internalCoin, .internalCoin])
            expect(Set(first.map(\.id)).count == 3 && Set(first.map(\.zone)).count == 3)
            let nextWave = state.targets(at: date("2026-11-12T08:00:00Z"), calendar: calendar)
            expect(Set(first.map(\.id)).isDisjoint(with: nextWave.map(\.id)))
            expect(first != player(number: 2).targets(at: morning, calendar: calendar))
        }

        try test("reward weights match 80/16/4 and rare internal coins remain conditional") {
            var counts: [FindReward: Int] = [:]
            for index in 1...1_000 {
                for target in player(number: index).targets(at: morning, calendar: calendar) {
                    counts[target.reward, default: 0] += 1
                }
            }
            let total = 3_000.0
            let internalRatio =
                Double(counts[.internalCoin, default: 0] + counts[.rareCoin, default: 0]) / total
            expect((0.76...0.84).contains(internalRatio))
            expect((0.13...0.19).contains(Double(counts[.collectionItem, default: 0]) / total))
            expect((0.02...0.06).contains(Double(counts[.externalCoin, default: 0]) / total))
            let rareRatio = Double(counts[.rareCoin, default: 0]) / (internalRatio * total)
            expect((0.21...0.29).contains(rareRatio))
        }

        try test("login and check-in award once per local calendar day") {
            var state = player()
            expect(state.recordLogin(at: morning, calendar: calendar))
            expect(!state.recordLogin(at: morning, calendar: calendar))
            expect(state.points == 5)
            expect(state.checkIn(at: morning, calendar: calendar))
            expect(!state.checkIn(at: morning, calendar: calendar))
            expect(state.wallet.internalCoins == 2)
            expect(!state.isCheckedIn(at: date("2026-11-12T19:00:00Z"), calendar: calendar))
        }

        try test("attendance uses one clock reading at the midnight boundary") {
            try withDefaults { defaults in
                var reads = 0
                var crossingMidnight = false
                let before = date("2026-11-12T18:59:59Z")
                let after = date("2026-11-12T19:00:00Z")
                let store = AppStore(
                    defaults: defaults, calendar: calendar,
                    clock: {
                        reads += 1
                        return crossingMidnight ? (reads == 1 ? before : after) : morning
                    })
                store.saveProfile(name: "Вика", department: "Дизайн")
                reads = 0
                crossingMidnight = true
                store.checkIn()
                expect(store.state.isCheckedIn(at: before, calendar: calendar))
                expect(!store.state.isCheckedIn(at: after, calendar: calendar))
                expect(store.state.wallet.internalCoins == 2)
            }
        }

        try test("profile, attendance and wave gates reject invalid starts") {
            var blank = PlayerState()
            try expectError(.profileRequired) {
                try blank.beginAttempt(in: .coffee, at: morning, calendar: calendar)
            }
            var state = player()
            try expectError(.checkInRequired) {
                try state.beginAttempt(in: .coffee, at: morning, calendar: calendar)
            }
            state.checkIn(at: morning, calendar: calendar)
            try expectError(.noActiveWave) {
                try state.beginAttempt(in: .coffee, at: date("2026-11-12T07:01:00Z"), calendar: calendar)
            }
            try expectError(.noObjectHere) {
                try state.beginAttempt(in: .secret, at: morning, calendar: calendar)
            }
            expect(state.attemptCounts.isEmpty)
        }

        try test("repeated marker callbacks reuse the current attempt") {
            var state = checkedInPlayer()
            let first = try state.beginAttempt(in: .coffee, at: morning, calendar: calendar)
            let duplicate = try state.beginAttempt(
                in: .coffee, at: morning.addingTimeInterval(1), calendar: calendar)
            expect(first == duplicate)
            expect(state.attemptsRemaining(for: first.target) == 2)
            try expectError(.staleAttempt) {
                try state.beginAttempt(in: .it, at: morning, calendar: calendar)
            }
        }

        try test("collection receipt, wallet and mission progress change atomically") {
            var state = checkedInPlayer()
            let attempt = try state.beginAttempt(in: .coffee, at: morning, calendar: calendar)
            let receipt = try state.collect(
                attemptID: attempt.id, at: morning.addingTimeInterval(1), calendar: calendar)
            expect(receipt.reward == .collectionItem && receipt.completedMissions == 1)
            expect(receipt.internalCoins == 1 && receipt.points == 30)
            expect(state.wallet.internalCoins == 3 && state.points == 35)
            expect(state.finds.count == 1 && state.activeAttempt == nil)
            let saved = state
            try expectError(.staleAttempt) {
                try state.collect(
                    attemptID: attempt.id, at: morning.addingTimeInterval(2), calendar: calendar)
            }
            expect(state == saved)
        }

        try test("the hunt allows collection after 10 seconds and until the 25-second deadline") {
            for elapsed in [10.0, 24.99] {
                var state = checkedInPlayer()
                let attempt = try state.beginAttempt(in: .coffee, at: morning, calendar: calendar)
                expect(attempt.expiresAt.timeIntervalSince(attempt.startedAt) == 25)
                _ = try state.collect(
                    attemptID: attempt.id, at: morning.addingTimeInterval(elapsed), calendar: calendar)
                expect(state.finds.count == 1)
            }
        }

        try test("expired and time-reversed taps never award a reward") {
            var state = checkedInPlayer()
            let start = morning.addingTimeInterval(60)
            let attempt = try state.beginAttempt(in: .coffee, at: start, calendar: calendar)
            try expectError(.attemptExpired) {
                try state.collect(attemptID: attempt.id, at: attempt.expiresAt, calendar: calendar)
            }
            try expectError(.attemptExpired) {
                try state.collect(
                    attemptID: attempt.id, at: start.addingTimeInterval(-0.1), calendar: calendar)
            }
            expect(state.wallet.internalCoins == 2 && state.finds.isEmpty)
        }

        try test("three timed-out attempts exhaust the object permanently") {
            var state = checkedInPlayer()
            var firstID: UUID?
            for index in 0..<3 {
                let now = morning.addingTimeInterval(Double(index) * (GameRules.attemptDuration + 1))
                let attempt = try state.beginAttempt(in: .coffee, at: now, calendar: calendar)
                if firstID == nil { firstID = attempt.id }
                if let firstID, index > 0 {
                    try expectError(.staleAttempt) {
                        try state.collect(attemptID: firstID, at: now, calendar: calendar)
                    }
                }
                state.cancelAttempt(id: attempt.id)
            }
            try expectError(.attemptsExhausted) {
                try state.beginAttempt(
                    in: .coffee, at: morning.addingTimeInterval(3 * (GameRules.attemptDuration + 1)),
                    calendar: calendar)
            }
            expect(state.finds.isEmpty)
        }

        try test("a stale timeout cannot cancel a replacement attempt") {
            var state = checkedInPlayer()
            let first = try state.beginAttempt(in: .coffee, at: morning, calendar: calendar)
            let restart = first.expiresAt.addingTimeInterval(1)
            let replacement = try state.beginAttempt(
                in: .coffee, at: restart, calendar: calendar)
            state.cancelAttempt(id: first.id)
            expect(state.activeAttempt?.id == replacement.id)
            let receipt = try state.collect(
                attemptID: replacement.id, at: restart.addingTimeInterval(1), calendar: calendar)
            expect(receipt.reward == .collectionItem && state.finds.count == 1)
        }

        try test("all daily missions and their bonus are credited once") {
            var state = checkedInPlayer()
            try collectWave(into: &state, at: morning)
            expect(state.wallet.internalCoins == 6 && state.points == 75)
            try collectWave(into: &state, at: date("2026-11-12T08:00:00Z"))
            expect(state.wallet.internalCoins == 14 && state.points == 125)
            expect(state.claimedMissions["2026-11-12"]?.count == 3)
            expect(state.claimedDailyBonuses == ["2026-11-12"])
            let target = state.targets(at: morning, calendar: calendar)[0]
            try expectError(.alreadyCollected) {
                try state.beginAttempt(in: target.zone, at: morning, calendar: calendar)
            }
        }

        try test("wallet cap preserves find and point progress") {
            var wallet = Wallet()
            expect(wallet.creditInternal(-4) == 0)
            expect(wallet.creditInternal(110) == 100)
            expect(wallet.creditInternal(3) == 0)
            var state = player(wallet: wallet)
            state.checkIn(at: morning, calendar: calendar)
            let attempt = try state.beginAttempt(in: .it, at: morning, calendar: calendar)
            let receipt = try state.collect(
                attemptID: attempt.id, at: morning.addingTimeInterval(1), calendar: calendar)
            expect(receipt.internalCoins == 0 && receipt.points == 30)
            expect(state.wallet.internalCoins == 100 && state.finds.count == 1)
        }

        try test("a wave ending invalidates an otherwise live attempt") {
            var state = checkedInPlayer()
            let start = date("2026-11-12T06:59:55Z")
            let attempt = try state.beginAttempt(in: .coffee, at: start, calendar: calendar)
            try expectError(.noActiveWave) {
                try state.collect(attemptID: attempt.id, at: start.addingTimeInterval(6), calendar: calendar)
            }
            expect(state.finds.isEmpty)
        }

        try test("external find quota resets at the ISO week boundary") {
            let monday = date("2026-11-09T05:00:00Z")
            var chosen: PlayerState?
            for number in 1...100 {
                let candidate = player(number: number)
                let externalCount = (0..<7).flatMap { offset in
                    DailyWave.allCases.flatMap { wave -> [HuntTarget] in
                        let day = monday.addingTimeInterval(Double(offset) * 86_400)
                        return HuntTarget.personalTargets(
                            playerID: candidate.profile.id, at: day, wave: wave, calendar: calendar)
                    }
                }.filter { $0.reward == .externalCoin }.count
                if externalCount > 3 { chosen = candidate; break }
            }
            guard var state = chosen else { fatalError("Missing deterministic quota fixture") }
            var quotaWasReached = false
            for offset in 0..<7 {
                let day = monday.addingTimeInterval(Double(offset) * 86_400)
                state.checkIn(at: day, calendar: calendar)
                for wave in DailyWave.allCases {
                    let start = day.addingTimeInterval(Double(wave.rawValue - 10) * 3_600)
                    for receipt in try collectWave(into: &state, at: start) {
                        quotaWasReached = quotaWasReached || receipt.externalLimitReached
                    }
                }
            }
            expect(state.wallet.externalCoins == 3 && quotaWasReached)
            expect(!GameCalendar.sameWeek(monday, monday.addingTimeInterval(7 * 86_400), calendar: calendar))
            var nextWeekReceipt: CollectionReceipt?
            for offset in 7..<21 where nextWeekReceipt == nil {
                let day = monday.addingTimeInterval(Double(offset) * 86_400)
                for wave in DailyWave.allCases where nextWeekReceipt == nil {
                    let start = day.addingTimeInterval(Double(wave.rawValue - 10) * 3_600)
                    if let external = state.targets(at: start, calendar: calendar).first(where: {
                        $0.reward == .externalCoin
                    }) {
                        state.checkIn(at: start, calendar: calendar)
                        nextWeekReceipt = try collectOne(into: &state, zone: external.zone, at: start)
                    }
                }
            }
            expect(nextWeekReceipt?.externalCoins == 1 && state.wallet.externalCoins == 4)
        }

        try test("working-day streak skips weekends and forgives one absence") {
            let days: Set<String> = ["2026-11-02", "2026-11-03", "2026-11-05", "2026-11-06", "2026-11-09"]
            let streak = GameCalendar.streak(
                days: days, through: date("2026-11-09T05:00:00Z"), calendar: calendar)
            expect(streak.count == 5 && streak.start == "2026-11-02")
            let broken: Set<String> = ["2026-11-02", "2026-11-03", "2026-11-06", "2026-11-09"]
            expect(
                GameCalendar.streak(days: broken, through: date("2026-11-09T05:00:00Z"), calendar: calendar)
                    .count == 2)
        }

        try test("streak milestone bonus cannot replay on relaunch") {
            var state = player()
            for text in ["2026-11-02", "2026-11-03", "2026-11-04", "2026-11-05", "2026-11-06"] {
                state.recordLogin(at: date("\(text)T05:00:00Z"), calendar: calendar)
            }
            expect(state.wallet.internalCoins == 10 && state.points == 25)
            state = try JSONDecoder().decode(PlayerState.self, from: JSONEncoder().encode(state))
            state.recordLogin(at: date("2026-11-06T06:00:00Z"), calendar: calendar)
            expect(state.wallet.internalCoins == 10 && state.points == 25)
        }

        try test("persistence restores a partial hunt and all balances") {
            try withDefaults { defaults in
                let repository = PlayerRepository(defaults: defaults)
                var state = checkedInPlayer()
                try collectOne(into: &state, zone: .coffee, at: morning)
                let attempt = try state.beginAttempt(
                    in: .it, at: morning.addingTimeInterval(2), calendar: calendar)
                try repository.save(state)
                try expect(try repository.load() == state)
                let store = AppStore(
                    defaults: defaults, calendar: calendar, clock: { morning.addingTimeInterval(3) })
                expect(store.state.activeAttempt == nil)
                expect(store.state.attemptCounts[attempt.target.id] == 1)
                expect(store.state.finds.count == 1 && store.state.wallet.internalCoins == 3)
            }
        }

        try test("legacy profile migration keeps identity and clamps the old demo wallet") {
            try withDefaults { defaults in
                let legacy: [String: Any] = [
                    "name": "Костя", "department": "Разработка", "hasStarted": true,
                    "activeDays": ["2026-11-11", "2026-11-12"], "checkInDay": "2026-11-12",
                    "coinHunt": ["totalCollected": 150],
                ]
                let data = try JSONSerialization.data(withJSONObject: legacy)
                defaults.set(data, forKey: "alfaquest.local-profile.v1")
                let repository = PlayerRepository(defaults: defaults)
                let migrated = try repository.load()
                try expect(try repository.load().profile.id == migrated.profile.id)
                expect(migrated.profile.name == "Костя" && migrated.profile.department == "Разработка")
                expect(migrated.wallet.internalCoins == 100 && migrated.totalFinds == 150)
                expect(migrated.loginDays.count == 2 && migrated.isCheckedIn(at: morning, calendar: calendar))
                try repository.save(migrated)
                try expect(try repository.load() == migrated)
                expect(defaults.data(forKey: "alfaquest.local-profile.v1") == data)
            }
        }

        try test("corrupt or newer saves are not silently overwritten") {
            try withDefaults { defaults in
                let corrupt = Data("broken".utf8)
                defaults.set(corrupt, forKey: PlayerRepository.key)
                let store = AppStore(defaults: defaults, calendar: calendar, clock: { morning })
                expect(store.recoveryRequired)
                store.checkIn()
                expect(defaults.data(forKey: PlayerRepository.key) == corrupt)
                store.reset()
                expect(!store.recoveryRequired && !store.state.profile.isRegistered)
                defaults.set(Data("{\"version\":999}".utf8), forKey: PlayerRepository.key)
                do {
                    _ = try PlayerRepository(defaults: defaults).load()
                    fatalError("A newer save must not be loaded")
                } catch StorageError.newerVersion {}
            }
        }

        try test("invalid balances in otherwise valid JSON preserve the original save") {
            try withDefaults { defaults in
                var object =
                    try JSONSerialization.jsonObject(with: JSONEncoder().encode(checkedInPlayer()))
                    as? [String: Any]
                object?["wallet"] = ["internalCoins": 101, "externalCoins": 0, "superCoins": 0]
                let data = try JSONSerialization.data(withJSONObject: object ?? [:])
                defaults.set(data, forKey: PlayerRepository.key)
                do {
                    _ = try PlayerRepository(defaults: defaults).load()
                    fatalError("Invalid wallet must require recovery")
                } catch StorageError.unreadableProfile {}
                expect(defaults.data(forKey: PlayerRepository.key) == data)
            }
        }

        try test("camera permission return and view attachment start only one run") {
            var camera = CameraSessionLifecycle()
            camera.setActive(true)
            expect(camera.prepare() == nil)
            camera.setActive(false)
            camera.attach()
            expect(camera.prepare() == nil)
            camera.setActive(true)
            guard let run = camera.prepare() else { fatalError("Expected one preparation") }
            camera.setActive(true)
            expect(camera.prepare() == nil)
            expect(camera.start(run))
            expect(camera.prepare() == nil && camera.acceptsEvents(from: run))
        }

        try test("backgrounding cancels pending camera startup") {
            var camera = CameraSessionLifecycle()
            camera.attach()
            camera.setActive(true)
            guard let old = camera.prepare() else { fatalError("Missing old run") }
            camera.setActive(false)
            expect(!camera.start(old) && !camera.fail(old))
            camera.setActive(true)
            guard let current = camera.prepare() else { fatalError("Missing foreground run") }
            expect(current != old && camera.start(current))
            expect(!camera.acceptsEvents(from: old) && camera.acceptsEvents(from: current))
        }

        try test("stale AR failures cannot overwrite a restarted camera") {
            var camera = CameraSessionLifecycle()
            camera.attach()
            camera.setActive(true)
            guard let old = camera.prepare() else { fatalError("Missing old run") }
            expect(camera.start(old) && camera.fail(old))
            expect(!camera.acceptsEvents(from: old) && camera.prepare() == nil)
            camera.reset()
            guard let current = camera.prepare() else { fatalError("Missing replacement run") }
            expect(camera.start(current))
            expect(!camera.fail(old) && !camera.interrupt(old))
            expect(camera.acceptsEvents(from: current))
        }

        try test("a removed camera view cannot open a session after marker validation") {
            var camera = CameraSessionLifecycle()
            camera.setActive(true)
            camera.attach()
            guard let old = camera.prepare() else { fatalError("Missing pending run") }
            camera.detach()
            expect(!camera.start(old) && camera.prepare() == nil)
            camera.attach()
            guard let current = camera.prepare() else { fatalError("Missing attached run") }
            expect(current != old && camera.start(current))
            expect(!camera.fail(old))
        }

        try test("camera interruption recovers once and ignores duplicate completion") {
            var camera = CameraSessionLifecycle()
            camera.attach()
            camera.setActive(true)
            guard let old = camera.prepare() else { fatalError("Missing old run") }
            expect(camera.start(old) && camera.interrupt(old))
            expect(!camera.acceptsEvents(from: old) && camera.prepare() == nil)
            expect(camera.resume(old))
            guard let current = camera.prepare() else { fatalError("Missing recovery run") }
            expect(!camera.resume(old) && camera.start(current))
            expect(camera.acceptsEvents(from: current))
        }

        try test("a paused camera cannot be restarted in the background") {
            var camera = CameraSessionLifecycle()
            camera.attach()
            camera.setActive(false)
            camera.reset()
            expect(camera.prepare() == nil)
        }

        try test("objects spawn outside the initial view on both sides within turning distance") {
            var generator = PlacementRandom()
            var left = false
            var right = false
            for _ in 0..<512 {
                let position = HuntObjectPlacement.position(
                    relativeTo: matrix_identity_float4x4, using: &generator)
                let angle = atan2(abs(position.x), -position.z) * 180 / .pi
                let distance = sqrt(position.x * position.x + position.z * position.z)
                expect((54.99...95.01).contains(angle))
                expect((0.899...1.301).contains(distance))
                expect((-0.251...0.151).contains(position.y))
                left = left || position.x < 0
                right = right || position.x > 0
            }
            expect(left && right)
        }

        try test("object placement follows player heading and stays level with a tilted phone") {
            var generator = PlacementRandom()
            let base = HuntObjectPlacement.position(
                relativeTo: matrix_identity_float4x4, using: &generator)
            let yaw = simd_quatf(angle: .pi / 3, axis: SIMD3(0, 1, 0))
            let origin = SIMD3<Float>(3, 1.6, -2)
            for pitch: Float in [-.pi / 2, -.pi / 4, 0, .pi / 2] {
                var camera = simd_float4x4(yaw * simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0)))
                camera.columns.3 = SIMD4(origin, 1)
                var sameGenerator = PlacementRandom()
                let position = HuntObjectPlacement.position(relativeTo: camera, using: &sameGenerator)
                expect(simd_distance(position, origin + yaw.act(base)) < 0.0001)
            }
        }

        print("PASS: \(passed) scenarios")
    }

    @MainActor
    private static func test(_ name: String, _ body: () throws -> Void) throws {
        try body()
        passed += 1
        FileHandle.standardOutput.write(Data("PASS: \(name)\n".utf8))
    }

    private static func expect(
        _ condition: @autoclosure () throws -> Bool, file: StaticString = #file, line: UInt = #line
    ) rethrows {
        guard try condition() else { fatalError("Expectation failed", file: file, line: line) }
    }

    private static func expectError<Value>(_ expected: HuntError, _ body: () throws -> Value) throws {
        do {
            _ = try body()
            fatalError("Expected \(expected)")
        } catch let actual as HuntError {
            guard actual == expected else { fatalError("Expected \(expected), got \(actual)") }
        }
    }

    private static func date(_ text: String) -> Date {
        guard let value = ISO8601DateFormatter().date(from: text) else {
            fatalError("Invalid date fixture: \(text)")
        }
        return value
    }

    private static func player(number: Int = 1, wallet: Wallet = Wallet()) -> PlayerState {
        let text = String(format: "00000000-0000-0000-0000-%012d", number)
        guard let id = UUID(uuidString: text) else { fatalError("Invalid player fixture") }
        return PlayerState(
            profile: PlayerProfile(id: id, name: "Вика", department: "Дизайн", isRegistered: true),
            wallet: wallet)
    }

    private static func checkedInPlayer() -> PlayerState {
        var state = player()
        state.recordLogin(at: morning, calendar: calendar)
        state.checkIn(at: morning, calendar: calendar)
        return state
    }

    @discardableResult
    private static func collectOne(into state: inout PlayerState, zone: OfficeZone, at date: Date) throws
        -> CollectionReceipt
    {
        let attempt = try state.beginAttempt(in: zone, at: date, calendar: calendar)
        return try state.collect(attemptID: attempt.id, at: date.addingTimeInterval(0.1), calendar: calendar)
    }

    @discardableResult
    private static func collectWave(into state: inout PlayerState, at date: Date) throws
        -> [CollectionReceipt]
    {
        let targets = state.targets(at: date, calendar: calendar)
        return try targets.enumerated().map { index, target in
            try collectOne(into: &state, zone: target.zone, at: date.addingTimeInterval(Double(index)))
        }
    }

    @MainActor
    private static func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "alfaquest-tests-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else { fatalError("Unavailable test defaults") }
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    private struct PlacementRandom: RandomNumberGenerator {
        private var state: UInt64 = 42

        mutating func next() -> UInt64 {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return state
        }
    }
}
