import XCTest

@MainActor
final class UmpQaUITests: XCTestCase {
  private var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication(bundleIdentifier: "com.syamo.hitasuraads")
    app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
    app.launch()
    XCTAssertTrue(app.staticTexts["qa_ready"].waitForExistence(timeout: 30))
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

  private func exactButton(_ labels: [String], timeout: TimeInterval) throws -> XCUIElement {
    let deadline = Date().addingTimeInterval(timeout)
    repeat {
      if app.staticTexts["qa_error"].exists {
        retainEvidence("sdk-error")
        XCTFail("Actual UMP request/form failed; inspect retained state and UI")
        throw NSError(domain: "HitasuraUmpQa", code: 1)
      }
      for label in labels {
        let button = app.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
        if button.exists && button.isHittable { return button }
      }
      Thread.sleep(forTimeInterval: 0.25)
    } while Date() < deadline
    retainEvidence("expected-control-missing")
    XCTFail("No visible native button with approved exact labels: \(labels)")
    throw NSError(domain: "HitasuraUmpQa", code: 2)
  }

  private func gather(_ choice: String, evidence: String) throws {
    try exactButton(["Reset and start EEA consent"], timeout: 5).tap()
    let button = try exactButton([choice], timeout: 90)
    retainEvidence("\(evidence)-actual-native-form")
    button.tap()
    XCTAssertTrue(app.staticTexts["consent_complete"].waitForExistence(timeout: 30))
    retainEvidence("\(evidence)-actual-sdk-result")
    // A refusal may still permit contextual/limited ads. Never assert that
    // canRequestAds == false means refusal or that true means personalization.
    let options = try exactButton(["Open required privacy options"], timeout: 5)
    XCTAssertTrue(options.isEnabled)
    options.tap()
    // Observed Hitasura UMP privacy-options UI reopens the three-choice page.
    // Exercise a real change, including withdrawal after the accept path.
    let changedChoice = choice == "Consent" ? "Do not consent" : "Consent"
    let confirm = try exactButton([changedChoice], timeout: 30)
    retainEvidence("\(evidence)-reopened-privacy-options")
    confirm.tap()
    XCTAssertTrue(app.staticTexts["privacy_options_complete"].waitForExistence(timeout: 30))
    retainEvidence("\(evidence)-privacy-options-result")
  }

  func testAcceptAndReopenPrivacyOptions() throws {
    try gather("Consent", evidence: "accept")
  }

  func testRefuseAndReopenPrivacyOptions() throws {
    try gather("Do not consent", evidence: "refuse")
  }
}
