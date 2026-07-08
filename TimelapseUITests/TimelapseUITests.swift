import XCTest

final class TimelapseUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFullJourney() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitests", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launch()

        let startButton = app.buttons["Başla"]
        if startButton.waitForExistence(timeout: 5) {
            attachScreenshot(of: app, named: "welcome")
            startButton.tap()
        }

        let addButton = app.buttons["addProjectButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Sakal")
        app.buttons["Saç & Sakal"].tap()
        app.buttons["Kaydet"].tap()

        let card = app.buttons["projectCard-Sakal"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "project-list")

        card.tap()
        XCTAssertTrue(app.staticTexts["Henüz çekim yok"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "project-detail")
        app.navigationBars.buttons.firstMatch.tap()

        let settingsButton = app.buttons["settingsButton"]
        XCTAssertTrue(settingsButton.waitForExistence(timeout: 5))
        settingsButton.tap()
        XCTAssertTrue(app.navigationBars["Ayarlar"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "settings")

        let darkroomTheme = app.buttons["theme-darkroom"]
        let settingsScroll = app.collectionViews.firstMatch
        var scrollAttempts = 0
        while !darkroomTheme.exists, scrollAttempts < 10 {
            settingsScroll.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(darkroomTheme.waitForExistence(timeout: 5))
        darkroomTheme.tap()
        attachScreenshot(of: app, named: "settings-darkroom-theme")
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(card.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "project-list-darkroom-theme")

        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        XCTAssertTrue(app.staticTexts["Flapse Pro"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "paywall")
    }

    @MainActor
    func testInviteButtonDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitests", "-override.debugPro", "YES", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launch()

        let startButton = app.buttons["Başla"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        let addButton = app.buttons["addProjectButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Sakal")
        app.buttons["Saç & Sakal"].tap()
        app.buttons["Kaydet"].tap()

        let card = app.buttons["projectCard-Sakal"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()

        let inviteButton = app.buttons["inviteButton"]
        XCTAssertTrue(inviteButton.waitForExistence(timeout: 5))
        inviteButton.tap()

        sleep(3)
        XCTAssertEqual(app.state, .runningForeground)
        attachScreenshot(of: app, named: "invite-flow")
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
