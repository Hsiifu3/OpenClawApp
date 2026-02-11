import SwiftUI

struct SessionsView: View {
    @Environment(AppState.self) private var appState

    @State private var sessions: [SessionInfo] = []
    @State private var selectedKey: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatLoading = false
    @State private var showDeleteConfirm = false

    var body: some View {
        HSplitView {
            // 列表
            VStack(spacing: 0) {
                // 工具栏
                HStack {
                    Text("\(sessions.count) 个会话")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await loadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.regularMaterial)

                Divider()

                if isLoading {
                    ProgressView("加载中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text(error).foregroundStyle(.secondary).font(.caption)
                        Button("重试") { Task { await loadData() } }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(sessions, selection: $selectedKey) { session in
                        sessionRow(session)
                            .tag(session.key ?? session.id)
                            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                            .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .background(Color(nsColor: .controlBackgroundColor))
                }
            }
            .frame(minWidth: 280, idealWidth: 320)

            // 详情
            if let key = selectedKey, let session = sessions.first(where: { ($0.key ?? $0.id) == key }) {
                sessionDetail(session)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundStyle(.quaternary)
                    Text("选择一个会话查看详情")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
            }
        }
        .task { await loadData() }
        .onChange(of: selectedKey) { _, newKey in
            chatMessages = []
            if let key = newKey {
                Task { await loadChatHistory(key) }
            }
        }
    }

    private func sessionRow(_ session: SessionInfo) -> some View {
        let isActive = (Date().timeIntervalSince1970 * 1000 - (session.lastActiveAtMs ?? session.lastActiveAt ?? 0)) < 30 * 60 * 1000
        let accentColor: Color = isActive ? .green : .gray

        return HStack(spacing: 0) {
            Rectangle()
                .fill(accentColor)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(session.label ?? session.key ?? "未知")
                        .font(.system(size: 14, weight: .medium))
                        .lineLimit(1)
                    Spacer()
                    if let ts = session.lastActiveAtMs ?? session.lastActiveAt {
                        Text(relativeTime(ts))
                            .font(.caption2)
                            .foregroundStyle(isActive ? .primary : .secondary)
                    }
                }

                HStack(spacing: 12) {
                    if let agent = session.agentId {
                        Label(agent, systemImage: "person")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let model = session.model {
                        Label(model, systemImage: "cpu")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .background(selectedKey == (session.key ?? session.id) ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }

    private func sessionDetail(_ s: SessionInfo) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.label ?? s.key ?? "会话详情")
                            .font(.title2.bold())
                        Text(s.key ?? "")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    StatusBadge(text: s.kind?.capitalized ?? "Chat", color: .blue)

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("删除会话")
                    .alert("确认删除", isPresented: $showDeleteConfirm) {
                        Button("取消", role: .cancel) {}
                        Button("删除", role: .destructive) {
                            Task { await deleteSession(s) }
                        }
                    } message: {
                        Text("确定要删除会话 \"\(s.label ?? s.key ?? "")\" 吗？")
                    }
                }

                // Info Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    detailCard(title: "代理", value: s.agentId ?? "-", icon: "person.fill", color: .purple)
                    detailCard(title: "模型", value: s.model ?? "-", icon: "cpu", color: .orange)
                    detailCard(title: "总 Tokens", value: s.totalTokens.map { formatNumber($0) } ?? "-", icon: "text.quote", color: .gray)
                    detailCard(title: "上下文", value: s.contextTokens.map { formatNumber($0) } ?? "-", icon: "memorychip", color: .blue)
                }

                // 时间信息
                VStack(alignment: .leading, spacing: 12) {
                    Text("时间信息")
                        .font(.headline)

                    VStack(spacing: 0) {
                        if let ts = s.lastActiveAtMs ?? s.lastActiveAt {
                            InfoRow(label: "最后活跃", value: relativeTime(ts) + " (" + formatDate(ts) + ")")
                            Divider().padding(.vertical, 8)
                        }
                        if let ts = s.createdAtMs ?? s.createdAt {
                            InfoRow(label: "创建时间", value: formatDate(ts))
                        }
                    }
                    .padding(16)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                }

                // 聊天历史
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("消息历史")
                            .font(.headline)
                        Spacer()
                        if chatLoading {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Text("\(chatMessages.count) 条消息")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if chatMessages.isEmpty && !chatLoading {
                        Text("暂无消息记录")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(20)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(12)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(chatMessages, id: \.stableId) { msg in
                                chatBubble(msg)
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Chat Bubble

    private func chatBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == "user"
        let text = msg.content?.textValue ?? ""

        return HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if !isUser {
                        Image(systemName: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.purple)
                    }
                    Text(isUser ? "用户" : "助手")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let ts = msg.timestamp {
                        Text(formatTime(ts))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Text(text)
                    .font(.system(size: 13))
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isUser ? Color.blue.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                    )
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }

    // MARK: - Detail Card

    private func detailCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    private func formatNumber(_ n: Int) -> String {
        if n >= 1_000_000 { return String(format: "%.1fM", Double(n) / 1_000_000) }
        if n >= 1_000 { return String(format: "%.1fK", Double(n) / 1_000) }
        return "\(n)"
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

    private func formatDate(_ ms: Double) -> String {
        let date = Date(timeIntervalSince1970: ms / 1000)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.string(from: date)
    }

    private func formatTime(_ ms: Double) -> String {
        let date = Date(timeIntervalSince1970: ms / 1000)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    // MARK: - Data Loading

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        guard await appState.gateway.waitForConnection() else {
            isLoading = false; errorMessage = "无法连接到 Gateway"; return
        }
        do {
            let resp: SessionsListResponse = try await appState.gateway.request("sessions.list", params: ["activeMinutes": 120])
            sessions = (resp.sessions ?? []).sorted { ($0.lastActiveAtMs ?? $0.lastActiveAt ?? 0) > ($1.lastActiveAtMs ?? $1.lastActiveAt ?? 0) }
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    private struct ChatHistoryParams: Encodable {
        let sessionKey: String
        let limit: Int
    }

    private func loadChatHistory(_ sessionKey: String) async {
        chatLoading = true
        do {
            let resp: ChatHistoryResponse = try await appState.gateway.request("chat.history", params: ChatHistoryParams(sessionKey: sessionKey, limit: 50))
            chatMessages = resp.messages ?? []
        } catch {
            // 静默处理聊天历史加载失败
            chatMessages = []
        }
        chatLoading = false
    }

    private func deleteSession(_ session: SessionInfo) async {
        guard let key = session.key else { return }
        do {
            let _: EmptyResponse = try await appState.gateway.request("sessions.delete", params: ["key": key])
            selectedKey = nil
            await loadData()
        } catch {
            // 静默处理
        }
    }
}
