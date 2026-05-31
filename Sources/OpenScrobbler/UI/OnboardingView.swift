import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Open Scrobbler")
                    .font(.largeTitle.weight(.semibold))
                Text("Accedi al tuo account Last.fm per iniziare a scrobblare.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if appState.isAuthorizing {
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("In attesa di autorizzazione nel browser...")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    }
                    Button("Ho completato l'accesso") {
                        appState.completeLogin()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                Button("Accedi con Last.fm") {
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
                Text("API key/secret di Last.fm non configurati. Imposta LASTFM_API_KEY e LASTFM_API_SECRET.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(40)
        .frame(width: 480, height: 340)
    }
}
