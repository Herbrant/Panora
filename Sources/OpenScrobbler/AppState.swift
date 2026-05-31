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

    var current: TrackPlayback? { monitor.current }
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

        monitor.onUpdate = { [weak engine] track in engine?.handle(track) }
    }

    func start() {
        guard !started else { return }
        started = true
        monitor.start()
        Task { await engine.flushQueue() }
    }

    // MARK: Auth

    func beginLogin() {
        authError = nil
        isAuthorizing = true
        Task {
            do {
                let token = try await client.fetchRequestToken()
                pendingToken = token
                NSWorkspace.shared.open(client.authorizationURL(token: token))
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
    }
}
