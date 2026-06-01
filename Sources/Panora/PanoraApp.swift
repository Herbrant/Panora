// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftData
import SwiftUI

/// App entry point: builds the SwiftData container and ``AppState``, then hosts the
/// main window and the menu bar extra. Substitutes test doubles under UI testing.
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
            MenuBarIconLabel()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarIconLabel: View {
    var body: some View {
        Image(nsImage: Self.image)
            .renderingMode(.template)
            .accessibilityHidden(true)
    }

    private static let image: NSImage = {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        NSColor.black.withAlphaComponent(0.22).setFill()
        NSBezierPath(roundedRect: NSRect(x: 1.6, y: 1.6, width: 14.8, height: 14.8), xRadius: 4.2, yRadius: 4.2).fill()

        NSColor.black.withAlphaComponent(0.9).setStroke()
        let pPath = NSBezierPath()
        pPath.lineWidth = 2.2
        pPath.lineCapStyle = .round
        pPath.lineJoinStyle = .round
        pPath.move(to: NSPoint(x: 5.4, y: 3.4))
        pPath.line(to: NSPoint(x: 5.4, y: 13.8))
        pPath.line(to: NSPoint(x: 9.5, y: 13.8))
        pPath.curve(to: NSPoint(x: 14.0, y: 9.4), controlPoint1: NSPoint(x: 12.4, y: 13.8), controlPoint2: NSPoint(x: 14.0, y: 12.1))
        pPath.curve(to: NSPoint(x: 9.5, y: 5.8), controlPoint1: NSPoint(x: 14.0, y: 7.0), controlPoint2: NSPoint(x: 12.4, y: 5.8))
        pPath.line(to: NSPoint(x: 5.4, y: 5.8))
        pPath.stroke()

        NSColor.black.setStroke()
        let wavePath = NSBezierPath()
        wavePath.lineWidth = 1.65
        wavePath.lineCapStyle = .round
        wavePath.lineJoinStyle = .round
        wavePath.move(to: NSPoint(x: 3.5, y: 8.9))
        wavePath.line(to: NSPoint(x: 6.3, y: 8.9))
        wavePath.curve(to: NSPoint(x: 7.4, y: 11.0), controlPoint1: NSPoint(x: 6.8, y: 8.9), controlPoint2: NSPoint(x: 6.8, y: 11.0))
        wavePath.curve(to: NSPoint(x: 8.6, y: 6.5), controlPoint1: NSPoint(x: 8.2, y: 11.0), controlPoint2: NSPoint(x: 7.8, y: 6.5))
        wavePath.curve(to: NSPoint(x: 10.1, y: 12.5), controlPoint1: NSPoint(x: 9.5, y: 6.5), controlPoint2: NSPoint(x: 9.2, y: 12.5))
        wavePath.curve(to: NSPoint(x: 11.4, y: 8.9), controlPoint1: NSPoint(x: 10.9, y: 12.5), controlPoint2: NSPoint(x: 10.6, y: 8.9))
        wavePath.line(to: NSPoint(x: 12.9, y: 8.9))
        wavePath.curve(to: NSPoint(x: 14.0, y: 10.6), controlPoint1: NSPoint(x: 13.4, y: 8.9), controlPoint2: NSPoint(x: 13.4, y: 10.6))
        wavePath.curve(to: NSPoint(x: 15.1, y: 8.9), controlPoint1: NSPoint(x: 14.6, y: 10.6), controlPoint2: NSPoint(x: 14.6, y: 8.9))
        wavePath.line(to: NSPoint(x: 15.8, y: 8.9))
        wavePath.stroke()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }()
}

/// In-memory session store used during UI tests so runs do not touch the Keychain.
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

/// Deterministic ``LastfmServing`` returning canned data for UI tests (no network).
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
