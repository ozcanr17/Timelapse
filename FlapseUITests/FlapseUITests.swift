import XCTest

final class FlapseUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testFullJourney() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitests", "-auth.appleUserID", "uitest-user", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["FLAPSE_UI_TESTS"] = "1"
        app.launch()

        let startButton = app.buttons["Başla"]
        if startButton.waitForExistence(timeout: 5) {
            attachScreenshot(of: app, named: "welcome")
            startButton.tap()
        }

        let projectsTab = app.buttons["projectsTab"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 5))
        projectsTab.tap()

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

        let settingsScroll = app.collectionViews.firstMatch
        let showWelcomeButton = app.buttons["Karşılama ekranını göster"]
        var scrollAttempts = 0
        while !showWelcomeButton.exists, scrollAttempts < 10 {
            settingsScroll.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(showWelcomeButton.waitForExistence(timeout: 5))
        showWelcomeButton.tap()
        XCTAssertTrue(app.buttons["Başla"].waitForExistence(timeout: 5))
        app.buttons["Başla"].tap()
        XCTAssertTrue(app.buttons["homeTab"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["homeTab"].isSelected)
        settingsButton.tap()
        XCTAssertTrue(app.navigationBars["Ayarlar"].waitForExistence(timeout: 5))

        let darkroomTheme = app.buttons["theme-darkroom"]
        scrollAttempts = 0
        while !darkroomTheme.exists, scrollAttempts < 10 {
            settingsScroll.swipeUp()
            scrollAttempts += 1
        }
        XCTAssertTrue(darkroomTheme.waitForExistence(timeout: 5))
        darkroomTheme.tap()
        attachScreenshot(of: app, named: "settings-darkroom-theme")
        projectsTab.tap()

        XCTAssertTrue(card.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "project-list-darkroom-theme")

        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()
        XCTAssertTrue(app.staticTexts["Flapse Pro"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "paywall")
    }

    @MainActor
    func testSavedTabShowsEmptyState() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitests", "-auth.appleUserID", "uitest-user", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["FLAPSE_UI_TESTS"] = "1"
        app.launch()

        let startButton = app.buttons["Başla"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        let savedTab = app.buttons["savedTab"]
        XCTAssertTrue(savedTab.waitForExistence(timeout: 5))
        savedTab.tap()

        XCTAssertTrue(app.staticTexts["Henüz kayıtlı timelapse yok"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "saved-empty")
    }

    @MainActor
    func testInviteButtonDoesNotCrash() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitests", "-auth.appleUserID", "uitest-user", "-override.debugPro", "YES", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["FLAPSE_UI_TESTS"] = "1"
        app.launch()

        let startButton = app.buttons["Başla"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        let projectsTab = app.buttons["projectsTab"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 5))
        projectsTab.tap()

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
    func testPhotoImportPanelIsEdgeAttached() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitests", "-auth.appleUserID", "uitest-user", "-override.debugPro", "YES", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["FLAPSE_UI_TESTS"] = "1"
        app.launch()

        let startButton = app.buttons["Başla"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        let projectsTab = app.buttons["projectsTab"]
        XCTAssertTrue(projectsTab.waitForExistence(timeout: 5))
        projectsTab.tap()

        let addButton = app.buttons["addProjectButton"]
        XCTAssertTrue(addButton.waitForExistence(timeout: 5))
        addButton.tap()

        let titleField = app.textFields.firstMatch
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText("Panel Testi")
        app.buttons["Kaydet"].tap()

        let card = app.buttons["projectCard-Panel Testi"]
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()

        let importButton = app.buttons["importButton"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        importButton.tap()

        let panel = app.otherElements["photoImportPanel"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        XCTAssertEqual(panel.frame.minX, app.frame.minX, accuracy: 1)
        XCTAssertEqual(panel.frame.maxX, app.frame.maxX, accuracy: 1)
        XCTAssertEqual(panel.frame.height, app.frame.height * 0.75, accuracy: 2)
        attachScreenshot(of: app, named: "photo-import-edge-attached")
    }

    @MainActor
    func testRapidTabNavigationRemainsResponsive() throws {
        let app = XCUIApplication()
        app.launchArguments += ["--uitests", "-auth.appleUserID", "uitest-user", "-AppleLanguages", "(tr)", "-AppleLocale", "tr_TR"]
        app.launchEnvironment["FLAPSE_UI_TESTS"] = "1"
        app.launch()

        let startButton = app.buttons["Başla"]
        if startButton.waitForExistence(timeout: 5) {
            startButton.tap()
        }

        let tabs = ["projectsTab", "savedTab", "settingsButton", "homeTab"].map { app.buttons[$0] }
        XCTAssertTrue(tabs.allSatisfy { $0.waitForExistence(timeout: 5) })

        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric()], options: options) {
            for tab in tabs {
                tab.tap()
                XCTAssertTrue(tab.waitForExistence(timeout: 2))
            }
        }

        XCTAssertTrue(app.buttons["homeTab"].isSelected)
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
