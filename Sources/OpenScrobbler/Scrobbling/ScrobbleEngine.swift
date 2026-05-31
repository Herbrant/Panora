import Foundation
import Observation

/// Applies Last.fm scrobbling rules to the stream of now-playing updates.
///
/// Rules: update "now playing" on every track change; scrobble once a track has
/// played past the lesser of 50% of its duration or 4 minutes (only for tracks
/// longer than 30s). A local timer drives the threshold so we do not depend on
/// position updates arriving from the adapter.
@MainActor
@Observable
final class ScrobbleEngine {
    private(set) var lastScrobbledIdentity: String?

    private let client: LastfmClient
    private let store: ScrobbleStore
    private let sessionProvider: () -> LastfmSession?

    private var currentIdentity: String?
    private var currentStartUnix: Int = 0
    private var scrobbled = false
    private var scrobbleTask: Task<Void, Never>?

    init(client: LastfmClient, store: ScrobbleStore, sessionProvider: @escaping () -> LastfmSession?) {
        self.client = client
        self.store = store
        self.sessionProvider = sessionProvider
    }

    func handle(_ track: TrackPlayback?) {
        guard let track else {
            cancelScrobbleTimer()
            currentIdentity = nil
            return
        }

        if track.identity != currentIdentity {
            startNewTrack(track)
        } else {
            // Same track: react to play/pause transitions.
            if track.isPlaying {
                if scrobbleTask == nil && !scrobbled {
                    scheduleScrobble(track)
                }
            } else {
                cancelScrobbleTimer()
            }
        }
    }

    func flushQueue() async {
        guard let session = sessionProvider() else { return }
        for entry in store.sendable() {
            do {
                try await client.scrobble(
                    track: entry.scrobbleTrack,
                    timestamp: entry.timestamp,
                    sessionKey: session.sessionKey
                )
                store.markSent(entry)
            } catch {
                store.markFailed(entry, error: error.localizedDescription)
            }
        }
    }

    // MARK: Private

    private func startNewTrack(_ track: TrackPlayback) {
        cancelScrobbleTimer()
        currentIdentity = track.identity
        currentStartUnix = Int(Date().timeIntervalSince1970 - track.elapsedSeconds)
        scrobbled = false

        guard track.isPlaying else { return }
        Task { await sendNowPlaying(track) }
        scheduleScrobble(track)
    }

    private func scheduleScrobble(_ track: TrackPlayback) {
        guard canScrobble(track) else { return }
        let remaining = max(0, scrobbleThreshold(track) - track.elapsedSeconds)
        let identity = track.identity

        scrobbleTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(remaining))
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.currentIdentity == identity && !self.scrobbled {
                self.scrobbled = true
                await self.commitScrobble(track)
            }
            self.scrobbleTask = nil
        }
    }

    private func cancelScrobbleTimer() {
        scrobbleTask?.cancel()
        scrobbleTask = nil
    }

    private func commitScrobble(_ track: TrackPlayback) async {
        let entry = ScrobbleEntry(track: track.scrobbleTrack, timestamp: currentStartUnix)
        store.insert(entry)
        lastScrobbledIdentity = track.identity
        await flushQueue()
    }

    private func sendNowPlaying(_ track: TrackPlayback) async {
        guard let session = sessionProvider() else { return }
        try? await client.updateNowPlaying(track: track.scrobbleTrack, sessionKey: session.sessionKey)
    }

    private func canScrobble(_ track: TrackPlayback) -> Bool {
        if let duration = track.durationSeconds, duration > 0 { return duration > 30 }
        return true // unknown duration: allow (scrobbles after the 4-minute fallback)
    }

    private func scrobbleThreshold(_ track: TrackPlayback) -> Double {
        if let duration = track.durationSeconds, duration > 0 { return min(duration / 2, 240) }
        return 240
    }
}
