import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState
        NavigationSplitView {
            SidebarView(selection: $state.selectedPanel)
        } detail: {
            Group {
                if appState.selectedPanel.isWeb {
                    WebView(url: WebView.url(for: appState.selectedPanel))
                } else {
                    switch appState.selectedPanel {
                    case .overview:
                        OverviewView()
                    case .sessions:
                        SessionsView()
                    case .agents:
                        AgentsView()
                    case .cronJobs:
                        CronJobsView()
                    case .channels:
                        ChannelsView()
                    case .skills:
                        SkillsView()
                    case .nodes:
                        NodesView()
                    case .config:
                        ConfigView()
                    case .logs:
                        LogsView()
                    default:
                        WebView(url: WebView.url(for: appState.selectedPanel))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationTitle(appState.selectedPanel.titleZH)
        .navigationSplitViewStyle(.balanced)
        .task {
            await appState.gateway.connect()
        }
    }
}
