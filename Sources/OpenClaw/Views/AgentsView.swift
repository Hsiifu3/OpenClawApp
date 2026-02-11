import SwiftUI

struct AgentsView: View {
    @Environment(AppState.self) private var appState

    @State private var agents: [AgentInfo] = []
    @State private var defaultId: String?
    @State private var identities: [String: AgentIdentity] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 280), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("代理管理")
                            .font(.largeTitle.bold())
                        Text("配置智能体行为与模型")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button {
                        Task { await loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.top, 10)

                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity)
                        .padding(40)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32)).foregroundStyle(.secondary)
                        Text(error).foregroundStyle(.secondary).font(.caption)
                        Button("重试") { Task { await loadData() } }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(agents) { agent in
                            agentCard(agent)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { await loadData() }
    }

    private func agentCard(_ agent: AgentInfo) -> some View {
        let isDefault = agent.id == defaultId
        let identity = identities[agent.id]

        return VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                // Avatar 区域 — 优先使用 identity 的 emoji
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 48, height: 48)
                    if let emoji = identity?.emoji, !emoji.isEmpty {
                        Text(emoji)
                            .font(.system(size: 24))
                    } else {
                        Text(String((agent.name ?? agent.id).prefix(1)).uppercased())
                            .font(.title2.bold())
                            .foregroundColor(.purple)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(identity?.name ?? agent.name ?? agent.id)
                            .font(.headline)
                            .lineLimit(1)
                        if isDefault {
                            Image(systemName: "star.fill")
                                .font(.caption)
                                .foregroundColor(.yellow)
                        }
                    }
                    Text(agent.id)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            Divider()

            // 详情
            VStack(spacing: 8) {
                if let model = agent.model?.primary {
                    HStack {
                        Text("模型")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        StatusBadge(text: model, color: .blue)
                    }
                }

                if let ws = agent.workspace {
                    InfoRow(label: "工作区", value: ws)
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isDefault ? Color.purple.opacity(0.5) : Color.secondary.opacity(0.1), lineWidth: isDefault ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        guard await appState.gateway.waitForConnection() else {
            isLoading = false; errorMessage = "无法连接到 Gateway"; return
        }
        do {
            let resp: AgentsListResponse = try await appState.gateway.request("agents.list")
            agents = resp.agents ?? []
            defaultId = resp.defaultId
            isLoading = false

            // 并行加载每个代理的身份信息
            for agent in agents {
                Task {
                    await loadIdentity(agent.id)
                }
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private func loadIdentity(_ agentId: String) async {
        do {
            let identity: AgentIdentity = try await appState.gateway.request("agent.identity.get", params: ["agentId": agentId])
            identities[agentId] = identity
        } catch {
            // 静默处理 — 身份信息非必需
        }
    }
}
