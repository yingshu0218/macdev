import SwiftUI

struct DashboardHomeView: View {
    let navigation: AppNavigationModel
    let localAppShortcutStore: LocalAppShortcutStore
    let dnsStore: DNSStore
    let serverStore: ServerStore
    let operationsStore: OperationsStore

    private let columns = [
        GridItem(.adaptive(minimum: 230, maximum: 330), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                HomeHeroView()

                LocalAppDockView(store: localAppShortcutStore)

                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("功能总览").font(.title2.weight(.semibold))
                        Text("查看资源数据，点击卡片进入对应工作台。")
                            .foregroundStyle(.secondary)
                    }
                    moduleGrid
                }

                HomeStatusStrip(dnsStore: dnsStore, serverStore: serverStore, navigation: navigation)
            }
            .frame(maxWidth: 1080, alignment: .leading)
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .navigationTitle("首页")
        .errorAlert(message: Binding(get: { localAppShortcutStore.lastErrorMessage }, set: { localAppShortcutStore.lastErrorMessage = $0 }))
    }

    @ViewBuilder
    private var moduleGrid: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 16) { gridContent }
            } else {
                gridContent
            }
        }
    }

    private var gridContent: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
            ForEach(AppModuleCatalog.modules) { module in
                AppShortcutCard(module: module, metrics: metrics(for: module.id)) {
                    navigation.open(module.destination)
                }
            }
        }
    }

    private func metrics(for id: AppModuleID) -> [AppShortcutMetric] {
        switch id {
        case .dns:
            return [
                AppShortcutMetric(label: "连接", value: "\(dnsStore.accounts.count)"),
                AppShortcutMetric(label: "域名", value: "\(dnsStore.domains.filter(\.isActive).count)"),
                AppShortcutMetric(label: "解析", value: "\(dnsStore.recordIndex.count)")
            ]
        case .servers:
            return [
                AppShortcutMetric(label: "资产", value: "\(serverStore.servers.count)"),
                AppShortcutMetric(label: "在线", value: "\(serverStore.onlineCount)"),
                AppShortcutMetric(label: "需关注", value: "\(serverStore.servers.filter { $0.status == .offline }.count)")
            ]
        case .certificates:
            return [
                AppShortcutMetric(label: "证书", value: "\(operationsStore.certificates.count)"),
                AppShortcutMetric(label: "有效", value: "\(operationsStore.certificates.filter { $0.status == .valid }.count)"),
                AppShortcutMetric(label: "需关注", value: "\(operationsStore.expiringCertificateCount)")
            ]
        case .deployments:
            return [
                AppShortcutMetric(label: "部署", value: "\(operationsStore.deployments.count)"),
                AppShortcutMetric(label: "成功", value: "\(operationsStore.deployments.filter { $0.result == .succeeded }.count)"),
                AppShortcutMetric(label: "失败/回滚", value: "\(operationsStore.deployments.filter { $0.result == .failed || $0.result == .rolledBack }.count)")
            ]
        }
    }
}

private struct HomeHeroView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            Image(systemName: "hammer.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(.tint)
                .frame(width: 60, height: 60)
                .background(.tint.opacity(0.12), in: .rect(cornerRadius: 16))

            VStack(alignment: .leading, spacing: 6) {
                Text("开发资源，一处管理")
                    .font(.largeTitle.weight(.semibold))
                Text("快速打开本机应用，并统一查看 DNS、服务器、证书和部署记录。")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HomeStatusStrip: View {
    let dnsStore: DNSStore
    let serverStore: ServerStore
    let navigation: AppNavigationModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 28) {
                StatusMetric(value: "\(dnsStore.accounts.count)", label: "DNS 连接", systemImage: "link")
                StatusMetric(value: "\(dnsStore.domains.filter(\.isActive).count)", label: "同步域名", systemImage: "globe")
                StatusMetric(value: "\(serverStore.servers.count)", label: "服务器", systemImage: "server.rack")
                StatusMetric(value: "\(serverStore.onlineCount)", label: "在线节点", systemImage: "checkmark.circle")
                Spacer()
                Button("打开资源总览") {
                    navigation.open(serverStore.servers.isEmpty ? .dnsWorkbench : .serversWorkbench)
                }
            }

            if let message = dnsStore.startupErrorMessage
                ?? serverStore.startupErrorMessage
                ?? dnsStore.lastErrorMessage
                ?? serverStore.lastErrorMessage {
                Label(message, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.orange)
            } else {
                Label("DNS 与服务器资产已启用本地持久化；敏感凭证不写入资产数据。", systemImage: "checkmark.shield.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .modernGlassCard()
    }
}

private struct StatusMetric: View {
    let value: String
    let label: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.tint)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.title3.weight(.semibold))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
