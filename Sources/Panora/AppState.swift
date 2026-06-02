// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation
import Observation
import ServiceManagement
import SwiftData

/// Top-level coordinator wiring detection, scrobbling, persistence and auth.
///
/// Owns the ``NowPlayingMonitor``, ``ScrobbleEngine`` and ``LastfmServing`` client,
/// holds auth/session state, and applies the per-app source filter before tracks
/// reach the engine. Injected into the SwiftUI environment as the single source of truth.
@MainActor
@Observable
final class AppState {
    private(set) var session: LastfmSession?
    var authError: String?
    var isAuthorizing = false

    let monitor: NowPlayingMonitor
    private let engine: ScrobbleEngine
    let client: LastfmServing
    private let sessionStore: LastfmSessionStoring
    private let defaults: UserDefaults
    private let startsMonitor: Bool
    private let opensAuthorization: Bool
    private var pendingToken: String?
    private var started = false
    private var lastTrack: TrackPlayback?

    // Source filtering
    private(set) var selectiveScrobblingEnabled: Bool = false
    private(set) var hasCompletedSourceSetup: Bool = false
    private(set) var allowedApps: Set<String> = []
    private(set) var knownApps: [String: String] = [:]
    private(set) var scrobblingSuspended: Bool = false
    private(set) var current: TrackPlayback?

    var scrobbleProgress: ScrobbleProgress? { current == nil ? nil : engine.progress }
    var isConfigured: Bool { client.isConfigured }
    var launchAtLogin: Bool { SMAppService.mainApp.status == .enabled }

    func setLaunchAtLogin(_ enabled: Bool) {
        if enabled { try? SMAppService.mainApp.register() }
        else        { try? SMAppService.mainApp.unregister() }
    }

    var isCurrentScrobbled: Bool {
        guard let id = monitor.current?.identity else { return false }
        return engine.lastScrobbledIdentity == id
    }

    init(
        context: ModelContext,
        client: LastfmServing = LastfmClient(),
        sessionStore: LastfmSessionStoring = KeychainSessionStore(),
        defaults: UserDefaults = .standard,
        startsMonitor: Bool = true,
        opensAuthorization: Bool = true,
        discoversApps: Bool = true,
        initialSession: LastfmSession? = nil,
        sourceSetupCompleted: Bool? = nil
    ) {
        let store = ScrobbleStore(context: context)
        let monitor = NowPlayingMonitor()
        self.client = client
        self.monitor = monitor
        self.sessionStore = sessionStore
        self.defaults = defaults
        self.startsMonitor = startsMonitor
        self.opensAuthorization = opensAuthorization
        self.session = initialSession ?? sessionStore.load()

        var sessionRef: () -> LastfmSession? = { nil }
        let engine = ScrobbleEngine(client: client, store: store, sessionProvider: { sessionRef() })
        self.engine = engine
        sessionRef = { [weak self] in self?.session }

        loadPreferences()
        engine.setScrobblingSuspended(scrobblingSuspended)
        if discoversApps { discoverInstalledMusicApps() }
        if let sourceSetupCompleted {
            hasCompletedSourceSetup = sourceSetupCompleted
        }

        monitor.onUpdate = { [weak self, weak engine] track in
            guard let self else { engine?.handle(track); return }
            if let track { self.registerApp(track) }
            self.lastTrack = track
            let filteredTrack = self.filter(track)
            self.current = filteredTrack
            engine?.handle(filteredTrack)
        }
    }

    /// Starts now-playing detection and flushes any queued scrobbles. Idempotent.
    func start() {
        guard !started else { return }
        started = true
        if startsMonitor {
            monitor.start()
        }
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

    func setScrobblingSuspended(_ suspended: Bool) {
        scrobblingSuspended = suspended
        engine.setScrobblingSuspended(suspended)
        savePreferences()
        reapplyFilter()
        if !suspended {
            Task { await engine.flushQueue() }
        }
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
        let filteredTrack = filter(lastTrack ?? monitor.current)
        current = filteredTrack
        engine.handle(filteredTrack)
    }

    /// Scans for installed apps from ``knownMusicApps`` and prunes stale entries,
    /// populating the list the user picks from in selective mode.
    func discoverInstalledMusicApps() {
        let validIDs = Set(knownMusicApps.map(\.bundleID)).union(mediaRemoteBundleMapping.values)
        for key in knownApps.keys where !validIDs.contains(key) {
            knownApps.removeValue(forKey: key)
        }
        for (bundleID, name) in knownMusicApps {
            guard knownApps[bundleID] == nil else { continue }
            if NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil {
                knownApps[bundleID] = name
            }
        }
        if knownApps.isEmpty { return }
        savePreferences()
    }

    func setupSelectiveApps(_ allowed: Set<String>) {
        allowedApps = allowed
        savePreferences()
        completeSourceSetup(selective: true)
    }

    private func registerApp(_ track: TrackPlayback) {
        guard let raw = track.bundleIdentifier else { return }
        let id = mediaRemoteBundleMapping[raw] ?? raw
        if knownApps[id] == nil {
            knownApps[id] = track.appName ?? id
            savePreferences()
        }
    }

    /// Drops the track when selective mode is on and its source app is not allowed.
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
        static let suspended = "scrobbler.suspended"
    }

    private func loadPreferences() {
        selectiveScrobblingEnabled = defaults.bool(forKey: Keys.selectiveEnabled)
        hasCompletedSourceSetup = defaults.bool(forKey: Keys.sourceSetupDone)
        scrobblingSuspended = defaults.bool(forKey: Keys.suspended)
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
        defaults.set(selectiveScrobblingEnabled, forKey: Keys.selectiveEnabled)
        defaults.set(hasCompletedSourceSetup, forKey: Keys.sourceSetupDone)
        defaults.set(scrobblingSuspended, forKey: Keys.suspended)
        if let data = try? JSONEncoder().encode(Array(allowedApps)) {
            defaults.set(data, forKey: Keys.allowedApps)
        }
        if let data = try? JSONEncoder().encode(knownApps) {
            defaults.set(data, forKey: Keys.knownApps)
        }
    }

    // MARK: Auth

    /// Starts the desktop auth flow: fetches a token and opens the browser authorization page.
    func beginLogin() {
        authError = nil
        isAuthorizing = true
        Task {
            do {
                let token = try await client.fetchRequestToken()
                pendingToken = token
                if opensAuthorization {
                    NSWorkspace.shared.open(client.authorizationURL(token: token, callbackURL: "panora://auth/callback"))
                }
            } catch {
                authError = error.localizedDescription
                isAuthorizing = false
            }
        }
    }

    /// Exchanges the pending token for a session, persists it, and flushes the queue.
    func completeLogin() {
        guard let token = pendingToken else {
            authError = "Start sign-in first."
            return
        }
        Task {
            defer { isAuthorizing = false }
            do {
                let session = try await client.fetchSession(token: token)
                sessionStore.save(session)
                self.session = session
                pendingToken = nil
                await engine.flushQueue()
            } catch {
                authError = error.localizedDescription
            }
        }
    }

    func logout() {
        sessionStore.clear()
        session = nil
        pendingToken = nil
        authError = nil
        isAuthorizing = false
    }

    /// Handles the `panora://auth/callback` deep link by completing sign-in.
    func handleCallback(url: URL) {
        guard url.scheme == "panora", url.host == "auth" else { return }
        completeLogin()
    }
}
