import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var store: AppStore
    @State private var showEditor = false
    @State private var showRules = false
    @State private var confirmReset = false

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ScreenHeading(title: "Твой профиль")
            Surface {
                HStack(spacing: 15) {
                    Text(store.state.profile.initials)
                        .font(.title2.weight(.semibold))
                        .frame(width: 60, height: 60)
                        .background(AppColors.raised, in: RoundedRectangle(cornerRadius: 20))
                    VStack(alignment: .leading, spacing: 7) {
                        Text(store.state.profile.name).font(.title3.weight(.semibold))
                        Text(store.state.profile.department).font(.subheadline).foregroundColor(
                            AppColors.secondary)
                    }
                    Spacer()
                    Button {
                        showEditor = true
                    } label: {
                        Image(systemName: "pencil").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Редактировать профиль")
                }
            }
            WalletView(wallet: store.state.wallet)
            Surface {
                VStack(spacing: 18) {
                    statistic("Находок", value: store.state.totalFinds)
                    statistic("Очков", value: store.state.points)
                    statistic("Дней в игре", value: store.state.loginDays.count)
                    statistic(
                        "Серия по рабочим дням",
                        value: GameCalendar.streak(
                            days: store.state.loginDays, through: store.now, calendar: store.calendar
                        ).count)
                    statistic(
                        "Предметов коллекции",
                        value: store.state.finds.filter { $0.target.reward == .collectionItem }.count)
                }
            }
            Button {
                showRules = true
            } label: {
                HStack {
                    Label("Как играть", systemImage: "questionmark.circle")
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .font(.subheadline)
                .frame(minHeight: 48)
            }
            Text(
                "Локальный прототип · прогресс хранится на устройстве. Отметка пока работает без проверки геозоны; сервер и корпоративный вход ещё не подключены."
            )
            .font(.caption)
            .foregroundColor(AppColors.secondary)
            .fixedSize(horizontal: false, vertical: true)
            Button("Сбросить локальные данные", role: .destructive) { confirmReset = true }
                .font(.subheadline)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showEditor) { EditProfileView() }
        .sheet(isPresented: $showRules) { RulesView() }
        .alert("Начать заново?", isPresented: $confirmReset) {
            Button("Отмена", role: .cancel) {}
            Button("Сбросить", role: .destructive) { store.reset() }
        } message: {
            Text("Профиль, монеты и история находок на этом устройстве будут очищены.")
        }
    }

    private func statistic(_ title: String, value: Int) -> some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(AppColors.secondary)
            Spacer()
            Text("\(value)").font(.headline.monospacedDigit())
        }
    }
}

private struct EditProfileView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var department = ""

    var body: some View {
        DetailPage(title: "Редактировать профиль") {
            ProfileFields(name: $name, department: $department)
            PrimaryButton(title: "Сохранить", symbol: "checkmark") {
                store.saveProfile(name: name, department: department)
                if store.message == nil { dismiss() }
            }
            .disabled(!ProfileFields.isValid(name: name, department: department))
        }
        .onAppear {
            name = store.state.profile.name
            department = store.state.profile.department
        }
    }
}

struct RulesView: View {
    var body: some View {
        DetailPage(title: "Как играть") {
            ScreenHeading(title: "Найди своего котика.")
            rule("1", "Отметься в офисе", "Отметка доступна раз в день и даёт 2 внутренние монеты.")
            rule(
                "2", "Дождись волны",
                "В 10:00, 13:00 и 16:00 появляются по три личных объекта. Каждая волна длится два часа.")
            rule(
                "3", "Наведи камеру на постер",
                "У каждой зоны свой котик. Распознай постер, затем поверни телефон и найди монету или предмет коллекции рядом."
            )
            rule(
                "4", "Поймай находку",
                "На поиск и сбор — \(Int(GameRules.attemptDuration)) секунд. На каждый объект есть три попытки, награда начисляется один раз."
            )
            rule(
                "5", "Выполняй задания",
                "Ежедневные задания и баланс обновляются после сбора. Красные монеты — внутренние, зелёные — внешние, золотые — супер-монеты."
            )
        }
    }

    private func rule(_ number: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(number).font(.headline).foregroundColor(AppColors.accent)
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.headline)
                Text(text).font(.subheadline).foregroundColor(AppColors.secondary)
            }
        }
    }
}
