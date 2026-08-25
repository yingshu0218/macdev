import AppKit
import SwiftUI

struct SystemSettingsView: View {
    let store: DNSStore
    let serverStore: ServerStore
    let operationsStore: OperationsStore
    let automation: AutomationCoordinator
    let gitBackupStore: GitBackupStore
    let appLock: AppLockModel

    @State private var backupURL: URL?
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("外观") {
                LabeledContent("主题", value: "跟随系统")
                LabeledContent("界面", value: "原生 SwiftUI · Liquid Glass")
            }

            Section("本地数据") {
                LabeledContent("数据库") {
                    Text(AppDatabase.storeURL.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
                LabeledContent("备份目录") {
                    Text(AppDatabase.backupDirectoryURL.path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                        .lineLimit(2)
                }
                LabeledContent(
                    "当前索引",
                    value: "\(store.accounts.count) 个账号 · \(store.domains.count) 个域名 · \(serverStore.servers.count) 台服务器 · \(operationsStore.certificates.count) 张证书 · \(operationsStore.deployments.count) 条部署"
                )

                HStack {
                    Button("立即备份", systemImage: "externaldrive.badge.plus") {
                        createBackup()
                    }
                    Button("在 Finder 中显示", systemImage: "folder") {
                        NSWorkspace.shared.activateFileViewerSelecting([backupURL ?? AppDatabase.backupDirectoryURL])
                    }
                    Spacer()
                    if let backupURL {
                        Label(backupURL.lastPathComponent, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }

            Section("安全") {
                Label("Provider 凭证保存在 macOS 钥匙串，不写入 SQLite 或操作日志。", systemImage: "key.fill")
                Label("删除连接、删除解析和恢复变更均需要显式确认。", systemImage: "checkmark.shield.fill")
                Button("立即锁定应用", systemImage: "lock.fill") {
                    appLock.lock()
                }
            }

            Section("自动化") {
                Picker("DNS 自动同步", selection: Binding(get: { automation.dnsIntervalMinutes }, set: { automation.dnsIntervalMinutes = $0 })) {
                    Text("关闭").tag(0)
                    Text("每 15 分钟").tag(15)
                    Text("每小时").tag(60)
                    Text("每 6 小时").tag(360)
                }
                Picker("服务器健康检查", selection: Binding(get: { automation.serverIntervalMinutes }, set: { automation.serverIntervalMinutes = $0 })) {
                    Text("关闭").tag(0)
                    Text("每 5 分钟").tag(5)
                    Text("每 15 分钟").tag(15)
                    Text("每小时").tag(60)
                }
                Toggle("本机通知", isOn: Binding(get: { automation.notificationsEnabled }, set: { automation.notificationsEnabled = $0 }))
                HStack {
                    Button("立即运行全部检查", systemImage: "arrow.clockwise") {
                        Task { await automation.runNow() }
                    }
                    Spacer()
                    if let date = automation.lastRunAt {
                        Text("上次：\(date.formatted(date: .omitted, time: .shortened))")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            GitBackupSettingsSection(store: gitBackupStore)

            Section("关于") {
                LabeledContent("应用", value: "开发管理助手")
                LabeledContent("版本", value: "1.0.0 (1)")
                LabeledContent("最低系统", value: "macOS 15")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 620, minHeight: 520)
        .navigationTitle("系统设置")
        .errorAlert(message: $errorMessage)
    }

    private func createBackup() {
        do {
            backupURL = try store.createDatabaseBackup()
        } catch {
            errorMessage = "备份失败：\(error.localizedDescription)"
        }
    }
}
