import SwiftUI

struct SidebarView: View {
    @Binding var selection: Panel
    @Environment(AppState.self) private var appState

    private let general: [Panel] = [.chat, .overview]
    private let management: [Panel] = [.sessions, .agents, .skills, .nodes]
    private let connectivity: [Panel] = [.channels, .cronJobs]
    private let system: [Panel] = [.config, .debug, .logs]

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                // App header
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 26))
                            .foregroundStyle(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .shadow(radius: 2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("OpenClaw")
                                    .font(.headline)
                                Circle()
                                    .fill(gatewayStatusColor)
                                    .frame(width: 8, height: 8)
                                    .shadow(color: gatewayStatusColor.opacity(0.5), radius: 2)
                            }
                            Text("控制面板")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                Section("通用") {
                    panelList(general, color: .blue)
                }
                Section("管理") {
                    panelList(management, color: .purple)
                }
                Section("连接") {
                    panelList(connectivity, color: .orange)
                }
                Section("系统") {
                    panelList(system, color: .gray)
                }
            }
            .listStyle(.sidebar)
            
            // Footer with Version
            HStack {
                Text("v1.0.0") // Ideally fetch from Bundle
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }

    private var gatewayStatusColor: Color {
        switch appState.gatewayStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .red
        }
    }

    @ViewBuilder
    private func panelList(_ panels: [Panel], color: Color) -> some View {
        ForEach(panels) { panel in
            NavigationLink(value: panel) {
                HStack(spacing: 10) {
                    Image(systemName: panel.icon)
                        .font(.system(size: 14))
                        .foregroundColor(selection == panel ? .white : color)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 0) {
                        Text(panel.titleZH)
                            .font(.system(size: 13, weight: selection == panel ? .semibold : .regular))
                        Text(panel.titleEN)
                            .font(.system(size: 10))
                            .foregroundStyle(selection == panel ? Color.white.opacity(0.8) : Color.secondary.opacity(0.5))
                    }
                }
                .padding(.vertical, 2)
            }
            .tag(panel)
        }
    }
}
