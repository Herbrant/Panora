import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \ScrobbleEntry.timestamp, order: .reverse) private var entries: [ScrobbleEntry]

    var body: some View {
        Group {
            if entries.isEmpty {
                ContentUnavailableView(
                    "No scrobbles",
                    systemImage: "music.note.list",
                    description: Text("Played tracks will appear here once scrobbled.")
                )
            } else {
                List(entries) { entry in
                    ScrobbleRow(entry: entry)
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("History")
    }
}

private struct ScrobbleRow: View {
    let entry: ScrobbleEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title).fontWeight(.medium)
                Text(entry.artist).foregroundStyle(.secondary).font(.subheadline)
            }
            Spacer()
            Text(Date(timeIntervalSince1970: TimeInterval(entry.timestamp)), style: .relative)
                .foregroundStyle(.tertiary)
                .font(.caption)
            StatusBadge(status: entry.status)
        }
        .padding(.vertical, 4)
        .help(entry.lastError ?? "")
    }
}

private struct StatusBadge: View {
    let status: ScrobbleStatus

    var body: some View {
        Image(systemName: symbol)
            .foregroundStyle(color)
            .help(label)
            .accessibilityLabel(label)
    }

    private var symbol: String {
        switch status {
        case .sent: return "checkmark.circle.fill"
        case .pending: return "clock.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var color: Color {
        switch status {
        case .sent: return .green
        case .pending: return .orange
        case .failed: return .red
        }
    }

    private var label: String {
        switch status {
        case .sent: return "Sent"
        case .pending: return "Queued"
        case .failed: return "Error"
        }
    }
}
