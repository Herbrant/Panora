import Foundation
import Observation

@MainActor
@Observable
final class StatisticsViewModel {
    private(set) var userInfo: LastfmUserInfo?
    private(set) var topArtists: [LastfmTopArtist] = []
    private(set) var topTracks: [LastfmTopTrack] = []
    private(set) var recentTracks: [LastfmRecentTrack] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load(username: String, period: StatsPeriod, client: LastfmServing = LastfmClient()) async {
        isLoading = true
        errorMessage = nil
        do {
            async let info = client.userInfo(username)
            async let artists = client.topArtists(username, period: period)
            async let tracks = client.topTracks(username, period: period)
            async let recent = client.recentTracks(username)

            userInfo = try await info
            topArtists = try await artists
            topTracks = try await tracks
            recentTracks = try await recent
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
