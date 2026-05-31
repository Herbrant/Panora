import Foundation
import MediaRemoteAdapter
import Observation

/// Wraps the MediaRemote adapter and exposes the currently playing track.
@MainActor
@Observable
final class NowPlayingMonitor {
    private(set) var current: TrackPlayback?

    /// Called on every update (track change, play/pause, position). nil means nothing is playing.
    var onUpdate: ((TrackPlayback?) -> Void)?

    private let controller = MediaController()
    private var started = false

    func start() {
        guard !started else { return }
        started = true

        // The adapter dispatches its callbacks on the main queue, so it is safe
        // to assume main-actor isolation here.
        controller.onTrackInfoReceived = { [weak self] info in
            MainActor.assumeIsolated { self?.handle(info) }
        }
        controller.onListenerTerminated = { [weak self] in
            MainActor.assumeIsolated { self?.controller.startListening() }
        }
        controller.startListening()
    }

    func stop() {
        controller.stopListening()
        started = false
    }

    private func handle(_ info: TrackInfo?) {
        guard let payload = info?.payload, let track = TrackPlayback(payload: payload) else {
            current = nil
            onUpdate?(nil)
            return
        }
        current = track
        onUpdate?(track)
    }
}
