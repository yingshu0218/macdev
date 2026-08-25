import AppKit
import SwiftUI

@main
struct DeveloperAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var navigation = AppNavigationModel()
    @State private var shortcutStore = ShortcutStore()
    @State private var localAppShortcutStore = LocalAppShortcutStore()
    @State private var dnsStore: DNSStore
    @State private var serverStore: ServerStore
    @State private var operationsStore: OperationsStore
    @State private var automation: AutomationCoordinator
    @State private var gitBackupStore: GitBackupStore
    @State private var appLock = AppLockModel()

    init() {
        let dns = DNSStore.bootstrap()
        let servers = ServerStore.bootstrap()
        let operations = OperationsStore.bootstrap()
        _dnsStore = State(initialValue: dns)
        _serverStore = State(initialValue: servers)
        _operationsStore = State(initialValue: operations)
        _automation = State(initialValue: AutomationCoordinator(dnsStore: dns, serverStore: servers, operationsStore: operations))
        _gitBackupStore = State(initialValue: GitBackupStore(dns: dns, servers: servers, operations: operations))
    }

    var body: some Scene {
        WindowGroup("开发管理助手", id: "main") {
            AppShellView(
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
            .frame(minWidth: 920, minHeight: 620)
        }
        .defaultSize(width: 1180, height: 760)
        .commands {
            CommandMenu("前往") {
                Button("首页") {
                    navigation.open(.home)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("DNS 工作台") {
                    navigation.open(.dnsWorkbench)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("服务器管理") {
                    navigation.open(.serversWorkbench)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("证书管理") { navigation.open(.certificatesWorkbench) }
                    .keyboardShortcut("4", modifiers: .command)
                Button("部署记录") { navigation.open(.deploymentsWorkbench) }
                    .keyboardShortcut("5", modifiers: .command)

                Divider()

                Button("服务商连接") {
                    navigation.open(.connections)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Button("全局搜索") {
                    navigation.open(.globalSearch)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Divider()

                Button("立即锁定") {
                    appLock.lock()
                }
                .keyboardShortcut("l", modifiers: [.command, .control])
                .disabled(!appLock.isUnlocked)
            }
        }

        MenuBarExtra("开发管理助手", systemImage: menuBarSystemImage) {
            DeveloperAssistantMenuBarView(
                navigation: navigation,
                dnsStore: dnsStore,
                serverStore: serverStore,
                operationsStore: operationsStore,
                automation: automation
            )
        }

        Settings {
            if appLock.isUnlocked {
                SystemSettingsView(store: dnsStore, serverStore: serverStore, operationsStore: operationsStore, automation: automation, gitBackupStore: gitBackupStore, appLock: appLock)
            } else {
                AppLockView(model: appLock)
                    .frame(minWidth: 620, minHeight: 520)
            }
        }
    }

    private var menuBarSystemImage: String {
        if serverStore.servers.contains(where: { $0.status == .offline }) || operationsStore.expiringCertificateCount > 0 {
            return "hammer.circle.fill"
        }
        return "hammer.circle"
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
