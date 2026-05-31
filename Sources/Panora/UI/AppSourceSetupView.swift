import SwiftUI

struct AppSourceSetupView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
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
                    appState.completeSourceSetup(selective: false)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Choose apps") {
                    appState.completeSourceSetup(selective: true)
                }
                .controlSize(.large)

                Text("In selective mode, you can configure apps under Settings > Sources as you use them.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding(40)
        .frame(width: 480, height: 380)
        .accessibilityIdentifier("panora.sourceSetup.content")
    }
}
