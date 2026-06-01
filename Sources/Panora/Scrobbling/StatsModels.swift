// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/// Last.fm chart ranges for top artists/tracks.
enum StatsPeriod: String, CaseIterable, Identifiable {
    case week
    case month
    case quarter
    case halfYear
    case year
    case overall

    var id: String { rawValue }

    /// Value expected by the Last.fm `period` parameter.
    var apiValue: String {
        switch self {
        case .week: return "7day"
        case .month: return "1month"
        case .quarter: return "3month"
        case .halfYear: return "6month"
        case .year: return "12month"
        case .overall: return "overall"
        }
    }

    /// Human-readable label shown in the period picker.
    var title: String {
        switch self {
        case .week: return "7 days"
        case .month: return "1 month"
        case .quarter: return "3 months"
        case .halfYear: return "6 months"
        case .year: return "12 months"
        case .overall: return "All time"
        }
    }
}

/// A Last.fm user's profile summary (`user.getInfo`).
struct LastfmUserInfo {
    var name: String
    var realName: String?
    var playcount: Int
    var registered: Date?
    var imageURL: URL?
    var profileURL: URL?
}

/// A ranked artist from `user.getTopArtists`.
struct LastfmTopArtist: Identifiable {
    var name: String
    var playcount: Int
    var imageURL: URL?
    var url: URL?
    var id: String { name }
}

/// A ranked track from `user.getTopTracks`.
struct LastfmTopTrack: Identifiable {
    var name: String
    var artist: String
    var playcount: Int
    var imageURL: URL?
    var url: URL?
    var id: String { "\(artist)|\(name)" }
}

/// A recently scrobbled (or currently playing) track from `user.getRecentTracks`.
struct LastfmRecentTrack: Identifiable {
    var name: String
    var artist: String
    var album: String?
    var date: Date?
    /// `true` when this entry is the user's live now-playing track (it has no scrobble `date`).
    var nowPlaying: Bool
    var imageURL: URL?
    var id: String { "\(artist)|\(name)|\(date?.timeIntervalSince1970 ?? 0)" }
}
