// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import Foundation
import Observation

enum ScrobbleProgressStatus: Equatable {
    case notEligible
    case waiting
    case scrobbled
    case pausedPlayback
    case suspended
}

struct ScrobbleProgress: Equatable {
    var identity: String
    var status: ScrobbleProgressStatus
    var thresholdSeconds: Double
    var baseElapsedSeconds: Double
    var referenceDate: Date

    func elapsedSeconds(at date: Date = Date()) -> Double {
        let elapsed: Double
        switch status {
        case .waiting:
            elapsed = baseElapsedSeconds + date.timeIntervalSince(referenceDate)
        case .scrobbled:
            elapsed = thresholdSeconds
        case .notEligible, .pausedPlayback, .suspended:
            elapsed = baseElapsedSeconds
        }
        return min(max(elapsed, 0), max(thresholdSeconds, 0))
    }

    func remainingSeconds(at date: Date = Date()) -> Double {
        max(0, thresholdSeconds - elapsedSeconds(at: date))
    }

    func fraction(at date: Date = Date()) -> Double {
        guard thresholdSeconds > 0 else { return status == .scrobbled ? 1 : 0 }
        return min(max(elapsedSeconds(at: date) / thresholdSeconds, 0), 1)
    }
}

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
    private(set) var progress: ScrobbleProgress?
    private(set) var scrobblingSuspended = false

    private let client: LastfmServing
    private let store: ScrobbleQueueStoring
    private let sessionProvider: () -> LastfmSession?
    private let dateProvider: () -> Date
    private let sleep: (Double) async -> Void

    private var currentIdentity: String?
    private var currentStartUnix: Int = 0
    private var scrobbled = false
    private var scrobbleTask: Task<Void, Never>?
    /// Updated on each same-track callback so artwork is available at scrobble time
    /// even if the initial payload had no artwork yet.
    private var pendingArtwork: NSImage?

    init(
        client: LastfmServing,
        store: ScrobbleQueueStoring,
        sessionProvider: @escaping () -> LastfmSession?,
        dateProvider: @escaping () -> Date = Date.init,
        sleep: @escaping (Double) async -> Void = { seconds in
            try? await Task.sleep(for: .seconds(seconds))
        }
    ) {
        self.client = client
        self.store = store
        self.sessionProvider = sessionProvider
        self.dateProvider = dateProvider
        self.sleep = sleep
    }

    /// Feeds a now-playing update into the engine: starts a new track, reacts to
    /// play/pause on the current track, or clears state when `track` is `nil`.
    func handle(_ track: TrackPlayback?) {
        guard let track else {
            cancelScrobbleTimer()
            currentIdentity = nil
            progress = nil
            return
        }

        if scrobblingSuspended {
            if track.identity != currentIdentity {
                currentIdentity = track.identity
                currentStartUnix = Int(dateProvider().timeIntervalSince1970 - effectiveElapsedSeconds(for: track))
                scrobbled = false
                pendingArtwork = track.artwork
            } else if track.artwork != nil {
                pendingArtwork = track.artwork
            }
            cancelScrobbleTimer()
            updateProgress(track, status: .suspended)
            return
        }

        if track.identity != currentIdentity {
            startNewTrack(track)
        } else {
            // Same track: react to play/pause transitions.
            if track.artwork != nil {
                pendingArtwork = track.artwork
            }
            let previousStatus = progress?.status
            updateProgress(track)
            if track.isPlaying {
                if previousStatus == .suspended {
                    Task { await sendNowPlaying(track) }
                }
                if scrobbleTask == nil && !scrobbled {
                    scheduleScrobble(track)
                }
            } else {
                cancelScrobbleTimer()
            }
        }
    }

    /// Sends every queued scrobble that is still owed, marking each sent or failed.
    /// No-op when signed out. The offline-retry mechanism.
    func flushQueue() async {
        guard !scrobblingSuspended else { return }
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

    func setScrobblingSuspended(_ suspended: Bool) {
        guard scrobblingSuspended != suspended else { return }
        scrobblingSuspended = suspended
        if suspended {
            cancelScrobbleTimer()
            freezeProgress(as: .suspended)
        }
    }

    // MARK: Private

    private func startNewTrack(_ track: TrackPlayback) {
        cancelScrobbleTimer()
        currentIdentity = track.identity
        currentStartUnix = Int(dateProvider().timeIntervalSince1970 - effectiveElapsedSeconds(for: track))
        scrobbled = false
        pendingArtwork = track.artwork
        updateProgress(track)

        guard track.isPlaying, canScrobble(track) else { return }
        Task { await sendNowPlaying(track) }
        scheduleScrobble(track)
    }

    private func scheduleScrobble(_ track: TrackPlayback) {
        guard !scrobblingSuspended else { return }
        guard canScrobble(track) else { return }
        let remaining = max(0, scrobbleThreshold(track) - effectiveElapsedSeconds(for: track))
        let identity = track.identity

        scrobbleTask = Task { [weak self] in
            await self?.sleep(remaining)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            if self.currentIdentity == identity && !self.scrobbled && !self.scrobblingSuspended {
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
        let artwork = track.artwork ?? pendingArtwork
        let artworkData = artwork?.jpegData()
        let entry = ScrobbleEntry(track: track.scrobbleTrack, timestamp: currentStartUnix, artworkData: artworkData)
        store.insert(entry)
        lastScrobbledIdentity = track.identity
        updateProgress(track, status: .scrobbled)
        await flushQueue()
    }

    private func sendNowPlaying(_ track: TrackPlayback) async {
        guard !scrobblingSuspended else { return }
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

    private func updateProgress(_ track: TrackPlayback, status explicitStatus: ScrobbleProgressStatus? = nil) {
        let now = dateProvider()
        let threshold = scrobbleThreshold(track)
        let elapsed = effectiveElapsedSeconds(for: track, at: now)
        let status = explicitStatus ?? progressStatus(for: track)
        progress = ScrobbleProgress(
            identity: track.identity,
            status: status,
            thresholdSeconds: threshold,
            baseElapsedSeconds: elapsed,
            referenceDate: now
        )
    }

    private func progressStatus(for track: TrackPlayback) -> ScrobbleProgressStatus {
        if scrobblingSuspended { return .suspended }
        if !canScrobble(track) { return .notEligible }
        if scrobbled { return .scrobbled }
        return track.isPlaying ? .waiting : .pausedPlayback
    }

    private func effectiveElapsedSeconds(for track: TrackPlayback, at date: Date? = nil) -> Double {
        guard let progress, progress.identity == track.identity else {
            return track.elapsedSeconds
        }
        return max(track.elapsedSeconds, progress.elapsedSeconds(at: date ?? dateProvider()))
    }

    private func freezeProgress(as status: ScrobbleProgressStatus) {
        guard var progress else { return }
        let now = dateProvider()
        progress.baseElapsedSeconds = progress.elapsedSeconds(at: now)
        progress.referenceDate = now
        progress.status = status
        self.progress = progress
    }
}
