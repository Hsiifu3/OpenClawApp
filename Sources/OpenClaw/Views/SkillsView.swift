import SwiftUI

struct SkillsStatusResponse: Decodable {
    let skills: [SkillInfo]?
}

struct SkillInfo: Decodable, Identifiable {
    let name: String?
    let description: String?
    let location: String?
    let eligible: Bool?
    let missing: [String]?

    var id: String { name ?? UUID().uuidString }
}

struct SkillsView: View {
    @Environment(AppState.self) private var appState

    @State private var skills: [SkillInfo] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("技能库")
                            .font(.largeTitle.bold())
                        Text("\(skills.count) 个已安装")
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
                } else if skills.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "square.dashed")
                            .font(.system(size: 40)).foregroundStyle(.quaternary)
                        Text("暂无已安装的技能").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 16)], spacing: 16) {
                        ForEach(skills) { skill in
                            skillCard(skill)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .task { await loadData() }
    }

    private func skillCard(_ skill: SkillInfo) -> some View {
        let isEligible = skill.eligible == true
        let statusColor = isEligible ? Color.green : Color.orange
        
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: isEligible ? "sparkles" : "exclamationmark.triangle")
                    .font(.title2)
                    .foregroundColor(statusColor)
                    .frame(width: 32, height: 32)
                    .background(statusColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(skill.name ?? "未知")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let desc = skill.description, !desc.isEmpty {
                        Text(desc)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                StatusBadge(text: isEligible ? "可用" : "受限", color: statusColor)
            }
            
            Divider()
                .opacity(0.5)
            
            if let missing = skill.missing, !missing.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                    Text("缺少依赖: " + missing.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } else if let loc = skill.location {
                 HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(loc)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
        // Subtle background tint for inactive
        .background(isEligible ? Color.clear : statusColor.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func loadData() async {
        isLoading = true; errorMessage = nil
        guard await appState.gateway.waitForConnection() else {
            isLoading = false; errorMessage = "无法连接到 Gateway"; return
        }
        do {
            let agentId = appState.gateway.helloPayload?.snapshot?.sessionDefaults?.defaultAgentId ?? "main"
            let resp: SkillsStatusResponse = try await appState.gateway.request("skills.status", params: ["agentId": agentId])
            skills = resp.skills ?? []
            isLoading = false
        } catch {
            isLoading = false; errorMessage = error.localizedDescription
        }
    }
}
