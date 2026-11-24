import SwiftUI

struct CompassMark: Shape {
    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let points = (0..<8).map { index -> CGPoint in
            let angle = Double(index) * .pi / 4 - .pi / 2
            let length = index.isMultiple(of: 2) ? radius : radius * 0.25
            return CGPoint(x: center.x + cos(angle) * length, y: center.y + sin(angle) * length)
        }
        var path = Path()
        path.addLines(points)
        path.closeSubpath()
        return path
    }
}

struct CoinBadge: View {
    var kind: CoinKind = .internalCoin
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [kind.color.opacity(0.75), kind.color, kind.color.opacity(0.65)],
                        startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 1))
            Circle()
                .stroke(.black.opacity(0.18), lineWidth: max(1, size * 0.02))
                .padding(size * 0.1)
            CompassMark()
                .fill(
                    LinearGradient(
                        colors: [.white.opacity(0.85), .white.opacity(0.15)], startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                )
                .frame(width: size * 0.58, height: size * 0.58)
                .rotationEffect(.degrees(12))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct WalletView: View {
    let wallet: Wallet

    var body: some View {
        HStack(spacing: 10) {
            ForEach(CoinKind.allCases, id: \.self) { kind in
                VStack(alignment: .leading, spacing: 12) {
                    CoinBadge(kind: kind, size: 32)
                    Text("\(wallet[kind])")
                        .font(.system(.title2, weight: .bold))
                        .monospacedDigit()
                    Text(kind.title)
                        .font(.caption2)
                        .foregroundColor(AppColors.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(15)
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(kind.title) монеты: \(wallet[kind])")
            }
        }
    }
}
