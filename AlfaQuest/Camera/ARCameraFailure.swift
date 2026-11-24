import ARKit

struct ARCameraFailure: Equatable, Sendable {
    let message: String
    let diagnostic: String
    let requiresSettings: Bool

    init(error: Error) {
        let error = error as NSError
        diagnostic = "\(error.domain) · \(error.code)"
        requiresSettings =
            error.domain == ARErrorDomain && error.code == ARError.Code.cameraUnauthorized.rawValue
        guard error.domain == ARErrorDomain else {
            message = "AR остановился. Попробуй перезапустить камеру."
            return
        }
        switch ARError.Code(rawValue: error.code) {
        case .cameraUnauthorized:
            message = "Нужно разрешить камеру в настройках приложения."
        case .invalidReferenceImage, .insufficientFeatures:
            message = "AR не смог обработать постер. Попробуй перезапустить камеру."
        case .sensorFailed, .sensorUnavailable:
            message = "Камера временно недоступна для AR. Попробуй перезапустить её."
        case .worldTrackingFailed:
            message = "AR потерял положение в пространстве. Добавь света и перезапусти камеру."
        case .unsupportedConfiguration, .invalidConfiguration:
            message = "Не удалось запустить распознавание постеров. Попробуй перезапустить камеру."
        default:
            message = "AR остановился. Попробуй перезапустить камеру."
        }
    }

    init(message: String, diagnostic: String) {
        self.message = message
        self.diagnostic = diagnostic
        requiresSettings = false
    }
}
