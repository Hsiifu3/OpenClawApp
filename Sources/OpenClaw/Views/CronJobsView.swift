import SwiftUI

struct CronJobsView: View {
    @Environment(AppState.self) private var appState

    @State private var jobs: [CronJobInfo] = []
    @State private var cronStatus: CronStatusResponse?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var triggeringId: String?
    @State private var expandedJobId: String?
    @State private var jobRuns: [String: [CronRun]] = [:]
    @State private var runsLoading: String?

    // 倒计时定时器
    @State private var now = Date()
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("定时任务")
                            .font(.largeTitle.bold())
                        Text("自动化任务调度与管理")
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
                    VStack(spacing: 16) {
                        // 状态卡片
                        if let status = cronStatus {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("调度器状态")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    HStack {
                                        Circle()
                                            .fill(status.running == true ? Color.green : Color.red)
                                            .frame(width: 8, height: 8)
                                        Text(status.running == true ? "运行中" : "已停止")
                                            .font(.headline)
                                    }
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("任务总数")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(status.jobCount ?? 0)")
                                        .font(.headline)
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

                        // 任务列表
                        ForEach(jobs) { job in
                            jobCard(job)
                        }

                        if jobs.isEmpty {
                            Text("暂无定时任务")
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onReceive(timer) { input in
            now = input
        }
        .task { await loadData() }
    }

    private func jobCard(_ job: CronJobInfo) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                // 启用/禁用指示
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(job.enabled == true ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 32, height: 18)

                    Circle()
                        .fill(.white)
                        .frame(width: 14, height: 14)
                        .offset(x: job.enabled == true ? 7 : -7)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text(job.name ?? job.id)
                        .font(.headline)
                    if let desc = job.description {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button {
                    Task { await triggerJob(job) }
                } label: {
                    if triggeringId == job.id {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "play.fill")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(triggeringId != nil)
                .help("手动触发")
            }

            Divider()

            // 信息网格
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                    Text(scheduleText(job))
                        .font(.caption.monospaced())
                }

                if let state = job.state, let next = state.nextRunAtMs {
                    HStack {
                        Image(systemName: "hourglass")
                            .foregroundColor(.blue)
                        Text(countdown(to: next))
                            .font(.caption.monospaced())
                            .foregroundColor(.blue)
                    }
                } else {
                    HStack {
                        Image(systemName: "hourglass")
                            .foregroundColor(.secondary)
                        Text("-")
                            .font(.caption)
                    }
                }

                if let status = job.state?.lastStatus {
                    HStack {
                        Image(systemName: status == "ok" ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(status == "ok" ? .green : .orange)
                        Text(status == "ok" ? "成功" : "失败")
                            .font(.caption)
                    }
                }

                if let target = job.sessionTarget {
                    HStack {
                        Image(systemName: "arrow.right.to.line")
                            .foregroundColor(.secondary)
                        Text(target)
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }

            // Payload 预览
            if let payload = job.payload {
                let preview = payload.message ?? payload.text ?? ""
                if !preview.isEmpty {
                    Text(preview)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                }
            }

            // 运行历史（可展开）
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedJobId == job.id },
                    set: { expanded in
                        if expanded {
                            expandedJobId = job.id
                            Task { await loadRuns(job.id) }
                        } else {
                            expandedJobId = nil
                        }
                    }
                )
            ) {
                runHistoryContent(job.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.caption)
                    Text("运行历史")
                        .font(.caption)
                    if let runs = jobRuns[job.id] {
                        Text("(\(runs.count))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.secondary)
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

    // MARK: - 运行历史内容

    @ViewBuilder
    private func runHistoryContent(_ jobId: String) -> some View {
        if runsLoading == jobId {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity)
                .padding(8)
        } else if let runs = jobRuns[jobId], !runs.isEmpty {
            VStack(spacing: 6) {
                ForEach(runs) { run in
                    HStack(spacing: 8) {
                        // 状态图标
                        Image(systemName: run.status == "ok" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(run.status == "ok" ? .green : .red)

                        // 时间
                        if let ts = run.startedAtMs {
                            Text(formatRunTime(ts))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        // 耗时
                        if let dur = run.durationMs {
                            Text(formatDuration(dur))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                        }

                        // 状态文字
                        Text(run.status ?? "-")
                            .font(.caption2)
                            .foregroundStyle(run.status == "ok" ? .green : .red)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.03))
                    .cornerRadius(6)

                    // 错误信息
                    if let err = run.error, !err.isEmpty {
                        Text(err)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 8)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.top, 8)
        } else {
            Text("暂无运行记录")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .padding(8)
        }
    }

    // MARK: - Helpers

    private func scheduleText(_ job: CronJobInfo) -> String {
        guard let s = job.schedule else { return "-" }
        switch s.kind {
        case "cron": return s.expr ?? "-"
        case "every":
            if let ms = s.everyMs {
                let min = Int(ms / 60000)
                return min >= 60 ? "Every \(min / 60)h" : "Every \(min)m"
            }
            return "Periodic"
        case "at": return s.at ?? "-"
        default: return s.kind ?? "-"
        }
    }

    private func countdown(to ms: Double) -> String {
        let diff = (ms / 1000) - now.timeIntervalSince1970
        if diff <= 0 { return "Pending..." }

        let hours = Int(diff) / 3600
        let minutes = (Int(diff) % 3600) / 60
        let seconds = Int(diff) % 60

        if hours > 24 {
            return String(format: "> %dd", hours / 24)
        } else if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func formatRunTime(_ ms: Double) -> String {
        let date = Date(timeIntervalSince1970: ms / 1000)
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private func formatDuration(_ ms: Double) -> String {
        if ms < 1000 { return "\(Int(ms))ms" }
        let seconds = ms / 1000
        if seconds < 60 { return String(format: "%.1fs", seconds) }
        return String(format: "%.0fm%.0fs", seconds / 60, seconds.truncatingRemainder(dividingBy: 60))
    }

    // MARK: - Data Loading

    private func triggerJob(_ job: CronJobInfo) async {
        triggeringId = job.id
        do {
            let _: EmptyResponse = try await appState.gateway.request("cron.run", params: ["id": job.id, "mode": "force"])
            try? await Task.sleep(for: .seconds(1))
            await loadData()
        } catch {
            // 静默处理
        }
        triggeringId = nil
    }

    private struct CronRunsParams: Encodable {
        let id: String
        let limit: Int
    }

    private func loadRuns(_ jobId: String) async {
        runsLoading = jobId
        do {
            let resp: CronRunsResponse = try await appState.gateway.request("cron.runs", params: CronRunsParams(id: jobId, limit: 10))
            jobRuns[jobId] = resp.runs ?? []
        } catch {
            jobRuns[jobId] = []
        }
        runsLoading = nil
    }

    private func loadData() async {
        isLoading = true
        errorMessage = nil
        guard await appState.gateway.waitForConnection() else {
            isLoading = false; errorMessage = "无法连接到 Gateway"; return
        }
        do {
            let gateway = appState.gateway
            async let jobsReq: CronListResponse = gateway.request("cron.list", params: ["includeDisabled": true])
            async let statusReq: CronStatusResponse = gateway.request("cron.status")
            let (j, s) = try await (jobsReq, statusReq)
            jobs = j.jobs ?? []
            cronStatus = s
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }
}

struct EmptyResponse: Decodable {}
