// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Last.fm API credentials. Register an app at
/// https://www.last.fm/api/account/create and fill these in, or provide them
/// via the LASTFM_API_KEY / LASTFM_API_SECRET environment variables.
///
/// Priority (first wins):
///   1. Environment variable (dev convenience, Xcode scheme)
///   2. Secrets.generated.swift (generated from Config.xcconfig at build time)
///   3. Placeholder "YOUR_..." string (triggers isConfigured = false)
enum LastfmConfig {
    static let apiKey: String =
        ProcessInfo.processInfo.environment["LASTFM_API_KEY"]
        ?? Secrets.lastfmApiKey
        ?? "YOUR_LASTFM_API_KEY"

    static let sharedSecret: String =
        ProcessInfo.processInfo.environment["LASTFM_API_SECRET"]
        ?? Secrets.lastfmSharedSecret
        ?? "YOUR_LASTFM_API_SECRET"

    static var isConfigured: Bool {
        !apiKey.hasPrefix("YOUR_") && !sharedSecret.hasPrefix("YOUR_")
    }

    static let apiRoot = URL(string: "https://ws.audioscrobbler.com/2.0/")!
    static let authRoot = "https://www.last.fm/api/auth/"

    static var credentials: LastfmCredentials {
        LastfmCredentials(
            apiKey: apiKey,
            sharedSecret: sharedSecret,
            apiRoot: apiRoot,
            authRoot: authRoot
        )
    }
}

/// Resolved Last.fm endpoints + secrets, injected into ``LastfmClient``.
struct LastfmCredentials {
    var apiKey: String
    var sharedSecret: String
    var apiRoot: URL
    var authRoot: String

    /// `false` while either secret is still a `YOUR_…` placeholder.
    var isConfigured: Bool {
        !apiKey.hasPrefix("YOUR_") && !sharedSecret.hasPrefix("YOUR_")
    }
}
