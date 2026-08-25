import SwiftUI

struct AppShellView: View {
    let navigation: AppNavigationModel
    let shortcutStore: ShortcutStore
    let localAppShortcutStore: LocalAppShortcutStore
    let dnsStore: DNSStore
    let serverStore: ServerStore
    let operationsStore: OperationsStore
    let automation: AutomationCoordinator
    let gitBackupStore: GitBackupStore
    let appLock: AppLockModel

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        if appLock.isUnlocked {
            unlockedContent
        } else {
            AppLockView(model: appLock)
        }
    }

    private var unlockedContent: some View {
        @Bindable var navigation = navigation

        return NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selection: $navigation.selection)
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
        } detail: {
            DetailRouteView(
                destination: navigation.selection ?? .home,
                navigation: navigation,
                shortcutStore: shortcutStore,
                localAppShortcutStore: localAppShortcutStore,
                dnsStore: dnsStore,
                serverStore: serverStore,
                operationsStore: operationsStore,
                automation: automation,
                gitBackupStore: gitBackupStore,
                appLock: appLock
            )
        }
        .task { automation.start() }
    }
}

private struct DetailRouteView: View {
    let destination: NavigationDestination
    let navigation: AppNavigationModel
    let shortcutStore: ShortcutStore
    let localAppShortcutStore: LocalAppShortcutStore
    let dnsStore: DNSStore
    let serverStore: ServerStore
    let operationsStore: OperationsStore
    let automation: AutomationCoordinator
    let gitBackupStore: GitBackupStore
    let appLock: AppLockModel

    var body: some View {
        switch destination {
        case .home:
            DashboardHomeView(
                navigation: navigation,
                localAppShortcutStore: localAppShortcutStore,
                dnsStore: dnsStore,
                serverStore: serverStore,
                operationsStore: operationsStore
            )
        case .dnsWorkbench:
            DNSWorkbenchView(navigation: navigation, store: dnsStore)
        case .projectsAndTags:
            ProjectsAndTagsView(store: dnsStore)
        case .history:
            OperationHistoryView(store: dnsStore)
        case .connections:
            ProviderConnectionsView(store: dnsStore)
        case .globalSearch:
            GlobalSearchView(store: dnsStore)
        case .serversWorkbench:
            ServersWorkbenchView(store: serverStore)
        case .certificatesWorkbench:
            CertificatesWorkbenchView(store: operationsStore)
        case .deploymentsWorkbench:
            DeploymentsWorkbenchView(store: operationsStore, serverStore: serverStore)
        case .modulePreview(let id):
            if let module = AppModuleCatalog.module(for: id) {
                ModulePreviewView(module: module, navigation: navigation)
            } else {
                ContentUnavailableView("应用不存在", systemImage: "questionmark.app")
            }
        case .settings:
            SystemSettingsView(store: dnsStore, serverStore: serverStore, operationsStore: operationsStore, automation: automation, gitBackupStore: gitBackupStore, appLock: appLock)
        }
    }
}
