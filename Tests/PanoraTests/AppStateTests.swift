@testable import Panora
import SwiftData
import XCTest

@MainActor
final class AppStateTests: XCTestCase {
    /// Keep container alive for the duration of the test (context does not
    /// retain it strongly enough when accessed asynchronously).
    private var container: ModelContainer?

    private func makeContext() -> ModelContext {
        let schema = Schema([ScrobbleEntry.self])
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("PanoraTests-\(UUID().uuidString).store")
        let config = ModelConfiguration(schema: schema, url: url)
        let c = try! ModelContainer(for: schema, configurations: [config])
        container = c
        return c.mainContext
    }

    override func tearDown() {
        container = nil
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: UUID().uuidString)!
    }

    private func track(
        artist: String = "Artist",
        title: String = "Song",
        bundleId: String? = "com.test.Player"
    ) -> TrackPlayback {
        TrackPlayback(artist: artist, title: title, album: nil, durationSeconds: 180,
                      elapsedSeconds: 10, isPlaying: true, bundleIdentifier: bundleId,
                      appName: bundleId.map { _ in "Test Player" })
    }

    // MARK: - Session restoration

    func testInitLoadsSessionFromStore() {
        let sessionStore = FakeSessionStore()
        sessionStore.save(LastfmSession(username: "storedUser", sessionKey: "storedKey"))
        let state = AppState(
            context: makeContext(), sessionStore: sessionStore,
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        XCTAssertEqual(state.session?.username, "storedUser")
        XCTAssertEqual(state.session?.sessionKey, "storedKey")
    }

    func testInitWithInitialSessionPreferredOverStore() {
        let sessionStore = FakeSessionStore()
        sessionStore.save(LastfmSession(username: "stored", sessionKey: "stored"))
        let state = AppState(
            context: makeContext(), sessionStore: sessionStore,
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false,
            initialSession: LastfmSession(username: "initial", sessionKey: "initial")
        )
        XCTAssertEqual(state.session?.username, "initial")
    }

    func testInitWithoutSessionLeavesNil() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        XCTAssertNil(state.session)
    }

    // MARK: - Auth

    func testBeginLoginSetsAuthorizing() async {
        let client = FakeLastfmClient()
        let state = AppState(
            context: makeContext(), client: client, sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        state.beginLogin()
        XCTAssertTrue(state.isAuthorizing)
        await settleMainActor()
        // isAuthorizing stays true in success path until completeLogin is called
        XCTAssertTrue(state.isAuthorizing)
        XCTAssertNil(state.authError)
    }

    func testBeginLoginWithAuthError() async {
        let client = FakeLastfmClient()
        client.fetchTokenError = LastfmError.http(500)
        let state = AppState(
            context: makeContext(), client: client, sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        state.beginLogin()
        await waitUntil { !state.isAuthorizing }
        XCTAssertNotNil(state.authError)
    }

    func testCompleteLoginWithoutPendingTokenShowsError() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        state.completeLogin()
        XCTAssertEqual(state.authError, "Start sign-in first.")
        XCTAssertFalse(state.isAuthorizing)
        XCTAssertNil(state.session)
    }

    func testCompleteLoginHappyPath() async {
        let client = FakeLastfmClient()
        let sessionStore = FakeSessionStore()
        let state = AppState(
            context: makeContext(), client: client, sessionStore: sessionStore,
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        // beginLogin sets pendingToken via its internal Task
        state.beginLogin()
        await settleMainActor()

        state.completeLogin()
        await waitUntil { !state.isAuthorizing }

        XCTAssertEqual(state.session?.username, "tester")
        XCTAssertEqual(state.session?.sessionKey, "session")
        XCTAssertEqual(sessionStore.stored?.username, "tester")
    }

    func testLogoutClearsSessionAndState() {
        let sessionStore = FakeSessionStore()
        sessionStore.save(LastfmSession(username: "u", sessionKey: "k"))
        let state = AppState(
            context: makeContext(), sessionStore: sessionStore,
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        state.logout()
        XCTAssertNil(state.session)
        XCTAssertNil(state.authError)
        XCTAssertFalse(state.isAuthorizing)
        XCTAssertNil(sessionStore.stored)
    }

    // MARK: - URL callback

    func testHandleCallbackWithAuthURLTriggersCompleteLogin() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        // completeLogin without pending token shows error
        state.handleCallback(url: URL(string: "panora://auth/callback?token=x")!)
        XCTAssertEqual(state.authError, "Start sign-in first.")
    }

    func testHandleCallbackWithNonAuthURLIgnored() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        state.handleCallback(url: URL(string: "panora://other")!)
        XCTAssertNil(state.authError)
        state.handleCallback(url: URL(string: "https://example.test")!)
        XCTAssertNil(state.authError)
    }

    // MARK: - Source filtering

    func testCompleteSourceSetupSetsSelectiveMode() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        state.completeSourceSetup(selective: true)
        XCTAssertTrue(state.hasCompletedSourceSetup)
        XCTAssertTrue(state.selectiveScrobblingEnabled)
    }

    func testCompleteSourceSetupDisablesSelective() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        state.completeSourceSetup(selective: false)
        XCTAssertTrue(state.hasCompletedSourceSetup)
        XCTAssertFalse(state.selectiveScrobblingEnabled)
    }

    func testSetSelectiveScrobblingToggle() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        state.setSelectiveScrobbling(true)
        XCTAssertTrue(state.selectiveScrobblingEnabled)
        state.setSelectiveScrobbling(false)
        XCTAssertFalse(state.selectiveScrobblingEnabled)
    }

    func testToggleAppAddsAndRemovesAllowed() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        state.toggleApp("com.test.Player", enabled: true)
        XCTAssertTrue(state.allowedApps.contains("com.test.Player"))
        state.toggleApp("com.test.Player", enabled: false)
        XCTAssertFalse(state.allowedApps.contains("com.test.Player"))
    }

    func testToggleAppMultipleApps() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        state.toggleApp("com.test.A", enabled: true)
        state.toggleApp("com.test.B", enabled: true)
        XCTAssertEqual(state.allowedApps.count, 2)
        state.toggleApp("com.test.A", enabled: false)
        XCTAssertEqual(state.allowedApps.count, 1)
        XCTAssertTrue(state.allowedApps.contains("com.test.B"))
    }

    func testSetupSelectiveAppsPersistsAllowedAppsAndCompletesSetup() {
        let defaults = makeDefaults()
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: defaults, startsMonitor: false, opensAuthorization: false
        )

        state.setupSelectiveApps(["com.test.A", "com.test.B"])

        XCTAssertTrue(state.hasCompletedSourceSetup)
        XCTAssertTrue(state.selectiveScrobblingEnabled)
        XCTAssertEqual(state.allowedApps, ["com.test.A", "com.test.B"])

        let reloaded = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: defaults, startsMonitor: false, opensAuthorization: false
        )
        XCTAssertTrue(reloaded.hasCompletedSourceSetup)
        XCTAssertTrue(reloaded.selectiveScrobblingEnabled)
        XCTAssertEqual(reloaded.allowedApps, ["com.test.A", "com.test.B"])
    }

    func testSelectiveFilteringAllowsOnlyConfiguredAppsToReachEngine() async {
        let client = FakeLastfmClient()
        let state = AppState(
            context: makeContext(), client: client, sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false,
            discoversApps: false,
            initialSession: LastfmSession(username: "tester", sessionKey: "session")
        )
        state.setupSelectiveApps(["com.test.Allowed"])

        state.monitor.onUpdate?(track(title: "Blocked", bundleId: "com.test.Blocked"))
        await settleMainActor()
        XCTAssertTrue(client.nowPlaying.isEmpty)

        state.monitor.onUpdate?(track(title: "Allowed", bundleId: "com.test.Allowed"))
        await waitUntil { client.nowPlaying.count == 1 }
        XCTAssertEqual(client.nowPlaying.first?.title, "Allowed")
    }

    func testSuspendedScrobblingRegistersAppButDoesNotSendNowPlaying() async {
        let client = FakeLastfmClient()
        let state = AppState(
            context: makeContext(), client: client, sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false,
            discoversApps: false,
            initialSession: LastfmSession(username: "tester", sessionKey: "session")
        )
        state.setScrobblingSuspended(true)

        state.monitor.onUpdate?(track(bundleId: "com.test.Suspended"))
        await settleMainActor()

        XCTAssertEqual(state.knownApps["com.test.Suspended"], "Test Player")
        XCTAssertEqual(state.current?.title, "Song")
        XCTAssertEqual(state.scrobbleProgress?.status, .suspended)
        XCTAssertTrue(client.nowPlaying.isEmpty)
    }

    func testReenablingScrobblingReappliesCurrentTrack() async {
        let client = FakeLastfmClient()
        let state = AppState(
            context: makeContext(), client: client, sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false,
            discoversApps: false,
            initialSession: LastfmSession(username: "tester", sessionKey: "session")
        )
        state.setScrobblingSuspended(true)
        state.monitor.onUpdate?(track(bundleId: "com.test.Player"))
        await settleMainActor()
        XCTAssertTrue(client.nowPlaying.isEmpty)

        state.setScrobblingSuspended(false)
        await waitUntil { client.nowPlaying.count == 1 }

        XCTAssertEqual(client.nowPlaying.first?.title, "Song")
        XCTAssertEqual(state.scrobbleProgress?.status, .waiting)
    }

    // MARK: - onUpdate wiring

    func testOnUpdateRegistersAppInKnownApps() async {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        let testTrack = track(bundleId: "com.test.Unique")
        state.monitor.onUpdate?(testTrack)
        await settleMainActor()
        XCTAssertEqual(state.knownApps["com.test.Unique"], "Test Player")
    }

    func testOnUpdateSkipsNilTrack() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false,
            discoversApps: false
        )
        state.monitor.onUpdate?(nil)
        XCTAssertTrue(state.knownApps.isEmpty)
    }

    func testOnUpdateDoesNotDuplicateKnownApps() async {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false,
            discoversApps: false
        )
        let testTrack = track(bundleId: "com.test.Same")
        XCTAssertTrue(state.knownApps.isEmpty)
        state.monitor.onUpdate?(testTrack)
        state.monitor.onUpdate?(testTrack)
        await settleMainActor()
        XCTAssertEqual(state.knownApps.count, 1)
    }

    // MARK: - Preference persistence

    func testPreferencesPersistSelectiveSetting() {
        let defaults = makeDefaults()
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: defaults, startsMonitor: false, opensAuthorization: false
        )
        state.setSelectiveScrobbling(true)
        state.toggleApp("com.test.Player", enabled: true)

        let reloaded = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: defaults, startsMonitor: false, opensAuthorization: false
        )
        XCTAssertTrue(reloaded.selectiveScrobblingEnabled)
        XCTAssertTrue(reloaded.allowedApps.contains("com.test.Player"))
    }

    func testPreferencesPersistSourceSetup() {
        let defaults = makeDefaults()
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: defaults, startsMonitor: false, opensAuthorization: false
        )
        state.completeSourceSetup(selective: true)

        let reloaded = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: defaults, startsMonitor: false, opensAuthorization: false
        )
        XCTAssertTrue(reloaded.hasCompletedSourceSetup)
        XCTAssertTrue(reloaded.selectiveScrobblingEnabled)
    }

    func testPreferencesPersistScrobblingSuspension() {
        let defaults = makeDefaults()
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: defaults, startsMonitor: false, opensAuthorization: false
        )
        state.setScrobblingSuspended(true)

        let reloaded = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: defaults, startsMonitor: false, opensAuthorization: false
        )
        XCTAssertTrue(reloaded.scrobblingSuspended)
    }

    // MARK: - isConfigured

    func testIsConfiguredDelegatesToClient() {
        let configuredClient = FakeLastfmClient()
        configuredClient.isConfigured = true
        let configured = AppState(
            context: makeContext(), client: configuredClient, sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        XCTAssertTrue(configured.isConfigured)

        let unconfiguredClient = FakeLastfmClient()
        unconfiguredClient.isConfigured = false
        let unconfigured = AppState(
            context: makeContext(), client: unconfiguredClient, sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false
        )
        XCTAssertFalse(unconfigured.isConfigured)
    }

    // MARK: - init sourceSetupCompleted

    func testInitAcceptsSourceSetupCompleted() {
        let state = AppState(
            context: makeContext(), sessionStore: FakeSessionStore(),
            defaults: makeDefaults(), startsMonitor: false, opensAuthorization: false,
            sourceSetupCompleted: true
        )
        XCTAssertTrue(state.hasCompletedSourceSetup)
    }
}
