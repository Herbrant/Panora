import SwiftData
import SwiftUI

@main
struct PanoraApp: App {
    private let container: ModelContainer
    @State private var appState: AppState

    init() {
        let container = try! ModelContainer(for: ScrobbleEntry.self)
        self.container = container
        _appState = State(initialValue: AppState(context: container.mainContext))
    }

    var body: some Scene {
        Window("Panora", id: "main") {
            MainWindowView()
                .environment(appState)
                .task { appState.start() }
                .onOpenURL { appState.handleCallback(url: $0) }
        }
        .modelContainer(container)
        .windowResizability(.contentSize)

        MenuBarExtra {
            MenuBarView()
                .environment(appState)
                .onOpenURL { appState.handleCallback(url: $0) }
        } label: {
            Image(systemName: "music.note")
        }
        .menuBarExtraStyle(.window)
    }
}
