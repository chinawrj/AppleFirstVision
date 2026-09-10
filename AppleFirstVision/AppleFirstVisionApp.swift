import SwiftUI

@main struct AppleFirstVisionApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}

struct ContentView: View {
    @StateObject private var store = VisionStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("FIRST VISION").font(.caption.weight(.bold)).tracking(3).foregroundStyle(.mint)
                    Text("See beyond.").font(.largeTitle.bold())
                }
                Spacer()
                Text("YOLO26").font(.caption.monospaced().bold()).padding(10).background(.white.opacity(0.09), in: Capsule())
            }
            Text(store.source).font(.caption2.monospaced()).foregroundStyle(.secondary)
            GeometryReader { geo in
                ZStack {
                    RoundedRectangle(cornerRadius: 24).fill(.white.opacity(0.04))
                    if let image = store.image {
                        let size = fitted(image: image, in: geo.size)
                        Image(decorative: image, scale: 1).resizable().aspectRatio(contentMode: .fit)
                        ForEach(store.detections) { detection in
                            let r = detection.rect
                            RoundedRectangle(cornerRadius: 5).stroke(.mint, lineWidth: 2)
                                .overlay(alignment: .topLeading) {
                                    Text("\(label(detection.classID)) \(Int(detection.confidence * 100))%")
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .padding(4).background(.black.opacity(0.75)).foregroundStyle(.mint)
                                        .fixedSize().offset(y: -23)
                                }
                                .frame(width: r.width * size.width, height: r.height * size.height)
                                .position(x: (geo.size.width-size.width)/2 + r.midX*size.width,
                                          y: (geo.size.height-size.height)/2 + r.midY*size.height)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "viewfinder").font(.system(size: 52)).foregroundStyle(.mint)
                            Text("Connecting vision pipeline").font(.subheadline)
                        }
                    }
                }.clipped()
            }
            HStack(spacing: 0) {
                metric("OBJECTS", "\(store.detections.count)")
                metric("INFERENCE", "\(Int(store.latency)) ms")
                metric("FRAMES", "\(store.frames)")
            }.padding(.vertical, 12).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
            Picker("Model", selection: $store.modelName) {
                Text("S · Fast").tag("yolo26s")
                Text("M · Balanced").tag("yolo26m")
                Text("X · Precision").tag("yolo26x")
            }.pickerStyle(.segmented).accessibilityIdentifier("modelPicker")
            HStack {
                Text("Confidence").font(.caption)
                Slider(value: $store.threshold, in: 0.1...0.9, step: 0.05).tint(.mint)
                Text("\(Int(store.threshold * 100))%").font(.caption.monospaced()).frame(width: 36)
            }
            Text(store.status).font(.caption.monospaced()).foregroundStyle(.secondary)
                .accessibilityIdentifier("pipelineStatus").lineLimit(3)
            Button(store.running ? "Pause camera" : "Start camera") {
                if store.running { store.stop() } else { store.start() }
            }.buttonStyle(.borderedProminent).tint(.mint).foregroundStyle(.black)
                .frame(maxWidth: .infinity).accessibilityIdentifier("cameraToggle")
        }
        .padding(22).background(Color(red: 0.025, green: 0.045, blue: 0.065))
        .preferredColorScheme(.dark)
        .onAppear { store.start() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.start() } else { store.stop() }
        }
    }
    private func label(_ id: Int) -> String { store.labels.indices.contains(id) ? store.labels[id] : "Class \(id)" }
    private func metric(_ title: String, _ value: String) -> some View {
        VStack(spacing: 5) { Text(title).font(.system(size: 9, design: .monospaced)).foregroundStyle(.secondary); Text(value).font(.headline.monospaced()) }.frame(maxWidth: .infinity)
    }
    private func fitted(image: CGImage, in size: CGSize) -> CGSize {
        let scale = min(size.width / CGFloat(image.width), size.height / CGFloat(image.height))
        return CGSize(width: CGFloat(image.width)*scale, height: CGFloat(image.height)*scale)
    }
}
