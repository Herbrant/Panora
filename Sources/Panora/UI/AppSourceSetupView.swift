// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// One-time setup asking whether to scrobble from all apps or a chosen subset.
struct AppSourceSetupView: View {
    @Environment(AppState.self) private var appState
    @State private var phase: Phase = .choice
    @State private var selectedApps: Set<String> = []
    @State private var pendingSelective: Bool = false
    @State private var pendingSelectedApps: Set<String> = []

    private enum Phase {
        case choice
        case selecting
        case launchAtLogin
    }

    var body: some View {
        switch phase {
        case .choice:
            choiceView
        case .selecting:
            selectingView
        case .launchAtLogin:
            launchAtLoginView
        }
    }

    private var choiceView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .panoraArrowCursor()

            VStack(spacing: 8) {
                Text("Which apps do you want to scrobble?")
                    .font(.largeTitle.weight(.semibold))
                Text("You can change this setting anytime from Settings.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button("All apps") {
                    pendingSelective = false
                    phase = .launchAtLogin
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Choose apps") {
                    phase = .selecting
                }
                .controlSize(.large)
            }

            Spacer()
        }
        .padding(40)
        .frame(width: 480, height: 380)
        .accessibilityIdentifier("panora.sourceSetup.content")
    }

    private var selectingView: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accentColor)
                    .panoraArrowCursor()

                Text("Select apps to scrobble")
                    .font(.title2.weight(.semibold))
            }
            .padding(.top, 24)

            if appState.knownApps.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("No music apps found on your system.")
                        .foregroundStyle(.secondary)
                    Text("You can configure apps later from Settings.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(appState.knownApps.sorted(by: { $0.value < $1.value }), id: \.key) { id, name in
                            Toggle(isOn: Binding(
                                get: { selectedApps.contains(id) },
                                set: { on in
                                    if on { selectedApps.insert(id) }
                                    else { selectedApps.remove(id) }
                                }
                            )) {
                                HStack(spacing: 10) {
                                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                                        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                            .resizable()
                                            .frame(width: 24, height: 24)
                                    }
                                    Text(name)
                                }
                            }
                            .toggleStyle(.switch)
                            .padding(.horizontal, 8)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(minHeight: 200)
            }

            Button("Confirm") {
                pendingSelectedApps = selectedApps
                pendingSelective = true
                phase = .launchAtLogin
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 40)
        .frame(width: 480, height: 460)
        .accessibilityIdentifier("panora.sourceSetup.selecting")
    }

    private var launchAtLoginView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.up.circle")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .panoraArrowCursor()

            VStack(spacing: 8) {
                Text("Launch Panora at login?")
                    .font(.largeTitle.weight(.semibold))
                Text("You can change this anytime from Settings.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button("Enable") {
                    finishSetup(launchAtLogin: true)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Not now") {
                    finishSetup(launchAtLogin: false)
                }
                .controlSize(.large)
            }

            Spacer()
        }
        .padding(40)
        .frame(width: 480, height: 380)
        .accessibilityIdentifier("panora.sourceSetup.launchAtLogin")
    }

    private func finishSetup(launchAtLogin: Bool) {
        appState.setLaunchAtLogin(launchAtLogin)
        if pendingSelective {
            appState.setupSelectiveApps(pendingSelectedApps)
        } else {
            appState.completeSourceSetup(selective: false)
        }
    }
}
