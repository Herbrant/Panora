@testable import Panora
import XCTest

@MainActor
final class StatisticsViewModelTests: XCTestCase {
    func testLoadPopulatesAllSections() async {
        let client = FakeLastfmClient()
        client.userInfoResult = LastfmUserInfo(name: "tester", realName: "Test User", playcount: 10, registered: nil, imageURL: nil, profileURL: nil)
        client.topArtistsResult = [LastfmTopArtist(name: "Artist", playcount: 7, imageURL: nil, url: nil)]
        client.topTracksResult = [LastfmTopTrack(name: "Track", artist: "Artist", playcount: 4, imageURL: nil, url: nil)]
        client.recentTracksResult = [LastfmRecentTrack(name: "Recent", artist: "Artist", album: nil, date: nil, nowPlaying: false, imageURL: nil)]
        let model = StatisticsViewModel()

        await model.load(username: "tester", period: .week, client: client)

        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(model.userInfo?.name, "tester")
        XCTAssertEqual(model.topArtists.map(\.name), ["Artist"])
        XCTAssertEqual(model.topTracks.map(\.name), ["Track"])
        XCTAssertEqual(model.recentTracks.map(\.name), ["Recent"])
    }

    func testLoadReportsErrorsAndStopsLoading() async {
        let client = FakeLastfmClient(userInfoError: LastfmError.http(500))
        let model = StatisticsViewModel()

        await model.load(username: "tester", period: .week, client: client)

        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.errorMessage, "Network error (HTTP 500).")
    }
}
