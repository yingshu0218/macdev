import SwiftUI

struct ServerEditorView: View {
    let store: ServerStore
    let serverID: UUID?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: ServerDraft
    @State private var hasExpiration: Bool
    @State private var errorMessage: String?

    init(store: ServerStore, serverID: UUID?) {
        self.store = store
        self.serverID = serverID
        let initial = store.server(id: serverID)?.draft ?? ServerDraft()
        _draft = State(initialValue: initial)
        _hasExpiration = State(initialValue: initial.expiresAt != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(serverID == nil ? "新增服务器" : "编辑服务器")
                        .font(.title2.weight(.semibold))
                    Text("保存资产与 SSH 连接信息，不保存密码或私钥。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(20)

            Divider()

            Form {
                Section("基本信息") {
                    TextField("名称", text: $draft.name, prompt: Text("例如：生产应用服务器"))
                    Picker("Provider", selection: $draft.provider) {
                        ForEach(ServerProvider.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                    Picker("环境", selection: $draft.environment) {
                        ForEach(ServerEnvironment.allCases) { environment in
                            Text(environment.title).tag(environment)
                        }
                    }
                    TextField("项目", text: $draft.project, prompt: Text("可选"))
                }

                Section("SSH 连接") {
                    TextField("IP / 主机名", text: $draft.host, prompt: Text("server.example.com"))
                    TextField("端口", value: $draft.port, format: .number)
                    TextField("用户名", text: $draft.username, prompt: Text("root"))
                }

                Section("资产信息") {
                    TextField("区域", text: $draft.region, prompt: Text("例如：华东 1（杭州）"))
                    TextField("操作系统", text: $draft.operatingSystem, prompt: Text("例如：Ubuntu 24.04 LTS"))
                    TextField("标签", text: $draft.tags, prompt: Text("多个标签用英文逗号分隔"))
                    Toggle("设置到期时间", isOn: $hasExpiration)
                    if hasExpiration {
                        DatePicker(
                            "到期时间",
                            selection: Binding(
                                get: { draft.expiresAt ?? .now },
                                set: { draft.expiresAt = $0 }
                            ),
                            displayedComponents: .date
                        )
                    }
                    Toggle("收藏", isOn: $draft.isFavorite)
                }

                Section("备注") {
                    TextEditor(text: $draft.note)
                        .darkBorderTextEditor()
                        .frame(minHeight: 80)
                }
            }
            .textFieldStyle(.darkBorder)
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("保存") { save() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 610, height: 680)
        .errorAlert(message: $errorMessage)
    }

    private func save() {
        if !hasExpiration { draft.expiresAt = nil }
        do {
            if let serverID {
                try store.update(serverID: serverID, draft: draft)
            } else {
                try store.add(draft)
            }
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
