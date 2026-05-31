@testable import Panora
import Foundation
import XCTest

@MainActor
final class FakeLastfmClient: LastfmServing {
    struct ScrobbleCall: Equatable {
        var track: ScrobbleTrack
        var timestamp: Int
        var sessionKey: String
    }

    var isConfigured = true
    var nowPlaying: [ScrobbleTrack] = []
    var scrobbles: [ScrobbleCall] = []
    var userInfoResult = LastfmUserInfo(name: "tester", realName: nil, playcount: 0, registered: nil, imageURL: nil, profileURL: nil)
    var topArtistsResult: [LastfmTopArtist] = []
    var topTracksResult: [LastfmTopTrack] = []
    var recentTracksResult: [LastfmRecentTrack] = []

    private let scrobbleError: Error?
    private let userInfoError: Error?
    var fetchTokenError: Error?

    init(scrobbleError: Error? = nil, userInfoError: Error? = nil) {
        self.scrobbleError = scrobbleError
        self.userInfoError = userInfoError
    }

    func fetchRequestToken() async throws -> String {
        if let fetchTokenError { throw fetchTokenError }
        return "token"
    }

    func authorizationURL(token: String, callbackURL: String?) -> URL {
        URL(string: "https://example.test/auth?token=\(token)")!
    }

    func fetchSession(token: String) async throws -> LastfmSession {
        LastfmSession(username: "tester", sessionKey: "session")
    }

    func updateNowPlaying(track: ScrobbleTrack, sessionKey: String) async throws {
        nowPlaying.append(track)
    }

    func scrobble(track: ScrobbleTrack, timestamp: Int, sessionKey: String) async throws {
        if let scrobbleError {
            throw scrobbleError
        }
        scrobbles.append(ScrobbleCall(track: track, timestamp: timestamp, sessionKey: sessionKey))
    }

    func userInfo(_ user: String) async throws -> LastfmUserInfo {
        if let userInfoError {
            throw userInfoError
        }
        return userInfoResult
    }

    func topArtists(_ user: String, period: StatsPeriod, limit: Int) async throws -> [LastfmTopArtist] {
        topArtistsResult
    }

    func topTracks(_ user: String, period: StatsPeriod, limit: Int) async throws -> [LastfmTopTrack] {
        topTracksResult
    }

    func recentTracks(_ user: String, limit: Int) async throws -> [LastfmRecentTrack] {
        recentTracksResult
    }
}

@MainActor
final class FakeScrobbleStore: ScrobbleQueueStoring {
    var inserted: [ScrobbleEntry] = []
    var queued: [ScrobbleEntry] = []
    var sent: [ScrobbleEntry] = []
    var failed: [(entry: ScrobbleEntry, error: String)] = []

    func insert(_ entry: ScrobbleEntry) {
        inserted.append(entry)
        queued.append(entry)
    }

    func markSent(_ entry: ScrobbleEntry) {
        entry.status = .sent
        sent.append(entry)
    }

    func markFailed(_ entry: ScrobbleEntry, error: String) {
        entry.attempts += 1
        entry.status = .failed
        entry.lastError = error
        failed.append((entry, error))
    }

    func sendable() -> [ScrobbleEntry] {
        queued.filter { ($0.status == .pending || $0.status == .failed) && $0.attempts < 5 }
            .sorted { $0.timestamp < $1.timestamp }
    }
}

@MainActor
final class RecordingSleeper {
    private let returnsImmediately: Bool
    private var continuations: [CheckedContinuation<Void, Never>] = []
    var delays: [Double] = []

    init(returnsImmediately: Bool) {
        self.returnsImmediately = returnsImmediately
    }

    func sleep(_ seconds: Double) async {
        delays.append(seconds)
        guard !returnsImmediately else { return }
        await withCheckedContinuation { continuation in
            continuations.append(continuation)
        }
    }

    func resumeAll() {
        let pending = continuations
        continuations.removeAll()
        pending.forEach { $0.resume() }
    }
}

final class FakeHTTPClient: LastfmHTTPClient {
    private struct Response {
        var data: Data
        var status: Int
    }

    private var responses: [Response] = []
    private(set) var requests: [URLRequest] = []

    func enqueue(json: String, status: Int = 200) {
        responses.append(Response(data: Data(json.utf8), status: status))
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        let response = responses.isEmpty ? Response(data: Data("{}".utf8), status: 200) : responses.removeFirst()
        let http = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.test")!,
            statusCode: response.status,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response.data, http)
    }
}

final class FakeSessionStore: LastfmSessionStoring {
    var stored: LastfmSession?

    func load() -> LastfmSession? { stored }
    func save(_ session: LastfmSession) { stored = session }
    func clear() { stored = nil }
}

@MainActor
func waitUntil(
    timeout: TimeInterval = 1,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ condition: @escaping () -> Bool
) async {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if condition() { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
    XCTFail("Timed out waiting for condition", file: file, line: line)
}

@MainActor
func settleMainActor() async {
    try? await Task.sleep(nanoseconds: 20_000_000)
}
