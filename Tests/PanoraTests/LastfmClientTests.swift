@testable import Panora
import CryptoKit
import Foundation
import XCTest

final class LastfmClientTests: XCTestCase {
    func testAuthTokenAndSessionUseSignedGetRequests() async throws {
        let http = FakeHTTPClient()
        http.enqueue(json: #"{ "token": "request-token" }"#)
        http.enqueue(json: #"{ "session": { "name": "tester", "key": "session-key" } }"#)
        let client = LastfmClient(httpClient: http, credentials: credentials)

        let token = try await client.fetchRequestToken()
        let session = try await client.fetchSession(token: token)

        XCTAssertEqual(token, "request-token")
        XCTAssertEqual(session, LastfmSession(username: "tester", sessionKey: "session-key"))

        let tokenQuery = queryValues(try XCTUnwrap(http.requests.first?.url))
        XCTAssertEqual(tokenQuery["method"], "auth.getToken")
        XCTAssertEqual(tokenQuery["api_key"], "api-key")
        XCTAssertEqual(tokenQuery["format"], "json")
        XCTAssertEqual(tokenQuery["api_sig"], expectedSignature([
            "method": "auth.getToken",
            "api_key": "api-key"
        ]))

        let sessionQuery = queryValues(try XCTUnwrap(http.requests.last?.url))
        XCTAssertEqual(sessionQuery["method"], "auth.getSession")
        XCTAssertEqual(sessionQuery["token"], "request-token")
        XCTAssertEqual(sessionQuery["api_sig"], expectedSignature([
            "method": "auth.getSession",
            "token": "request-token",
            "api_key": "api-key"
        ]))
    }

    func testAuthorizationURLIncludesEncodedCallback() {
        let client = LastfmClient(httpClient: FakeHTTPClient(), credentials: credentials)

        let url = client.authorizationURL(token: "token value", callbackURL: "panora://auth/callback")
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let items = Dictionary(uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(components?.scheme, "https")
        XCTAssertEqual(components?.host, "auth.example.test")
        XCTAssertEqual(items["api_key"], "api-key")
        XCTAssertEqual(items["token"], "token value")
        XCTAssertEqual(items["cb"], "panora://auth/callback")
    }

    func testPostRequestsAreSignedAndFormEncoded() async throws {
        let http = FakeHTTPClient()
        http.enqueue(json: #"{}"#)
        let client = LastfmClient(httpClient: http, credentials: credentials)
        let track = ScrobbleTrack(artist: "A&B", title: "Song Name", album: "Album", durationSeconds: 183.8)

        try await client.scrobble(track: track, timestamp: 123, sessionKey: "session")

        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")

        let body = try XCTUnwrap(String(data: try XCTUnwrap(request.httpBody), encoding: .utf8))
        let values = formValues(body)
        XCTAssertEqual(values["method"], "track.scrobble")
        XCTAssertEqual(values["artist"], "A&B")
        XCTAssertEqual(values["track"], "Song Name")
        XCTAssertEqual(values["album"], "Album")
        XCTAssertEqual(values["duration"], "183")
        XCTAssertEqual(values["timestamp"], "123")
        XCTAssertEqual(values["sk"], "session")
        XCTAssertEqual(values["api_key"], "api-key")
        XCTAssertEqual(values["format"], "json")
        XCTAssertEqual(values["api_sig"], expectedSignature([
            "method": "track.scrobble",
            "artist": "A&B",
            "track": "Song Name",
            "album": "Album",
            "duration": "183",
            "timestamp": "123",
            "sk": "session",
            "api_key": "api-key"
        ]))
    }

    func testUpdateNowPlayingOmitsEmptyAlbumAndNonPositiveDuration() async throws {
        let http = FakeHTTPClient()
        http.enqueue(json: #"{}"#)
        let client = LastfmClient(httpClient: http, credentials: credentials)
        let track = ScrobbleTrack(artist: "Artist", title: "Song", album: "", durationSeconds: 0)

        try await client.updateNowPlaying(track: track, sessionKey: "session")

        let body = try XCTUnwrap(String(data: try XCTUnwrap(http.requests.first?.httpBody), encoding: .utf8))
        let values = formValues(body)
        XCTAssertEqual(values["method"], "track.updateNowPlaying")
        XCTAssertEqual(values["artist"], "Artist")
        XCTAssertEqual(values["track"], "Song")
        XCTAssertEqual(values["sk"], "session")
        XCTAssertNil(values["album"])
        XCTAssertNil(values["duration"])
        XCTAssertEqual(values["api_sig"], expectedSignature([
            "method": "track.updateNowPlaying",
            "artist": "Artist",
            "track": "Song",
            "sk": "session",
            "api_key": "api-key"
        ]))
    }

    func testUserInfoParsesResponseAndUsesUnsignedGet() async throws {
        let http = FakeHTTPClient()
        http.enqueue(json: #"""
        {
          "user": {
            "name": "tester",
            "realname": "Test User",
            "playcount": "1234",
            "registered": { "unixtime": "1700000000" },
            "url": "https://last.fm/user/tester",
            "image": [
              { "#text": "https://example.test/small.jpg", "size": "small" },
              { "#text": "https://example.test/mega.jpg", "size": "mega" }
            ]
          }
        }
        """#)
        let client = LastfmClient(httpClient: http, credentials: credentials)

        let user = try await client.userInfo("tester")

        XCTAssertEqual(user.name, "tester")
        XCTAssertEqual(user.realName, "Test User")
        XCTAssertEqual(user.playcount, 1_234)
        XCTAssertEqual(user.registered, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(user.imageURL?.absoluteString, "https://example.test/mega.jpg")
        XCTAssertEqual(user.profileURL?.absoluteString, "https://last.fm/user/tester")

        let query = queryValues(try XCTUnwrap(http.requests.first?.url))
        XCTAssertEqual(query["method"], "user.getInfo")
        XCTAssertEqual(query["user"], "tester")
        XCTAssertEqual(query["api_key"], "api-key")
        XCTAssertEqual(query["format"], "json")
        XCTAssertNil(query["api_sig"])
    }

    func testTopAndRecentParsersHandleLastfmShapes() async throws {
        let http = FakeHTTPClient()
        http.enqueue(json: #"""
        { "topartists": { "artist": [
          { "name": "Artist", "playcount": "7", "url": "https://example.test/artist", "image": [{ "#text": "https://example.test/a.jpg", "size": "large" }] }
        ] } }
        """#)
        http.enqueue(json: #"""
        { "toptracks": { "track": [
          { "name": "Track", "artist": { "name": "Artist" }, "playcount": "9", "url": "https://example.test/track", "image": [{ "#text": "https://example.test/t.jpg", "size": "large" }] }
        ] } }
        """#)
        http.enqueue(json: #"""
        { "recenttracks": { "track":
          { "name": "Recent", "artist": { "#text": "Artist" }, "album": { "#text": "Album" }, "date": { "uts": "1700000100" }, "image": [{ "#text": "https://example.test/r.jpg", "size": "large" }] }
        } }
        """#)
        let client = LastfmClient(httpClient: http, credentials: credentials)

        let artists = try await client.topArtists("tester", period: .week, limit: 1)
        let tracks = try await client.topTracks("tester", period: .month, limit: 1)
        let recent = try await client.recentTracks("tester", limit: 1)

        XCTAssertEqual(artists.first?.name, "Artist")
        XCTAssertEqual(artists.first?.playcount, 7)
        XCTAssertEqual(artists.first?.imageURL?.absoluteString, "https://example.test/a.jpg")
        XCTAssertEqual(tracks.first?.name, "Track")
        XCTAssertEqual(tracks.first?.artist, "Artist")
        XCTAssertEqual(tracks.first?.playcount, 9)
        XCTAssertEqual(recent.first?.name, "Recent")
        XCTAssertEqual(recent.first?.album, "Album")
        XCTAssertEqual(recent.first?.date, Date(timeIntervalSince1970: 1_700_000_100))
    }

    func testStatsParsersSkipIncompleteEntriesAndHandleNowPlayingRecentTrack() async throws {
        let http = FakeHTTPClient()
        http.enqueue(json: #"""
        { "topartists": { "artist": [
          { "playcount": "100" },
          { "name": "Valid Artist", "playcount": 3, "image": [
            { "#text": "", "size": "mega" },
            { "#text": "https://example.test/fallback.jpg", "size": "small" }
          ] }
        ] } }
        """#)
        http.enqueue(json: #"""
        { "toptracks": { "track": [
          { "artist": { "name": "No Name" }, "playcount": "5" },
          { "name": "Valid Track", "playcount": "not-a-number", "image": [{ "#text": "https://example.test/track.jpg", "size": "medium" }] }
        ] } }
        """#)
        http.enqueue(json: #"""
        { "recenttracks": { "track": [
          { "artist": { "#text": "No Name" } },
          { "name": "Live Track", "artist": { "#text": "Artist" }, "album": { "#text": "" },
            "@attr": { "nowplaying": "true" },
            "image": [{ "#text": "https://example.test/live.jpg", "size": "small" }] }
        ] } }
        """#)
        let client = LastfmClient(httpClient: http, credentials: credentials)

        let artists = try await client.topArtists("tester", period: .week, limit: 5)
        let tracks = try await client.topTracks("tester", period: .week, limit: 5)
        let recent = try await client.recentTracks("tester", limit: 5)

        XCTAssertEqual(artists.map(\.name), ["Valid Artist"])
        XCTAssertEqual(artists.first?.playcount, 3)
        XCTAssertEqual(artists.first?.imageURL?.absoluteString, "https://example.test/fallback.jpg")
        XCTAssertEqual(tracks.map(\.name), ["Valid Track"])
        XCTAssertEqual(tracks.first?.artist, "")
        XCTAssertEqual(tracks.first?.playcount, 0)
        XCTAssertEqual(recent.map(\.name), ["Live Track"])
        XCTAssertNil(recent.first?.album)
        XCTAssertNil(recent.first?.date)
        XCTAssertEqual(recent.first?.nowPlaying, true)
    }

    func testStatsEndpointsReturnEmptyRecentListWhenTrackKeyMissing() async throws {
        let http = FakeHTTPClient()
        http.enqueue(json: #"{ "recenttracks": {} }"#)
        let client = LastfmClient(httpClient: http, credentials: credentials)

        let recent = try await client.recentTracks("tester", limit: 10)

        XCTAssertTrue(recent.isEmpty)
    }

    func testArtworkFallbacksAndCacheAvoidDuplicateLookupRequests() async throws {
        let http = FakeHTTPClient()
        http.enqueue(json: #"""
        { "topartists": { "artist": [
          { "name": "Artist", "playcount": "1", "image": [] }
        ] } }
        """#)
        http.enqueue(json: #"""
        { "artist": { "image": [
          { "#text": "https://example.test/artist-mega.jpg", "size": "mega" }
        ] } }
        """#)
        http.enqueue(json: #"""
        { "topartists": { "artist": [
          { "name": "Artist", "playcount": "2", "image": [] }
        ] } }
        """#)
        let client = LastfmClient(httpClient: http, credentials: credentials)

        let first = try await client.topArtists("tester", period: .week, limit: 1)
        let second = try await client.topArtists("tester", period: .month, limit: 1)

        XCTAssertEqual(first.first?.imageURL?.absoluteString, "https://example.test/artist-mega.jpg")
        XCTAssertEqual(second.first?.imageURL?.absoluteString, "https://example.test/artist-mega.jpg")
        XCTAssertEqual(http.requests.count, 3)
        XCTAssertEqual(http.requests.map { queryValues($0.url!)["method"] }, [
            "user.getTopArtists",
            "artist.getInfo",
            "user.getTopArtists"
        ])
    }

    func testTrackArtworkFallsBackToAlbumArtwork() async throws {
        let http = FakeHTTPClient()
        http.enqueue(json: #"""
        { "toptracks": { "track": [
          { "name": "Song", "artist": { "name": "Artist" }, "playcount": "4", "image": [] }
        ] } }
        """#)
        http.enqueue(json: #"""
        { "track": { "album": { "title": "Album", "image": [] }, "image": [] } }
        """#)
        http.enqueue(json: #"""
        { "album": { "image": [
          { "#text": "https://example.test/album.jpg", "size": "extralarge" }
        ] } }
        """#)
        let client = LastfmClient(httpClient: http, credentials: credentials)

        let tracks = try await client.topTracks("tester", period: .overall, limit: 1)

        XCTAssertEqual(tracks.first?.imageURL?.absoluteString, "https://example.test/album.jpg")
        XCTAssertEqual(http.requests.map { queryValues($0.url!)["method"] }, [
            "user.getTopTracks",
            "track.getInfo",
            "album.getInfo"
        ])
    }

    func testMalformedAuthResponsesThrowMalformedResponse() async throws {
        let http = FakeHTTPClient()
        http.enqueue(json: #"{}"#)
        http.enqueue(json: #"{ "session": { "name": "tester" } }"#)
        let client = LastfmClient(httpClient: http, credentials: credentials)

        do {
            _ = try await client.fetchRequestToken()
            XCTFail("Expected malformedResponse")
        } catch LastfmError.malformedResponse {
            // Expected.
        }

        do {
            _ = try await client.fetchSession(token: "token")
            XCTFail("Expected malformedResponse")
        } catch LastfmError.malformedResponse {
            // Expected.
        }
    }

    func testApiAndHttpErrorsAreSurfaced() async throws {
        let apiHTTP = FakeHTTPClient()
        apiHTTP.enqueue(json: #"{ "error": 9, "message": "Bad session" }"#)
        let apiClient = LastfmClient(httpClient: apiHTTP, credentials: credentials)

        do {
            _ = try await apiClient.fetchRequestToken()
            XCTFail("Expected API error")
        } catch LastfmError.api(let code, let message) {
            XCTAssertEqual(code, 9)
            XCTAssertEqual(message, "Bad session")
        }

        let http = FakeHTTPClient()
        http.enqueue(json: #"{}"#, status: 500)
        let httpClient = LastfmClient(httpClient: http, credentials: credentials)

        do {
            _ = try await httpClient.fetchRequestToken()
            XCTFail("Expected HTTP error")
        } catch LastfmError.http(let status) {
            XCTAssertEqual(status, 500)
        }
    }

    func testNotConfiguredShortCircuitsBeforeNetwork() async {
        let http = FakeHTTPClient()
        let client = LastfmClient(
            httpClient: http,
            credentials: LastfmCredentials(
                apiKey: "YOUR_LASTFM_API_KEY",
                sharedSecret: "YOUR_LASTFM_API_SECRET",
                apiRoot: URL(string: "https://ws.example.test/2.0/")!,
                authRoot: "https://auth.example.test/"
            )
        )

        do {
            _ = try await client.fetchRequestToken()
            XCTFail("Expected notConfigured")
        } catch LastfmError.notConfigured {
            XCTAssertTrue(http.requests.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private var credentials: LastfmCredentials {
        LastfmCredentials(
            apiKey: "api-key",
            sharedSecret: "secret",
            apiRoot: URL(string: "https://ws.example.test/2.0/")!,
            authRoot: "https://auth.example.test/"
        )
    }

    private func queryValues(_ url: URL) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    private func formValues(_ body: String) -> [String: String] {
        Dictionary(uniqueKeysWithValues: (URLComponents(string: "?\(body)")?.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
    }

    private func expectedSignature(_ params: [String: String]) -> String {
        let concatenated = params.sorted { $0.key < $1.key }
            .map { $0.key + $0.value }
            .joined()
        let digest = Insecure.MD5.hash(data: Data((concatenated + "secret").utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
