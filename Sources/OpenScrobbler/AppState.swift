import AppKit
import Foundation
import Observation
import SwiftData

/// Top-level coordinator wiring detection, scrobbling, persistence and auth.
@MainActor
@Observable
final class AppState {
    private(set) var session: LastfmSession?
    var authError: String?
    var isAuthorizing = false

    let monitor: NowPlayingMonitor
    private let engine: ScrobbleEngine
    private let client = LastfmClient()
    private var pendingToken: String?
    private var started = false

    // Source filtering
    private(set) var selectiveScrobblingEnabled: Bool = false
    private(set) var hasCompletedSourceSetup: Bool = false
    private(set) var allowedApps: Set<String> = []
    private(set) var knownApps: [String: String] = [:]

    var current: TrackPlayback? { filter(monitor.current) }
    var isConfigured: Bool { LastfmConfig.isConfigured }

    var isCurrentScrobbled: Bool {
        guard let id = monitor.current?.identity else { return false }
        return engine.lastScrobbledIdentity == id
    }

    init(context: ModelContext) {
        let store = ScrobbleStore(context: context)
        let monitor = NowPlayingMonitor()
        self.monitor = monitor
        self.session = KeychainStore.load()

        var sessionRef: () -> LastfmSession? = { nil }
        let engine = ScrobbleEngine(client: client, store: store, sessionProvider: { sessionRef() })
        self.engine = engine
        sessionRef = { [weak self] in self?.session }

        loadPreferences()

        monitor.onUpdate = { [weak self, weak engine] track in
            guard let self else { engine?.handle(track); return }
            if let track { self.registerApp(track) }
            engine?.handle(self.filter(track))
        }
    }

    func start() {
        guard !started else { return }
        started = true
        monitor.start()
        Task { await engine.flushQueue() }
    }

    // MARK: Source filtering

    func completeSourceSetup(selective: Bool) {
        hasCompletedSourceSetup = true
        selectiveScrobblingEnabled = selective
        savePreferences()
    }

    func setSelectiveScrobbling(_ enabled: Bool) {
        selectiveScrobblingEnabled = enabled
        savePreferences()
        reapplyFilter()
    }

    func toggleApp(_ bundleId: String, enabled: Bool) {
        if enabled {
            allowedApps.insert(bundleId)
        } else {
            allowedApps.remove(bundleId)
        }
        savePreferences()
        reapplyFilter()
    }

    private func reapplyFilter() {
        engine.handle(filter(monitor.current))
    }

    private func registerApp(_ track: TrackPlayback) {
        guard let id = track.bundleIdentifier else { return }
        if knownApps[id] == nil {
            knownApps[id] = track.appName ?? id
            savePreferences()
        }
    }

    private func filter(_ track: TrackPlayback?) -> TrackPlayback? {
        guard selectiveScrobblingEnabled,
              let track,
              let id = track.bundleIdentifier else { return track }
        return allowedApps.contains(id) ? track : nil
    }

    // MARK: Preferences persistence

    private enum Keys {
        static let selectiveEnabled = "scrobbler.selectiveEnabled"
        static let sourceSetupDone = "scrobbler.sourceSetupDone"
        static let allowedApps = "scrobbler.allowedApps"
        static let knownApps = "scrobbler.knownApps"
    }

    private func loadPreferences() {
        let defaults = UserDefaults.standard
        selectiveScrobblingEnabled = defaults.bool(forKey: Keys.selectiveEnabled)
        hasCompletedSourceSetup = defaults.bool(forKey: Keys.sourceSetupDone)
        if let data = defaults.data(forKey: Keys.allowedApps),
           let arr = try? JSONDecoder().decode([String].self, from: data) {
            allowedApps = Set(arr)
        }
        if let data = defaults.data(forKey: Keys.knownApps),
           let dict = try? JSONDecoder().decode([String: String].self, from: data) {
            knownApps = dict
        }
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(selectiveScrobblingEnabled, forKey: Keys.selectiveEnabled)
        defaults.set(hasCompletedSourceSetup, forKey: Keys.sourceSetupDone)
        if let data = try? JSONEncoder().encode(Array(allowedApps)) {
            defaults.set(data, forKey: Keys.allowedApps)
        }
        if let data = try? JSONEncoder().encode(knownApps) {
            defaults.set(data, forKey: Keys.knownApps)
        }
    }

    // MARK: Auth

    func beginLogin() {
        authError = nil
        isAuthorizing = true
        Task {
            do {
                let token = try await client.fetchRequestToken()
                pendingToken = token
                NSWorkspace.shared.open(client.authorizationURL(token: token, callbackURL: "openscrobbler://auth/callback"))
            } catch {
                authError = error.localizedDescription
                isAuthorizing = false
            }
        }
    }

    func completeLogin() {
        guard let token = pendingToken else {
            authError = "Avvia prima l'accesso."
            return
        }
        Task {
            defer { isAuthorizing = false }
            do {
                let session = try await client.fetchSession(token: token)
                KeychainStore.save(session)
                self.session = session
                pendingToken = nil
                await engine.flushQueue()
            } catch {
                authError = error.localizedDescription
            }
        }
    }

    func logout() {
        KeychainStore.clear()
        session = nil
        pendingToken = nil
        authError = nil
        isAuthorizing = false
    }

    func handleCallback(url: URL) {
        guard url.scheme == "openscrobbler", url.host == "auth" else { return }
        completeLogin()
    }
}
