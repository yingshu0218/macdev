import SwiftUI

struct ProviderConnectionsView: View {
    let store: DNSStore

    @State private var showingConnectionForm = false
    @State private var editingAccountID: UUID?
    @State private var deletingAccountID: UUID?
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("服务商连接")
                        .font(.title2.weight(.semibold))
                    Text("连接 DNSPod 与阿里云 DNS；凭证加密保存在 macOS 钥匙串。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("添加连接", systemImage: "plus") {
                    showingConnectionForm = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)

            Divider()

            if store.accounts.isEmpty {
                ContentUnavailableView {
                    Label("还没有服务商连接", systemImage: "link.badge.plus")
                } description: {
                    Text("添加 DNSPod 或阿里云账号后，即可统一同步和管理域名。")
                } actions: {
                    Button("添加连接") {
                        showingConnectionForm = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 14) {
                        ForEach(store.accounts) { account in
                            ConnectionCard(
                                account: account,
                                isWorking: store.isWorking,
                                sync: { sync(account.id) },
                                edit: { editingAccountID = account.id },
                                delete: { deletingAccountID = account.id }
                            )
                        }
                    }
                    .frame(maxWidth: 900)
                    .padding(24)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("服务商连接")
        .sheet(isPresented: $showingConnectionForm) {
            AddConnectionView(store: store)
        }
        .sheet(
            isPresented: Binding(
                get: { editingAccountID != nil },
                set: { if !$0 { editingAccountID = nil } }
            )
        ) {
            if let editingAccountID, let account = store.account(id: editingAccountID) {
                UpdateCredentialView(store: store, account: account)
            }
        }
        .confirmationDialog(
            "删除连接？",
            isPresented: Binding(
                get: { deletingAccountID != nil },
                set: { if !$0 { deletingAccountID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除连接及本地数据", role: .destructive) {
                deleteSelectedAccount()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除该账号的钥匙串凭证、域名索引和本地分类数据。服务商端的 DNS 解析不会被删除。")
        }
        .errorAlert(message: $errorMessage)
    }

    private func sync(_ accountID: UUID) {
        Task {
            do {
                try await store.syncDomains(accountID: accountID)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteSelectedAccount() {
        guard let deletingAccountID else { return }
        do {
            try store.deleteConnection(accountID: deletingAccountID)
        } catch {
            errorMessage = error.localizedDescription
        }
        self.deletingAccountID = nil
    }
}

private struct ConnectionCard: View {
    let account: DNSAccount
    let isWorking: Bool
    let sync: () -> Void
    let edit: () -> Void
    let delete: () -> Void

    private var tint: Color {
        switch account.status {
        case .connected: .green
        case .needsAttention: .orange
        case .syncing: .blue
        case .disabled: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: account.provider.systemImage)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 52, height: 52)
                .background(.tint.opacity(0.1), in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(account.name)
                        .font(.headline)
                    Text(account.provider.title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.secondary.opacity(0.1), in: .capsule)
                }

                HStack(spacing: 14) {
                    Label(account.status.title, systemImage: "circle.fill")
                        .foregroundStyle(tint)
                    Label("\(account.domainCount) 个域名", systemImage: "globe")
                    if let date = account.lastSyncedAt {
                        Text("上次同步 ") + Text(date, style: .relative)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button("同步", systemImage: "arrow.trianglehead.2.clockwise", action: sync)
                .disabled(isWorking || account.status == .syncing)
            Menu {
                if account.provider != .mock {
                    Button("更新凭证", systemImage: "key", action: edit)
                    Divider()
                }
                Button("删除连接", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(18)
        .modernGlassCard(interactive: true)
    }
}

private struct UpdateCredentialView: View {
    @Environment(\.dismiss) private var dismiss

    let store: DNSStore
    let account: DNSAccount

    @State private var accessKeyID = ""
    @State private var accessKeySecret = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("更新访问凭证")
                        .font(.title2.weight(.semibold))
                    Text("\(account.provider.title) · \(account.name)")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)

            Divider()

            Form {
                Section("新凭证") {
                    TextField(
                        account.provider == .dnspod ? "SecretId" : "AccessKey ID",
                        text: $accessKeyID,
                        prompt: Text("留空保持当前值")
                    )
                    SecureField(
                        account.provider == .dnspod ? "SecretKey" : "AccessKey Secret",
                        text: $accessKeySecret,
                        prompt: Text("留空保持当前值")
                    )
                }

                Section {
                    Label("现有凭证不会回显。提交后先测试新凭证；如果测试失败，会自动恢复原凭证。", systemImage: "checkmark.shield")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
            .textFieldStyle(.darkBorder)
            .formStyle(.grouped)

            Divider()

            HStack {
                if isSubmitting {
                    ProgressView().controlSize(.small)
                    Text("正在测试新凭证…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .disabled(isSubmitting)
                Button("测试并更新") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled((accessKeyID.isEmpty && accessKeySecret.isEmpty) || isSubmitting)
            }
            .padding(18)
        }
        .frame(width: 560, height: 430)
        .errorAlert(message: $errorMessage)
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                try await store.updateCredential(
                    accountID: account.id,
                    accessKeyID: accessKeyID,
                    accessKeySecret: accessKeySecret
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

private struct AddConnectionView: View {
    @Environment(\.dismiss) private var dismiss

    let store: DNSStore

    @State private var provider = DNSProviderKind.dnspod
    @State private var accountName = ""
    @State private var accessKeyID = ""
    @State private var accessKeySecret = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        guard !accountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return provider == .mock || (!accessKeyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !accessKeySecret.isEmpty)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("添加 DNS 连接")
                        .font(.title2.weight(.semibold))
                    Text("保存前会向服务商发起连接测试。")
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(24)

            Divider()

            Form {
                Section("服务商") {
                    Picker("类型", selection: $provider) {
                        ForEach(DNSProviderKind.allCases.filter { $0 != .mock }) { kind in
                            Label(kind.title, systemImage: kind.systemImage).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: provider) { _, newValue in
                        if accountName.isEmpty || accountName.hasSuffix("账号") {
                            accountName = "\(newValue.title) 账号"
                        }
                    }

                    TextField("连接名称", text: $accountName, prompt: Text("例如：生产环境"))
                }

                Section("访问凭证") {
                    TextField(provider == .dnspod ? "SecretId" : "AccessKey ID", text: $accessKeyID)
                    SecureField(provider == .dnspod ? "SecretKey" : "AccessKey Secret", text: $accessKeySecret)
                    Text(provider == .dnspod
                         ? "使用腾讯云 API 密钥，并确保已授予 DNSPod 读写权限。"
                         : "使用 RAM 用户 AccessKey，建议仅授予 AliDNS 所需权限。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .textFieldStyle(.darkBorder)
            .formStyle(.grouped)

            Divider()

            HStack {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                    Text("正在测试并同步域名…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .disabled(isSubmitting)
                Button("测试并保存") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSubmit || isSubmitting)
            }
            .padding(18)
        }
        .frame(width: 570, height: 530)
        .onAppear {
            if accountName.isEmpty { accountName = "DNSPod 账号" }
        }
        .errorAlert(message: $errorMessage)
    }

    private func submit() {
        isSubmitting = true
        Task {
            do {
                _ = try await store.addConnection(
                    provider: provider,
                    name: accountName,
                    accessKeyID: accessKeyID,
                    accessKeySecret: accessKeySecret
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSubmitting = false
            }
        }
    }
}

extension View {
    func errorAlert(message: Binding<String?>) -> some View {
        alert(
            "操作失败",
            isPresented: Binding(
                get: { message.wrappedValue != nil },
                set: { if !$0 { message.wrappedValue = nil } }
            )
        ) {
            Button("好", role: .cancel) {}
        } message: {
            Text(message.wrappedValue ?? "未知错误")
        }
    }
}
