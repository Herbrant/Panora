// SPDX-License-Identifier: GPL-3.0-or-later

import SwiftUI

/// Root of the main window. Routes to onboarding, source setup, or the
/// History/Statistics/Settings split view depending on auth and setup state.
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
                .accessibilityIdentifier("panora.onboarding")
        } else if !appState.hasCompletedSourceSetup {
            AppSourceSetupView()
                .accessibilityIdentifier("panora.sourceSetup")
        } else {
            splitView
                .accessibilityIdentifier("panora.mainSplitView")
        }
    }

    private var splitView: some View {
        NavigationSplitView {
            List(Section.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.icon)
                    .panoraArrowCursor()
                    .accessibilityIdentifier("panora.sidebar.\(section.rawValue)")
                    .tag(section)
            }
            .accessibilityIdentifier("panora.sidebar")
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
