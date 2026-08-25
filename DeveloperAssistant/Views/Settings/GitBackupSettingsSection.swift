import SwiftUI

struct GitBackupSettingsSection: View {
    let store: GitBackupStore
    @State private var showingToken = false
    @State private var showingPassword = false

    var body: some View {
        @Bindable var store = store
        Section("Git 远程备份") {
            LabeledContent("仓库地址") {
                TextField("", text: $store.configuration.repositoryURL, prompt: Text("https://…/backup.git 或 git@…"))
                    .labelsHidden()
            }
            LabeledContent("备份分支") {
                TextField("", text: $store.configuration.branch)
                    .labelsHidden()
            }
            LabeledContent("认证") {
                Picker("认证", selection: $store.configuration.authenticationMode) {
                    ForEach(GitAuthenticationMode.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 210)
            }
            if store.configuration.authenticationMode == .httpsToken {
                LabeledContent("Git 用户名") {
                    TextField("", text: $store.configuration.accountName)
                        .labelsHidden()
                }
                LabeledContent("Token") {
                    HStack(spacing: 8) {
                        Group {
                            if showingToken { TextField("", text: $store.token) }
                            else { SecureField("", text: $store.token) }
                        }
                        .labelsHidden()
                        Button(showingToken ? "隐藏" : "显示", systemImage: showingToken ? "eye.slash" : "eye") { showingToken.toggle() }
                            .labelStyle(.iconOnly)
                    }
                }
            } else {
                Label("使用 ~/.ssh/config 与系统 SSH Agent，不读取或复制私钥。", systemImage: "key.horizontal")
                    .foregroundStyle(.secondary)
            }
            LabeledContent("备份加密密码") {
                HStack(spacing: 8) {
                    Group {
                        if showingPassword { TextField("", text: $store.encryptionPassword) }
                        else { SecureField("", text: $store.encryptionPassword) }
                    }
                    .labelsHidden()
                    Button(showingPassword ? "隐藏" : "显示", systemImage: showingPassword ? "eye.slash" : "eye") { showingPassword.toggle() }
                        .labelStyle(.iconOnly)
                }
            }
            Text("Token 和加密密码仅保存到 macOS 钥匙串；Provider 密钥与 SSH 私钥不会进入备份。")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("测试连接", systemImage: "network") { Task { await store.testConnection() } }
                Button("立即备份", systemImage: "arrow.up.doc") { Task { await store.backupNow() } }
                    .buttonStyle(.borderedProminent)
                Spacer()
                if store.isWorking { ProgressView().controlSize(.small) }
            }
            if let status = store.statusMessage { Label(status, systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
            if let error = store.errorMessage { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).textSelection(.enabled) }
            if let date = store.lastBackupAt { LabeledContent("最近备份", value: date.formatted(date: .abbreviated, time: .shortened)) }
        }
        .textFieldStyle(.darkBorder)
    }
}
