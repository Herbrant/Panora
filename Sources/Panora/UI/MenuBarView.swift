import SwiftUI

struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            nowPlaying
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 300)
    }

    @ViewBuilder
    private var nowPlaying: some View {
        if let track = appState.current {
            HStack(spacing: 12) {
                artwork(track)
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title).fontWeight(.semibold).lineLimit(1)
                    Text(track.artist).foregroundStyle(.secondary).lineLimit(1)
                    if let album = track.album, !album.isEmpty {
                        Text(album).foregroundStyle(.tertiary).font(.caption).lineLimit(1)
                    }
                    statusLine(track)
                }
            }
        } else {
            HStack(spacing: 10) {
                Image(systemName: "music.note")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Nothing playing")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func artwork(_ track: TrackPlayback) -> some View {
        if let image = track.artwork {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(width: 52, height: 52)
                .overlay(Image(systemName: "music.note").foregroundStyle(.secondary))
        }
    }

    @ViewBuilder
    private func statusLine(_ track: TrackPlayback) -> some View {
        if appState.isCurrentScrobbled {
            Label("Scrobbled", systemImage: "checkmark.circle.fill")
                .font(.caption).foregroundStyle(.green)
        } else if track.isPlaying {
            Label("Now playing", systemImage: "dot.radiowaves.left.and.right")
                .font(.caption).foregroundStyle(.secondary)
        } else {
            Label("Paused", systemImage: "pause.circle")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let session = appState.session {
                Label(session.username, systemImage: "person.crop.circle")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label("Not connected to Last.fm", systemImage: "exclamationmark.circle")
                    .font(.caption).foregroundStyle(.orange)
            }
            HStack {
                Button("Open Panora") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                    DispatchQueue.main.async {
                        if let window = NSApp.windows.first(where: {
                            $0.identifier?.rawValue.hasPrefix("main") == true || $0.title == "Panora"
                        }) {
                            window.makeKeyAndOrderFront(nil)
                            window.orderFrontRegardless()
                        }
                    }
                }
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
        }
    }
}
