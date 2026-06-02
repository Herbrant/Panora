@testable import Panora
import XCTest

@MainActor
final class ScrobbleEngineTests: XCTestCase {
    func testNewPlayingTrackUpdatesNowPlayingAndScrobblesAtHalfDuration() async {
        let client = FakeLastfmClient()
        let store = FakeScrobbleStore()
        let sleeper = RecordingSleeper(returnsImmediately: true)
        let engine = makeEngine(client: client, store: store, sleeper: sleeper)

        engine.handle(track(duration: 100, elapsed: 10, isPlaying: true))
        await waitUntil { store.inserted.count == 1 && client.nowPlaying.count == 1 && client.scrobbles.count == 1 }

        XCTAssertEqual(sleeper.delays, [40])
        XCTAssertEqual(engine.progress?.thresholdSeconds, 50)
        XCTAssertEqual(engine.progress?.status, .scrobbled)
        XCTAssertEqual(store.inserted.first?.timestamp, 990)
        XCTAssertEqual(store.inserted.first?.status, .sent)
        XCTAssertEqual(client.nowPlaying.first?.title, "Song")
        XCTAssertEqual(client.scrobbles.first?.timestamp, 990)
        XCTAssertEqual(engine.lastScrobbledIdentity, "Artist|Song|Album")
    }

    func testLongTrackScrobblesAtFourMinuteCap() async {
        let sleeper = RecordingSleeper(returnsImmediately: true)
        let store = FakeScrobbleStore()
        let engine = makeEngine(store: store, sleeper: sleeper)

        engine.handle(track(duration: 1_000, elapsed: 60, isPlaying: true))
        await waitUntil { store.inserted.count == 1 }

        XCTAssertEqual(sleeper.delays, [180])
        XCTAssertEqual(engine.progress?.thresholdSeconds, 240)
    }

    func testShortTracksDoNotScrobble() async {
        let sleeper = RecordingSleeper(returnsImmediately: true)
        let store = FakeScrobbleStore()
        let engine = makeEngine(store: store, sleeper: sleeper)

        engine.handle(track(duration: 30, elapsed: 29, isPlaying: true))
        await settleMainActor()

        XCTAssertTrue(sleeper.delays.isEmpty)
        XCTAssertTrue(store.inserted.isEmpty)
        XCTAssertEqual(engine.progress?.status, .notEligible)
    }

    func testPauseCancelsPendingScrobbleAndResumeSchedulesAgain() async {
        let sleeper = RecordingSleeper(returnsImmediately: false)
        let store = FakeScrobbleStore()
        let engine = makeEngine(store: store, sleeper: sleeper)

        engine.handle(track(duration: 100, elapsed: 10, isPlaying: true))
        await waitUntil { sleeper.delays.count == 1 }

        engine.handle(track(duration: 100, elapsed: 20, isPlaying: false))
        sleeper.resumeAll()
        await settleMainActor()
        XCTAssertTrue(store.inserted.isEmpty)
        XCTAssertEqual(engine.progress?.status, .pausedPlayback)

        engine.handle(track(duration: 100, elapsed: 25, isPlaying: true))
        await waitUntil { sleeper.delays.count == 2 }
        sleeper.resumeAll()
        await waitUntil { store.inserted.count == 1 }

        XCTAssertEqual(sleeper.delays, [40, 25])
    }

    func testTrackChangeCancelsPreviousScrobble() async {
        let sleeper = RecordingSleeper(returnsImmediately: false)
        let store = FakeScrobbleStore()
        let engine = makeEngine(store: store, sleeper: sleeper)

        engine.handle(track(title: "First", duration: 100, elapsed: 10, isPlaying: true))
        await waitUntil { sleeper.delays.count == 1 }
        engine.handle(track(title: "Second", duration: 100, elapsed: 60, isPlaying: true))
        await waitUntil { sleeper.delays.count == 2 }
        sleeper.resumeAll()
        await waitUntil { store.inserted.count == 1 }

        XCTAssertEqual(store.inserted.map(\.title), ["Second"])
    }

    func testProgressCountsTowardScrobbleThreshold() {
        let sleeper = RecordingSleeper(returnsImmediately: false)
        let engine = makeEngine(sleeper: sleeper)

        engine.handle(track(duration: 100, elapsed: 10, isPlaying: true))

        XCTAssertEqual(engine.progress?.status, .waiting)
        XCTAssertEqual(engine.progress?.remainingSeconds(at: Date(timeIntervalSince1970: 1_000)), 40)
        XCTAssertEqual(engine.progress?.fraction(at: Date(timeIntervalSince1970: 1_020)), 0.6)
    }

    func testSuspensionBlocksNowPlayingAndScrobble() async {
        let client = FakeLastfmClient()
        let sleeper = RecordingSleeper(returnsImmediately: true)
        let store = FakeScrobbleStore()
        let engine = makeEngine(client: client, store: store, sleeper: sleeper)

        engine.setScrobblingSuspended(true)
        engine.handle(track(duration: 100, elapsed: 10, isPlaying: true))
        await settleMainActor()

        XCTAssertTrue(sleeper.delays.isEmpty)
        XCTAssertTrue(client.nowPlaying.isEmpty)
        XCTAssertTrue(client.scrobbles.isEmpty)
        XCTAssertTrue(store.inserted.isEmpty)
        XCTAssertEqual(engine.progress?.status, .suspended)
    }

    func testSuspensionCancelsPendingScrobble() async {
        let sleeper = RecordingSleeper(returnsImmediately: false)
        let store = FakeScrobbleStore()
        let engine = makeEngine(store: store, sleeper: sleeper)

        engine.handle(track(duration: 100, elapsed: 10, isPlaying: true))
        await waitUntil { sleeper.delays.count == 1 }

        engine.setScrobblingSuspended(true)
        sleeper.resumeAll()
        await settleMainActor()

        XCTAssertTrue(store.inserted.isEmpty)
        XCTAssertEqual(engine.progress?.status, .suspended)
    }

    func testReactivationReschedulesCurrentTrack() async {
        let client = FakeLastfmClient()
        let sleeper = RecordingSleeper(returnsImmediately: false)
        let store = FakeScrobbleStore()
        let engine = makeEngine(client: client, store: store, sleeper: sleeper)

        engine.setScrobblingSuspended(true)
        engine.handle(track(duration: 100, elapsed: 20, isPlaying: true))
        engine.setScrobblingSuspended(false)
        engine.handle(track(duration: 100, elapsed: 20, isPlaying: true))

        await waitUntil { sleeper.delays.count == 1 && client.nowPlaying.count == 1 }
        XCTAssertEqual(sleeper.delays, [30])
        XCTAssertEqual(engine.progress?.status, .waiting)
    }

    func testFlushQueueMarksFailuresAndSkipsWithoutSession() async {
        let failingClient = FakeLastfmClient(scrobbleError: LastfmError.http(500))
        let store = FakeScrobbleStore()
        let pending = ScrobbleEntry(track: ScrobbleTrack(artist: "A", title: "B", album: nil, durationSeconds: nil), timestamp: 1)
        store.queued = [pending]
        let engine = ScrobbleEngine(
            client: failingClient,
            store: store,
            sessionProvider: { LastfmSession(username: "u", sessionKey: "s") }
        )

        await engine.flushQueue()
        XCTAssertEqual(store.failed.map(\.entry.title), ["B"])
        XCTAssertEqual(pending.status, .failed)
        XCTAssertEqual(pending.attempts, 1)

        let noSessionClient = FakeLastfmClient()
        let noSessionStore = FakeScrobbleStore()
        noSessionStore.queued = [pending]
        let noSessionEngine = ScrobbleEngine(client: noSessionClient, store: noSessionStore, sessionProvider: { nil })

        await noSessionEngine.flushQueue()
        XCTAssertTrue(noSessionClient.scrobbles.isEmpty)
    }

    private func makeEngine(
        client: FakeLastfmClient? = nil,
        store: FakeScrobbleStore? = nil,
        sleeper: RecordingSleeper
    ) -> ScrobbleEngine {
        ScrobbleEngine(
            client: client ?? FakeLastfmClient(),
            store: store ?? FakeScrobbleStore(),
            sessionProvider: { LastfmSession(username: "tester", sessionKey: "session") },
            dateProvider: { Date(timeIntervalSince1970: 1_000) },
            sleep: sleeper.sleep
        )
    }

    private func track(
        title: String = "Song",
        duration: Double?,
        elapsed: Double,
        isPlaying: Bool
    ) -> TrackPlayback {
        TrackPlayback(
            artist: "Artist",
            title: title,
            album: "Album",
            durationSeconds: duration,
            elapsedSeconds: elapsed,
            isPlaying: isPlaying
        )
    }
}
