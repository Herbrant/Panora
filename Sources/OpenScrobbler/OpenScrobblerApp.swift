import SwiftData
import SwiftUI

@main
struct OpenScrobblerApp: App {
    private let container: ModelContainer
    @State private var appState: AppState

    init() {
        let container = try! ModelContainer(for: ScrobbleEntry.self)
        self.container = container
        _appState = State(initialValue: AppState(context: container.mainContext))
    }

    var body: some Scene {
        Window("Open Scrobbler", id: "main") {
            MainWindowView()
                .environment(appState)
                .task { appState.start() }
        }
        .modelContainer(container)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
        } label: {
            Image(systemName: "music.note")
        }
        .menuBarExtraStyle(.window)
    }
}
