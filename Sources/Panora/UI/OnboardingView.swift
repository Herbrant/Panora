import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)
                .panoraArrowCursor()

            VStack(spacing: 8) {
                Text("Panora")
                    .font(.largeTitle.weight(.semibold))
                Text("Sign in to your Last.fm account to start scrobbling.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if appState.isAuthorizing {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("Waiting for browser authorization...")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    Button("I've completed sign-in") {
                        appState.completeLogin()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                Button("Sign in with Last.fm") {
                    appState.beginLogin()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!appState.isConfigured)
            }

            if let error = appState.authError {
                Text(error)
                    .foregroundStyle(.red)
                    .font(.callout)
                    .multilineTextAlignment(.center)
            }

            if !appState.isConfigured {
                Text("Last.fm API key/secret not configured. Set LASTFM_API_KEY and LASTFM_API_SECRET.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(40)
        .frame(width: 480, height: 340)
        .accessibilityIdentifier("panora.onboarding.content")
    }
}
