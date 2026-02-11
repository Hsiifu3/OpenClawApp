import SwiftUI

struct LogsView: View {
    @Environment(AppState.self) private var appState

    @State private var logLines: [String] = []
    @State private var cursor: Int?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var autoRefresh = true
    @State private var refreshTask: Task<Void, Never>?
    @State private var searchText = ""
    @State private var levelFilter: LogLevel = .all

    enum LogLevel: String, CaseIterable {
        case all = "全部"
        case error = "Error"
        case warn = "Warn"
        case info = "Info"
    }

    private var filteredLines: [String] {
        logLines.filter { line in
            let matchesLevel: Bool
            switch levelFilter {
            case .all: matchesLevel = true
            case .error: matchesLevel = line.contains("ERROR") || line.contains("error")
            case .warn: matchesLevel = line.contains("WARN") || line.contains("warn")
            case .info: matchesLevel = !line.contains("ERROR") && !line.contains("error") && !line.contains("WARN") && !line.contains("warn") && !line.contains("DEBUG") && !line.contains("debug")
            }
            let matchesSearch = searchText.isEmpty || line.localizedCaseInsensitiveContains(searchText)
            return matchesLevel && matchesSearch
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack(spacing: 10) {
                Label("日志", systemImage: "doc.text")
                    .font(.system(size: 13, weight: .medium))

                // 搜索框
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    TextField("搜索日志...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(6)
                .frame(maxWidth: 200)

                // 级别过滤
                Picker("", selection: $levelFilter) {
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 220)

                Spacer()

                Text("\(filteredLines.count)/\(logLines.count) 行")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                Toggle("自动刷新", isOn: $autoRefresh)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .onChange(of: autoRefresh) { _, newValue in
                        if newValue { startAutoRefresh() } else { stopAutoRefresh() }
                    }

                Button {
                    logLines = []
                    cursor = nil
                    Task { await loadData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    logLines = []
                    cursor = nil
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("清空日志缓存")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            Divider()

            // 日志内容
            if isLoading && logLines.isEmpty {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage, logLines.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32)).foregroundStyle(.secondary)
                    Text(error).foregroundStyle(.secondary).font(.caption)
                    Button("重试") { Task { await loadData() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(Array(filteredLines.enumerated()), id: \.offset) { idx, line in
                                logRow(line)
                                    .id(idx)
                            }
                        }
                        .padding(12)
                    }
                    .onChange(of: filteredLines.count) { _, _ in
                        if autoRefresh, let last = filteredLines.indices.last {
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(.background)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            await loadData()
            if autoRefresh { startAutoRefresh() }
        }
        .onDisappear { stopAutoRefresh() }
    }

    private func logRow(_ line: String) -> some View {
        Text(highlightedLine(line))
            .font(.system(size: 11, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func highlightedLine(_ line: String) -> AttributedString {
        var attr = AttributedString(line)
        attr.foregroundColor = logColor(line)

        // 高亮搜索词
        if !searchText.isEmpty, let range = attr.range(of: searchText, options: .caseInsensitive) {
            attr[range].backgroundColor = .yellow.opacity(0.3)
            attr[range].foregroundColor = .primary
        }
        return attr
    }

    private func logColor(_ line: String) -> Color {
        if line.contains("ERROR") || line.contains("error") { return .red }
        if line.contains("WARN") || line.contains("warn") { return .orange }
        if line.contains("DEBUG") || line.contains("debug") { return .secondary }
        return .primary
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                if !Task.isCancelled { await loadData() }
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    private struct LogsParams: Encodable {
        let limit: Int
        var cursor: Int?
    }

    private func loadData() async {
        if logLines.isEmpty { isLoading = true }
        errorMessage = nil
        guard await appState.gateway.waitForConnection() else {
            isLoading = false; errorMessage = "无法连接到 Gateway"; return
        }
        do {
            let params = LogsParams(limit: 200, cursor: cursor)
            let resp: LogsTailResponse = try await appState.gateway.request("logs.tail", params: params)
            if let newLines = resp.lines, !newLines.isEmpty {
                if resp.reset == true { logLines = newLines }
                else { logLines.append(contentsOf: newLines) }
            }
            if let c = resp.cursor { cursor = c }
            isLoading = false
        } catch {
            isLoading = false; errorMessage = error.localizedDescription
        }
    }
}
