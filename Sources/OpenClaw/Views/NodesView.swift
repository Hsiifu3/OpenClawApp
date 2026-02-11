import SwiftUI

struct NodesView: View {
    @Environment(AppState.self) private var appState

    @State private var nodes: [NodeInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.adaptive(minimum: 260), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("节点管理")
                            .font(.largeTitle.bold())
                        let connectedCount = nodes.filter { $0.connected == true }.count
                        Text("\(connectedCount)/\(nodes.count) 个节点在线")
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
                } else if nodes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "desktopcomputer.trianglebadge.exclamationmark")
                            .font(.system(size: 40)).foregroundStyle(.quaternary)
                        Text("暂无已配对的节点").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(nodes, id: \.stableId) { node in
                            nodeCard(node)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { await loadData() }
    }

    private func nodeCard(_ node: NodeInfo) -> some View {
        let isOnline = node.connected == true
        let statusColor: Color = isOnline ? .green : .gray

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: platformIcon(node.platform ?? ""))
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .frame(width: 36, height: 36)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(node.displayName ?? node.name ?? node.id ?? "未知")
                            .font(.headline)
                            .lineLimit(1)
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                    }
                    if let platform = node.platform {
                        Text(platform)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            Divider()

            VStack(spacing: 6) {
                if let caps = node.capabilities, !caps.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "cpu")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(caps.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                if let ts = node.lastSeenAtMs ?? node.lastSeenAt {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text("最后在线: \(relativeTime(ts))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(statusColor.opacity(0.2), lineWidth: 1)
        )
    }

    private func platformIcon(_ p: String) -> String {
        let l = p.lowercased()
        if l.contains("darwin") || l.contains("mac") { return "laptopcomputer" }
        if l.contains("win") { return "pc" }
        if l.contains("linux") { return "server.rack" }
        if l.contains("android") { return "candybarphone" }
        if l.contains("ios") { return "iphone" }
        return "desktopcomputer"
    }

    private func relativeTime(_ ms: Double) -> String {
        let seconds = Int((Date().timeIntervalSince1970 * 1000 - ms) / 1000)
        if seconds < 60 { return "刚刚" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)分钟前" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours)小时前" }
        return "\(hours / 24)天前"
    }

    private func loadData() async {
        isLoading = true; errorMessage = nil
        guard await appState.gateway.waitForConnection() else {
            isLoading = false; errorMessage = "无法连接到 Gateway"; return
        }
        do {
            let resp: NodeListResponse = try await appState.gateway.request("node.list")
            nodes = resp.nodes ?? []
            isLoading = false
        } catch {
            isLoading = false; errorMessage = error.localizedDescription
        }
    }
}
