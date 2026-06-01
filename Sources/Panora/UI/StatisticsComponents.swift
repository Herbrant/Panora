// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// A single bar in the top-artists/top-tracks chart.
struct PlayChartItem: Identifiable {
    let id: String
    /// Display label, already truncated to fit the chart axis.
    let label: String
    let playcount: Int
}

/// A compact metric card (icon, title, value) used in the statistics dashboard's summary strip.
struct MetricTile: View {
    let title: String
    let value: String
    /// SF Symbol name shown beside the title.
    let symbol: String
    /// Tint applied to the symbol.
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }
}
