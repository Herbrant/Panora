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

    func testTrackPlaybackUsesCurrentElapsedTimeWhenAvailable() throws {
        let payload = TrackInfo.Payload(
            title: "Song",
            artist: "Artist",
            isPlaying: false,
            durationMicros: 200_000_000,
            elapsedTimeMicros: 20_000_000,
            applicationName: "Music",
            bundleIdentifier: "com.apple.Music",
            timestampEpochMicros: 1_700_000_000_000_000,
            playbackRate: 1
        )

        let track = try XCTUnwrap(TrackPlayback(payload: payload))

        XCTAssertEqual(track.elapsedSeconds, 20)
        XCTAssertEqual(track.durationSeconds, 200)
        XCTAssertEqual(track.appName, "Music")
        XCTAssertEqual(track.bundleIdentifier, "com.apple.Music")
    }

    func testTrackPlaybackDefaultsMissingOptionalPayloadFields() throws {
        let payload = TrackInfo.Payload(title: "Song", artist: "Artist")

        let track = try XCTUnwrap(TrackPlayback(payload: payload))

        XCTAssertEqual(track.identity, "Artist|Song|")
        XCTAssertNil(track.album)
        XCTAssertNil(track.durationSeconds)
        XCTAssertEqual(track.elapsedSeconds, 0)
        XCTAssertFalse(track.isPlaying)
        XCTAssertNil(track.bundleIdentifier)
        XCTAssertNil(track.appName)
        XCTAssertNil(track.artwork)
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

    func testStatsModelIdentifiers() {
        let artist = LastfmTopArtist(name: "Artist", playcount: 1, imageURL: nil, url: nil)
        let track = LastfmTopTrack(name: "Song", artist: "Artist", playcount: 2, imageURL: nil, url: nil)
        let datedRecent = LastfmRecentTrack(
            name: "Recent",
            artist: "Artist",
            album: nil,
            date: Date(timeIntervalSince1970: 123),
            nowPlaying: false,
            imageURL: nil
        )
        let liveRecent = LastfmRecentTrack(
            name: "Live",
            artist: "Artist",
            album: nil,
            date: nil,
            nowPlaying: true,
            imageURL: nil
        )

        XCTAssertEqual(artist.id, "Artist")
        XCTAssertEqual(track.id, "Artist|Song")
        XCTAssertEqual(datedRecent.id, "Artist|Recent|123.0")
        XCTAssertEqual(liveRecent.id, "Artist|Live|0.0")
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
        XCTAssertNil(entry.artworkData)

        entry.status = .failed
        XCTAssertEqual(entry.statusRaw, ScrobbleStatus.failed.rawValue)
    }

    func testImageJPEGDataReturnsDataForDrawableImage() throws {
        let image = NSImage(size: NSSize(width: 4, height: 4))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 4, height: 4).fill()
        image.unlockFocus()

        let data = try XCTUnwrap(image.jpegData())

        XCTAssertFalse(data.isEmpty)
    }
}
