import XCTest

/// Read-only capture of the process already prepared and attested by the host.
/// No launch/activate/terminate operation is allowed here: activate() can itself
/// launch a stopped application, so foreground is a hard precondition instead.
@MainActor
final class NativeScreenshotUITests: XCTestCase {
  func testCaptureExistingForegroundApp() throws {
    continueAfterFailure = false
    let app = XCUIApplication(bundleIdentifier: "com.syamo.hitasuraads")
    XCTAssertEqual(app.state, .runningForeground,
                   "Host must have an already-running foreground capture app")
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "hitasura-existing-native-frame"
    attachment.lifetime = .keepAlways
    add(attachment)
    XCTAssertEqual(app.state, .runningForeground,
                   "Capture app must remain foreground after the screenshot")
  }
}
