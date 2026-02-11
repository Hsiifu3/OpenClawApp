import SwiftUI

struct ChannelsView: View {
    @Environment(AppState.self) private var appState

    @State private var channelOrder: [String] = []
    @State private var channelAccounts: [String: [ChannelsStatusResponse.ChannelAccount]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?

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
                        Text("通道管理")
                            .font(.largeTitle.bold())
                        let connectedCount = channelOrder.filter { ch in
                            (channelAccounts[ch] ?? []).contains { $0.connected == true }
                        }.count
                        Text("\(connectedCount)/\(channelOrder.count) 个通道已连接")
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
                } else if channelOrder.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "antenna.radiowaves.left.and.right.slash")
                            .font(.system(size: 40)).foregroundStyle(.quaternary)
                        Text("暂无已配置的通道").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(channelOrder, id: \.self) { channel in
                            channelCard(channel)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { await loadData() }
    }

    private func channelCard(_ channel: String) -> some View {
        let accounts = channelAccounts[channel] ?? []
        let anyConnected = accounts.contains { $0.connected == true }
        let statusColor: Color = anyConnected ? .green : .gray

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: iconForChannel(channel))
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .frame(width: 36, height: 36)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.capitalized)
                        .font(.headline)
                    Text("\(accounts.count) 个账号")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(anyConnected ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }

            Divider()

            ForEach(Array(accounts.enumerated()), id: \.offset) { _, account in
                HStack {
                    Text(account.accountId ?? "默认")
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                    Spacer()
                    if account.connected == true {
                        Label("已连接", systemImage: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                    } else if account.running == true {
                        Label("运行中", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(size: 10))
                            .foregroundStyle(.orange)
                    } else {
                        Label("离线", systemImage: "xmark.circle")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                if let err = account.error, !err.isEmpty {
                    Text(err)
                        .font(.system(size: 10))
                        .foregroundStyle(.red)
                        .lineLimit(2)
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

    private func iconForChannel(_ ch: String) -> String {
        switch ch.lowercased() {
        case "telegram": return "paperplane"
        case "discord": return "gamecontroller"
        case "whatsapp": return "phone.bubble"
        case "slack": return "number"
        case "signal": return "lock.shield"
        case "feishu": return "bird"
        case "bluebubbles", "imessage": return "message"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    private func loadData() async {
        isLoading = true; errorMessage = nil
        guard await appState.gateway.waitForConnection() else {
            isLoading = false; errorMessage = "无法连接到 Gateway"; return
        }
        do {
            let resp: ChannelsStatusResponse = try await appState.gateway.request("channels.status")
            channelOrder = resp.channelOrder ?? []
            channelAccounts = resp.channelAccounts ?? [:]
            isLoading = false
        } catch {
            isLoading = false; errorMessage = error.localizedDescription
        }
    }
}
