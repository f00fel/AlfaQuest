import SwiftUI

private enum AppTab: String {
    case home = "Главная"
    case missions = "Миссии"
    case profile = "Профиль"

    var symbol: String {
        switch self {
        case .home: return "house"
        case .missions: return "flag"
        case .profile: return "person.crop.circle"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selection
    @State private var tab = AppTab.home
    @State private var showCamera = false
    @State private var showSchedule = false
    @State private var confirmReset = false

    var body: some View {
        Group {
            if store.recoveryRequired {
                recoveryScreen
            } else if store.state.profile.isRegistered {
                mainScreen
            } else {
                WelcomeView()
            }
        }
        .foregroundColor(AppColors.text)
        .background(AppColors.background.ignoresSafeArea())
        .alert(
            "Альфа Квест",
            isPresented: Binding(
                get: { store.message != nil && !store.recoveryRequired },
                set: { if !$0 { store.message = nil } })
        ) {
            Button("Понятно") { store.message = nil }
        } message: {
            Text(store.message ?? "")
        }
        .onChange(of: store.state.profile.id) { _ in
            tab = .home
            showCamera = false
        }
    }

    private var mainScreen: some View {
        VStack(spacing: 0) {
            HStack {
                Text(tab == .home ? "Альфа Квест" : tab.rawValue).font(.headline)
                Spacer()
                IconButton(symbol: "clock", label: "Расписание волн") { showSchedule = true }
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            Page {
                Group {
                    switch tab {
                    case .home:
                        HomeView(openCamera: { showCamera = true }, openMissions: { select(.missions) })
                    case .missions: MissionsView(openCamera: { showCamera = true })
                    case .profile: ProfileView()
                    }
                }
                .id(tab)
                .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { navigationBar }
        .sheet(isPresented: $showSchedule) { ScheduleView() }
        .fullScreenCover(isPresented: $showCamera) { CoinHuntView() }
    }

    private var navigationBar: some View {
        HStack(spacing: 4) {
            tabButton(.home)
            tabButton(.missions)
            Button {
                showCamera = true
            } label: {
                navigationLabel("Камера", symbol: "camera.fill")
                    .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 18))
            }
            .accessibilityLabel("Открыть AR-камеру")
            tabButton(.profile)
        }
        .buttonStyle(PressButtonStyle())
        .padding(6)
        .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 25))
        .padding(.horizontal, 24)
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(AppColors.background)
    }

    private func tabButton(_ item: AppTab) -> some View {
        Button {
            select(item)
        } label: {
            navigationLabel(item.rawValue, symbol: item.symbol)
                .foregroundColor(tab == item ? AppColors.text : AppColors.secondary)
                .background {
                    if tab == item {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(AppColors.raised)
                            .matchedGeometryEffect(id: "selection", in: selection)
                    }
                }
        }
        .accessibilityAddTraits(tab == item ? .isSelected : [])
    }

    private func navigationLabel(_ title: String, symbol: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 20))
            Text(title).font(.system(size: 10, weight: .medium))
        }
        .frame(maxWidth: .infinity, minHeight: 60)
    }

    private func select(_ item: AppTab) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { tab = item }
    }

    private var recoveryScreen: some View {
        Page {
            ScreenHeading(title: "Профиль недоступен", subtitle: store.message)
            Text(
                "Сохранение осталось на устройстве. Можно вернуться после обновления приложения или начать новый локальный профиль."
            )
            .foregroundColor(AppColors.secondary)
            Button("Начать заново") { confirmReset = true }
                .alert("Очистить локальное сохранение?", isPresented: $confirmReset) {
                    Button("Отмена", role: .cancel) {}
                    Button("Очистить", role: .destructive) { store.reset() }
                }
        }
    }
}

private struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    @State private var name = ""
    @State private var department = ""

    var body: some View {
        Page {
            CoinBadge(size: 100).padding(.vertical, 30)
            ScreenHeading(
                title: "Твой офис.\nНовые открытия.",
                subtitle: "Находи монеты, исследуй зоны и выполняй задания.")
            ProfileFields(name: $name, department: $department)
            PrimaryButton(title: "Начать", symbol: "arrow.right") {
                store.saveProfile(name: name, department: department)
            }
            .disabled(!ProfileFields.isValid(name: name, department: department))
            Text("Локальный прототип. Профиль и прогресс сохраняются на этом iPhone.")
                .font(.caption)
                .foregroundColor(AppColors.secondary)
        }
    }
}

#if DEBUG
    @MainActor
    struct RootView_Previews: PreviewProvider {
        private static let previewStore: AppStore? = {
            let suite = "com.alfaquest.xcode-preview"
            guard let defaults = UserDefaults(suiteName: suite) else { return nil }
            defaults.removePersistentDomain(forName: suite)
            let store = AppStore(defaults: defaults)
            store.saveProfile(name: "", department: "")
            store.checkIn()
            return store
        }()

        static var previews: some View {
            Group {
                if let previewStore {
                    RootView().environmentObject(previewStore)
                } else {
                    Text("Не удалось создать предпросмотр")
                }
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Альфа Квест")
        }
    }
#endif
