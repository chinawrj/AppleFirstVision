import Cocoa
import AVFoundation
import Network

final class Bridge: NSObject, NSApplicationDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    let queue = DispatchQueue(label: "bridge.capture")
    let networkQueue = DispatchQueue(label: "bridge.network")
    let lock = NSLock()
    var jpeg: Data?
    var frameTime = Date.distantPast
    var listener: NWListener?
    let context = CIContext()
    var window: NSWindow!
    let status = NSTextField(labelWithString: "Requesting camera access…")
    func applicationDidFinishLaunching(_ notification: Notification) {
        window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 510, height: 150), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        window.title = "First Vision · Camera Bridge"
        status.frame = NSRect(x: 24, y: 35, width: 465, height: 85)
        status.maximumNumberOfLines = 4
        window.contentView?.addSubview(status)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        AVCaptureDevice.requestAccess(for: .video) { allowed in
            if allowed { self.queue.async { self.start() } }
            else { self.message("Camera access denied. Enable First Vision Camera Bridge in System Settings → Privacy & Security → Camera.") }
        }
    }
    func message(_ value: String) { DispatchQueue.main.async { self.status.stringValue = value }; print(value) }
    func start() {
        do {
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .unspecified) ?? AVCaptureDevice.default(for: .video) else {
                message("No camera found"); return
            }
            session.beginConfiguration()
            session.sessionPreset = .hd1280x720
            let input = try AVCaptureDeviceInput(device: device)
            session.addInput(input)
            let output = AVCaptureVideoDataOutput()
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: queue)
            session.addOutput(output)
            session.commitConfiguration()
            let parameters = NWParameters.tcp
            parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: 8765)
            let listener = try NWListener(using: parameters)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] connection in self?.serve(connection) }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state { self?.message(error.localizedDescription) }
            }
            listener.start(queue: networkQueue)
            session.startRunning()
            message("LIVE · \(device.localizedName)\n127.0.0.1:8765 · Local access only\nKeep this app open while using the iOS Simulator.")
        } catch { message(error.localizedDescription) }
    }
    func serve(_ connection: NWConnection) {
        connection.start(queue: networkQueue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, _, _ in
            guard let self else { connection.cancel(); return }
            let request = String(data: data ?? Data(), encoding: .utf8) ?? ""
            self.lock.lock()
            let frame = self.jpeg
            let fresh = Date().timeIntervalSince(self.frameTime) < 3
            self.lock.unlock()
            let valid = request.hasPrefix("GET /frame ")
            let body = valid && fresh ? frame ?? Data() : Data()
            let code = !valid ? "404 Not Found" : body.isEmpty ? "503 Service Unavailable" : "200 OK"
            var response = Data("HTTP/1.1 \(code)\r\nContent-Type: image/jpeg\r\nContent-Length: \(body.count)\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n".utf8)
            response.append(body)
            connection.send(content: response, completion: .contentProcessed { _ in connection.cancel() })
        }
        networkQueue.asyncAfter(deadline: .now() + 5) { connection.cancel() }
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ci = CIImage(cvPixelBuffer: buffer)
        guard let cg = context.createCGImage(ci, from: ci.extent),
              let data = NSBitmapImageRep(cgImage: cg).representation(using: .jpeg, properties: [.compressionFactor: 0.75]) else { return }
        lock.lock(); jpeg = data; frameTime = Date(); lock.unlock()
    }
    func applicationWillTerminate(_ notification: Notification) { session.stopRunning(); listener?.cancel() }
}
let app = NSApplication.shared
let delegate = Bridge()
app.setActivationPolicy(.regular)
app.delegate = delegate
app.run()
