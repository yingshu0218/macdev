import SwiftUI

struct DNSWorkbenchView: View {
    let navigation: AppNavigationModel
    let store: DNSStore

    @State private var searchText = ""
    @State private var filters = DomainFilters()
    @State private var selectedDomainID: UUID?
    @State private var openedDomainID: UUID?
    @State private var errorMessage: String?

    private var visibleDomains: [ManagedDomain] {
        store.filteredDomains(searchText: searchText, filters: filters)
    }

    var body: some View {
        VStack(spacing: 0) {
            summaryHeader
            Divider()
            filterBar
            Divider()

            if store.accounts.isEmpty {
                ContentUnavailableView {
                    Label("尚未连接 DNS 服务商", systemImage: "network.slash")
                } description: {
                    Text("添加 DNSPod 或阿里云 DNS 连接后，域名会显示在这里。")
                } actions: {
                    Button("前往服务商连接") {
                        navigation.open(.connections)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if visibleDomains.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                domainTable
            }
        }
        .navigationTitle("DNS 工作台")
        .searchable(text: $searchText, prompt: "搜索域名、项目、标签或备注")
        .toolbar {
            ToolbarItemGroup {
                Button("打开", systemImage: "arrow.up.forward.app") {
                    openedDomainID = selectedDomainID
                }
                .disabled(selectedDomainID == nil)

                Button("同步全部", systemImage: "arrow.trianglehead.2.clockwise") {
                    syncAll()
                }
                .disabled(store.isWorking || store.accounts.isEmpty)

                Button("服务商连接", systemImage: "link") {
                    navigation.open(.connections)
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { openedDomainID != nil },
                set: { if !$0 { openedDomainID = nil } }
            )
        ) {
            if let openedDomainID {
                DomainDetailView(store: store, domainID: openedDomainID)
            }
        }
        .errorAlert(message: $errorMessage)
    }

    private var summaryHeader: some View {
        HStack(spacing: 14) {
            ResourceSummaryMetric(
                title: "连接",
                value: "\(store.accounts.count)",
                systemImage: "link",
                tint: .blue
            )
            ResourceSummaryMetric(
                title: "活动域名",
                value: "\(store.domains.filter(\.isActive).count)",
                systemImage: "globe",
                tint: .green
            )
            ResourceSummaryMetric(
                title: "收藏",
                value: "\(store.domains.filter(\.isFavorite).count)",
                systemImage: "star.fill",
                tint: .yellow
            )
            ResourceSummaryMetric(
                title: "解析索引",
                value: "\(store.recordIndex.count)",
                systemImage: "list.bullet.rectangle",
                tint: .purple
            )
            Spacer()
        }
        .padding(18)
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            FilterPicker(
                title: store.project(id: filters.projectID)?.name ?? "项目",
                systemImage: "folder",
                hasSelection: filters.projectID != nil,
                clear: { filters.projectID = nil }
            ) {
                ForEach(store.projects) { project in
                    Button(project.name) { filters.projectID = project.id }
                }
            }

            FilterPicker(
                title: store.tags.first(where: { $0.id == filters.tagID })?.name ?? "标签",
                systemImage: "tag",
                hasSelection: filters.tagID != nil,
                clear: { filters.tagID = nil }
            ) {
                ForEach(store.tags) { tag in
                    Button(tag.name) { filters.tagID = tag.id }
                }
            }

            FilterPicker(
                title: filters.provider?.title ?? "Provider",
                systemImage: "building.2",
                hasSelection: filters.provider != nil,
                clear: { filters.provider = nil }
            ) {
                ForEach(DNSProviderKind.allCases) { provider in
                    Button(provider.title) { filters.provider = provider }
                }
            }

            FilterPicker(
                title: store.accounts.first(where: { $0.id == filters.accountID })?.name ?? "账号",
                systemImage: "person.crop.circle",
                hasSelection: filters.accountID != nil,
                clear: { filters.accountID = nil }
            ) {
                ForEach(store.accounts) { account in
                    Button(account.name) { filters.accountID = account.id }
                }
            }

            Toggle("仅收藏", systemImage: "star", isOn: $filters.favoritesOnly)
                .toggleStyle(.button)

            if filters != DomainFilters() {
                Button("清除筛选", systemImage: "xmark.circle") {
                    filters = DomainFilters()
                }
                .buttonStyle(.borderless)
            }

            Spacer()
            Text("\(visibleDomains.count) 个域名")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
    }

    private var domainTable: some View {
        Table(visibleDomains, selection: $selectedDomainID) {
            TableColumn("") { domain in
                Button {
                    do {
                        try store.setFavorite(domainID: domain.id, isFavorite: !domain.isFavorite)
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                } label: {
                    Image(systemName: domain.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(domain.isFavorite ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .help(domain.isFavorite ? "取消收藏" : "收藏")
            }
            .width(28)

            TableColumn("域名", value: \.name)
                .width(min: 160, ideal: 205, max: 235)

            TableColumn("服务商") { domain in
                if let account = store.account(id: domain.accountID) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.provider.title)
                        Text(account.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .width(min: 110, ideal: 135, max: 155)

            TableColumn("项目") { domain in
                Text(store.project(id: domain.projectID)?.name ?? "—")
                    .foregroundStyle(domain.projectID == nil ? .tertiary : .primary)
            }
            .width(min: 80, ideal: 105, max: 125)

            TableColumn("标签") { domain in
                Text(store.tagsForDomain(domain.id).map(\.name).joined(separator: " · "))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .width(min: 80, ideal: 105, max: 135)

            TableColumn("解析") { domain in
                Text(domain.recordCount.map(String.init) ?? "—")
                    .monospacedDigit()
            }
            .width(55)

            TableColumn("到期") { domain in
                if let date = domain.expiresAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                } else {
                    Text("未知")
                        .foregroundStyle(.tertiary)
                }
            }
            .width(min: 78, ideal: 88, max: 100)

            TableColumn("上次同步") { domain in
                if let date = domain.lastSyncedAt {
                    Text(date.formatted(.relative(presentation: .named)))
                        .foregroundStyle(.secondary)
                } else {
                    Text("—").foregroundStyle(.tertiary)
                }
            }
            .width(min: 88, ideal: 102, max: 116)
        }
        .contextMenu(forSelectionType: UUID.self) { selected in
            if let domainID = selected.first, let domain = store.domain(id: domainID) {
                Button("打开解析管理") { openedDomainID = domainID }
                Button(domain.isFavorite ? "取消收藏" : "收藏") {
                    try? store.setFavorite(domainID: domainID, isFavorite: !domain.isFavorite)
                }
            }
        } primaryAction: { selected in
            openedDomainID = selected.first
        }
    }

    private func syncAll() {
        Task {
            await store.syncAllDomains()
            errorMessage = store.lastErrorMessage
        }
    }
}

private struct FilterPicker<Content: View>: View {
    let title: String
    let systemImage: String
    let hasSelection: Bool
    let clear: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu {
            Button("全部", action: clear)
            Divider()
            content()
        } label: {
            Label(title, systemImage: systemImage)
                .foregroundStyle(hasSelection ? Color.accentColor : Color.primary)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}
