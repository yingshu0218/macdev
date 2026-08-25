import AppKit
import SwiftUI

struct DeveloperAssistantMenuBarView: View {
    let navigation: AppNavigationModel
    let dnsStore: DNSStore
    let serverStore: ServerStore
    let operationsStore: OperationsStore
    let automation: AutomationCoordinator

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("打开开发管理助手", systemImage: "macwindow") { open(.home) }

        Divider()

        Button("DNS · \(dnsStore.domains.filter(\.isActive).count) 个域名", systemImage: "network") { open(.dnsWorkbench) }
        Button("服务器 · \(serverStore.onlineCount)/\(serverStore.servers.count) 在线", systemImage: "server.rack") { open(.serversWorkbench) }
        Button("证书 · \(operationsStore.expiringCertificateCount) 个需关注", systemImage: "checkmark.shield") { open(.certificatesWorkbench) }
        Button("部署 · \(operationsStore.deployments.count) 条记录", systemImage: "shippingbox") { open(.deploymentsWorkbench) }

        Divider()

        Button("立即运行全部检查", systemImage: "arrow.clockwise") { Task { await automation.runNow() } }
        SettingsLink { Label("设置", systemImage: "gearshape") }

        Divider()

        Button("退出开发管理助手", systemImage: "power") { NSApplication.shared.terminate(nil) }
    }

    private func open(_ destination: NavigationDestination) {
        navigation.open(destination)
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }
}
