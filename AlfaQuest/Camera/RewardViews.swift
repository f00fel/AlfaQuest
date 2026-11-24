import SwiftUI

struct CameraWallet: View {
    let wallet: Wallet

    var body: some View {
        HStack(spacing: 12) {
            ForEach(CoinKind.allCases, id: \.self) { kind in
                HStack(spacing: 5) {
                    CoinBadge(kind: kind, size: 21)
                    Text("\(wallet[kind])").font(.subheadline.bold()).monospacedDigit()
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(kind.title): \(wallet[kind])")
            }
        }
        .padding(12)
        .background(AppColors.surface.opacity(0.9), in: Capsule())
    }
}

struct RewardCard: View {
    let receipt: CollectionReceipt
    let continueSearching: () -> Void

    var body: some View {
        Surface {
            VStack(alignment: .leading, spacing: 17) {
                HStack(spacing: 13) {
                    RewardIcon(reward: receipt.reward, size: 52)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Находка твоя!").font(.title2.bold())
                        Text(receipt.reward.title).font(.subheadline).foregroundColor(AppColors.secondary)
                    }
                }
                if receipt.internalCoins > 0 {
                    Label("+\(receipt.internalCoins) внутренних монет", systemImage: "plus.circle.fill")
                        .foregroundColor(AppColors.accent)
                }
                if receipt.externalCoins > 0 {
                    Label("+\(receipt.externalCoins) внешняя монета", systemImage: "gift.fill")
                        .foregroundColor(AppColors.green)
                }
                Text("+\(receipt.points) очков").font(.subheadline)
                if receipt.completedMissions > 0 {
                    Text("Заданий выполнено: \(receipt.completedMissions). Награды включены.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                if receipt.externalLimitReached {
                    Text("Недельный лимит находок с внешними монетами — 3. Очки за находку учтены.")
                        .font(.caption)
                        .foregroundColor(AppColors.secondary)
                }
                PrimaryButton(title: "Искать дальше", symbol: "arrow.right", action: continueSearching)
            }
        }
    }
}

struct RewardIcon: View {
    let reward: FindReward
    let size: CGFloat

    var body: some View {
        if let kind = reward.coinKind {
            CoinBadge(kind: kind, size: size)
        } else {
            Image(systemName: "diamond.fill")
                .font(.system(size: size * 0.75))
                .foregroundColor(AppColors.purple)
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }
}

struct FlyingReward: View {
    let flight: CollectionFlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    var body: some View {
        GeometryReader { geometry in
            RewardIcon(reward: flight.receipt.reward, size: 38)
                .position(
                    x: arrived && !reduceMotion
                        ? geometry.size.width - 85 : geometry.size.width * flight.location.x,
                    y: arrived && !reduceMotion ? 36 : geometry.size.height * flight.location.y
                )
                .scaleEffect(arrived ? 0.4 : 1.15)
                .opacity(arrived ? 0 : 1)
                .task {
                    withAnimation(.easeInOut(duration: reduceMotion ? 0.2 : 0.65)) { arrived = true }
                }
        }
        .accessibilityHidden(true)
    }
}
