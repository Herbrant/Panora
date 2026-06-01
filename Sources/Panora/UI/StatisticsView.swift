// SPDX-License-Identifier: GPL-3.0-or-later

import Charts
import SwiftUI

/// Statistics dashboard: profile header, summary metrics, top-artist/track charts,
/// and recent activity for the signed-in user over a selectable period.
struct StatisticsView: View {
    @Environment(AppState.self) private var appState
    @State private var model = StatisticsViewModel()
    @State private var period: StatsPeriod = .week

    private var username: String? { appState.session?.username }

    var body: some View {
        Group {
            if let username {
                content(username: username)
            } else {
                ContentUnavailableView(
                    "Not signed in",
                    systemImage: "person.crop.circle.badge.questionmark",
                    description: Text("Sign in to Last.fm to see your statistics.")
                )
            }
        }
        .navigationTitle("Statistics")
        .accessibilityIdentifier("panora.statistics")
        .task(id: taskKey) {
            guard let username else { return }
            await model.load(username: username, period: period, client: appState.client)
        }
    }

    private var taskKey: String { "\(username ?? "")|\(period.rawValue)" }

    private var hasDashboardData: Bool {
        model.userInfo != nil || !model.topArtists.isEmpty || !model.topTracks.isEmpty || !model.recentTracks.isEmpty
    }

    private var topArtistPlays: Int {
        model.topArtists.reduce(0) { $0 + $1.playcount }
    }

    private var topTrackPlays: Int {
        model.topTracks.reduce(0) { $0 + $1.playcount }
    }

    private var topArtistName: String {
        model.topArtists.first?.name ?? "No artist"
    }

    private var topTrackName: String {
        model.topTracks.first.map { "\($0.name) - \($0.artist)" } ?? "No track"
    }

    private var accountAgeText: String {
        guard let registered = model.userInfo?.registered else { return "Unknown" }
        let components = Calendar.current.dateComponents([.year, .month], from: registered, to: Date())
        if let years = components.year, years > 0 {
            let months = max(components.month ?? 0, 0)
            return months > 0 ? "\(years)y \(months)m" : "\(years)y"
        }
        if let months = components.month, months > 0 {
            return "\(months)m"
        }
        return "New"
    }

    @ViewBuilder
    private func content(username: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                profileHeader

                if let error = model.errorMessage {
                    errorBanner(error)
                }

                HStack(alignment: .center, spacing: 12) {
                    periodControl
                    Spacer()
                    if model.isLoading && hasDashboardData {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Refreshing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if model.isLoading && !hasDashboardData {
                    loadingPanel
                } else {
                    dashboard
                }
            }
            .padding(20)
        }
    }

    // MARK: Dashboard

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 16) {
            metricStrip
            chartPanels
            recentPanel
        }
    }

    private var metricStrip: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
            alignment: .leading,
            spacing: 12
        ) {
            MetricTile(
                title: "Artist plays",
                value: topArtistPlays.formatted(),
                symbol: "music.mic",
                color: .accentColor
            )
            MetricTile(
                title: "Track plays",
                value: topTrackPlays.formatted(),
                symbol: "music.note",
                color: .blue
            )
            MetricTile(
                title: "Top artist",
                value: topArtistName,
                symbol: "crown.fill",
                color: .orange
            )
            MetricTile(
                title: "Top track",
                value: topTrackName,
                symbol: "waveform",
                color: .green
            )
        }
    }

    private var chartPanels: some View {
        VStack(alignment: .leading, spacing: 16) {
            topArtistsPanel
            topTracksPanel
        }
    }

    private var topArtistsPanel: some View {
        panel(title: "Top Artists", subtitle: "Most played in \(period.title)", symbol: "chart.bar.xaxis") {
            if model.topArtists.isEmpty {
                emptyState("No artists for this period.", symbol: "music.mic")
            } else {
                playChart(items: artistChartItems, tint: .accentColor)
            }
        }
    }

    private var topTracksPanel: some View {
        panel(title: "Top Tracks", subtitle: "Most repeated songs", symbol: "chart.line.uptrend.xyaxis") {
            if model.topTracks.isEmpty {
                emptyState("No tracks for this period.", symbol: "music.note")
            } else {
                playChart(items: trackChartItems, tint: .blue)
            }
        }
    }

    private var recentPanel: some View {
        panel(title: "Recent Activity", subtitle: "Latest scrobbles", symbol: "clock.arrow.circlepath") {
            if model.recentTracks.isEmpty {
                emptyState("No recent tracks.", symbol: "music.note.list")
            } else {
                VStack(spacing: 0) {
                    ForEach(model.recentTracks.prefix(8)) { track in
                        recentRow(track)
                        if track.id != model.recentTracks.prefix(8).last?.id {
                            Divider().padding(.leading, 50)
                        }
                    }
                }
            }
        }
    }

    // MARK: Profile

    private var profileHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                avatar(url: model.userInfo?.imageURL, size: 64, fallback: "person.crop.circle.fill")
                profileIdentity
            }
            registeredSummary
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }

    private var profileIdentity: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(model.userInfo?.realName ?? model.userInfo?.name ?? (username ?? ""))
                    .font(.title2.weight(.semibold))
                    .lineLimit(1)
                if let real = model.userInfo?.realName, real != model.userInfo?.name {
                    Text("@\(model.userInfo?.name ?? "")")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .lineLimit(1)
                }
            }

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 112), spacing: 6)],
                alignment: .leading,
                spacing: 6
            ) {
                profileBadges
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var profileBadges: some View {
        profileBadge(
            "\(model.userInfo?.playcount.formatted() ?? "-") scrobbles",
            symbol: "headphones",
            color: .accentColor
        )
        profileBadge(
            accountAgeText,
            symbol: "calendar",
            color: .secondary
        )
    }

    @ViewBuilder
    private var registeredSummary: some View {
        if let registered = model.userInfo?.registered {
            VStack(alignment: .leading, spacing: 3) {
                Text("Scrobbling since")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(registered.formatted(.dateTime.year().month(.abbreviated).day()))
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: Period

    private var periodControl: some View {
        ViewThatFits(in: .horizontal) {
            periodPicker
            periodMenu
        }
    }

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(StatsPeriod.allCases) { p in
                Text(p.title).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    private var periodMenu: some View {
        Menu {
            ForEach(StatsPeriod.allCases) { p in
                Button {
                    period = p
                } label: {
                    if p == period {
                        Label(p.title, systemImage: "checkmark")
                    } else {
                        Text(p.title)
                    }
                }
            }
        } label: {
            Label(period.title, systemImage: "calendar")
        }
        .menuStyle(.borderlessButton)
    }

    // MARK: Charts

    private var artistChartItems: [PlayChartItem] {
        model.topArtists.prefix(8).map {
            PlayChartItem(id: $0.id, label: chartLabel($0.name), playcount: $0.playcount)
        }
    }

    private var trackChartItems: [PlayChartItem] {
        model.topTracks.prefix(8).map {
            PlayChartItem(id: $0.id, label: chartLabel("\($0.name) - \($0.artist)"), playcount: $0.playcount)
        }
    }

    private func playChart(items: [PlayChartItem], tint: Color) -> some View {
        Chart(items) { item in
            BarMark(
                x: .value("Plays", max(item.playcount, 1)),
                y: .value("Name", item.label)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .foregroundStyle(
                LinearGradient(
                    colors: [tint.opacity(0.9), tint.opacity(0.45)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .annotation(position: .trailing, alignment: .leading) {
                Text(item.playcount.formatted())
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading) {
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .chartXScale(domain: chartDomain(for: items))
        .frame(height: CGFloat(max(items.count, 1)) * 28 + 8)
    }

    private func chartDomain(for items: [PlayChartItem]) -> ClosedRange<Int> {
        let maxPlay = items.map(\.playcount).max() ?? 1
        let padding = max(1, maxPlay / 5)
        return 0...max(maxPlay + padding, 1)
    }

    private func chartLabel(_ text: String) -> String {
        text.count > 24 ? "\(text.prefix(21))..." : text
    }

    // MARK: Building blocks

    private var loadingPanel: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading statistics")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }

    private func errorBanner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.callout)
            .foregroundStyle(.red)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func panel<Content: View>(
        title: String,
        subtitle: String,
        symbol: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: symbol)
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary, lineWidth: 1)
        }
    }

    private func profileBadge(_ text: String, symbol: String, color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.caption.weight(.medium))
            .lineLimit(1)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func recentRow(_ track: LastfmRecentTrack) -> some View {
        HStack(spacing: 12) {
            avatar(url: track.imageURL, size: 38, fallback: "music.note")
            VStack(alignment: .leading, spacing: 2) {
                Text(track.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(track.artist)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            if track.nowPlaying {
                Label("Now playing", systemImage: "waveform")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.green)
                    .help("Now playing")
            } else if let date = track.date {
                Text(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                    .foregroundStyle(.tertiary)
                    .font(.caption)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 7)
    }

    private func emptyState(_ text: String, symbol: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tertiary)
            Text(text)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func avatar(url: URL?, size: CGFloat, fallback: String) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Image(systemName: fallback)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.22)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: min(size * 0.18, 8), style: .continuous))
    }
}
