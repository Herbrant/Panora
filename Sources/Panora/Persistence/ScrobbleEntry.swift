// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import SwiftData

/// Delivery state of a scrobble in the local queue.
enum ScrobbleStatus: String, Codable {
    /// Not yet sent to Last.fm.
    case pending
    /// Successfully delivered.
    case sent
    /// A delivery attempt failed; eligible for retry until the attempt cap.
    case failed
}

/// A persisted scrobble and its delivery state — one row in the offline retry queue.
@Model
final class ScrobbleEntry {
    var artist: String
    var title: String
    var album: String?
    var durationSeconds: Double?
    /// Unix time (seconds) when playback of the track started.
    var timestamp: Int
    var statusRaw: String
    var attempts: Int
    var lastError: String?
    var createdAt: Date
    /// Compressed JPEG data of the album artwork, captured at scrobble time.
    var artworkData: Data?

    var status: ScrobbleStatus {
        get { ScrobbleStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    var scrobbleTrack: ScrobbleTrack {
        ScrobbleTrack(artist: artist, title: title, album: album, durationSeconds: durationSeconds)
    }

    init(track: ScrobbleTrack, timestamp: Int, status: ScrobbleStatus = .pending, artworkData: Data? = nil) {
        self.artist = track.artist
        self.title = track.title
        self.album = track.album
        self.durationSeconds = track.durationSeconds
        self.timestamp = timestamp
        self.statusRaw = status.rawValue
        self.attempts = 0
        self.lastError = nil
        self.createdAt = Date()
        self.artworkData = artworkData
    }
}
