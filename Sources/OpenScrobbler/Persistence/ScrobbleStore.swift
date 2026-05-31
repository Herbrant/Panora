import Foundation
import SwiftData

/// Thin wrapper around the SwiftData context for scrobble persistence + queue.
@MainActor
final class ScrobbleStore {
    private let context: ModelContext
    private let maxAttempts = 5

    init(context: ModelContext) {
        self.context = context
    }

    func insert(_ entry: ScrobbleEntry) {
        context.insert(entry)
        try? context.save()
    }

    func markSent(_ entry: ScrobbleEntry) {
        entry.status = .sent
        try? context.save()
    }

    func markFailed(_ entry: ScrobbleEntry, error: String) {
        entry.attempts += 1
        entry.status = .failed
        entry.lastError = error
        try? context.save()
    }

    /// Entries still owed to Last.fm (pending or failed, below the retry cap), oldest first.
    func sendable() -> [ScrobbleEntry] {
        let pendingRaw = ScrobbleStatus.pending.rawValue
        let failedRaw = ScrobbleStatus.failed.rawValue
        let cap = maxAttempts
        let descriptor = FetchDescriptor<ScrobbleEntry>(
            predicate: #Predicate { entry in
                (entry.statusRaw == pendingRaw || entry.statusRaw == failedRaw) && entry.attempts < cap
            },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }
}
