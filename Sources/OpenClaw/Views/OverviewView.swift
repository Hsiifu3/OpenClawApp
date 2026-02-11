import SwiftUI

struct OverviewView: View {
    @Environment(AppState.self) private var appState

    @State private var status: StatusResponse?
    @State private var health: HealthResponse?
    @State private var sessions: [SessionInfo] = []
    @State private var models: [ModelInfo] = []
    @State private var cronStatus: CronStatusResponse?
    @State private var nodes: [NodeInfo] = []
    @State private var channelOrder: [String] = []
    @State private var channelAccounts: [String: [ChannelsStatusResponse.ChannelAccount]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isPulsing = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("概览")
                            .font(.largeTitle.bold())
                        Text("OpenClaw 控制面板")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if !isLoading {
                        StatusBadge(text: statusText, color: statusColor)
                    }
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
                    ProgressView("连接中...")
                        .frame(maxWidth: .infinity)
                        .padding(40)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        Text(error)
                            .foregroundStyle(.secondary)
                        Button("重试") { Task { await loadData() } }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        // Gateway 状态（特殊卡片）
                        gatewayStatusCard

                        // 活跃会话
                        StatCard(
                            title: "活跃会话",
                            value: "\(sessions.count)",
                            subtext: sessions.first.map { "最近: \($0.label ?? $0.key ?? "-")" },
                            icon: "bubble.left.and.bubble.right.fill",
                            color: .blue
                        )

                        // 可用模型
                        StatCard(
                            title: "可用模型",
                            value: "\(models.count)",
                            subtext: models.first.map { "默认: \($0.displayName ?? $0.model ?? "-")" },
                            icon: "cpu.fill",
                            color: .purple
                        )

                        // 定时任务
                        StatCard(
                            title: "定时任务",
                            value: "\(cronStatus?.jobCount ?? 0)",
                            subtext: cronStatus?.running == true ? "调度器运行中" : "调度器已停止",
                            icon: "clock.arrow.2.circlepath",
                            color: .orange
                        )

                        // 通道状态
                        channelsStatCard

                        // 节点状态
                        let connectedNodeCount = nodes.filter { $0.connected == true }.count
                        StatCard(
                            title: "节点状态",
                            value: "\(connectedNodeCount)/\(nodes.count)",
                            subtext: "\(connectedNodeCount) 个在线",
                            icon: "network",
                            color: .green
                        )

                        // 系统信息（特殊卡片）
                        systemInfoCard
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            await loadData()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }

    // MARK: - 特殊卡片

    private var gatewayStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Gateway")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(statusText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(isPulsing && appState.gatewayStatus == .connecting ? 0.3 : 0.1))
                        .frame(width: 32, height: 32)
                        .scaleEffect(isPulsing && appState.gatewayStatus == .connecting ? 1.2 : 1.0)

                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)
                }
            }

            Divider()

            VStack(spacing: 8) {
                if let v = health?.version ?? status?.version {
                    InfoRow(label: "版本", value: v)
                }
                if let uptime = health?.uptimeMs ?? health?.uptime.map({ $0 * 1000 }) ?? status?.uptimeMs {
                    InfoRow(label: "运行时间", value: formatUptime(uptime))
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    private var channelsStatCard: some View {
        let connectedChannels = channelOrder.filter { ch in
            (channelAccounts[ch] ?? []).contains { $0.connected == true }
        }.count
        let totalAccounts = channelAccounts.values.flatMap { $0 }.count

        return StatCard(
            title: "通道状态",
            value: "\(connectedChannels)/\(channelOrder.count)",
            subtext: "\(totalAccounts) 个账号",
            icon: "antenna.radiowaves.left.and.right",
            color: .teal
        )
    }

    private var systemInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("系统环境")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(status?.platform?.capitalized ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                Spacer()
                Image(systemName: "desktopcomputer")
                    .font(.title2)
                    .foregroundColor(.gray)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(Circle())
            }

            Divider()

            if let nodeVer = status?.nodeVersion {
                InfoRow(label: "Node.js", value: nodeVer)
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private var statusColor: Color {
        switch appState.gatewayStatus {
        case .connected: return .green
        case .connecting: return .yellow
        case .disconnected: return .red
        }
    }

    private var statusText: String {
        switch appState.gatewayStatus {
        case .connected: return "已连接"
        case .connecting: return "连接中..."
        case .disconnected: return "未连接"
        }
    }

    private func formatUptime(_ ms: Double) -> String {
        let totalSeconds = Int(ms / 1000)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60
        if days > 0 {
            return "\(days)天 \(hours)小时"
        } else if hours > 0 {
            return "\(hours)小时 \(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil

        if appState.gatewayStatus != .connected {
            for _ in 0..<20 {
                try? await Task.sleep(for: .milliseconds(500))
                if appState.gatewayStatus == .connected { break }
            }
            if appState.gatewayStatus != .connected {
                isLoading = false
                errorMessage = "无法连接到 Gateway"
                return
            }
        }

        do {
            let gateway = appState.gateway
            async let statusReq: StatusResponse = gateway.request("status")
            async let healthReq: HealthResponse = gateway.request("health")
            async let sessionsReq: SessionsListResponse = gateway.request("sessions.list", params: ["activeMinutes": 120])
            async let modelsReq: ModelsListResponse = gateway.request("models.list")
            async let cronReq: CronStatusResponse = gateway.request("cron.status")
            async let nodesReq: NodeListResponse = gateway.request("node.list")
            async let channelsReq: ChannelsStatusResponse = gateway.request("channels.status")

            let (s, h, sess, m, c, n, ch) = try await (statusReq, healthReq, sessionsReq, modelsReq, cronReq, nodesReq, channelsReq)
            status = s
            health = h
            sessions = sess.sessions ?? []
            models = m.models ?? []
            cronStatus = c
            nodes = n.nodes ?? []
            channelOrder = ch.channelOrder ?? []
            channelAccounts = ch.channelAccounts ?? [:]
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "加载失败: \(error.localizedDescription)"
        }
    }
}
