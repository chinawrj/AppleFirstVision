import SwiftUI

@MainActor final class VisionStore: ObservableObject {
    @Published var image: CGImage?
    @Published var detections: [Detection] = []
    @Published var status = "Starting Core ML…"
    @Published var latency = 0.0
    @Published var frames = 0
    @Published var running = false
    @Published var modelName = "yolo26m"
    @Published var threshold = 0.35
    private let detector = Detector()
    private let camera = CameraSource()
    private let inferenceQueue = DispatchQueue(label: "yolo.inference", qos: .userInitiated)
    private var busy = false
    private var generation = 0
    private var streamTask: Task<Void, Never>?
    let labels: [String] = {
        guard let url = Bundle.main.url(forResource: "labels", withExtension: "json"),
              let data = try? Data(contentsOf: url), let labels = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return labels
    }()
    var source: String {
        if ProcessInfo.processInfo.arguments.contains("--fixture") { return "TEST FIXTURE" }
        #if targetEnvironment(simulator)
        return "MAC CAMERA · LOCAL BRIDGE"
        #else
        return "IPHONE CAMERA · ON DEVICE"
        #endif
    }
    func start() {
        guard !running else { return }
        running = true
        generation += 1
        if ProcessInfo.processInfo.arguments.contains("--fixture") {
            if let image = UIImage(named: "bus.jpg")?.cgImage { submit(image) }
            else { status = "Fixture unavailable" }
            return
        }
        #if targetEnvironment(simulator)
        streamTask = Task {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 3
            let session = URLSession(configuration: config)
            defer { session.invalidateAndCancel() }
            while !Task.isCancelled {
                if !busy {
                    do {
                        let (data, response) = try await session.data(from: URL(string: "http://127.0.0.1:8765/frame")!)
                        guard (response as? HTTPURLResponse)?.statusCode == 200,
                              let image = UIImage(data: data)?.cgImage else { throw URLError(.cannotDecodeContentData) }
                        if !Task.isCancelled { submit(image) }
                    } catch {
                        if !Task.isCancelled { status = "Waiting for Mac camera bridge: \(error.localizedDescription)" }
                    }
                }
                try? await Task.sleep(for: .milliseconds(70))
            }
        }
        #else
        camera.onFrame = { [weak self] image in Task { @MainActor in self?.submit(image) } }
        camera.onError = { [weak self] message in Task { @MainActor in self?.status = message } }
        camera.start()
        #endif
    }
    func stop() {
        running = false
        generation += 1
        streamTask?.cancel()
        streamTask = nil
        camera.stop()
        status = "Paused"
    }
    private func submit(_ frame: CGImage) {
        guard running, !busy else { return }
        busy = true
        let name = modelName, confidence = threshold, token = generation
        let engine = detector
        inferenceQueue.async { [self] in
            let start = CFAbsoluteTimeGetCurrent()
            let result = Result { try engine.predict(frame, name: name, threshold: confidence) }
            let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000
            Task { @MainActor in
                busy = false
                guard running, token == generation else { return }
                switch result {
                case .success(let values):
                    image = frame
                    detections = values
                    latency = elapsed
                    frames += 1
                    status = "Live · Core ML · \(name) · \(frames) frames"
                case .failure(let error): status = error.localizedDescription
                }
            }
        }
    }
}
