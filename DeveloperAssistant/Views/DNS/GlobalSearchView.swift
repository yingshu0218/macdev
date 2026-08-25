import SwiftUI

struct GlobalSearchView: View {
    let store: DNSStore

    @State private var query = ""
    @State private var openedDomainID: UUID?

    private var results: GlobalSearchResults { store.globalSearch(query) }
    private var reverseResults: [RecordSearchResult] { store.reverseLookup(ipAddress: query) }
    private var regularRecordResults: [RecordSearchResult] {
        let reverseIDs = Set(reverseResults.map(\.id))
        return results.records.filter { !reverseIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ContentUnavailableView {
                    Label("搜索 DNS 资产", systemImage: "magnifyingglass")
                } description: {
                    Text("可搜索域名、项目、标签、备注、主机记录、记录值，或输入 IP 反查域名。")
                }
            } else if results.isEmpty {
                ContentUnavailableView.search(text: query)
            } else {
                List {
                    if !reverseResults.isEmpty {
                        Section("IP 反向查找") {
                            ForEach(reverseResults) { result in
                                recordRow(result)
                            }
                        }
                    }

                    if !results.domains.isEmpty {
                        Section("域名") {
                            ForEach(results.domains) { result in
                                Button { openedDomainID = result.domain.id } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: result.domain.isFavorite ? "star.fill" : "globe")
                                            .foregroundStyle(result.domain.isFavorite ? Color.yellow : Color.accentColor)
                                            .frame(width: 24)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(result.domain.name)
                                                .font(.headline)
                                            Text([
                                                result.account?.name,
                                                result.project?.name,
                                                result.tags.map(\.name).joined(separator: " · ")
                                            ].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "  ·  "))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                    }
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !regularRecordResults.isEmpty {
                        Section("解析记录索引") {
                            ForEach(regularRecordResults) { result in
                                recordRow(result)
                            }
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle("全局搜索")
        .searchable(text: $query, placement: .toolbar, prompt: "域名、记录值或 IP")
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
    }

    private func recordRow(_ result: RecordSearchResult) -> some View {
        Button { openedDomainID = result.entry.domainID } label: {
            HStack(spacing: 12) {
                Text(result.entry.recordType.rawValue)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tint)
                    .frame(width: 48)
                    .padding(.vertical, 5)
                    .background(.tint.opacity(0.1), in: .capsule)
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(result.entry.name).\(result.entry.domainName)")
                        .font(.headline)
                    Text(result.entry.value)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("索引更新于 ") + Text(result.entry.lastSyncedAt, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text(result.account?.name ?? "")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
