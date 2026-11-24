@preconcurrency import ARKit
import AVFoundation
import Combine
import SwiftUI

enum TrackingStatus: Equatable, Sendable {
    case preparing, initializing, ready, paused
    case limited(String)
    case failed(ARCameraFailure)

    var instruction: String {
        switch self {
        case .preparing: return "Подготавливаем постеры для AR…"
        case .initializing: return "Медленно поводите телефоном перед собой"
        case .ready: return "Наведи камеру на постер-котика"
        case .paused: return "Камера приостановлена"
        case .limited(let text): return text
        case .failed(let failure): return failure.message
        }
    }
}

struct CollectionFlight: Identifiable {
    let id: UUID
    let location: UnitPoint
    let receipt: CollectionReceipt
}

@MainActor
final class ARHuntController: NSObject, ObservableObject {
    @Published private(set) var tracking = TrackingStatus.initializing
    @Published private(set) var attempt: HuntAttempt?
    @Published private(set) var receipt: CollectionReceipt?
    @Published private(set) var notice: String?
    @Published private(set) var flight: CollectionFlight?

    private weak var view: ARSCNView?
    private var lifecycle = CameraSessionLifecycle()
    private var preparation: Task<Void, Never>?
    private var sessionDelegate: ARCameraDelegate?
    private let markers = MarkerCatalog()
    private let diagnostics = ARCameraDiagnostics()
    private var coin: SCNNode?
    private var latestMarker: MarkerObservation?
    private var consideredMarkers: Set<UUID> = []
    private var timeout: Task<Void, Never>?
    private let feedbackPlayer = CollectionFeedbackPlayer()

    private var begin: ((OfficeZone) -> Result<HuntAttempt, HuntError>)?
    private var collect: ((UUID) -> Result<CollectionReceipt, HuntError>)?
    private var cancel: ((UUID?) -> Void)?

    func connect(
        _ view: ARSCNView, begin: @escaping (OfficeZone) -> Result<HuntAttempt, HuntError>,
        collect: @escaping (UUID) -> Result<CollectionReceipt, HuntError>, cancel: @escaping (UUID?) -> Void
    ) {
        preparation?.cancel()
        pauseSession()
        lifecycle.attach()
        self.view = view
        self.begin = begin
        self.collect = collect
        self.cancel = cancel
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
        diagnostics.record("Camera view attached")
        requestStart()
    }

    func disconnect(_ view: ARSCNView) {
        guard self.view === view else { return }
        preparation?.cancel()
        preparation = nil
        lifecycle.detach()
        timeout?.cancel()
        let pendingID = attempt?.id
        let cancellation = cancel
        pauseSession()
        self.view = nil
        coin = nil
        begin = nil
        collect = nil
        cancel = nil
        diagnostics.record("Camera view detached")
        Task { @MainActor [weak self] in
            if let pendingID { cancellation?(pendingID) }
            guard let self, self.view == nil else { return }
            self.attempt = nil
        }
    }

    func setActive(_ active: Bool) {
        let wasActive = lifecycle.isActive
        lifecycle.setActive(active)
        if active {
            requestStart()
        } else if wasActive {
            preparation?.cancel()
            endAttempt()
            pauseSession()
            tracking = .paused
            diagnostics.record("Camera paused: screen or application inactive")
        }
    }

    func restart() {
        preparation?.cancel()
        lifecycle.reset()
        endAttempt()
        pauseSession()
        requestStart()
    }

    func retry() {
        guard lifecycle.isActive, tracking == .ready, let marker = latestMarker, attempt == nil else {
            return
        }
        receipt = nil
        showObject(at: marker)
    }

    func continueSearching() {
        receipt = nil
        notice = nil
        consideredMarkers.removeAll()
    }

    private func requestStart() {
        guard let view, let run = lifecycle.prepare() else { return }
        diagnostics.record("Preparing AR run \(run)")
        preparation = Task { @MainActor [weak self, weak view] in
            await Task.yield()
            guard self?.lifecycle.phase == .preparing(run), view != nil,
                let catalog = self?.markers, let diagnostics = self?.diagnostics
            else { return }
            self?.tracking = .preparing
            do {
                let images = try await catalog.images(diagnostics: diagnostics)
                try Task.checkCancellation()
                guard let self, let view, self.view === view else { return }
                self.startSession(view, images: images, run: run)
            } catch is CancellationError {
                return
            } catch {
                self?.failed(ARCameraFailure(error: error), details: error.localizedDescription, run: run)
            }
        }
    }

    private func startSession(_ view: ARSCNView, images: Set<ARReferenceImage>, run: UUID) {
        guard lifecycle.phase == .preparing(run) else { return }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            let error = NSError(domain: ARErrorDomain, code: ARError.Code.cameraUnauthorized.rawValue)
            failed(ARCameraFailure(error: error), details: error.localizedDescription, run: run)
            return
        }
        guard lifecycle.start(run) else { return }
        preparation = nil
        endAttempt()
        consideredMarkers.removeAll()
        latestMarker = nil
        receipt = nil
        notice = nil

        // A failed capture pipeline must not be reused by the Restart button.
        pauseSession()
        let session = ARSession()
        let delegate = ARCameraDelegate(owner: self, run: run)
        session.delegateQueue = .main
        session.delegate = delegate
        sessionDelegate = delegate
        view.session = session
        let configuration = ARWorldTrackingConfiguration()
        configuration.detectionImages = images
        configuration.maximumNumberOfTrackedImages = 1
        configuration.isLightEstimationEnabled = false
        tracking = .initializing
        diagnostics.record("Starting AR run \(run), markers=\(images.count)")
        session.run(configuration)
    }

    private func pauseSession() {
        view?.session.delegate = nil
        view?.session.pause()
        sessionDelegate = nil
    }

    fileprivate func receive(_ observations: [MarkerObservation], run: UUID) {
        guard lifecycle.acceptsEvents(from: run), tracking == .ready else { return }
        for marker in observations {
            guard marker.isTracked else {
                if latestMarker?.id == marker.id { latestMarker = nil }
                consideredMarkers.remove(marker.id)
                continue
            }
            latestMarker = marker
            guard consideredMarkers.insert(marker.id).inserted, attempt == nil, receipt == nil else {
                continue
            }
            showObject(at: marker)
        }
    }

    private func showObject(at marker: MarkerObservation) {
        guard let view, let cameraTransform = view.session.currentFrame?.camera.transform,
            let result = begin?(marker.zone)
        else { return }
        switch result {
        case .failure(let error): notice = error.localizedDescription
        case .success(let attempt):
            self.attempt = attempt
            notice = nil
            let node = CoinNodeFactory.make(
                reward: attempt.target.reward, reduceMotion: UIAccessibility.isReduceMotionEnabled)
            node.name = attempt.id.uuidString
            var generator = SystemRandomNumberGenerator()
            node.simdPosition = HuntObjectPlacement.position(relativeTo: cameraTransform, using: &generator)
            node.simdLook(
                at: SIMD3(
                    cameraTransform.columns.3.x, cameraTransform.columns.3.y, cameraTransform.columns.3.z),
                up: SIMD3(0, 1, 0), localFront: SIMD3(0, 0, 1))
            if let camera = view.pointOfView {
                HuntSceneLighting.update(for: camera, in: view.scene)
            }
            view.scene.rootNode.addChildNode(node)
            coin = node
            timeout?.cancel()
            timeout = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: .seconds(max(0, attempt.expiresAt.timeIntervalSinceNow)))
                } catch { return }
                guard let self, self.attempt?.id == attempt.id else { return }
                self.endAttempt()
                self.notice = HuntError.attemptExpired.localizedDescription
            }
        }
    }

    private func endAttempt() {
        timeout?.cancel()
        timeout = nil
        if let attempt { cancel?(attempt.id) }
        attempt = nil
        coin?.removeFromParentNode()
        coin = nil
    }

    @objc private func tapped(_ gesture: UITapGestureRecognizer) {
        guard lifecycle.isActive, tracking == .ready, let view, let coin, let attempt else { return }
        let location = gesture.location(in: view)
        let hits = view.hitTest(location, options: [.searchMode: SCNHitTestSearchMode.all.rawValue])
        let hitCoin = hits.contains { result in
            var node: SCNNode? = result.node
            while let candidate = node {
                if candidate === coin { return true }
                node = candidate.parent
            }
            return false
        }
        guard hitCoin, let result = collect?(attempt.id) else { return }
        switch result {
        case .failure(let error):
            notice = error.localizedDescription
            endAttempt()
        case .success(let receipt):
            timeout?.cancel()
            self.attempt = nil
            self.coin = nil
            self.receipt = receipt
            flight = CollectionFlight(
                id: receipt.id,
                location: UnitPoint(
                    x: location.x / max(view.bounds.width, 1), y: location.y / max(view.bounds.height, 1)),
                receipt: receipt)
            coin.runAction(
                .sequence([
                    .group([.moveBy(x: 0, y: 0.12, z: 0, duration: 0.2), .scale(to: 0.01, duration: 0.2)]),
                    .removeFromParentNode(),
                ]))
            feedbackPlayer.play()
        }
    }

    fileprivate func trackingChanged(_ status: TrackingStatus, run: UUID) {
        guard lifecycle.acceptsEvents(from: run) else { return }
        if tracking != status {
            diagnostics.record("Tracking \(run): \(status.instruction)")
            tracking = status
        }
    }

    fileprivate func receivedFrames(_ event: String, run: UUID) {
        guard lifecycle.acceptsEvents(from: run) else { return }
        diagnostics.record("AR run \(run): \(event)")
    }

    fileprivate func interrupted(run: UUID) {
        guard lifecycle.interrupt(run) else { return }
        endAttempt()
        tracking = .paused
        diagnostics.record("AR run interrupted: \(run)")
    }

    fileprivate func interruptionEnded(run: UUID) {
        guard lifecycle.resume(run) else { return }
        requestStart()
    }

    fileprivate func failed(_ failure: ARCameraFailure, details: String, run: UUID) {
        guard lifecycle.fail(run) else { return }
        preparation = nil
        endAttempt()
        pauseSession()
        notice = nil
        tracking = .failed(failure)
        diagnostics.record("AR run \(run) failed: \(failure.diagnostic); \(details)")
    }
}

private struct MarkerObservation: Sendable {
    let id: UUID
    let zone: OfficeZone
    let isTracked: Bool
}

/// Each delegate keeps its run ID, so queued callbacks cannot affect a replacement session.
private final class ARCameraDelegate: NSObject, ARSessionDelegate {
    private weak var owner: ARHuntController?
    private let run: UUID
    private var firstFrameTime: TimeInterval?
    private var reportedContinuousFrames = false

    init(owner: ARHuntController, run: UUID) {
        self.owner = owner
        self.run = run
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) { receive(anchors) }
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) { receive(anchors) }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        let event: String
        if let firstFrameTime {
            guard !reportedContinuousFrames, frame.timestamp - firstFrameTime >= 3 else { return }
            reportedContinuousFrames = true
            event = "camera frames continue after 3 seconds"
        } else {
            firstFrameTime = frame.timestamp
            event = "first camera frame received"
        }
        let run = run
        Task { @MainActor [weak owner] in owner?.receivedFrames(event, run: run) }
    }

    private func receive(_ anchors: [ARAnchor]) {
        let observations = anchors.compactMap { anchor -> MarkerObservation? in
            guard let image = anchor as? ARImageAnchor, let name = image.referenceImage.name,
                let zone = OfficeZone.allCases.first(where: { $0.markerName == name })
            else { return nil }
            return MarkerObservation(
                id: image.identifier, zone: zone, isTracked: image.isTracked)
        }
        guard !observations.isEmpty else { return }
        let run = run
        Task { @MainActor [weak owner] in owner?.receive(observations, run: run) }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let status: TrackingStatus
        switch camera.trackingState {
        case .normal: status = .ready
        case .notAvailable: status = .initializing
        case .limited(let reason):
            switch reason {
            case .excessiveMotion: status = .limited("Двигай телефон чуть медленнее")
            case .insufficientFeatures: status = .limited("Добавь света и наведи камеру на предметы вокруг")
            case .relocalizing: status = .limited("Возвращаемся в пространство…")
            default: status = .initializing
            }
        }
        let run = run
        Task { @MainActor [weak owner] in owner?.trackingChanged(status, run: run) }
    }

    func sessionWasInterrupted(_ session: ARSession) {
        let run = run
        Task { @MainActor [weak owner] in owner?.interrupted(run: run) }
    }

    func sessionInterruptionEnded(_ session: ARSession) {
        let run = run
        Task { @MainActor [weak owner] in owner?.interruptionEnded(run: run) }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        let failure = ARCameraFailure(error: error)
        let nsError = error as NSError
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        let details = [nsError.localizedDescription, underlying?.description].compactMap { $0 }.joined(
            separator: "; ")
        let run = run
        Task { @MainActor [weak owner] in owner?.failed(failure, details: details, run: run) }
    }
}
