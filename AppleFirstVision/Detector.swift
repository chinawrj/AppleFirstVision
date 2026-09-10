import UIKit
import Vision
import CoreML

/// Mutable Core ML state is protected by the lock, including model switches.
final class Detector: @unchecked Sendable {
    private let lock = NSLock()
    private var model: VNCoreMLModel?
    private var loadedName = ""
    func predict(_ image: CGImage, name: String, threshold: Double) throws -> [Detection] {
        lock.lock()
        defer { lock.unlock() }
        if model == nil || loadedName != name {
            guard let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") else {
                throw NSError(domain: "Model", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing \(name). Run scripts/export_models.py and rebuild."])
            }
            let config = MLModelConfiguration()
            #if targetEnvironment(simulator)
            config.computeUnits = .cpuOnly
            #else
            config.computeUnits = .all
            #endif
            model = try VNCoreMLModel(for: MLModel(contentsOf: url, configuration: config))
            loadedName = name
        }
        let request = VNCoreMLRequest(model: model!)
        request.imageCropAndScaleOption = .scaleFill
        try VNImageRequestHandler(cgImage: image, orientation: .up).perform([request])
        guard let array = (request.results?.first as? VNCoreMLFeatureValueObservation)?.featureValue.multiArrayValue else {
            throw NSError(domain: "Model", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unexpected YOLO26 output"])
        }
        return try DetectionDecoder.decode(array, threshold: threshold)
    }
}
