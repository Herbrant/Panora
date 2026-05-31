import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("Account Last.fm") {
                if let session = appState.session {
                    LabeledContent("Connesso come", value: session.username)
                    Button("Disconnetti", role: .destructive) { appState.logout() }
                } else if !appState.isConfigured {
                    Label("API key/secret di Last.fm non configurati.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Imposta LASTFM_API_KEY e LASTFM_API_SECRET (vedi README).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Accedi per inviare gli scrobble al tuo account.")
                        .foregroundStyle(.secondary)
                    HStack {
                        Button("1. Apri Last.fm e autorizza") { appState.beginLogin() }
                            .disabled(appState.isAuthorizing)
                        Button("2. Ho autorizzato") { appState.completeLogin() }
                            .buttonStyle(.borderedProminent)
                    }
                    if let error = appState.authError {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }

            Section("Rilevamento") {
                if let track = appState.current {
                    LabeledContent("In riproduzione", value: "\(track.title) — \(track.artist)")
                    if let app = track.appName {
                        LabeledContent("Sorgente", value: app)
                    }
                } else {
                    Text("Nessun brano rilevato al momento.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Impostazioni")
    }
}
