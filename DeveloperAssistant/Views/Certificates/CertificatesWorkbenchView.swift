import SwiftUI

struct CertificatesWorkbenchView: View {
    let store: OperationsStore
    @State private var selection: UUID?
    @State private var editingID: UUID?
    @State private var showingEditor = false
    @State private var searchText = ""
    @State private var errorMessage: String?

    private var items: [ManagedCertificate] { store.certificates.filter { searchText.isEmpty || $0.name.localizedStandardContains(searchText) || $0.domains.localizedStandardContains(searchText) } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ResourceSummaryMetric(title: "证书", value: "\(store.certificates.count)", systemImage: "checkmark.shield", tint: .blue)
                ResourceSummaryMetric(title: "有效", value: "\(store.certificates.filter { $0.status == .valid }.count)", systemImage: "checkmark.circle.fill", tint: .green)
                ResourceSummaryMetric(title: "需关注", value: "\(store.expiringCertificateCount)", systemImage: "exclamationmark.triangle.fill", tint: .orange)
                Spacer()
            }.padding(18)
            Divider()
            if items.isEmpty { emptyState } else { certificateTable }
        }
        .navigationTitle("证书管理")
        .searchable(text: $searchText, prompt: "名称或域名")
        .toolbar { Button("新增证书", systemImage: "plus") { editingID = nil; showingEditor = true }.buttonStyle(.borderedProminent) }
        .sheet(isPresented: $showingEditor) { CertificateEditorView(store: store, certificateID: editingID) }
        .errorAlert(message: $errorMessage)
    }

    private var certificateTable: some View {
        Table(items, selection: $selection) {
            TableColumn("名称") { item in VStack(alignment: .leading) { Text(item.name).fontWeight(.medium); Text(item.domains).font(.caption).foregroundStyle(.secondary) } }
            TableColumn("状态") { item in Label(item.status.title, systemImage: item.status.systemImage).foregroundStyle(item.status == .valid ? Color.green : Color.orange) }.width(110)
            TableColumn("颁发者") { Text($0.issuer.isEmpty ? "—" : $0.issuer) }.width(120)
            TableColumn("到期日期") { Text($0.expiresAt.formatted(date: .abbreviated, time: .omitted)) }.width(120)
            TableColumn("部署位置") { Text($0.deploymentLocation.isEmpty ? "—" : $0.deploymentLocation) }.width(min: 130, ideal: 180)
        }
        .contextMenu(forSelectionType: UUID.self) { ids in
            if let id = ids.first {
                Button("编辑", systemImage: "pencil") { editingID = id; showingEditor = true }
                Button("删除", systemImage: "trash", role: .destructive) { do { try store.deleteCertificate(id) } catch { errorMessage = error.localizedDescription } }
            }
        } primaryAction: { ids in editingID = ids.first; showingEditor = true }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有证书", systemImage: "checkmark.shield")
        } description: {
            Text("录入证书后可以统一追踪域名、部署位置和到期风险。")
        } actions: {
            Button("新增证书") { showingEditor = true }.buttonStyle(.borderedProminent)
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CertificateEditorView: View {
    let store: OperationsStore; let certificateID: UUID?
    @Environment(\.dismiss) private var dismiss
    @State private var draft = CertificateDraft(); @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("证书") { TextField("名称", text: $draft.name); TextField("域名（可用逗号分隔）", text: $draft.domains); TextField("颁发者", text: $draft.issuer); DatePicker("到期日期", selection: $draft.expiresAt, displayedComponents: .date) }
                Section("部署") { TextField("部署位置", text: $draft.deploymentLocation); TextField("备注", text: $draft.note, axis: .vertical).lineLimit(3...6) }
            }
            .textFieldStyle(.darkBorder)
            .formStyle(.grouped)
            Divider(); HStack { Spacer(); Button("取消") { dismiss() }; Button("保存") { save() }.buttonStyle(.borderedProminent) }.padding()
        }.frame(width: 540, height: 500).onAppear(perform: load).errorAlert(message: $errorMessage)
    }
    private func load() { guard let item = store.certificates.first(where: { $0.id == certificateID }) else { return }; draft = CertificateDraft(name: item.name, domains: item.domains, issuer: item.issuer, expiresAt: item.expiresAt, deploymentLocation: item.deploymentLocation, note: item.note) }
    private func save() { do { try store.saveCertificate(draft, id: certificateID); dismiss() } catch { errorMessage = error.localizedDescription } }
}
