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
                    if appState.isAuthorizing {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.7)
                            Text("In attesa di autorizzazione nel browser...")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                        Button("Ho completato l'accesso") {
                            appState.completeLogin()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Accedi con Last.fm") { appState.beginLogin() }
                            .buttonStyle(.borderedProminent)
                    }
                    if let error = appState.authError {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }

            Section("Sorgenti") {
                Toggle("Modalità selettiva", isOn: Binding(
                    get: { appState.selectiveScrobblingEnabled },
                    set: { appState.setSelectiveScrobbling($0) }
                ))

                if appState.selectiveScrobblingEnabled {
                    if appState.knownApps.isEmpty {
                        Text("Nessuna app rilevata ancora. Riproduci musica per vedere le sorgenti disponibili.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(appState.knownApps.sorted(by: { $0.value < $1.value }), id: \.key) { id, name in
                            Toggle(name, isOn: Binding(
                                get: { appState.allowedApps.contains(id) },
                                set: { appState.toggleApp(id, enabled: $0) }
                            ))
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Impostazioni")
    }
}
