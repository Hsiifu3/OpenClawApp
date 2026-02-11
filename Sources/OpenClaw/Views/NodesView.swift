import SwiftUI

struct NodesView: View {
    @Environment(AppState.self) private var appState

    @State private var nodes: [NodeInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ScrollView {
            if isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity).padding(.top, 100)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32)).foregroundStyle(.secondary)
                    Text(error).foregroundStyle(.secondary).font(.caption)
                    Button("重试") { Task { await loadData() } }
                }
                .frame(maxWidth: .infinity).padding(.top, 100)
            } else if nodes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "desktopcomputer.trianglebadge.exclamationmark")
                        .font(.system(size: 40)).foregroundStyle(.quaternary)
                    Text("暂无已配对的节点").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(nodes, id: \.stableId) { node in
                        nodeCard(node)
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .task { await loadData() }
    }

    private func nodeCard(_ node: NodeInfo) -> some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(node.connected == true ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(node.displayName ?? node.name ?? node.id ?? "未知")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                }
                if let platform = node.platform {
                    HStack(spacing: 4) {
                        Image(systemName: platformIcon(platform))
                            .font(.system(size: 10))
                        Text(platform)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                }
                if let caps = node.capabilities, !caps.isEmpty {
                    Text(caps.joined(separator: " · "))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                if let ts = node.lastSeenAtMs ?? node.lastSeenAt {
                    Text(relativeTime(ts))
                        .font(.system(size: 10))
                        .foregroundStyle(.quaternary)
                }
            }
        } label: {
            Label(node.name ?? "节点", systemImage: "desktopcomputer")
                .font(.system(size: 12, weight: .medium))
        }
        .backgroundStyle(.regularMaterial)
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
