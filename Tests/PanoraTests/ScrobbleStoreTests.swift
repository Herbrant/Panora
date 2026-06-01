@testable import Panora
import SwiftData
import XCTest

@MainActor
final class ScrobbleStoreTests: XCTestCase {
    /// Keep the container alive for the test; the context does not retain it
    /// strongly enough, and operations trap once it deallocates.
    private var container: ModelContainer?

    override func tearDown() {
        container = nil
    }

    func testSendableReturnsPendingAndFailedBelowRetryCapOldestFirst() async throws {
        let store = try makeStore()
        let sent = entry(title: "Sent", timestamp: 1, status: .sent)
        let capped = entry(title: "Capped", timestamp: 2, status: .failed)
        capped.attempts = 5
        let newerPending = entry(title: "Newer", timestamp: 4, status: .pending)
        let olderFailed = entry(title: "Older", timestamp: 3, status: .failed)
        olderFailed.attempts = 4

        [sent, capped, newerPending, olderFailed].forEach(store.insert)

        XCTAssertEqual(store.sendable().map(\.title), ["Older", "Newer"])
    }

    func testMarkSentAndFailedPersistStatus() async throws {
        let store = try makeStore()
        let pending = entry(title: "Pending", timestamp: 10, status: .pending)
        store.insert(pending)

        store.markFailed(pending, error: "offline")
        XCTAssertEqual(pending.status, .failed)
        XCTAssertEqual(pending.attempts, 1)
        XCTAssertEqual(pending.lastError, "offline")

        store.markSent(pending)
        XCTAssertEqual(pending.status, .sent)
    }

    private func makeStore() throws -> ScrobbleStore {
        let schema = Schema([ScrobbleEntry.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        self.container = container
        return ScrobbleStore(context: container.mainContext)
    }

    private func entry(title: String, timestamp: Int, status: ScrobbleStatus) -> ScrobbleEntry {
        ScrobbleEntry(
            track: ScrobbleTrack(artist: "Artist", title: title, album: nil, durationSeconds: 180),
            timestamp: timestamp,
            status: status
        )
    }
}
