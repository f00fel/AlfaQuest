import AudioToolbox
import UIKit

@MainActor
final class CollectionFeedbackPlayer {
    private var sound: SystemSoundID = 0

    init() {
        if let url = Bundle.main.url(forResource: "collect", withExtension: "wav") {
            AudioServicesCreateSystemSoundID(url as CFURL, &sound)
        }
    }

    deinit {
        if sound != 0 { AudioServicesDisposeSystemSoundID(sound) }
    }

    func play() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        if sound != 0 { AudioServicesPlaySystemSound(sound) }
    }
}
