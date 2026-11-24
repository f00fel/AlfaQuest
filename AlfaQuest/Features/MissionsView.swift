import SwiftUI

struct MissionsView: View {
    @EnvironmentObject private var store: AppStore
    let openCamera: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let finds = store.state.finds(on: context.date, calendar: store.calendar)
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeading(
                    title: "Маленькие шаги.\nОбщие победы.",
                    subtitle: "Три задания на сегодня. Прогресс обновляется после находок.")
                ForEach(DailyMission.allCases) { mission in
                    missionCard(mission, finds: finds)
                }
                Surface {
                    HStack(spacing: 14) {
                        CoinBadge(size: 38)
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Все три — ещё +2 монеты").font(.headline)
                            Text(
                                "Награды начисляются автоматически, пока баланс внутренних монет меньше 100."
                            )
                            .font(.caption)
                            .foregroundColor(AppColors.secondary)
                        }
                    }
                }
                PrimaryButton(title: "Найти монеты", symbol: "camera.fill", action: openCamera)
            }
        }
    }

    private func missionCard(_ mission: DailyMission, finds: [FoundObject]) -> some View {
        let progress = mission.progress(in: finds)
        let complete = progress == mission.target
        return Surface {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(mission.title).font(.title3.weight(.semibold))
                    Spacer()
                    if complete {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(AppColors.green)
                    } else {
                        Text("\(progress)/\(mission.target)").font(.subheadline.monospacedDigit())
                    }
                }
                Text(mission.summary).font(.subheadline).foregroundColor(AppColors.secondary)
                ProgressView(value: Double(progress), total: Double(mission.target))
                    .tint(complete ? AppColors.green : AppColors.accent)
                    .accessibilityLabel("Прогресс: \(progress) из \(mission.target)")
                Text(complete ? "Выполнено · награда учтена" : "+1 внутренняя монета · +20 очков")
                    .font(.caption)
                    .foregroundColor(complete ? AppColors.green : AppColors.secondary)
            }
        }
    }
}
