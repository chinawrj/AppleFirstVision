import Foundation
import CoreML
import CoreGraphics

struct Detection: Identifiable {
    let id = UUID()
    let classID: Int
    let confidence: Double
    /// Normalized top-left-origin coordinates in the original image.
    let rect: CGRect
}

enum DetectionDecoder {
    enum Failure: Error { case invalidShape }
    static func decode(_ tensor: MLMultiArray, threshold: Double) throws -> [Detection] {
        guard tensor.shape.count == 3, tensor.shape[0].intValue == 1,
              tensor.shape[2].intValue == 6 else { throw Failure.invalidShape }
        return (0..<tensor.shape[1].intValue).compactMap { row in
            let v = (0..<6).map { tensor[[0, NSNumber(value: row), NSNumber(value: $0)]].doubleValue }
            guard v.allSatisfy(\.isFinite), v[4] >= threshold, v[4] <= 1,
                  v[5] >= 0, v[5] < 80, v[5].rounded() == v[5], v[2] > v[0], v[3] > v[1] else { return nil }
            let rect = CGRect(x: v[0]/640, y: v[1]/640, width: (v[2]-v[0])/640, height: (v[3]-v[1])/640)
                .intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
            guard !rect.isNull, rect.width > 0, rect.height > 0 else { return nil }
            return Detection(classID: Int(v[5]), confidence: v[4], rect: rect)
        }
    }
}
