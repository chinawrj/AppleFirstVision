import XCTest

final class LaunchTests: XCTestCase {
    func testLiveCameraModelSwitchesWhenBridgeAvailable() throws {
        #if targetEnvironment(simulator)
        let data = try? Data(contentsOf: URL(string: "http://127.0.0.1:8765/frame")!)
        try XCTSkipUnless(!(data?.isEmpty ?? true), "Live camera bridge is optional on CI; fixture inference is mandatory.")
        #endif
        let app = XCUIApplication()
        addUIInterruptionMonitor(withDescription: "Camera permission") { alert in
            for label in ["Allow", "允许", "OK", "好"] where alert.buttons[label].exists {
                alert.buttons[label].tap()
                return true
            }
            return false
        }
        app.launch()
        app.tap()
        let status = app.staticTexts["pipelineStatus"]
        for (button, model) in [("M · Balanced", "yolo26m"), ("X · Precision", "yolo26x"), ("S · Fast", "yolo26s")] {
            XCTAssertTrue(app.buttons[button].waitForExistence(timeout: 10))
            app.buttons[button].tap()
            expectation(for: NSPredicate(format: "label CONTAINS %@", model), evaluatedWith: status)
            waitForExpectations(timeout: 60)
            print("LIVE_MODEL \(model): \(status.label) latency=\(app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.hasSuffix(" ms") })")
        }
        app.buttons["M · Balanced"].tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "yolo26m"), evaluatedWith: status)
        waitForExpectations(timeout: 60)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Live camera with YOLO26m detection"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testRealModelPipelineAndPause() {
        let app = XCUIApplication()
        app.launchArguments = ["--fixture"]
        app.launch()
        XCTAssertTrue(app.staticTexts["See beyond."].waitForExistence(timeout: 15))
        let status = app.staticTexts["pipelineStatus"]
        let live = NSPredicate(format: "label CONTAINS %@", "Live · Core ML")
        expectation(for: live, evaluatedWith: status)
        waitForExpectations(timeout: 120)
        app.buttons["cameraToggle"].tap()
        XCTAssertEqual(status.label, "Paused")
        app.buttons["cameraToggle"].tap()
        expectation(for: live, evaluatedWith: status)
        waitForExpectations(timeout: 120)
    }
}
