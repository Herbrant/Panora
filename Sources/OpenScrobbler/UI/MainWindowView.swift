import SwiftUI

struct MainWindowView: View {
    private enum Section: String, CaseIterable, Identifiable {
        case history
        case settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .history: return "Cronologia"
            case .settings: return "Impostazioni"
            }
        }
        var icon: String {
            switch self {
            case .history: return "clock.arrow.circlepath"
            case .settings: return "gearshape"
            }
        }
    }

    @State private var selection: Section? = .history

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            switch selection ?? .history {
            case .history: HistoryView()
            case .settings: SettingsView()
            }
        }
        .frame(minWidth: 640, minHeight: 420)
    }
}
