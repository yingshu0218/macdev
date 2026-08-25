import SwiftUI

struct ServersWorkbenchView: View {
    let store: ServerStore

    @State private var selectedServerID: UUID?
    @State private var searchText = ""
    @State private var providerFilter: ServerProvider?
    @State private var environmentFilter: ServerEnvironment?
    @State private var statusFilter: ServerHealthStatus?
    @State private var favoritesOnly = false
    @State private var editorContext: ServerEditorContext?
    @State private var deletingServer: ManagedServer?
    @State private var errorMessage: String?

    private var visibleServers: [ManagedServer] {
        store.servers.filter { server in
            let matchesSearch = searchText.isEmpty
                || [
                    server.name,
                    server.host,
                    server.project,
                    server.region,
                    server.operatingSystem,
                    server.tags,
                    server.note
                ].contains { $0.localizedStandardContains(searchText) }
            return matchesSearch
                && (providerFilter == nil || server.provider == providerFilter)
                && (environmentFilter == nil || server.environment == environmentFilter)
                && (statusFilter == nil || server.status == statusFilter)
                && (!favoritesOnly || server.isFavorite)
        }
    }

    private var selectedServer: ManagedServer? { store.server(id: selectedServerID) }

    var body: some View {
        VStack(spacing: 0) {
            summaryHeader
            Divider()

            if store.servers.isEmpty {
                emptyState
            } else {
                filterBar
                Divider()
                workbenchContent
            }
        }
        .navigationTitle("服务器管理")
        .searchable(text: $searchText, placement: .toolbar, prompt: "名称、IP、项目或标签")
        .toolbar {
            ToolbarItemGroup {
                Button("检测全部", systemImage: "wave.3.right") {
                    Task { await store.checkAll() }
                }
                .disabled(store.servers.isEmpty || !store.checkingServerIDs.isEmpty)

                Button("新增服务器", systemImage: "plus") {
                    editorContext = ServerEditorContext(serverID: nil)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .sheet(item: $editorContext) { context in
            ServerEditorView(store: store, serverID: context.serverID)
        }
        .confirmationDialog(
            "删除服务器资产？",
            isPresented: Binding(
                get: { deletingServer != nil },
                set: { if !$0 { deletingServer = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除 \(deletingServer?.name ?? "服务器")", role: .destructive) {
                deleteServer()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会删除本地资产记录，不会关闭或删除远端服务器。")
        }
        .errorAlert(message: $errorMessage)
        .onChange(of: store.servers.map(\.id)) { _, ids in
            if let selectedServerID, !ids.contains(selectedServerID) {
                self.selectedServerID = nil
            }
        }
    }

    private var summaryHeader: some View {
        HStack(spacing: 14) {
            ResourceSummaryMetric(
                title: "服务器",
                value: "\(store.servers.count)",
                systemImage: "server.rack",
                tint: .blue
            )
            ResourceSummaryMetric(
                title: "在线",
                value: "\(store.onlineCount)",
                systemImage: "checkmark.circle.fill",
                tint: .green
            )
            ResourceSummaryMetric(
                title: "需关注",
                value: "\(store.servers.filter { $0.status == .offline }.count)",
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange
            )
            ResourceSummaryMetric(
                title: "30 天内到期",
                value: "\(store.expiringSoonCount)",
                systemImage: "calendar.badge.exclamationmark",
                tint: .pink
            )
            Spacer()
        }
        .padding(18)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Picker("Provider", selection: $providerFilter) {
                Text("全部 Provider").tag(ServerProvider?.none)
                ForEach(ServerProvider.allCases) { provider in
                    Text(provider.title).tag(Optional(provider))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 170)

            Picker("环境", selection: $environmentFilter) {
                Text("全部环境").tag(ServerEnvironment?.none)
                ForEach(ServerEnvironment.allCases) { environment in
                    Text(environment.title).tag(Optional(environment))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 130)

            Picker("状态", selection: $statusFilter) {
                Text("全部状态").tag(ServerHealthStatus?.none)
                ForEach(ServerHealthStatus.allCases) { status in
                    Text(status.title).tag(Optional(status))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 130)

            Toggle("仅收藏", systemImage: "star.fill", isOn: $favoritesOnly)
                .toggleStyle(.button)

            Spacer()
            Text("\(visibleServers.count) 台")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private var workbenchContent: some View {
        HStack(spacing: 0) {
            serverTable
                .frame(minWidth: 560)

            Divider()

            if let selectedServer {
                ServerInspectorView(
                    server: selectedServer,
                    isChecking: store.checkingServerIDs.contains(selectedServer.id),
                    check: { Task { await store.check(serverID: selectedServer.id) } },
                    edit: { editorContext = ServerEditorContext(serverID: selectedServer.id) },
                    delete: { deletingServer = selectedServer },
                    toggleFavorite: {
                        do {
                            try store.setFavorite(serverID: selectedServer.id, isFavorite: !selectedServer.isFavorite)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                )
                .frame(width: 330)
            } else {
                ContentUnavailableView(
                    "选择服务器",
                    systemImage: "sidebar.right",
                    description: Text("查看连接信息、运行状态和资产备注。")
                )
                .frame(width: 330)
            }
        }
    }

    private var serverTable: some View {
        Table(visibleServers, selection: $selectedServerID) {
            TableColumn("") { server in
                Image(systemName: server.isFavorite ? "star.fill" : "star")
                    .foregroundStyle(server.isFavorite ? Color.yellow : Color.secondary)
            }
            .width(26)

            TableColumn("服务器") { server in
                VStack(alignment: .leading, spacing: 2) {
                    Text(server.name).fontWeight(.medium)
                    Text(server.host)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }
            .width(min: 160, ideal: 210, max: 250)

            TableColumn("状态") { server in
                Label(server.status.title, systemImage: server.status.systemImage)
                    .foregroundStyle(statusColor(server.status))
            }
            .width(min: 90, ideal: 105, max: 120)

            TableColumn("环境") { server in
                Text(server.environment.title)
            }
            .width(min: 70, ideal: 85, max: 100)

            TableColumn("Provider") { server in
                Text(server.provider.title)
            }
            .width(min: 95, ideal: 115, max: 135)

            TableColumn("项目") { server in
                Text(server.project.isEmpty ? "—" : server.project)
                    .foregroundStyle(server.project.isEmpty ? .tertiary : .primary)
            }
            .width(min: 85, ideal: 105, max: 125)

            TableColumn("最近检测") { server in
                if let lastCheckedAt = server.lastCheckedAt {
                    Text(lastCheckedAt.formatted(.relative(presentation: .named)))
                        .foregroundStyle(.secondary)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(min: 92, ideal: 105, max: 120)
        }
        .contextMenu(forSelectionType: UUID.self) { selected in
            if let id = selected.first, let server = store.server(id: id) {
                Button("检测连接", systemImage: "wave.3.right") {
                    Task { await store.check(serverID: id) }
                }
                Button("编辑", systemImage: "pencil") {
                    editorContext = ServerEditorContext(serverID: id)
                }
                Divider()
                Button(server.isFavorite ? "取消收藏" : "收藏", systemImage: "star") {
                    try? store.setFavorite(serverID: id, isFavorite: !server.isFavorite)
                }
                Button("删除", systemImage: "trash", role: .destructive) {
                    deletingServer = server
                }
            }
        } primaryAction: { selected in
            selectedServerID = selected.first
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有服务器资产", systemImage: "server.rack")
        } description: {
            Text("添加服务器后，可集中查看连接信息、环境、到期时间与可达状态。")
        } actions: {
            Button("新增服务器", systemImage: "plus") {
                editorContext = ServerEditorContext(serverID: nil)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteServer() {
        guard let deletingServer else { return }
        do {
            try store.delete(serverID: deletingServer.id)
            selectedServerID = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        self.deletingServer = nil
    }

    private func statusColor(_ status: ServerHealthStatus) -> Color {
        switch status {
        case .unknown: .secondary
        case .online: .green
        case .offline: .red
        case .maintenance: .orange
        }
    }
}

struct ServerEditorContext: Identifiable {
    let id = UUID()
    let serverID: UUID?
}
