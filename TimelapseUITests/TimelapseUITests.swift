import XCTest

final class TimelapseUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAddProjectFlow() throws {
        let app = XCUIApplication()
        app.launch()

        app.navigationBars["Projeler"].buttons.firstMatch.tap()

        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Sakal")

        app.buttons["Saç & Sakal"].tap()
        app.buttons["Kaydet"].tap()

        let card = app.staticTexts["Sakal"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "project-list")

        card.tap()
        XCTAssertTrue(app.staticTexts["Henüz çekim yok"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "project-detail")

        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars["Projeler"].buttons.firstMatch.tap()

        XCTAssertTrue(app.staticTexts["Timelapse Pro"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "paywall")
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
