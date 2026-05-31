import CryptoKit
import Foundation

enum LastfmError: Error, LocalizedError {
    case notConfigured
    case http(Int)
    case api(code: Int, message: String)
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
actor LastfmClient {
    private let urlSession = URLSession.shared
    private var artistArtworkTasks: [String: Task<URL?, Never>] = [:]
    private var albumArtworkTasks: [String: Task<URL?, Never>] = [:]
    private var trackArtworkTasks: [String: Task<URL?, Never>] = [:]

    // MARK: Public API

    func fetchRequestToken() async throws -> String {
        let data = try await get(["method": "auth.getToken"])
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = obj["token"] as? String else {
            throw LastfmError.malformedResponse
        }
        return token
    }

    nonisolated func authorizationURL(token: String, callbackURL: String? = nil) -> URL {
        var str = "\(LastfmConfig.authRoot)?api_key=\(LastfmConfig.apiKey)&token=\(token)"
        if let cb = callbackURL?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            str += "&cb=\(cb)"
        }
        return URL(string: str)!
    }

    func fetchSession(token: String) async throws -> LastfmSession {
        let data = try await get(["method": "auth.getSession", "token": token])
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let s = obj["session"] as? [String: Any],
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
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let obj = root["user"] as? [String: Any],
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
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let container = root["topartists"] as? [String: Any],
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
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let container = root["toptracks"] as? [String: Any],
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
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let container = root["recenttracks"] as? [String: Any] else {
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

    private func artistArtworkURL(artist: String) async -> URL? {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedArtist.isEmpty else { return nil }

        let key = trimmedArtist.lowercased()
        if let task = artistArtworkTasks[key] {
            return await task.value
        }

        let task = Task { [self] in
            do {
                return try await fetchArtistArtworkURL(artist: trimmedArtist)
            } catch {
                return nil
            }
        }
        artistArtworkTasks[key] = task
        return await task.value
    }

    private func fetchArtistArtworkURL(artist: String) async throws -> URL? {
        let data = try await get([
            "method": "artist.getInfo",
            "artist": artist,
            "autocorrect": "1"
        ], requiresSignature: false)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let obj = root["artist"] as? [String: Any] else {
            throw LastfmError.malformedResponse
        }
        return Self.imageURL(obj["image"])
    }

    private func albumArtworkURL(artist: String, album: String) async -> URL? {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAlbum = album.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedArtist.isEmpty, !trimmedAlbum.isEmpty else { return nil }

        let key = "\(trimmedArtist.lowercased())|\(trimmedAlbum.lowercased())"
        if let task = albumArtworkTasks[key] {
            return await task.value
        }

        let task = Task { [self] in
            do {
                return try await fetchAlbumArtworkURL(artist: trimmedArtist, album: trimmedAlbum)
            } catch {
                return nil
            }
        }
        albumArtworkTasks[key] = task
        return await task.value
    }

    private func fetchAlbumArtworkURL(artist: String, album: String) async throws -> URL? {
        let data = try await get([
            "method": "album.getInfo",
            "artist": artist,
            "album": album,
            "autocorrect": "1"
        ], requiresSignature: false)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let obj = root["album"] as? [String: Any] else {
            throw LastfmError.malformedResponse
        }
        return Self.imageURL(obj["image"])
    }

    private func trackArtworkURL(artist: String, track: String) async -> URL? {
        let trimmedArtist = artist.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTrack = track.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedArtist.isEmpty, !trimmedTrack.isEmpty else { return nil }

        let key = "\(trimmedArtist.lowercased())|\(trimmedTrack.lowercased())"
        if let task = trackArtworkTasks[key] {
            return await task.value
        }

        let task = Task { [self] in
            do {
                return try await fetchTrackArtworkURL(artist: trimmedArtist, track: trimmedTrack)
            } catch {
                return nil
            }
        }
        trackArtworkTasks[key] = task
        return await task.value
    }

    private func fetchTrackArtworkURL(artist: String, track: String) async throws -> URL? {
        let data = try await get([
            "method": "track.getInfo",
            "artist": artist,
            "track": track,
            "autocorrect": "1"
        ], requiresSignature: false)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let obj = root["track"] as? [String: Any] else {
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
        let digest = Insecure.MD5.hash(data: Data((concatenated + LastfmConfig.sharedSecret).utf8))
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
        p["api_key"] = LastfmConfig.apiKey
        p["api_sig"] = signature(p)
        p["format"] = "json"
        return p
    }

    private func get(_ params: [String: String], requiresSignature: Bool = true) async throws -> Data {
        guard LastfmConfig.isConfigured else { throw LastfmError.notConfigured }
        var components = URLComponents(url: LastfmConfig.apiRoot, resolvingAgainstBaseURL: false)!
        let finalParams: [String: String]
        if requiresSignature {
            finalParams = signed(params)
        } else {
            var p = params
            p["api_key"] = LastfmConfig.apiKey
            p["format"] = "json"
            finalParams = p
        }
        components.queryItems = finalParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        let (data, response) = try await urlSession.data(from: components.url!)
        try validate(data, response)
        return data
    }

    private func post(_ params: [String: String]) async throws -> Data {
        guard LastfmConfig.isConfigured else { throw LastfmError.notConfigured }
        var request = URLRequest(url: LastfmConfig.apiRoot)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncode(signed(params)).data(using: .utf8)
        let (data, response) = try await urlSession.data(for: request)
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
