import SwiftUI

struct DomainDetailView: View {
    @Environment(\.dismiss) private var dismiss

    let store: DNSStore
    let domainID: UUID

    @State private var selectedTab = DomainDetailTab.records
    @State private var records: [ProviderDNSRecord] = []
    @State private var selectedRecordID: String?
    @State private var editorContext: RecordEditorContext?
    @State private var deletingRecord: ProviderDNSRecord?
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var domain: ManagedDomain? { store.domain(id: domainID) }
    private var capabilities: DNSProviderCapabilities {
        (try? store.capabilities(for: domainID)) ?? .standard
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            Picker("视图", selection: $selectedTab) {
                ForEach(DomainDetailTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            .padding(16)

            Divider()

            switch selectedTab {
            case .records:
                recordsContent
            case .metadata:
                DomainMetadataView(store: store, domainID: domainID)
            }
        }
        .frame(minWidth: 880, idealWidth: 1040, minHeight: 620, idealHeight: 720)
        .task { await loadRecords() }
        .sheet(item: $editorContext) { context in
            RecordEditorView(
                domainName: domain?.name ?? "",
                record: context.record,
                capabilities: capabilities,
                save: { draft in
                    if let record = context.record {
                        _ = try await store.updateRecord(domainID: domainID, recordID: record.id, draft: draft)
                    } else {
                        _ = try await store.createRecord(domainID: domainID, draft: draft)
                    }
                    await loadRecords(forceRefresh: false)
                }
            )
        }
        .confirmationDialog(
            "删除解析记录？",
            isPresented: Binding(
                get: { deletingRecord != nil },
                set: { if !$0 { deletingRecord = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除记录", role: .destructive) { deleteSelectedRecord() }
            Button("取消", role: .cancel) {}
        } message: {
            if let record = deletingRecord {
                Text("将从服务商删除 \(record.name) \(record.type.rawValue) \(record.value)。操作完成后可在“操作历史”中恢复。")
            }
        }
        .errorAlert(message: $errorMessage)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "globe")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 46, height: 46)
                .background(.tint.opacity(0.1), in: .rect(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 3) {
                Text(domain?.name ?? "域名")
                    .font(.title2.weight(.semibold))
                if let domain, let account = store.account(id: domain.accountID) {
                    Text("\(account.provider.title) · \(account.name)")
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            }
            Button("关闭") { dismiss() }
                .keyboardShortcut(.cancelAction)
        }
        .padding(20)
    }

    @ViewBuilder
    private var recordsContent: some View {
        if isLoading && records.isEmpty {
            ProgressView("正在同步解析记录…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if records.isEmpty {
            ContentUnavailableView {
                Label("没有解析记录", systemImage: "list.bullet.rectangle")
            } description: {
                Text("从第一条 A、AAAA、CNAME 或 TXT 记录开始。")
            } actions: {
                Button("新增解析") { editorContext = RecordEditorContext(record: nil) }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbarLikePadding()
        } else {
            VStack(spacing: 0) {
                HStack {
                    Text("\(records.count) 条解析")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("刷新", systemImage: "arrow.clockwise") {
                        Task { await loadRecords(forceRefresh: true) }
                    }
                    .disabled(isLoading)
                    Button("编辑", systemImage: "pencil") {
                        guard let selectedRecordID,
                              let record = records.first(where: { $0.id == selectedRecordID }) else { return }
                        editorContext = RecordEditorContext(record: record)
                    }
                    .disabled(selectedRecordID == nil)
                    Button("删除", systemImage: "trash", role: .destructive) {
                        deletingRecord = records.first { $0.id == selectedRecordID }
                    }
                    .disabled(selectedRecordID == nil)
                    Button("新增解析", systemImage: "plus") {
                        editorContext = RecordEditorContext(record: nil)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)

                Divider()

                Table(records, selection: $selectedRecordID) {
                    TableColumn("主机记录", value: \.name)
                        .width(min: 90, ideal: 120, max: 145)
                    TableColumn("类型") { record in
                        Text(record.type.rawValue)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(.tint.opacity(0.1), in: .capsule)
                    }
                    .width(65)
                    TableColumn("记录值") { record in
                        Text(record.value)
                            .textSelection(.enabled)
                            .lineLimit(1)
                    }
                    .width(min: 230, ideal: 300, max: 350)
                    TableColumn("TTL") { record in
                        Text("\(record.ttl)").monospacedDigit()
                    }
                    .width(65)
                    TableColumn("线路") { record in
                        Text(record.line ?? "默认")
                    }
                    .width(min: 72, ideal: 86, max: 100)
                    TableColumn("状态") { record in
                        Label(
                            record.isEnabled ? "启用" : "停用",
                            systemImage: record.isEnabled ? "checkmark.circle.fill" : "pause.circle.fill"
                        )
                        .foregroundStyle(record.isEnabled ? .green : .secondary)
                    }
                    .width(80)
                }
                .contextMenu(forSelectionType: String.self) { selected in
                    if let record = records.first(where: { selected.contains($0.id) }) {
                        Button("编辑") { editorContext = RecordEditorContext(record: record) }
                        Button("删除", role: .destructive) { deletingRecord = record }
                    }
                } primaryAction: { selected in
                    guard let record = records.first(where: { selected.contains($0.id) }) else { return }
                    editorContext = RecordEditorContext(record: record)
                }
            }
        }
    }

    @MainActor
    private func loadRecords(forceRefresh: Bool = false) async {
        isLoading = true
        defer { isLoading = false }
        do {
            records = try await store.records(for: domainID, forceRefresh: forceRefresh)
            if let selectedRecordID, !records.contains(where: { $0.id == selectedRecordID }) {
                self.selectedRecordID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteSelectedRecord() {
        guard let deletingRecord else { return }
        Task {
            do {
                try await store.deleteRecord(domainID: domainID, recordID: deletingRecord.id)
                records.removeAll { $0.id == deletingRecord.id }
                selectedRecordID = nil
                self.deletingRecord = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private enum DomainDetailTab: String, CaseIterable, Identifiable {
    case records
    case metadata

    var id: String { rawValue }
    var title: String { self == .records ? "解析记录" : "分类与备注" }
    var systemImage: String { self == .records ? "list.bullet.rectangle" : "tag" }
}

private struct RecordEditorContext: Identifiable {
    let id = UUID()
    let record: ProviderDNSRecord?
}

private struct RecordEditorView: View {
    @Environment(\.dismiss) private var dismiss

    let domainName: String
    let record: ProviderDNSRecord?
    let capabilities: DNSProviderCapabilities
    let save: (DNSRecordDraft) async throws -> Void

    @State private var name: String
    @State private var type: DNSRecordType
    @State private var value: String
    @State private var ttl: String
    @State private var line: String
    @State private var priority: String
    @State private var weight: String
    @State private var isEnabled: Bool
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        domainName: String,
        record: ProviderDNSRecord?,
        capabilities: DNSProviderCapabilities,
        save: @escaping (DNSRecordDraft) async throws -> Void
    ) {
        self.domainName = domainName
        self.record = record
        self.capabilities = capabilities
        self.save = save
        let draft = record?.draft ?? .empty
        _name = State(initialValue: draft.name)
        _type = State(initialValue: draft.type)
        _value = State(initialValue: draft.value)
        _ttl = State(initialValue: String(draft.ttl))
        _line = State(initialValue: draft.line ?? "")
        _priority = State(initialValue: draft.priority.map(String.init) ?? "")
        _weight = State(initialValue: draft.weight.map(String.init) ?? "")
        _isEnabled = State(initialValue: draft.isEnabled)
    }

    private var canSave: Bool {
        let ttlValue = Int(ttl)
        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && ttlValue.map(capabilities.ttlRange.contains) == true
            && (!type.requiresPriority || Int(priority) != nil)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record == nil ? "新增解析" : "编辑解析")
                        .font(.title2.weight(.semibold))
                    Text(domainName)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(22)

            Divider()

            Form {
                Section("解析内容") {
                    TextField("主机记录", text: $name, prompt: Text("例如 @ 或 www"))
                    Picker("记录类型", selection: $type) {
                        ForEach(DNSRecordType.allCases.filter { capabilities.supportedRecordTypes.contains($0) }) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("记录值", text: $value)
                    TextField("TTL", text: $ttl)
                    Text("可用范围：\(capabilities.ttlRange.lowerBound)–\(capabilities.ttlRange.upperBound) 秒")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("高级") {
                    if capabilities.supportsLine {
                        TextField("解析线路（留空为默认）", text: $line)
                    }
                    if type.requiresPriority {
                        TextField("优先级", text: $priority)
                    }
                    if type == .srv && capabilities.supportsWeight {
                        TextField("权重", text: $weight)
                    }
                    if capabilities.supportsDisableRecord {
                        Toggle("启用记录", isOn: $isEnabled)
                    }
                }
            }
            .textFieldStyle(.darkBorder)
            .formStyle(.grouped)

            Divider()

            HStack {
                if isSaving { ProgressView().controlSize(.small) }
                Spacer()
                Button("取消", role: .cancel) { dismiss() }
                    .disabled(isSaving)
                Button(record == nil ? "新增" : "保存") { submit() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canSave || isSaving)
            }
            .padding(18)
        }
        .frame(width: 560, height: type == .srv ? 620 : 570)
        .errorAlert(message: $errorMessage)
    }

    private func submit() {
        guard let ttlValue = Int(ttl) else { return }
        let draft = DNSRecordDraft(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            type: type,
            value: value.trimmingCharacters(in: .whitespacesAndNewlines),
            ttl: ttlValue,
            line: capabilities.supportsLine ? line.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty : nil,
            priority: Int(priority),
            weight: capabilities.supportsWeight ? Int(weight) : nil,
            isEnabled: capabilities.supportsDisableRecord ? isEnabled : true
        )

        isSaving = true
        Task {
            do {
                try await save(draft)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

private struct DomainMetadataView: View {
    let store: DNSStore
    let domainID: UUID

    @State private var projectID: UUID?
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var note = ""
    @State private var didLoad = false
    @State private var errorMessage: String?
    @State private var didSave = false

    var body: some View {
        Form {
            Section("项目") {
                Picker("所属项目", selection: $projectID) {
                    Text("未分类").tag(Optional<UUID>.none)
                    ForEach(store.projects) { project in
                        Text(project.name).tag(Optional(project.id))
                    }
                }
            }

            Section("标签") {
                if store.tags.isEmpty {
                    Text("尚未创建标签，可在“项目与标签”中创建。")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(store.tags) { tag in
                        Toggle(tag.name, isOn: Binding(
                            get: { selectedTagIDs.contains(tag.id) },
                            set: { selected in
                                if selected { selectedTagIDs.insert(tag.id) }
                                else { selectedTagIDs.remove(tag.id) }
                            }
                        ))
                    }
                }
            }

            Section("备注") {
                TextEditor(text: $note)
                    .darkBorderTextEditor()
                    .frame(minHeight: 100)
            }

            Section {
                HStack {
                    if didSave {
                        Label("已保存", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    Spacer()
                    Button("保存分类与备注") { saveMetadata() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 24)
        .onAppear(perform: loadMetadata)
        .errorAlert(message: $errorMessage)
    }

    private func loadMetadata() {
        guard !didLoad, let domain = store.domain(id: domainID) else { return }
        projectID = domain.projectID
        selectedTagIDs = Set(store.tagsForDomain(domainID).map(\.id))
        note = domain.note
        didLoad = true
    }

    private func saveMetadata() {
        do {
            try store.updateDomainMetadata(
                domainID: domainID,
                projectID: projectID,
                tagIDs: selectedTagIDs,
                note: note
            )
            didSave = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension View {
    func toolbarLikePadding() -> some View { self }
}
