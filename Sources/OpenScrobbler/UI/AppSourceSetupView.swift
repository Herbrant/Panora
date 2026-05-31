import SwiftUI

struct AppSourceSetupView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "music.note.list")
                .font(.system(size: 56))
                .foregroundStyle(Color.accentColor)

            VStack(spacing: 8) {
                Text("Quali app vuoi scrobblare?")
                    .font(.largeTitle.weight(.semibold))
                Text("Puoi cambiare questa impostazione in qualsiasi momento dalle Impostazioni.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Button("Tutte le app") {
                    appState.completeSourceSetup(selective: false)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Scegli le app") {
                    appState.completeSourceSetup(selective: true)
                }
                .controlSize(.large)

                Text("Se scegli la modalità selettiva, potrai configurare le app nelle Impostazioni > Sorgenti man mano che le usi.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(40)
        .frame(width: 480, height: 380)
    }
}
