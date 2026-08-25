import CryptoKit
import Foundation
import Observation

@MainActor @Observable
final class GitBackupStore {
    private let dns: DNSStore; private let servers: ServerStore; private let operations: OperationsStore
    private let keychain = GenericKeychainStore(service: "com.infinity.developer-assistant.git-backup")
    private let git = GitProcessService(); private let defaults = UserDefaults.standard
    var configuration: GitBackupConfiguration { didSet { persistConfiguration() } }
    var token = ""; var encryptionPassword = ""; var isWorking = false
    var statusMessage: String?; var errorMessage: String?; var lastBackupAt: Date?; var revisions: [GitBackupRevision] = []

    init(dns: DNSStore, servers: ServerStore, operations: OperationsStore) {
        self.dns = dns; self.servers = servers; self.operations = operations
        configuration = defaults.data(forKey: "gitBackup.configuration").flatMap { try? JSONDecoder().decode(GitBackupConfiguration.self, from: $0) } ?? GitBackupConfiguration()
        token = (try? keychain.load(account: "token")) ?? ""; encryptionPassword = (try? keychain.load(account: "encryption-password")) ?? ""
        lastBackupAt = defaults.object(forKey: "gitBackup.lastBackupAt") as? Date
    }

    func saveSecrets() throws { try keychain.save(token, account: "token"); try keychain.save(encryptionPassword, account: "encryption-password") }

    func testConnection() async { await perform { try self.validate(); try self.saveSecrets(); try FileManager.default.createDirectory(at: self.workingRoot, withIntermediateDirectories: true); let result = try await self.git.run(arguments: ["ls-remote", "--heads", self.configuration.repositoryURL], directory: self.workingRoot, token: self.authToken, account: self.configuration.accountName); guard result.status == 0 else { throw BackupError.git(result.output) }; self.statusMessage = "仓库连接成功" } }

    func backupNow() async { await perform { try self.validate(); try self.saveSecrets(); try self.prepareRepository(); let payload = try self.makePackage(); let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; let payloadData = try encoder.encode(payload); let envelope = try self.encrypt(payloadData); let encrypted = try encoder.encode(envelope); let manifest = GitBackupManifest(format: "developer-assistant-portable-backup", schemaVersion: 1, platform: "macos", createdAt: .now, payloadSHA256: SignatureSupport.sha256Hex(payloadData), encryption: "AES-256-GCM/HKDF-SHA256"); try FileManager.default.createDirectory(at: self.backupDirectory, withIntermediateDirectories: true); try encrypted.write(to: self.backupDirectory.appending(path: "latest.enc"), options: .atomic); try encoder.encode(manifest).write(to: self.backupDirectory.appending(path: "manifest.json"), options: .atomic); try await self.commitAndPush(); self.lastBackupAt = .now; self.defaults.set(self.lastBackupAt, forKey: "gitBackup.lastBackupAt"); self.statusMessage = "备份已推送到 \(self.configuration.branch)"; await self.loadHistory() } }

    func loadHistory() async { let result = try? await git.run(arguments: ["log", "-20", "--format=%H%x09%cI%x09%s", "--", "backups/macos"], directory: repositoryDirectory); guard let result, result.status == 0 else { return }; revisions = result.output.split(separator: "\n").compactMap { line in let parts = line.split(separator: "\t", maxSplits: 2).map(String.init); guard parts.count == 3 else { return nil }; return GitBackupRevision(id: parts[0], date: ISO8601DateFormatter().date(from: parts[1]), subject: parts[2]) } }

    private func perform(_ action: @escaping () async throws -> Void) async { isWorking = true; errorMessage = nil; statusMessage = nil; defer { isWorking = false }; do { try await action() } catch { errorMessage = error.localizedDescription } }
    private var authToken: String? { configuration.authenticationMode == .httpsToken ? token : nil }
    private var workingRoot: URL { AppDatabase.storageDirectoryURL.appending(path: "GitBackup", directoryHint: .isDirectory) }
    private var repositoryDirectory: URL { workingRoot.appending(path: "repository", directoryHint: .isDirectory) }
    private var backupDirectory: URL { repositoryDirectory.appending(path: "backups/macos", directoryHint: .isDirectory) }
    private func persistConfiguration() { if let data = try? JSONEncoder().encode(configuration) { defaults.set(data, forKey: "gitBackup.configuration") } }
    private func validate() throws { guard !configuration.repositoryURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw BackupError.configuration("请填写仓库地址。") }; guard !configuration.branch.isEmpty else { throw BackupError.configuration("请填写备份分支。") }; guard !encryptionPassword.isEmpty else { throw BackupError.configuration("请设置备份加密密码。") }; if configuration.authenticationMode == .httpsToken, token.isEmpty { throw BackupError.configuration("请填写 Git Token。") } }

    private func prepareRepository() throws { try FileManager.default.createDirectory(at: repositoryDirectory, withIntermediateDirectories: true) }
    private func commitAndPush() async throws {
        func run(_ args: [String]) async throws { let r = try await git.run(arguments: args, directory: repositoryDirectory, token: authToken, account: configuration.accountName); guard r.status == 0 else { throw BackupError.git(r.output) } }
        if !FileManager.default.fileExists(atPath: repositoryDirectory.appending(path: ".git").path) { try await run(["init"]); try await run(["remote", "add", "origin", configuration.repositoryURL]) }
        else { _ = try await git.run(arguments: ["remote", "set-url", "origin", configuration.repositoryURL], directory: repositoryDirectory) }
        try await run(["checkout", "-B", configuration.branch]); try await run(["add", "backups/macos/latest.enc", "backups/macos/manifest.json"])
        let commit = try await git.run(arguments: ["-c", "user.name=Developer Assistant", "-c", "user.email=backup@localhost", "commit", "-m", "backup(macos): \(ISO8601DateFormatter().string(from: .now))"], directory: repositoryDirectory)
        if commit.status != 0, !commit.output.contains("nothing to commit") { throw BackupError.git(commit.output) }
        try await run(["push", "-u", "origin", configuration.branch])
    }

    private func encrypt(_ data: Data) throws -> EncryptedBackupEnvelope { let salt = Data((0..<32).map { _ in UInt8.random(in: 0...255) }); let input = SymmetricKey(data: Data(encryptionPassword.utf8)); let key = HKDF<SHA256>.deriveKey(inputKeyMaterial: input, salt: salt, info: Data("developer-assistant-backup-v1".utf8), outputByteCount: 32); let sealed = try AES.GCM.seal(data, using: key); guard let combined = sealed.combined else { throw BackupError.encryption }; return EncryptedBackupEnvelope(version: 1, salt: salt, sealedData: combined) }

    private func makePackage() -> PortableBackupPackage { PortableBackupPackage(schemaVersion: 1, createdAt: .now, dnsAccounts: dns.accounts.map { .init(id: $0.id, provider: $0.providerRawValue, name: $0.name) }, domains: dns.domains.map { .init(id: $0.id, accountID: $0.accountID, providerDomainID: $0.providerDomainID, name: $0.name, projectID: $0.projectID, note: $0.note, isFavorite: $0.isFavorite, isActive: $0.isActive, expiresAt: $0.expiresAt) }, projects: dns.projects.map { .init(id: $0.id, name: $0.name, colorName: $0.colorName) }, tags: dns.tags.map { .init(id: $0.id, name: $0.name, colorName: $0.colorName) }, domainTags: dns.tagLinks.map { .init(domainID: $0.domainID, tagID: $0.tagID) }, servers: servers.servers.map { .init(id: $0.id, name: $0.name, provider: $0.providerRawValue, host: $0.host, port: $0.port, username: $0.username, environment: $0.environmentRawValue, project: $0.project, region: $0.region, operatingSystem: $0.operatingSystem, tags: $0.tags, note: $0.note, expiresAt: $0.expiresAt, isFavorite: $0.isFavorite) }, certificates: operations.certificates.map { .init(id: $0.id, name: $0.name, domains: $0.domains, issuer: $0.issuer, expiresAt: $0.expiresAt, deploymentLocation: $0.deploymentLocation, note: $0.note) }, deployments: operations.deployments.map { .init(id: $0.id, project: $0.project, version: $0.version, environment: $0.environmentRawValue, result: $0.resultRawValue, serverID: $0.serverID, operatorName: $0.operatorName, deployedAt: $0.deployedAt, summary: $0.summary, rollbackVersion: $0.rollbackVersion) }) }

    enum BackupError: LocalizedError { case configuration(String), git(String), encryption; var errorDescription: String? { switch self { case .configuration(let s): s; case .git(let s): "Git 操作失败：\(s.trimmingCharacters(in: .whitespacesAndNewlines))"; case .encryption: "无法生成加密备份包。" } } }
}
