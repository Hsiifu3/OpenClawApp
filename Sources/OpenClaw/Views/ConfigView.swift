import SwiftUI

struct ConfigGetResponse: Decodable {
    let raw: String?
    let hash: String?
}

struct ConfigView: View {
    @Environment(AppState.self) private var appState

    @State private var configText: String = ""
    @State private var configHash: String?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var isSaving = false
    @State private var saveMessage: String?
    @State private var saveIsError = false

    var body: some View {
        VStack(spacing: 0) {
            // 工具栏
            HStack {
                Label("配置文件", systemImage: "gearshape")
                    .font(.system(size: 13, weight: .medium))
                Spacer()

                if let msg = saveMessage {
                    Label(msg, systemImage: saveIsError ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(saveIsError ? .red : .green)
                        .transition(.opacity)
                }

                if let hash = configHash {
                    Text("Hash: \(hash.prefix(8))…")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }

                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                }

                Button {
                    Task { await saveAndApply() }
                } label: {
                    Label("保存并应用", systemImage: "checkmark.circle")
                        .font(.system(size: 12))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isSaving || isLoading)

                Button {
                    Task { await loadData() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)

            Divider()

            // 内容
            if isLoading {
                ProgressView("加载中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 32)).foregroundStyle(.secondary)
                    Text(error).foregroundStyle(.secondary).font(.caption)
                    Button("重试") { Task { await loadData() } }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                TextEditor(text: $configText)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(.background)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await loadData() }
    }

    private func loadData() async {
        isLoading = true; errorMessage = nil; saveMessage = nil
        guard await appState.gateway.waitForConnection() else {
            isLoading = false; errorMessage = "无法连接到 Gateway"; return
        }
        do {
            let resp: ConfigGetResponse = try await appState.gateway.request("config.get")
            configText = resp.raw ?? "{}"
            configHash = resp.hash
            isLoading = false
        } catch {
            isLoading = false; errorMessage = error.localizedDescription
        }
    }

    private func saveAndApply() async {
        isSaving = true; saveMessage = nil
        do {
            // 保存配置
            let setResp: ConfigSetResponse = try await appState.gateway.request("config.set", params: ["raw": configText])
            if let hash = setResp.hash { configHash = hash }

            // 应用配置
            let _: ConfigApplyResponse = try await appState.gateway.request("config.apply")

            withAnimation { saveMessage = "已保存并应用"; saveIsError = false }
            // 3 秒后清除提示
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation { saveMessage = nil }
            }
        } catch {
            withAnimation { saveMessage = error.localizedDescription; saveIsError = true }
        }
        isSaving = false
    }
}
