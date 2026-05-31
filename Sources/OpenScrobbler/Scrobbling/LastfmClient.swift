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
            return "Last.fm API key/secret non configurati."
        case .http(let status):
            return "Errore di rete (HTTP \(status))."
        case .api(let code, let message):
            return "Errore Last.fm \(code): \(message)"
        case .malformedResponse:
            return "Risposta Last.fm non valida."
        }
    }
}

/// Minimal Last.fm API client: auth flow + now-playing + scrobble.
actor LastfmClient {
    private let urlSession = URLSession.shared

    // MARK: Public API

    func fetchRequestToken() async throws -> String {
        let data = try await get(["method": "auth.getToken"])
        guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = obj["token"] as? String else {
            throw LastfmError.malformedResponse
        }
        return token
    }

    nonisolated func authorizationURL(token: String) -> URL {
        URL(string: "\(LastfmConfig.authRoot)?api_key=\(LastfmConfig.apiKey)&token=\(token)")!
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

    // MARK: Helpers

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

    private func get(_ params: [String: String]) async throws -> Data {
        guard LastfmConfig.isConfigured else { throw LastfmError.notConfigured }
        var components = URLComponents(url: LastfmConfig.apiRoot, resolvingAgainstBaseURL: false)!
        components.queryItems = signed(params).map { URLQueryItem(name: $0.key, value: $0.value) }
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
            let message = obj["message"] as? String ?? "Errore sconosciuto"
            throw LastfmError.api(code: code, message: message)
        }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LastfmError.http(http.statusCode)
        }
    }
}
