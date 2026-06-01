// SPDX-License-Identifier: GPL-3.0-or-later

import CryptoKit
import Foundation

/// The Last.fm operations the app depends on: the desktop auth flow, scrobbling,
/// and the read-only statistics endpoints.
///
/// Abstracted as a protocol so the UI and tests can inject a fake (see the
/// UI-testing double in `PanoraApp`).
protocol LastfmServing: AnyObject {
    /// `false` when API credentials are missing/placeholder; sign-in is disabled until configured.
    var isConfigured: Bool { get }

    /// Requests an unauthorized token to start the desktop auth flow.
    func fetchRequestToken() async throws -> String
    /// Browser URL where the user authorizes `token`; `callbackURL` returns them to the app.
    func authorizationURL(token: String, callbackURL: String?) -> URL
    /// Exchanges an authorized `token` for a durable session (username + session key).
    func fetchSession(token: String) async throws -> LastfmSession
    /// Submits a `track.updateNowPlaying`; best-effort, not persisted.
    func updateNowPlaying(track: ScrobbleTrack, sessionKey: String) async throws
    /// Submits a `track.scrobble` played at `timestamp` (Unix seconds).
    func scrobble(track: ScrobbleTrack, timestamp: Int, sessionKey: String) async throws
    /// Fetches the profile summary for `user`.
    func userInfo(_ user: String) async throws -> LastfmUserInfo
    /// Fetches the top artists for `user` over `period`, capped at `limit`.
    func topArtists(_ user: String, period: StatsPeriod, limit: Int) async throws -> [LastfmTopArtist]
    /// Fetches the top tracks for `user` over `period`, capped at `limit`.
    func topTracks(_ user: String, period: StatsPeriod, limit: Int) async throws -> [LastfmTopTrack]
    /// Fetches the most recent scrobbles for `user`, capped at `limit`.
    func recentTracks(_ user: String, limit: Int) async throws -> [LastfmRecentTrack]
}

/// Convenience overloads supplying default arguments to ``LastfmServing``.
extension LastfmServing {
    func authorizationURL(token: String) -> URL {
        authorizationURL(token: token, callbackURL: nil)
    }

    func topArtists(_ user: String, period: StatsPeriod) async throws -> [LastfmTopArtist] {
        try await topArtists(user, period: period, limit: 20)
    }

    func topTracks(_ user: String, period: StatsPeriod) async throws -> [LastfmTopTrack] {
        try await topTracks(user, period: period, limit: 20)
    }

    func recentTracks(_ user: String) async throws -> [LastfmRecentTrack] {
        try await recentTracks(user, limit: 20)
    }
}

/// The networking surface ``LastfmClient`` needs, so tests can stub HTTP responses.
protocol LastfmHTTPClient {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: LastfmHTTPClient {}

/// Errors surfaced by ``LastfmClient``.
enum LastfmError: Error, LocalizedError {
    /// API key/secret are missing or still placeholders.
    case notConfigured
    /// A non-2xx HTTP status was returned.
    case http(Int)
    /// Last.fm returned an API error (these arrive with HTTP 200, so they are checked first).
    case api(code: Int, message: String)
    /// The response body could not be parsed into the expected shape.
    case malformedResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Last.fm API key/secret not configured."
        case .http(let status):
            return "Network error (HTTP \(status))."
        case .api(let code, let message):
            return "Last.fm error \(code): \(message)"
        case .malformedResponse:
            return "Invalid Last.fm response."
        }
    }
}

/// Minimal Last.fm API client: auth flow + now-playing + scrobble.
actor LastfmClient: LastfmServing {
    private let httpClient: LastfmHTTPClient
    private let credentials: LastfmCredentials
    /// In-flight/completed artwork lookups, keyed by a type-namespaced identity so
    /// concurrent callers share one request per subject. See ``cachedArtworkURL(key:fetch:)``.
    private var artworkTasks: [String: Task<URL?, Never>] = [:]

    nonisolated var isConfigured: Bool { credentials.isConfigured }

    init(httpClient: LastfmHTTPClient = URLSession.shared, credentials: LastfmCredentials = LastfmConfig.credentials) {
        self.httpClient = httpClient
        self.credentials = credentials
    }

    // MARK: Public API

    func fetchRequestToken() async throws -> String {
        let data = try await get(["method": "auth.getToken"])
        guard let token = try rootObject(data)["token"] as? String else {
            throw LastfmError.malformedResponse
        }
        return token
    }

    nonisolated func authorizationURL(token: String, callbackURL: String? = nil) -> URL {
        var str = "\(credentials.authRoot)?api_key=\(credentials.apiKey)&token=\(token)"
        if let cb = callbackURL?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            str += "&cb=\(cb)"
        }
        return URL(string: str)!
    }

    func fetchSession(token: String) async throws -> LastfmSession {
        let data = try await get(["method": "auth.getSession", "token": token])
        guard let s = try rootObject(data)["session"] as? [String: Any],
              let name = s["name"] as? String,
              let key = s["key"] as? String else {
            throw LastfmError.malformedResponse
        }
        return LastfmSession(username: name, sessionKey: key)
    }

    func updateNowPlaying(track: ScrobbleTrack, sessionKey: String) async throws {
        _ = try await post(trackParams(method: "track.updateNowPlaying", track: track, sessionKey: sessionKey))
    }

    func scrobble(track: ScrobbleTrack, timestamp: Int, sessionKey: String) async throws {
        var params = trackParams(method: "track.scrobble", track: track, sessionKey: sessionKey)
        params["timestamp"] = String(timestamp)
        _ = try await post(params)
    }

    // MARK: User statistics (public read methods, no signature)

    func userInfo(_ user: String) async throws -> LastfmUserInfo {
        let data = try await get(["method": "user.getInfo", "user": user], requiresSignature: false)
        guard let obj = try rootObject(data)["user"] as? [String: Any],
              let name = obj["name"] as? String else {
            throw LastfmError.malformedResponse
        }
        let real = (obj["realname"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        var registered: Date?
        if let reg = obj["registered"] as? [String: Any] {
            let uts = (reg["unixtime"] as? String) ?? (reg["#text"] as? String)
            if let uts, let secs = TimeInterval(uts) { registered = Date(timeIntervalSince1970: secs) }
        }
        return LastfmUserInfo(
            name: name,
            realName: real,
            playcount: Self.int(obj["playcount"]),
            registered: registered,
            imageURL: Self.imageURL(obj["image"]),
            profileURL: (obj["url"] as? String).flatMap(URL.init(string:))
        )
    }

    func topArtists(_ user: String, period: StatsPeriod, limit: Int = 20) async throws -> [LastfmTopArtist] {
        let data = try await get([
            "method": "user.getTopArtists", "user": user,
            "period": period.apiValue, "limit": String(limit)
        ], requiresSignature: false)
        guard let container = try rootObject(data)["topartists"] as? [String: Any],
              let arr = container["artist"] as? [[String: Any]] else {
            throw LastfmError.malformedResponse
        }
        var artists: [LastfmTopArtist] = []
        for obj in arr {
            guard let name = obj["name"] as? String else { continue }
            let imageURL: URL?
            if let existingImageURL = Self.imageURL(obj["image"]) {
                imageURL = existingImageURL
            } else {
                imageURL = await artistArtworkURL(artist: name)
            }
            artists.append(LastfmTopArtist(
                name: name,
                playcount: Self.int(obj["playcount"]),
                imageURL: imageURL,
                url: (obj["url"] as? String).flatMap(URL.init(string:))
            ))
        }
        return artists
    }

    func topTracks(_ user: String, period: StatsPeriod, limit: Int = 20) async throws -> [LastfmTopTrack] {
        let data = try await get([
            "method": "user.getTopTracks", "user": user,
            "period": period.apiValue, "limit": String(limit)
        ], requiresSignature: false)
        guard let container = try rootObject(data)["toptracks"] as? [String: Any],
              let arr = container["track"] as? [[String: Any]] else {
            throw LastfmError.malformedResponse
        }
        var tracks: [LastfmTopTrack] = []
        for obj in arr {
            guard let name = obj["name"] as? String else { continue }
            let artist = (obj["artist"] as? [String: Any])?["name"] as? String ?? ""
            let imageURL: URL?
            if let existingImageURL = Self.imageURL(obj["image"]) {
                imageURL = existingImageURL
            } else {
                imageURL = await trackArtworkURL(artist: artist, track: name)
            }
            tracks.append(LastfmTopTrack(
                name: name,
                artist: artist,
                playcount: Self.int(obj["playcount"]),
                imageURL: imageURL,
                url: (obj["url"] as? String).flatMap(URL.init(string:))
            ))
        }
        return tracks
    }

    func recentTracks(_ user: String, limit: Int = 20) async throws -> [LastfmRecentTrack] {
        let data = try await get([
            "method": "user.getRecentTracks", "user": user, "limit": String(limit)
        ], requiresSignature: false)
        guard let container = try rootObject(data)["recenttracks"] as? [String: Any] else {
            throw LastfmError.malformedResponse
        }
        // `track` is an array, or a single object when only one entry exists.
        let arr: [[String: Any]]
        if let list = container["track"] as? [[String: Any]] {
            arr = list
        } else if let single = container["track"] as? [String: Any] {
            arr = [single]
        } else {
            arr = []
        }
        var tracks: [LastfmRecentTrack] = []
        for obj in arr {
            guard let name = obj["name"] as? String else { continue }
            let artist = (obj["artist"] as? [String: Any])?["#text"] as? String ?? ""
            let album = ((obj["album"] as? [String: Any])?["#text"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let nowPlaying = ((obj["@attr"] as? [String: Any])?["nowplaying"] as? String) == "true"
            var date: Date?
            if let d = obj["date"] as? [String: Any], let uts = d["uts"] as? String, let secs = TimeInterval(uts) {
                date = Date(timeIntervalSince1970: secs)
            }
            let imageURL: URL?
            if let existingImageURL = Self.imageURL(obj["image"]) {
                imageURL = existingImageURL
            } else {
                imageURL = await trackArtworkURL(artist: artist, track: name)
            }
            tracks.append(LastfmRecentTrack(
                name: name,
                artist: artist,
                album: album,
                date: date,
                nowPlaying: nowPlaying,
                imageURL: imageURL
            ))
        }
        return tracks
    }

    // MARK: Parsing helpers

    /// Decodes response data into the top-level JSON object, or throws ``LastfmError/malformedResponse``.
    private nonisolated func rootObject(_ data: Data) throws -> [String: Any] {
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LastfmError.malformedResponse
        }
        return obj
    }

    /// Last.fm encodes counts as strings.
    private static func int(_ value: Any?) -> Int {
        if let i = value as? Int { return i }
        if let s = value as? String { return Int(s) ?? 0 }
        return 0
    }

    /// Picks the largest non-empty URL from a Last.fm `[{"#text","size"}]` image array.
    private static func imageURL(_ value: Any?) -> URL? {
        guard let images = value as? [[String: Any]] else { return nil }
        let order = ["mega", "extralarge", "large", "medium", "small", ""]
        for size in order {
            if let match = images.first(where: { ($0["size"] as? String) == size }),
               let text = match["#text"] as? String, !text.isEmpty {
                return URL(string: text)
            }
        }
        let any = images.compactMap { ($0["#text"] as? String).flatMap { $0.isEmpty ? nil : $0 } }.last
        return any.flatMap(URL.init(string:))
    }

    // MARK: Helpers

    /// Memoizes an artwork lookup so concurrent callers share one in-flight request.
    ///
    /// The first call for a `key` stores its `Task` in `cache`; later calls await
    /// the same task instead of issuing a duplicate network request. Failures
    /// resolve to `nil` and are cached, so a missing-artwork lookup is not retried.
    private func cachedArtworkURL(key: String, fetch: @escaping () async throws -> URL?) async -> URL? {
        if let task = artworkTasks[key] {
            return await task.value
        }
        let task = Task { try? await fetch() }
        artworkTasks[key] = task
        return await task.value
    }

    private func artistArtworkURL(artist: String) async -> URL? {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedArtist.isEmpty else { return nil }
        return await cachedArtworkURL(key: "artist|\(trimmedArtist.lowercased())") {
            try await self.fetchArtistArtworkURL(artist: trimmedArtist)
        }
    }

    private func fetchArtistArtworkURL(artist: String) async throws -> URL? {
        let data = try await get([
            "method": "artist.getInfo",
            "artist": artist,
            "autocorrect": "1"
        ], requiresSignature: false)
        guard let obj = try rootObject(data)["artist"] as? [String: Any] else {
            throw LastfmError.malformedResponse
        }
        return Self.imageURL(obj["image"])
    }

    private func albumArtworkURL(artist: String, album: String) async -> URL? {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedArtist.isEmpty, !trimmedAlbum.isEmpty else { return nil }
        let key = "album|\(trimmedArtist.lowercased())|\(trimmedAlbum.lowercased())"
        return await cachedArtworkURL(key: key) {
            try await self.fetchAlbumArtworkURL(artist: trimmedArtist, album: trimmedAlbum)
        }
    }

    private func fetchAlbumArtworkURL(artist: String, album: String) async throws -> URL? {
        let data = try await get([
            "method": "album.getInfo",
            "artist": artist,
            "album": album,
            "autocorrect": "1"
        ], requiresSignature: false)
        guard let obj = try rootObject(data)["album"] as? [String: Any] else {
            throw LastfmError.malformedResponse
        }
        return Self.imageURL(obj["image"])
    }

    private func trackArtworkURL(artist: String, track: String) async -> URL? {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTrack = track.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedArtist.isEmpty, !trimmedTrack.isEmpty else { return nil }
        let key = "track|\(trimmedArtist.lowercased())|\(trimmedTrack.lowercased())"
        return await cachedArtworkURL(key: key) {
            try await self.fetchTrackArtworkURL(artist: trimmedArtist, track: trimmedTrack)
        }
    }

    private func fetchTrackArtworkURL(artist: String, track: String) async throws -> URL? {
        let data = try await get([
            "method": "track.getInfo",
            "artist": artist,
            "track": track,
            "autocorrect": "1"
        ], requiresSignature: false)
        guard let obj = try rootObject(data)["track"] as? [String: Any] else {
            throw LastfmError.malformedResponse
        }
        let album = obj["album"] as? [String: Any]
        if let imageURL = Self.imageURL(album?["image"]) ?? Self.imageURL(obj["image"]) {
            return imageURL
        }
        if let albumTitle = album?["title"] as? String {
            return await albumArtworkURL(artist: artist, album: albumTitle)
        }
        return nil
    }

    private func trackParams(method: String, track: ScrobbleTrack, sessionKey: String) -> [String: String] {
        var params: [String: String] = [
            "method": method,
            "artist": track.artist,
            "track": track.title,
            "sk": sessionKey
        ]
        if let album = track.album, !album.isEmpty { params["album"] = album }
        if let duration = track.durationSeconds, duration > 0 { params["duration"] = String(Int(duration)) }
        return params
    }

    private func signature(_ params: [String: String]) -> String {
        let concatenated = params.sorted { $0.key < $1.key }
            .map { $0.key + $0.value }
            .joined()
        let digest = Insecure.MD5.hash(data: Data((concatenated + credentials.sharedSecret).utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func formEncode(_ params: [String: String]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return params.map { key, value in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(k)=\(v)"
        }.joined(separator: "&")
    }

    /// Adds api_key + api_sig (signature excludes `format`), then `format=json`.
    private func signed(_ params: [String: String]) -> [String: String] {
        var p = params
        p["api_key"] = credentials.apiKey
        p["api_sig"] = signature(p)
        p["format"] = "json"
        return p
    }

    private func get(_ params: [String: String], requiresSignature: Bool = true) async throws -> Data {
        guard credentials.isConfigured else { throw LastfmError.notConfigured }
        var components = URLComponents(url: credentials.apiRoot, resolvingAgainstBaseURL: false)!
        let finalParams: [String: String]
        if requiresSignature {
            finalParams = signed(params)
        } else {
            var p = params
            p["api_key"] = credentials.apiKey
            p["format"] = "json"
            finalParams = p
        }
        components.queryItems = finalParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        let request = URLRequest(url: components.url!)
        let (data, response) = try await httpClient.data(for: request)
        try validate(data, response)
        return data
    }

    private func post(_ params: [String: String]) async throws -> Data {
        guard credentials.isConfigured else { throw LastfmError.notConfigured }
        var request = URLRequest(url: credentials.apiRoot)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode(signed(params)).data(using: .utf8)
        let (data, response) = try await httpClient.data(for: request)
        try validate(data, response)
        return data
    }

    private func validate(_ data: Data, _ response: URLResponse) throws {
        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let code = obj["error"] as? Int {
            let message = obj["message"] as? String ?? "Unknown error"
            throw LastfmError.api(code: code, message: message)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LastfmError.http(http.statusCode)
        }
    }
}
