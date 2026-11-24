import SwiftUI

struct CoinHuntView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var permission = CameraPermission()
    @StateObject private var controller = ARHuntController()
    @State private var showHelp = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            ZStack {
                AppColors.background.ignoresSafeArea()
                if permission.status == .authorized {
                    camera(at: context.date)
                } else {
                    permissionScreen
                }
            }
        }
        .foregroundColor(AppColors.text)
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .task { updateActivity() }
        .onChange(of: scenePhase) { _ in updateActivity() }
        .onChange(of: showHelp) { _ in updateActivity() }
        .onDisappear { controller.setActive(false) }
        .sheet(isPresented: $showHelp) { MarkerGuideView() }
    }

    private func camera(at date: Date) -> some View {
        ZStack {
            ARSceneView(
                controller: controller, begin: store.beginAttempt, collect: store.collect,
                cancel: store.cancelAttempt
            )
            .ignoresSafeArea()
            .accessibilityLabel("AR-камера. Наведи на постер-котика, затем нажми на появившийся объект.")
            LinearGradient(
                colors: [.black.opacity(0.7), .clear, .clear, .black.opacity(0.85)], startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            VStack(spacing: 18) {
                HStack {
                    closeButton
                    Spacer()
                    CameraWallet(wallet: store.state.wallet)
                }
                Spacer()
                if let receipt = controller.receipt {
                    RewardCard(receipt: receipt, continueSearching: controller.continueSearching)
                } else {
                    huntInstructions(at: date)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 18)
            if let flight = controller.flight {
                FlyingReward(flight: flight)
                    .id(flight.id)
                    .allowsHitTesting(false)
            }
        }
    }

    private func huntInstructions(at date: Date) -> some View {
        Surface {
            VStack(alignment: .leading, spacing: 15) {
                if let attempt = controller.attempt {
                    let seconds = max(0, Int(ceil(attempt.expiresAt.timeIntervalSince(date))))
                    HStack {
                        Text(attempt.target.zone.title).font(.headline)
                        Spacer()
                        Label("\(seconds) с", systemImage: "timer")
                            .font(.headline.monospacedDigit())
                            .foregroundColor(seconds <= 3 ? AppColors.accent : AppColors.text)
                    }
                    Text(
                        controller.tracking == .ready
                            ? "Осмотрись вокруг и нажми на находку" : controller.tracking.instruction
                    )
                    .font(.subheadline)
                    .foregroundColor(AppColors.secondary)
                } else {
                    Text(instruction(at: date))
                        .font(.headline)
                        .fixedSize(horizontal: false, vertical: true)
                    let collected = store.state.targets(at: date, calendar: store.calendar).filter(
                        store.state.hasCollected
                    ).count
                    Text("\(collected) из 3 объектов волны собрано")
                        .font(.subheadline)
                        .foregroundColor(AppColors.secondary)
                    if case .failed(let failure) = controller.tracking {
                        Text(failure.diagnostic)
                            .font(.caption2.monospaced())
                            .foregroundColor(AppColors.secondary)
                            .textSelection(.enabled)
                        if failure.requiresSettings {
                            PrimaryButton(title: "Открыть настройки", symbol: "gearshape") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        } else {
                            PrimaryButton(
                                title: "Перезапустить камеру", symbol: "arrow.clockwise",
                                action: controller.restart)
                        }
                    } else if controller.notice != nil, availability(at: date) == nil {
                        Button("Попробовать на этом постере ещё раз", action: controller.retry)
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(AppColors.accent)
                    }
                }
                Button {
                    showHelp = true
                } label: {
                    Label("Какие постеры искать", systemImage: "questionmark.circle")
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                        .frame(minHeight: 32)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var permissionScreen: some View {
        gate(title: permissionTitle, message: permissionDescription) {
            switch permission.status {
            case .checking:
                ProgressView()
            case .notRequested:
                PrimaryButton(title: "Разрешить камеру", symbol: "camera.fill") {
                    Task { await permission.request() }
                }
            case .denied:
                PrimaryButton(title: "Открыть настройки", symbol: "gearshape") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            case .unsupported:
                PrimaryButton(title: "Понятно") { dismiss() }
            case .authorized:
                EmptyView()
            }
        }
    }

    private var permissionTitle: String {
        switch permission.status {
        case .denied: return "Разреши доступ к камере"
        case .unsupported: return "Нужен iPhone с AR"
        default: return "Монеты где-то рядом."
        }
    }

    private var permissionDescription: String {
        switch permission.status {
        case .denied: return "Включи камеру в настройках приложения и возвращайся к поиску."
        case .unsupported:
            return
                "Поиск работает на физическом iPhone с поддержкой ARKit. В симуляторе можно проверить остальные экраны."
        default: return "Камера распознает котика на постере и покажет находку рядом. Видео не записывается."
        }
    }

    private func gate<Action: View>(title: String, message: String, @ViewBuilder action: () -> Action)
        -> some View
    {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                closeButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            Spacer(minLength: 12)
            ScrollView {
                VStack(spacing: 25) {
                    CoinBadge(size: 96).padding(.vertical, 16)
                    Text(title).font(.largeTitle.bold()).multilineTextAlignment(.center)
                    Text(message).font(.body).foregroundColor(AppColors.secondary).multilineTextAlignment(
                        .center)
                    action()
                }
                .padding(24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            Spacer(minLength: 12)
        }
    }

    private var closeButton: some View {
        IconButton(symbol: "xmark", label: "Закрыть камеру") { dismiss() }
    }

    private func instruction(at date: Date) -> String {
        if case .failed = controller.tracking { return controller.tracking.instruction }
        return availability(at: date) ?? controller.notice ?? controller.tracking.instruction
    }

    private func availability(at date: Date) -> String? {
        guard store.state.isCheckedIn(at: date, calendar: store.calendar) else {
            return "Сначала нажми «Я в офисе» на главной."
        }
        guard DailyWave.active(at: date, calendar: store.calendar) != nil else {
            return "Объекты появляются с 10:00 до 12:00, с 13:00 до 15:00 и с 16:00 до 18:00."
        }
        let targets = store.state.targets(at: date, calendar: store.calendar)
        if targets.allSatisfy(store.state.hasCollected) {
            return "Все три объекта этой волны собраны. Возвращайся в следующую волну."
        }
        if targets.allSatisfy({ store.state.hasCollected($0) || store.state.attemptsRemaining(for: $0) == 0 }
        ), controller.attempt == nil {
            return "Попытки этой волны закончились. Новые объекты появятся в следующей."
        }
        return nil
    }

    private func updateActivity() {
        let active = scenePhase == .active && !showHelp
        if active { permission.refresh() }
        controller.setActive(active)
    }
}

private struct MarkerGuideView: View {
    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        DetailPage(title: "Постеры-котики") {
            Text(
                "Ищи постеры в разных зонах. В каждой волне у тебя три личных объекта. Распознай котика при хорошем освещении, затем поверни телефон и найди объект рядом. На поиск и сбор — \(Int(GameRules.attemptDuration)) секунд."
            )
            .font(.subheadline)
            .foregroundColor(AppColors.secondary)
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach(OfficeZone.allCases) { zone in
                    VStack(alignment: .leading, spacing: 8) {
                        Image("zone-\(zone.rawValue)")
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        Text(zone.title).font(.caption)
                    }
                }
            }
        }
    }
}
