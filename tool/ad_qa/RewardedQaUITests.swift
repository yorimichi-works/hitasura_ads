import XCTest

@MainActor
final class RewardedQaUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication(bundleIdentifier: "com.syamo.hitasuraads")
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    XCTAssertTrue(app.staticTexts["ad_qa_ready"].waitForExistence(timeout: 30))
  }

  override func tearDownWithError() throws {
    retainEvidence("final-state")
    app.terminate()
  }

  private func retainEvidence(_ name: String) {
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = name
    screenshot.lifetime = .keepAlways
    add(screenshot)
    let hierarchy = XCTAttachment(string: app.debugDescription)
    hierarchy.name = "\(name)-accessibility"
    hierarchy.lifetime = .keepAlways
    add(hierarchy)
  }

  private func button(_ labels: [String], timeout: TimeInterval) throws -> XCUIElement {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if app.staticTexts["ad_qa_error"].exists {
        retainEvidence("actual-sdk-error")
        throw NSError(domain: "HitasuraRewardedQa", code: 1)
      }
      for label in labels {
        let predicate = NSPredicate(format: "label == %@", label)
        for element in app.buttons.matching(predicate).allElementsBoundByIndex.reversed() {
          let frame = element.frame
          if element.exists && !frame.isEmpty && frame.minX >= 0 && frame.minY >= 0 &&
            app.frame.intersects(frame) && element.isHittable {
            return element
          }
        }
      }
      Thread.sleep(forTimeInterval: 0.25)
    } while Date() < deadline
    retainEvidence("approved-control-missing")
    throw NSError(domain: "HitasuraRewardedQa", code: 2)
  }

  private func observeNativeTestMode() throws {
    let deadline = Date().addingTimeInterval(30)
    repeat {
      // The Flutter QA screen deliberately never renders this exact label.
      let query = app.descendants(matching: .any).matching(
        NSPredicate(format: "label == %@", "Test mode")
      )
      for label in query.allElementsBoundByIndex {
        if label.exists && !label.frame.isEmpty && app.frame.intersects(label.frame) && label.isHittable {
          retainEvidence("sdk-test-mode-visible")
          return
        }
      }
      Thread.sleep(forTimeInterval: 0.25)
    } while Date() < deadline
    retainEvidence("native-test-mode-not-proven")
    throw NSError(domain: "HitasuraRewardedQa", code: 3)
  }

  func testOneGoogleDemoRewardedAd() throws {
    try button(["Reset consent and load Google demo"], timeout: 5).tap()
    let consent = try button(["Consent"], timeout: 90)
    retainEvidence("actual-eea-consent-before-test-ad")
    consent.tap()
    XCTAssertTrue(app.staticTexts["ad_qa_loaded"].waitForExistence(timeout: 60))
    retainEvidence("actual-demo-load-callback")
    try button(["Show Google demo rewarded ad"], timeout: 5).tap()
    try observeNativeTestMode()
    // Only watch the official demo creative. Never tap its body, Install,
    // Learn More, an external link, or an unrecognized control.
    let deadline = Date().addingTimeInterval(60)
    while Date() < deadline && !app.staticTexts["sdk_reward_callback"].exists {
      Thread.sleep(forTimeInterval: 0.25)
    }
    let close = try button(["Close", "Close ad", "Close Ad"], timeout: 30)
    retainEvidence("approved-demo-dismiss-control")
    close.tap()
    XCTAssertTrue(app.staticTexts["ad_qa_complete"].waitForExistence(timeout: 30))
    retainEvidence("actual-reward-and-dismiss-result")
  }
}
