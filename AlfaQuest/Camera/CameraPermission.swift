import ARKit
import AVFoundation
import Combine

@MainActor
final class CameraPermission: ObservableObject {
    enum Status {
        case checking, notRequested, denied, unsupported, authorized
    }

    @Published private(set) var status = Status.checking

    func refresh() {
        #if targetEnvironment(simulator)
            status = .unsupported
        #else
            guard ARWorldTrackingConfiguration.isSupported else {
                status = .unsupported
                return
            }
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: status = .authorized
            case .notDetermined: status = .notRequested
            case .denied, .restricted: status = .denied
            @unknown default: status = .denied
            }
        #endif
    }

    func request() async {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        status = granted ? .authorized : .denied
    }
}
