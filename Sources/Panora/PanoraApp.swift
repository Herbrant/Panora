import SwiftData
import SwiftUI

@main
struct PanoraApp: App {
    private let container: ModelContainer
    @State private var appState: AppState

    init() {
        let isUITesting = ProcessInfo.processInfo.environment["PANORA_UI_TESTING"] == "1"
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isUITesting)
        let container = try! ModelContainer(for: ScrobbleEntry.self, configurations: configuration)
        self.container = container
        if isUITesting {
            _appState = State(initialValue: AppState(
                context: container.mainContext,
                client: UITestLastfmClient(),
                sessionStore: InMemoryLastfmSessionStore(session: LastfmSession(username: "UITest", sessionKey: "test-session")),
                defaults: UserDefaults(suiteName: "PanoraUITests") ?? .standard,
                startsMonitor: false,
                opensAuthorization: false,
                initialSession: LastfmSession(username: "UITest", sessionKey: "test-session"),
                sourceSetupCompleted: true
            ))
        } else {
            _appState = State(initialValue: AppState(context: container.mainContext))
        }
    }

    var body: some Scene {
        Window("Panora", id: "main") {
            MainWindowView()
                .environment(appState)
                .accessibilityIdentifier("panora.mainWindow")
                .task { appState.start() }
                .onOpenURL { appState.handleCallback(url: $0) }
        }
        .modelContainer(container)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .onOpenURL { appState.handleCallback(url: $0) }
        } label: {
            Image(systemName: "music.note")
        }
        .menuBarExtraStyle(.window)
    }
}

private final class InMemoryLastfmSessionStore: LastfmSessionStoring {
    private var session: LastfmSession?

    init(session: LastfmSession? = nil) {
        self.session = session
    }

    func load() -> LastfmSession? {
        session
    }

    func save(_ session: LastfmSession) {
        self.session = session
    }

    func clear() {
        session = nil
    }
}

private final class UITestLastfmClient: LastfmServing {
    var isConfigured: Bool { true }

    func fetchRequestToken() async throws -> String {
        "ui-test-token"
    }

    func authorizationURL(token: String, callbackURL: String?) -> URL {
        URL(string: "https://example.com/auth?token=\(token)")!
    }

    func fetchSession(token: String) async throws -> LastfmSession {
        LastfmSession(username: "UITest", sessionKey: "test-session")
    }

    func updateNowPlaying(track: ScrobbleTrack, sessionKey: String) async throws {}

    func scrobble(track: ScrobbleTrack, timestamp: Int, sessionKey: String) async throws {}

    func userInfo(_ user: String) async throws -> LastfmUserInfo {
        LastfmUserInfo(
            name: user,
            realName: "UI Test",
            playcount: 42,
            registered: Date(timeIntervalSince1970: 1_700_000_000),
            imageURL: nil,
            profileURL: URL(string: "https://last.fm/user/\(user)")
        )
    }

    func topArtists(_ user: String, period: StatsPeriod, limit: Int) async throws -> [LastfmTopArtist] {
        [LastfmTopArtist(name: "Test Artist", playcount: 21, imageURL: nil, url: nil)]
    }

    func topTracks(_ user: String, period: StatsPeriod, limit: Int) async throws -> [LastfmTopTrack] {
        [LastfmTopTrack(name: "Test Track", artist: "Test Artist", playcount: 12, imageURL: nil, url: nil)]
    }

    func recentTracks(_ user: String, limit: Int) async throws -> [LastfmRecentTrack] {
        [LastfmRecentTrack(name: "Recent Track", artist: "Test Artist", album: nil, date: Date(), nowPlaying: false, imageURL: nil)]
    }
}
