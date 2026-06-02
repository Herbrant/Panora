// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

struct ScrobbleProgressIndicator: View {
    let progress: ScrobbleProgress
    var showsBar = true

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 5) {
                Label(statusText(at: context.date), systemImage: symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)

                if showsBar && progress.status == .waiting {
                    ProgressView(value: progress.fraction(at: context.date))
                        .controlSize(.small)
                        .tint(color)
                        .accessibilityLabel("Scrobble progress")
                        .accessibilityValue("\(Int(progress.fraction(at: context.date) * 100)) percent")
                }
            }
        }
    }

    private var symbol: String {
        switch progress.status {
        case .notEligible: return "slash.circle"
        case .waiting: return "timer"
        case .scrobbled: return "checkmark.circle.fill"
        case .pausedPlayback: return "pause.circle"
        case .suspended: return "power.circle"
        }
    }

    private var color: Color {
        switch progress.status {
        case .notEligible: return .secondary
        case .waiting: return .blue
        case .scrobbled: return .green
        case .pausedPlayback: return .secondary
        case .suspended: return .orange
        }
    }

    private func statusText(at date: Date) -> String {
        switch progress.status {
        case .notEligible:
            return "Not eligible"
        case .waiting:
            let remaining = Int(ceil(progress.remainingSeconds(at: date)))
            return remaining > 0 ? "Scrobble in \(formatDuration(remaining))" : "Scrobbling soon"
        case .scrobbled:
            return "Scrobbled"
        case .pausedPlayback:
            return "Paused"
        case .suspended:
            return "Scrobbling off"
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
