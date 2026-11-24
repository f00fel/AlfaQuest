import SwiftUI

enum AppColors {
    static let background = Color(red: 16 / 255, green: 17 / 255, blue: 19 / 255)
    static let surface = Color(red: 32 / 255, green: 34 / 255, blue: 38 / 255)
    static let raised = Color(red: 43 / 255, green: 45 / 255, blue: 50 / 255)
    static let accent = Color(red: 226 / 255, green: 67 / 255, blue: 54 / 255)
    static let text = Color(red: 246 / 255, green: 246 / 255, blue: 247 / 255)
    static let secondary = Color(red: 166 / 255, green: 168 / 255, blue: 175 / 255)
    static let gold = Color(red: 222 / 255, green: 185 / 255, blue: 93 / 255)
    static let green = Color(red: 66 / 255, green: 168 / 255, blue: 141 / 255)
    static let purple = Color(red: 168 / 255, green: 132 / 255, blue: 225 / 255)
}

extension CoinKind {
    var color: Color {
        switch self {
        case .internalCoin: return AppColors.accent
        case .externalCoin: return AppColors.green
        case .superCoin: return AppColors.gold
        }
    }
}
