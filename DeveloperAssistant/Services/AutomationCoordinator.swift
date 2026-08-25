import Foundation
import Observation

@MainActor @Observable
final class AutomationCoordinator {
    private let dnsStore: DNSStore
    private let serverStore: ServerStore
    private let operationsStore: OperationsStore
    private let notifications = LocalNotificationService()
    private var loopTask: Task<Void, Never>?

    var dnsIntervalMinutes: Int { didSet { UserDefaults.standard.set(dnsIntervalMinutes, forKey: "automation.dnsMinutes"); restart() } }
    var serverIntervalMinutes: Int { didSet { UserDefaults.standard.set(serverIntervalMinutes, forKey: "automation.serverMinutes"); restart() } }
    var notificationsEnabled: Bool { didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "automation.notifications"); restart() } }
    var lastRunAt: Date?

    init(dnsStore: DNSStore, serverStore: ServerStore, operationsStore: OperationsStore) {
        self.dnsStore = dnsStore; self.serverStore = serverStore; self.operationsStore = operationsStore
        dnsIntervalMinutes = UserDefaults.standard.integer(forKey: "automation.dnsMinutes")
        serverIntervalMinutes = UserDefaults.standard.integer(forKey: "automation.serverMinutes")
        notificationsEnabled = UserDefaults.standard.bool(forKey: "automation.notifications")
    }

    func start() { restart() }
    func stop() { loopTask?.cancel(); loopTask = nil }

    func runNow() async {
        await dnsStore.syncAllDomains(); await serverStore.checkAll(); lastRunAt = .now
        await sendAlertsIfNeeded()
    }

    private func restart() {
        loopTask?.cancel()
        guard dnsIntervalMinutes > 0 || serverIntervalMinutes > 0 else { return }
        loopTask = Task { [weak self] in
            guard let self else { return }
            if notificationsEnabled { _ = await notifications.requestAuthorization() }
            var dnsElapsed = 0; var serverElapsed = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60)); if Task.isCancelled { break }
                dnsElapsed += 1; serverElapsed += 1
                if dnsIntervalMinutes > 0, dnsElapsed >= dnsIntervalMinutes { await dnsStore.syncAllDomains(); dnsElapsed = 0; lastRunAt = .now }
                if serverIntervalMinutes > 0, serverElapsed >= serverIntervalMinutes { await serverStore.checkAll(); serverElapsed = 0; lastRunAt = .now }
                await sendAlertsIfNeeded()
            }
        }
    }

    private func sendAlertsIfNeeded() async {
        guard notificationsEnabled else { return }
        let offline = serverStore.servers.filter { $0.status == .offline }
        if !offline.isEmpty { await notifications.notify(identifier: "servers-offline", title: "服务器需要关注", body: "\(offline.count) 台服务器当前不可达。") }
        if serverStore.expiringSoonCount > 0 { await notifications.notify(identifier: "servers-expiring", title: "服务器到期提醒", body: "\(serverStore.expiringSoonCount) 台服务器将在 30 天内到期。") }
        let expiring = operationsStore.expiringCertificateCount
        if expiring > 0 { await notifications.notify(identifier: "certificates-expiring", title: "证书到期提醒", body: "\(expiring) 张证书已过期或将在 30 天内到期。") }
        let failedDNS = dnsStore.accounts.filter { $0.status == .needsAttention }
        if !failedDNS.isEmpty { await notifications.notify(identifier: "dns-needs-attention", title: "DNS 同步需要关注", body: "\(failedDNS.count) 个服务商连接同步失败。") }
    }
}
