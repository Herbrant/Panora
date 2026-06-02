// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Settings pane: Last.fm account (sign in/out) and per-app source filtering.
struct SettingsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        Form {
            Section("General") {
                Toggle("Enable scrobbling", isOn: Binding(
                    get: { !appState.scrobblingSuspended },
                    set: { appState.setScrobblingSuspended(!$0) }
                ))

                if appState.scrobblingSuspended {
                    Text("Panora will not send now-playing updates or scrobbles to Last.fm until this is enabled again.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Toggle("Launch at login", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { appState.setLaunchAtLogin($0) }
                ))
            }

            Section("Account Last.fm") {
                if let session = appState.session {
                    LabeledContent("Signed in as", value: session.username)
                    Button("Sign out", role: .destructive) { appState.logout() }
                } else if !appState.isConfigured {
                    Label("Last.fm API key/secret not configured.", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("Set LASTFM_API_KEY and LASTFM_API_SECRET (see README).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Sign in to send scrobbles to your account.")
                        .foregroundStyle(.secondary)
                    if appState.isAuthorizing {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.7)
                            Text("Waiting for browser authorization...")
                                .foregroundStyle(.secondary)
                                .font(.callout)
                        }
                        Button("I've completed sign-in") {
                            appState.completeLogin()
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button("Sign in with Last.fm") { appState.beginLogin() }
                            .buttonStyle(.borderedProminent)
                    }
                    if let error = appState.authError {
                        Text(error).foregroundStyle(.red).font(.caption)
                    }
                }
            }

            Section("Sources") {
                Toggle("Selective mode", isOn: Binding(
                    get: { appState.selectiveScrobblingEnabled },
                    set: { appState.setSelectiveScrobbling($0) }
                ))

                if appState.selectiveScrobblingEnabled {
                    if appState.knownApps.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No music apps found on your system.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Scan for apps") {
                                appState.discoverInstalledMusicApps()
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundStyle(Color.accentColor)
                        }
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
        .navigationTitle("Settings")
        .accessibilityIdentifier("panora.settings")
    }
}
