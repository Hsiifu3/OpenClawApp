import SwiftUI

struct ChannelsView: View {
    @Environment(AppState.self) private var appState

    @State private var channelOrder: [String] = []
    @State private var channelAccounts: [String: [ChannelsStatusResponse.ChannelAccount]] = [:]
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let columns = [
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
            } else if channelOrder.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 40)).foregroundStyle(.quaternary)
                    Text("暂无已配置的通道").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.top, 100)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(channelOrder, id: \.self) { channel in
                        channelCard(channel)
                    }
                }
                .padding(20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.background)
        .task { await loadData() }
    }

    private func channelCard(_ channel: String) -> some View {
        let accounts = channelAccounts[channel] ?? []
        let anyConnected = accounts.contains { $0.connected == true }
        return GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(anyConnected ? Color.green : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(channel.capitalized)
                        .font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("\(accounts.count) 账号")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

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
        } label: {
            Label(channel.capitalized, systemImage: iconForChannel(channel))
                .font(.system(size: 12, weight: .medium))
        }
        .backgroundStyle(.regularMaterial)
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
