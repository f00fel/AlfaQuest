import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    let openCamera: () -> Void
    let openMissions: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let today = store.state.finds(on: context.date, calendar: store.calendar)
            let checkedIn = store.state.isCheckedIn(at: context.date, calendar: store.calendar)
            VStack(alignment: .leading, spacing: 24) {
                ScreenHeading(
                    title: "Привет, \(store.state.profile.firstName)",
                    subtitle: "Небольшой перерыв. Новая находка.")
                WalletView(wallet: store.state.wallet)
                attendanceCard(checkedIn: checkedIn)
                Surface {
                    VStack(alignment: .leading, spacing: 18) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Твой следующий\nмаленький квест")
                                    .font(.system(.title2, weight: .semibold))
                                Text(huntDescription(at: context.date))
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.secondary)
                            }
                            Spacer()
                            CoinBadge(size: 60)
                        }
                        PrimaryButton(title: "Открыть AR-поиск", symbol: "camera.fill", action: openCamera)
                    }
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text("Ритм дня").font(.title3.weight(.semibold))
                    HStack(spacing: 10) {
                        ForEach(DailyWave.allCases) { wave in
                            VStack(alignment: .leading, spacing: 9) {
                                Text(wave.title).font(.system(.title3, weight: .semibold)).monospacedDigit()
                                Text(wave.status(at: context.date, calendar: store.calendar))
                                    .font(.caption2)
                                    .foregroundColor(
                                        DailyWave.active(at: context.date, calendar: store.calendar) == wave
                                            ? AppColors.accent : AppColors.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(15)
                            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 18))
                        }
                    }
                }
                Button(action: openMissions) {
                    Surface {
                        HStack {
                            VStack(alignment: .leading, spacing: 7) {
                                Text("Задания на сегодня").font(.headline)
                                Text("\(completedMissions(finds: today)) из 3 выполнено")
                                    .font(.subheadline)
                                    .foregroundColor(AppColors.secondary)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                    }
                }
                .buttonStyle(PressButtonStyle())
            }
        }
    }

    private func attendanceCard(checkedIn: Bool) -> some View {
        Button {
            store.checkIn()
        } label: {
            Surface {
                HStack(spacing: 14) {
                    Image(systemName: checkedIn ? "checkmark.circle.fill" : "building.2")
                        .font(.title2)
                        .foregroundColor(checkedIn ? AppColors.green : AppColors.accent)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(checkedIn ? "Ты сегодня в офисе" : "Я в офисе").font(.headline)
                        Text(checkedIn ? "Отметка сохранена" : "+2 внутренние монеты")
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                    }
                    Spacer()
                    if !checkedIn { Image(systemName: "arrow.right") }
                }
            }
        }
        .buttonStyle(PressButtonStyle())
        .disabled(checkedIn)
    }

    private func huntDescription(at date: Date) -> String {
        guard let wave = DailyWave.active(at: date, calendar: store.calendar) else {
            return "В каждой волне — три личных объекта."
        }
        let collected = store.state.targets(at: date, calendar: store.calendar).filter(
            store.state.hasCollected
        ).count
        return "Волна \(wave.title) · \(collected) из 3 собрано"
    }

    private func completedMissions(finds: [FoundObject]) -> Int {
        DailyMission.allCases.filter { $0.progress(in: finds) == $0.target }.count
    }
}

struct ScheduleView: View {
    var body: some View {
        DetailPage(title: "Расписание") {
            ScreenHeading(title: "Три волны.\nТри повода отвлечься.")
            ForEach(DailyWave.allCases) { wave in
                Surface {
                    HStack {
                        Image(systemName: "clock").foregroundColor(AppColors.accent)
                        Text("\(wave.title) — \(wave.endTitle)").font(.headline)
                        Spacer()
                        Text("3 объекта").font(.caption).foregroundColor(AppColors.secondary)
                    }
                }
            }
            Text("Объекты доступны после отметки в офисе. Время — по часовому поясу устройства.")
                .font(.subheadline)
                .foregroundColor(AppColors.secondary)
        }
    }
}
