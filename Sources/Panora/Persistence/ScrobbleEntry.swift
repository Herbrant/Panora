import Foundation
import SwiftData

enum ScrobbleStatus: String, Codable {
    case pending
    case sent
    case failed
}

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
