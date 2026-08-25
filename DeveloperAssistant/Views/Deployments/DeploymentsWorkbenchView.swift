import SwiftUI

struct DeploymentsWorkbenchView: View {
    let store: OperationsStore; let serverStore: ServerStore
    @State private var showingEditor = false; @State private var searchText = ""; @State private var environment: DeploymentEnvironment?; @State private var errorMessage: String?
    private var items: [DeploymentRecord] { store.deployments.filter { (searchText.isEmpty || $0.project.localizedStandardContains(searchText) || $0.version.localizedStandardContains(searchText)) && (environment == nil || $0.environment == environment) } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                ResourceSummaryMetric(title: "部署", value: "\(store.deployments.count)", systemImage: "shippingbox", tint: .blue)
                ResourceSummaryMetric(title: "成功", value: "\(store.deployments.filter { $0.result == .succeeded }.count)", systemImage: "checkmark.circle.fill", tint: .green)
                ResourceSummaryMetric(title: "失败/回滚", value: "\(store.deployments.filter { $0.result == .failed || $0.result == .rolledBack }.count)", systemImage: "arrow.uturn.backward.circle", tint: .orange)
                Spacer()
            }.padding(18)
            Divider()
            HStack { Picker("环境", selection: $environment) { Text("全部环境").tag(DeploymentEnvironment?.none); ForEach(DeploymentEnvironment.allCases) { Text($0.title).tag(Optional($0)) } }.frame(width: 150); Spacer(); Text("\(items.count) 条记录").foregroundStyle(.secondary) }.padding(12)
            Divider()
            if items.isEmpty {
                ContentUnavailableView {
                    Label("还没有部署记录", systemImage: "shippingbox")
                } description: {
                    Text("记录版本、环境、服务器与回滚线索。")
                } actions: {
                    Button("记录部署") { showingEditor = true }.buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            else { Table(items) {
                TableColumn("项目") { Text($0.project).fontWeight(.medium) }
                TableColumn("版本") { Text($0.version).font(.body.monospaced()) }.width(110)
                TableColumn("环境") { Text($0.environment.title) }.width(90)
                TableColumn("结果") { Label($0.result.title, systemImage: $0.result.systemImage) }.width(110)
                TableColumn("服务器") { item in Text(serverStore.server(id: item.serverID)?.name ?? "—") }.width(140)
                TableColumn("部署时间") { Text($0.deployedAt.formatted(date: .abbreviated, time: .shortened)) }.width(150)
            }.contextMenu(forSelectionType: UUID.self) { ids in if let id = ids.first { Button("删除记录", systemImage: "trash", role: .destructive) { do { try store.deleteDeployment(id) } catch { errorMessage = error.localizedDescription } } } } }
        }
        .navigationTitle("部署记录").searchable(text: $searchText, prompt: "项目或版本")
        .toolbar { Button("记录部署", systemImage: "plus") { showingEditor = true }.buttonStyle(.borderedProminent) }
        .sheet(isPresented: $showingEditor) { DeploymentEditorView(store: store, serverStore: serverStore) }
        .errorAlert(message: $errorMessage)
    }
}

private struct DeploymentEditorView: View {
    let store: OperationsStore; let serverStore: ServerStore
    @Environment(\.dismiss) private var dismiss
    @State private var draft = DeploymentDraft(); @State private var errorMessage: String?
    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("发布") { TextField("项目", text: $draft.project); TextField("版本", text: $draft.version); Picker("环境", selection: $draft.environment) { ForEach(DeploymentEnvironment.allCases) { Text($0.title).tag($0) } }; Picker("结果", selection: $draft.result) { ForEach(DeploymentResult.allCases) { Text($0.title).tag($0) } }; DatePicker("部署时间", selection: $draft.deployedAt) }
                Section("关联") { Picker("服务器", selection: $draft.serverID) { Text("不关联").tag(UUID?.none); ForEach(serverStore.servers) { Text($0.name).tag(Optional($0.id)) } }; TextField("操作人", text: $draft.operatorName); TextField("摘要", text: $draft.summary, axis: .vertical).lineLimit(2...5); if draft.result == .rolledBack { TextField("回滚到版本", text: $draft.rollbackVersion) } }
            }
            .textFieldStyle(.darkBorder)
            .formStyle(.grouped)
            Divider(); HStack { Spacer(); Button("取消") { dismiss() }; Button("保存") { save() }.buttonStyle(.borderedProminent) }.padding()
        }.frame(width: 560, height: 570).errorAlert(message: $errorMessage)
    }
    private func save() { do { try store.addDeployment(draft); dismiss() } catch { errorMessage = error.localizedDescription } }
}
