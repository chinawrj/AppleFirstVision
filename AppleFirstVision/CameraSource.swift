import AVFoundation
import UIKit

final class CameraSource: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera.capture")
    private let context = CIContext()
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?
    var onFrame: ((CGImage) -> Void)?
    var onError: ((String) -> Void)?
    func start() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            guard granted else { self.onError?("Camera permission denied. Enable it in Settings."); return }
            self.queue.async {
                do {
                    if self.session.inputs.isEmpty {
                        self.session.beginConfiguration()
                        defer { self.session.commitConfiguration() }
                        self.session.sessionPreset = .hd1280x720
                        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                            self.onError?("No camera available"); return
                        }
                        let input = try AVCaptureDeviceInput(device: device)
                        guard self.session.canAddInput(input) else { return }
                        self.session.addInput(input)
                        let output = AVCaptureVideoDataOutput()
                        output.alwaysDiscardsLateVideoFrames = true
                        output.setSampleBufferDelegate(self, queue: self.queue)
                        guard self.session.canAddOutput(output) else { return }
                        self.session.addOutput(output)
                        if let connection = output.connection(with: .video) {
                            let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: nil)
                            self.rotationCoordinator = coordinator
                            self.rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelCapture, options: [.initial, .new]) { [weak self] coordinator, _ in
                                let angle = coordinator.videoRotationAngleForHorizonLevelCapture
                                self?.queue.async {
                                    if connection.isVideoRotationAngleSupported(angle) {
                                        connection.videoRotationAngle = angle
                                    }
                                }
                            }
                        }
                    }
                    self.session.startRunning()
                } catch { self.onError?(error.localizedDescription) }
            }
        }
    }
    func stop() { queue.async { self.session.stopRunning() } }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: buffer)
        if let image = context.createCGImage(ci, from: ci.extent) { onFrame?(image) }
    }
}
