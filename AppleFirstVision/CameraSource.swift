import AVFoundation
import UIKit

final class CameraSource: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "camera.capture")
    private let context = CIContext()
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
                        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
                            connection.videoRotationAngle = 90
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
