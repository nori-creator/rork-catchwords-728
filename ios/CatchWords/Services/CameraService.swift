import AVFoundation
import UIKit

nonisolated enum CameraState: Equatable, Sendable {
    case idle
    case running
    case denied
    case unavailable
}

/// Real AVFoundation pipeline (also finds the cloud simulator's injected `.external` camera).
@Observable
final class CameraService: NSObject {
    var state: CameraState = .idle
    var zoom: CGFloat = 1

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var isConfigured = false
    private let queue = DispatchQueue(label: "catchwords.camera")
    private var photoContinuation: CheckedContinuation<UIImage?, Never>?

    func start() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: break
        case .notDetermined:
            let ok = await AVCaptureDevice.requestAccess(for: .video)
            if !ok { state = .denied; return }
        default:
            state = .denied
            return
        }
        if !isConfigured {
            guard configure() else { state = .unavailable; return }
        }
        let session = self.session
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            queue.async {
                if !session.isRunning { session.startRunning() }
                cont.resume()
            }
        }
        state = .running
    }

    func stop() {
        let session = self.session
        queue.async { if session.isRunning { session.stopRunning() } }
        if state == .running { state = .idle }
    }

    private func configure() -> Bool {
        var types: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
        types.append(.external)
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: .video, position: .unspecified)
        let preferred = discovery.devices.first(where: { $0.position == .back }) ?? discovery.devices.first
        guard let camera = preferred, let input = try? AVCaptureDeviceInput(device: camera) else { return false }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard session.canAddInput(input), session.canAddOutput(output) else {
            session.commitConfiguration()
            return false
        }
        session.addInput(input)
        session.addOutput(output)
        output.maxPhotoQualityPrioritization = .balanced
        session.commitConfiguration()
        device = camera
        isConfigured = true
        return true
    }

    /// Real optical/digital zoom (the web version could only CSS-scale).
    func setZoom(_ factor: CGFloat) {
        guard let device else { return }
        let clamped = max(device.minAvailableVideoZoomFactor, min(factor, min(device.maxAvailableVideoZoomFactor, 6)))
        zoom = clamped
        queue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            device.videoZoomFactor = clamped
            device.unlockForConfiguration()
        }
    }

    func focus(at devicePoint: CGPoint) {
        guard let device else { return }
        queue.async {
            guard (try? device.lockForConfiguration()) != nil else { return }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = devicePoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = devicePoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        }
    }

    func capture() async -> UIImage? {
        guard state == .running else { return nil }
        return await withCheckedContinuation { cont in
            photoContinuation = cont
            let settings = AVCapturePhotoSettings()
            if output.availablePhotoCodecTypes.contains(.jpeg) {
                settings.photoQualityPrioritization = .balanced
            }
            output.capturePhoto(with: settings, delegate: self)
        }
    }

    fileprivate func finish(_ image: UIImage?) {
        photoContinuation?.resume(returning: image)
        photoContinuation = nil
    }
}

extension CameraService: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let image = photo.fileDataRepresentation().flatMap { UIImage(data: $0) }?.normalizedOrientation()
        Task { @MainActor in self.finish(image) }
    }
}
