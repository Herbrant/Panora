import XCTest

final class PanoraSmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["PANORA_RUN_UI_TESTS"] == "1" else { return }
        app = XCUIApplication()
        app.launchEnvironment["PANORA_UI_TESTING"] = "1"
        app.launch()
    }

    override func tearDown() {
        app?.terminate()
        app = nil
    }

    private func skipIfNotUITesting() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["PANORA_RUN_UI_TESTS"] == "1",
            "Set PANORA_RUN_UI_TESTS=1 when running UI smoke tests (needs xcodebuild)."
        )
    }

    // MARK: - Smoke

    func testLaunchesMainWindowAndPrimarySections() throws {
        try skipIfNotUITesting()
        let mainWindow = app.windows["Panora"]
        XCTAssertTrue(mainWindow.waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["History"].waitForExistence(timeout: 5))

        app.staticTexts["Statistics"].click()
        XCTAssertTrue(app.staticTexts["UI Test"].waitForExistence(timeout: 5))

        app.staticTexts["Settings"].click()
        XCTAssertTrue(app.staticTexts["Account Last.fm"].waitForExistence(timeout: 5))
    }

    // MARK: - Sidebar navigation

    func testSidebarSectionsExist() throws {
        try skipIfNotUITesting()
        XCTAssertTrue(app.staticTexts["History"].exists)
        XCTAssertTrue(app.staticTexts["Statistics"].exists)
        XCTAssertTrue(app.staticTexts["Settings"].exists)
    }

    func testNavigateToEachSection() throws {
        try skipIfNotUITesting()
        app.staticTexts["Settings"].click()
        XCTAssertTrue(app.staticTexts["Signed in as"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["UITest"].waitForExistence(timeout: 3))

        app.staticTexts["History"].click()
        XCTAssertTrue(app.staticTexts["No scrobbles"].waitForExistence(timeout: 3))

        app.staticTexts["Statistics"].click()
        XCTAssertTrue(app.staticTexts["UI Test"].waitForExistence(timeout: 3))
    }

    // MARK: - History

    func testHistoryEmptyState() throws {
        try skipIfNotUITesting()
        app.staticTexts["History"].click()
        XCTAssertTrue(app.staticTexts["No scrobbles"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Played tracks will appear here once scrobbled."].waitForExistence(timeout: 3))
    }

    // MARK: - Statistics

    func testStatisticsShowsProfile() throws {
        try skipIfNotUITesting()
        app.staticTexts["Statistics"].click()

        XCTAssertTrue(app.staticTexts["UI Test"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["@UITest"].waitForExistence(timeout: 3))
    }

    func testStatisticsShowsScrobbleCount() throws {
        try skipIfNotUITesting()
        app.staticTexts["Statistics"].click()
        XCTAssertTrue(app.staticTexts["42 scrobbles"].waitForExistence(timeout: 5))
    }

    func testStatisticsShowsMetricsAndCharts() throws {
        try skipIfNotUITesting()
        app.staticTexts["Statistics"].click()

        XCTAssertTrue(app.staticTexts["Artist plays"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Track plays"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Top artist"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Top track"].waitForExistence(timeout: 3))

        XCTAssertTrue(app.staticTexts["Test Artist"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Test Track"].waitForExistence(timeout: 3))
    }

    func testStatisticsShowsTopArtistsPanel() throws {
        try skipIfNotUITesting()
        app.staticTexts["Statistics"].click()
        XCTAssertTrue(app.staticTexts["Top Artists"].waitForExistence(timeout: 5))
    }

    func testStatisticsShowsTopTracksPanel() throws {
        try skipIfNotUITesting()
        app.staticTexts["Statistics"].click()
        XCTAssertTrue(app.staticTexts["Top Tracks"].waitForExistence(timeout: 5))
    }

    func testStatisticsShowsRecentActivity() throws {
        try skipIfNotUITesting()
        app.staticTexts["Statistics"].click()
        XCTAssertTrue(app.staticTexts["Recent Activity"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Recent Track"].waitForExistence(timeout: 3))
    }

    // MARK: - Settings

    func testSettingsShowsAccountInfo() throws {
        try skipIfNotUITesting()
        app.staticTexts["Settings"].click()

        XCTAssertTrue(app.staticTexts["Signed in as"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["UITest"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Sign out"].exists)
    }

    func testSettingsHasSelectiveScrobblingToggle() throws {
        try skipIfNotUITesting()
        app.staticTexts["Settings"].click()

        XCTAssertTrue(app.staticTexts["Selective mode"].waitForExistence(timeout: 3))
    }

    func testSettingsSelectiveToggleShowsSources() throws {
        try skipIfNotUITesting()
        app.staticTexts["Settings"].click()
        // Initially selective is off
        let selectiveToggle = app.checkBoxes["Selective mode"]
        XCTAssertTrue(selectiveToggle.waitForExistence(timeout: 3))
        XCTAssertEqual(selectiveToggle.value as? String, "0")

        // Toggle on → sources section appears
        selectiveToggle.click()
        XCTAssertEqual(selectiveToggle.value as? String, "1")
    }

    // MARK: - Logout flow

    func testLogoutShowsOnboardingThenLoginReturns() throws {
        try skipIfNotUITesting()
        app.staticTexts["Settings"].click()
        XCTAssertTrue(app.buttons["Sign out"].waitForExistence(timeout: 3))
        app.buttons["Sign out"].click()

        // Onboarding shown after logout
        XCTAssertTrue(app.staticTexts["Sign in with Last.fm"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Sign in with Last.fm"].exists)

        // Sign in
        app.buttons["Sign in with Last.fm"].click()
        XCTAssertTrue(app.buttons["I've completed sign-in"].waitForExistence(timeout: 3))
        app.buttons["I've completed sign-in"].click()

        // Back to main split view
        XCTAssertTrue(app.staticTexts["Statistics"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["History"].exists)
        XCTAssertTrue(app.staticTexts["Settings"].exists)
    }
}
