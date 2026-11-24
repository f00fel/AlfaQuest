import SwiftUI

@main
struct AlfaQuestApp: App {
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .tint(AppColors.accent)
                .onChange(of: scenePhase) { phase in
                    if phase == .active { store.refresh() }
                }
        }
    }
}
