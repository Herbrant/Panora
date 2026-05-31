import AppKit
import Foundation
import MediaRemoteAdapter

/// Lightweight metadata used when talking to Last.fm.
struct ScrobbleTrack: Equatable {
    var artist: String
    var title: String
    var album: String?
    var durationSeconds: Double?
}

/// A snapshot of what is currently playing, derived from the adapter payload.
struct TrackPlayback {
    var artist: String
    var title: String
    var album: String?
    var durationSeconds: Double?
    var elapsedSeconds: Double
    var isPlaying: Bool
    var bundleIdentifier: String?
    var appName: String?
    var artwork: NSImage?

    /// Stable identity for a song, independent of playback position.
    var identity: String { "\(artist)|\(title)|\(album ?? "")" }

    var scrobbleTrack: ScrobbleTrack {
        ScrobbleTrack(artist: artist, title: title, album: album, durationSeconds: durationSeconds)
    }

    /// Builds a snapshot from the adapter payload, requiring at least artist + title.
    init(
        artist: String,
        title: String,
        album: String? = nil,
        durationSeconds: Double? = nil,
        elapsedSeconds: Double = 0,
        isPlaying: Bool = false,
        bundleIdentifier: String? = nil,
        appName: String? = nil,
        artwork: NSImage? = nil
    ) {
        self.artist = artist
        self.title = title
        self.album = album
        self.durationSeconds = durationSeconds
        self.elapsedSeconds = elapsedSeconds
        self.isPlaying = isPlaying
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.artwork = artwork
    }

    /// Builds a snapshot from the adapter payload, requiring at least artist + title.
    init?(payload: TrackInfo.Payload) {
        guard let artist = payload.artist, !artist.isEmpty,
              let title = payload.title, !title.isEmpty else { return nil }
        self.artist = artist
        self.title = title
        self.album = payload.album
        self.durationSeconds = payload.durationMicros.map { $0 / 1_000_000 }
        self.elapsedSeconds = payload.currentElapsedTime
            ?? payload.elapsedTimeMicros.map { $0 / 1_000_000 }
            ?? 0
        self.isPlaying = payload.isPlaying ?? false
        self.bundleIdentifier = payload.bundleIdentifier
        self.appName = payload.applicationName
        self.artwork = payload.artwork
    }
}

extension TrackPlayback: Equatable {
    // Artwork is intentionally excluded (NSImage identity is not meaningful here).
    static func == (lhs: TrackPlayback, rhs: TrackPlayback) -> Bool {
        lhs.artist == rhs.artist &&
        lhs.title == rhs.title &&
        lhs.album == rhs.album &&
        lhs.durationSeconds == rhs.durationSeconds &&
        lhs.isPlaying == rhs.isPlaying
    }
}

extension NSImage {
    func jpegData(compressionFactor: CGFloat = 0.6) -> Data? {
        if let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) {
            let bitmap = NSBitmapImageRep(cgImage: cgImage)
            return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
        }
        guard let tiff = tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff)
        else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: compressionFactor])
    }
}
