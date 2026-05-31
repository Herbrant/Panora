import SwiftUI

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
        .task(id: taskKey) {
            guard let username else { return }
            await model.load(username: username, period: period)
        }
    }

    private var taskKey: String { "\(username ?? "")|\(period.rawValue)" }

    @ViewBuilder
    private func content(username: String) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                profileHeader

                if let error = model.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }

                periodPicker

                if model.isLoading && model.topArtists.isEmpty && model.topTracks.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else {
                    topArtistsSection
                    topTracksSection
                    recentSection
                }
            }
            .padding(20)
        }
    }

    // MARK: Profile

    private var profileHeader: some View {
        HStack(spacing: 16) {
            avatar(url: model.userInfo?.imageURL, size: 64, fallback: "person.crop.circle.fill")
            VStack(alignment: .leading, spacing: 4) {
                Text(model.userInfo?.realName ?? model.userInfo?.name ?? (username ?? ""))
                    .font(.title2).fontWeight(.semibold)
                if let real = model.userInfo?.realName, real != model.userInfo?.name {
                    Text("@\(model.userInfo?.name ?? "")").foregroundStyle(.secondary).font(.subheadline)
                }
                if let count = model.userInfo?.playcount {
                    Text("\(count.formatted()) scrobbles").foregroundStyle(.secondary)
                }
                if let registered = model.userInfo?.registered {
                    Text("Scrobbling since \(registered.formatted(.dateTime.year().month(.abbreviated).day()))")
                        .foregroundStyle(.tertiary).font(.caption)
                }
            }
            Spacer()
        }
    }

    // MARK: Period

    private var periodPicker: some View {
        Picker("Period", selection: $period) {
            ForEach(StatsPeriod.allCases) { p in
                Text(p.title).tag(p)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
    }

    // MARK: Top lists

    private var topArtistsSection: some View {
        section(title: "Top Artists") {
            if model.topArtists.isEmpty {
                emptyRow("No artists for this period.")
            } else {
                ForEach(Array(model.topArtists.enumerated()), id: \.element.id) { index, artist in
                    rankedRow(
                        rank: index + 1,
                        imageURL: artist.imageURL,
                        fallback: "music.mic",
                        title: artist.name,
                        subtitle: nil,
                        playcount: artist.playcount
                    )
                }
            }
        }
    }

    private var topTracksSection: some View {
        section(title: "Top Tracks") {
            if model.topTracks.isEmpty {
                emptyRow("No tracks for this period.")
            } else {
                ForEach(Array(model.topTracks.enumerated()), id: \.element.id) { index, track in
                    rankedRow(
                        rank: index + 1,
                        imageURL: track.imageURL,
                        fallback: "music.note",
                        title: track.name,
                        subtitle: track.artist,
                        playcount: track.playcount
                    )
                }
            }
        }
    }

    private var recentSection: some View {
        section(title: "Recent Activity") {
            if model.recentTracks.isEmpty {
                emptyRow("No recent tracks.")
            } else {
                ForEach(model.recentTracks) { track in
                    HStack(spacing: 12) {
                        avatar(url: track.imageURL, size: 36, fallback: "music.note")
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.name).fontWeight(.medium)
                            Text(track.artist).foregroundStyle(.secondary).font(.subheadline)
                        }
                        Spacer()
                        if track.nowPlaying {
                            Label("Now playing", systemImage: "waveform")
                                .labelStyle(.iconOnly)
                                .foregroundStyle(.green)
                                .help("Now playing")
                        } else if let date = track.date {
                            Text(date.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                .foregroundStyle(.tertiary).font(.caption)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: Building blocks

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            VStack(spacing: 0) { content() }
        }
    }

    private func rankedRow(rank: Int, imageURL: URL?, fallback: String, title: String, subtitle: String?, playcount: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(rank)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 24, alignment: .trailing)
            avatar(url: imageURL, size: 36, fallback: fallback)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).fontWeight(.medium)
                if let subtitle {
                    Text(subtitle).foregroundStyle(.secondary).font(.subheadline)
                }
            }
            Spacer()
            Text("\(playcount.formatted()) plays")
                .foregroundStyle(.tertiary).font(.caption)
        }
        .padding(.vertical, 4)
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .foregroundStyle(.tertiary)
            .font(.callout)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }

    private func avatar(url: URL?, size: CGFloat, fallback: String) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            default:
                Image(systemName: fallback)
                    .resizable().scaledToFit().padding(size * 0.22)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .background(.quaternary)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
    }
}
