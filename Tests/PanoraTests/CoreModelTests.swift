@testable import Panora
import AppKit
import MediaRemoteAdapter
import XCTest

final class CoreModelTests: XCTestCase {
    func testTrackPlaybackRequiresArtistAndTitleFromPayload() {
        XCTAssertNil(TrackPlayback(payload: .init(title: nil, artist: "Artist")))
        XCTAssertNil(TrackPlayback(payload: .init(title: "Title", artist: nil)))
        XCTAssertNil(TrackPlayback(payload: .init(title: "", artist: "Artist")))
        XCTAssertNil(TrackPlayback(payload: .init(title: "Title", artist: "")))
    }

    func testTrackPlaybackIdentityAndScrobbleTrack() throws {
        let payload = TrackInfo.Payload(
            title: "Song",
            artist: "Artist",
            album: "Album",
            isPlaying: true,
            durationMicros: 180_000_000,
            elapsedTimeMicros: 45_000_000,
            applicationName: "Music",
            bundleIdentifier: "com.apple.Music"
        )

        let track = try XCTUnwrap(TrackPlayback(payload: payload))

        XCTAssertEqual(track.identity, "Artist|Song|Album")
        XCTAssertEqual(track.scrobbleTrack, ScrobbleTrack(artist: "Artist", title: "Song", album: "Album", durationSeconds: 180))
        XCTAssertEqual(track.elapsedSeconds, 45)
        XCTAssertTrue(track.isPlaying)
    }

    func testTrackPlaybackEqualityIgnoresArtworkAndElapsedSeconds() {
        let imageA = NSImage(size: NSSize(width: 1, height: 1))
        let imageB = NSImage(size: NSSize(width: 2, height: 2))
        let lhs = TrackPlayback(artist: "Artist", title: "Song", album: "Album", durationSeconds: 120, elapsedSeconds: 1, isPlaying: true, artwork: imageA)
        let rhs = TrackPlayback(artist: "Artist", title: "Song", album: "Album", durationSeconds: 120, elapsedSeconds: 80, isPlaying: true, artwork: imageB)

        XCTAssertEqual(lhs, rhs)
    }

    func testStatsPeriodMappings() {
        XCTAssertEqual(StatsPeriod.week.apiValue, "7day")
        XCTAssertEqual(StatsPeriod.month.apiValue, "1month")
        XCTAssertEqual(StatsPeriod.quarter.apiValue, "3month")
        XCTAssertEqual(StatsPeriod.halfYear.apiValue, "6month")
        XCTAssertEqual(StatsPeriod.year.apiValue, "12month")
        XCTAssertEqual(StatsPeriod.overall.apiValue, "overall")

        XCTAssertEqual(StatsPeriod.week.title, "7 days")
        XCTAssertEqual(StatsPeriod.overall.title, "All time")
    }

    func testScrobbleEntryDefaultsAndTrackConversion() {
        let track = ScrobbleTrack(artist: "Artist", title: "Song", album: "Album", durationSeconds: 240)
        let entry = ScrobbleEntry(track: track, timestamp: 123)

        XCTAssertEqual(entry.artist, "Artist")
        XCTAssertEqual(entry.title, "Song")
        XCTAssertEqual(entry.album, "Album")
        XCTAssertEqual(entry.durationSeconds, 240)
        XCTAssertEqual(entry.timestamp, 123)
        XCTAssertEqual(entry.status, .pending)
        XCTAssertEqual(entry.attempts, 0)
        XCTAssertNil(entry.lastError)
        XCTAssertEqual(entry.scrobbleTrack, track)

        entry.status = .failed
        XCTAssertEqual(entry.statusRaw, ScrobbleStatus.failed.rawValue)
    }
}
