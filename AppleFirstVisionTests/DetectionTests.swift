import XCTest
import CoreML
import UIKit
@testable import AppleFirstVision

final class DetectionTests: XCTestCase {
    func tensor(_ rows: [[Double]]) throws -> MLMultiArray {
        let value = try MLMultiArray(shape: [1, NSNumber(value: rows.count), 6], dataType: .double)
        for (i, row) in rows.enumerated() { for (j, x) in row.enumerated() { value[[0, NSNumber(value: i), NSNumber(value: j)]] = NSNumber(value: x) } }
        return value
    }
    func testCoordinatesAndFiltering() throws {
        let value = try tensor([[64,128,320,384,0.9,0], [0,0,640,640,0.1,1]])
        let detections = try DetectionDecoder.decode(value, threshold: 0.35)
        XCTAssertEqual(detections.count, 1)
        XCTAssertEqual(detections[0].rect.minX, 0.1, accuracy: 0.0001)
        XCTAssertEqual(detections[0].rect.minY, 0.2, accuracy: 0.0001)
        XCTAssertEqual(detections[0].rect.width, 0.4, accuracy: 0.0001)
        XCTAssertEqual(detections[0].rect.height, 0.4, accuracy: 0.0001)
    }
    func testRejectsInvalidRowsAndClips() throws {
        let value = try tensor([[0,0,640,640,0.8,80], [0,0,640,640,Double.nan,0],
                                [100,100,10,10,0.9,0], [-64,-64,700,700,0.9,0]])
        let detections = try DetectionDecoder.decode(value, threshold: 0.35)
        XCTAssertEqual(detections.count, 1)
        XCTAssertEqual(detections[0].rect, CGRect(x: 0, y: 0, width: 1, height: 1))
    }
    func testRejectsUnexpectedOutputContract() throws {
        XCTAssertThrowsError(try DetectionDecoder.decode(MLMultiArray(shape: [1,84,8400], dataType: .float32), threshold: 0.35))
    }
    func testOfficialModelsDetectBusAndPeople() throws {
        let image = try XCTUnwrap(UIImage(named: "bus.jpg", in: Bundle.main, compatibleWith: nil)?.cgImage)
        let detector = Detector()
        for model in ["yolo26s", "yolo26m", "yolo26x"] {
            let start = Date()
            let detections = try detector.predict(image, name: model, threshold: 0.35)
            XCTAssertTrue(detections.contains { $0.classID == 5 }, "\(model) must detect bus")
            XCTAssertTrue(detections.contains { $0.classID == 0 }, "\(model) must detect person")
            print("MODEL_BENCHMARK \(model) cold_ms=\(Date().timeIntervalSince(start)*1000) detections=\(detections.count)")
        }
    }
}
