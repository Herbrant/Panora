import SwiftData
import SwiftUI

struct HistoryView: View {
    @Environment(AppState.self) private var appState
    @Query(sort: \ScrobbleEntry.timestamp, order: .reverse) private var entries: [ScrobbleEntry]

    var body: some View {
        Group {
            if entries.isEmpty && appState.current == nil {
                ContentUnavailableView(
                    "No scrobbles",
                    systemImage: "music.note.list",
                    description: Text("Played tracks will appear here once scrobbled.")
                )
                .accessibilityIdentifier("panora.history.empty")
            } else {
                List {
                    if let current = appState.current {
                        CurrentScrobbleRow(track: current)
                    }

                    ForEach(entries) { entry in
                        ScrobbleRow(entry: entry)
                    }
                }
                .listStyle(.inset)
                .accessibilityIdentifier("panora.history.list")
            }
        }
        .navigationTitle("History")
        .accessibilityIdentifier("panora.history")
    }
}

private struct CurrentScrobbleRow: View {
    let track: TrackPlayback
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title).fontWeight(.medium)
                Text(track.artist).foregroundStyle(.secondary).font(.subheadline)
            }
            Spacer()
            Text("Scrobbling now")
                .foregroundStyle(.blue)
                .font(.caption)
                .fontWeight(.semibold)
            Image(systemName: "waveform")
                .foregroundStyle(.blue)
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating, value: isAnimating)
                .scaleEffect(isAnimating ? 1.12 : 0.96)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isAnimating)
                .help("Scrobbling now")
                .accessibilityLabel("Scrobbling now")
        }
        .padding(.vertical, 4)
        .onAppear { isAnimating = true }
        .onDisappear { isAnimating = false }
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
            Text(Date(timeIntervalSince1970: TimeInterval(entry.timestamp)), format: .dateTime.year().month(.abbreviated).day().hour().minute())
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
