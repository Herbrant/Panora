import SwiftUI

struct MainWindowView: View {
    @Environment(AppState.self) private var appState

    private enum Section: String, CaseIterable, Identifiable {
        case history
        case statistics
        case settings
        var id: String { rawValue }
        var title: String {
            switch self {
            case .history: return "History"
            case .statistics: return "Statistics"
            case .settings: return "Settings"
            }
        }
        var icon: String {
            switch self {
            case .history: return "clock.arrow.circlepath"
            case .statistics: return "chart.bar.fill"
            case .settings: return "gearshape"
            }
        }
    }

    @State private var selection: Section? = .history

    var body: some View {
        if appState.session == nil {
            OnboardingView()
        } else if !appState.hasCompletedSourceSetup {
            AppSourceSetupView()
        } else {
            splitView
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
        } detail: {
            switch selection ?? .history {
            case .history: HistoryView()
            case .statistics: StatisticsView()
            case .settings: SettingsView()
            }
        }
        .frame(minWidth: 640, minHeight: 420)
    }
}

