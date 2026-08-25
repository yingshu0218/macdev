import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class DNSStore {
    private let context: ModelContext
    private let credentialStore: any CredentialStore
    private let providerRegistry: ProviderRegistry
    private let recordCacheTTL: TimeInterval = 30

    var accounts: [DNSAccount] = []
    var domains: [ManagedDomain] = []
    var projects: [DNSProject] = []
    var tags: [DNSTag] = []
    var tagLinks: [DomainTagLink] = []
    var recordIndex: [DNSRecordIndexEntry] = []
    var operations: [DNSOperationLog] = []
    var isWorking = false
    var startupErrorMessage: String?
    var lastErrorMessage: String?

    init(
        container: ModelContainer,
        credentialStore: any CredentialStore = KeychainCredentialStore(),
        providerRegistry: ProviderRegistry = ProviderRegistry(),
        startupErrorMessage: String? = nil
    ) {
        self.context = ModelContext(container)
        self.credentialStore = credentialStore
        self.providerRegistry = providerRegistry
        self.startupErrorMessage = startupErrorMessage
        reload()
    }

    static func bootstrap() -> DNSStore {
        do {
            return DNSStore(container: try AppDatabase.makeContainer())
        } catch {
            let message = "本地数据库无法打开，当前使用临时内存数据：\(error.localizedDescription)"
            do {
                return DNSStore(
                    container: try AppDatabase.makeContainer(inMemory: true),
                    startupErrorMessage: message
                )
            } catch {
                preconditionFailure("无法创建持久化或内存数据库：\(error)")
            }
        }
    }

    func reload() {
        do {
            accounts = try context.fetch(FetchDescriptor<DNSAccount>())
                .sorted { $0.createdAt < $1.createdAt }
            domains = try context.fetch(FetchDescriptor<ManagedDomain>())
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            projects = try context.fetch(FetchDescriptor<DNSProject>())
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            tags = try context.fetch(FetchDescriptor<DNSTag>())
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            tagLinks = try context.fetch(FetchDescriptor<DomainTagLink>())
            recordIndex = try context.fetch(FetchDescriptor<DNSRecordIndexEntry>())
            operations = try context.fetch(FetchDescriptor<DNSOperationLog>())
                .sorted { $0.createdAt > $1.createdAt }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func addDemoConnection(name: String = "本地演示账号") async throws -> DNSAccount {
        try validateAccountName(name)
        let account = DNSAccount(
            provider: .mock,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            lastTestedAt: .now
        )
        let provider = MockDNSProvider(seed: MockDNSProvider.stableSeed(for: account.id))
        let domainCount = try await provider.testConnection()

        account.domainCount = domainCount
        context.insert(account)
        providerRegistry.register(provider, for: account.id)
        try context.save()
        reload()

        do {
            try await syncDomains(accountID: account.id)
        } catch {
            account.status = .needsAttention
            try? context.save()
            reload()
            throw error
        }
        return account
    }

    func addConnection(
        provider kind: DNSProviderKind,
        name: String,
        accessKeyID: String,
        accessKeySecret: String
    ) async throws -> DNSAccount {
        if kind == .mock {
            return try await addDemoConnection(name: name)
        }

        try validateAccountName(name)
        let credential = DNSProviderCredential(
            provider: kind,
            accessKeyID: accessKeyID,
            accessKeySecret: accessKeySecret
        )
        guard credential.isComplete else {
            throw DNSProviderError.authenticationFailed
        }

        let account = DNSAccount(
            provider: kind,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        try credentialStore.save(credential, for: account.id)

        do {
            let provider = try providerRegistry.provider(for: account, credentialStore: credentialStore)
            account.domainCount = try await provider.testConnection()
            account.lastTestedAt = .now
            context.insert(account)
            try context.save()
            reload()
            try await syncDomains(accountID: account.id)
            return account
        } catch {
            try? credentialStore.delete(for: account.id)
            throw error
        }
    }

    func updateCredential(
        accountID: UUID,
        accessKeyID: String,
        accessKeySecret: String
    ) async throws {
        guard let account = account(id: accountID) else {
            throw DNSProviderError.authenticationFailed
        }
        guard account.provider != .mock else { return }
        let existingCredential = try credentialStore.load(for: account.id)
        let cleanAccessKeyID = accessKeyID.trimmingCharacters(in: .whitespacesAndNewlines)
        let credential = DNSProviderCredential(
            provider: account.provider,
            accessKeyID: cleanAccessKeyID.isEmpty ? (existingCredential?.accessKeyID ?? "") : cleanAccessKeyID,
            accessKeySecret: accessKeySecret.isEmpty ? (existingCredential?.accessKeySecret ?? "") : accessKeySecret
        )
        guard credential.isComplete else {
            throw DNSProviderError.authenticationFailed
        }
        try credentialStore.save(credential, for: account.id)
        providerRegistry.remove(accountID: account.id)

        do {
            let provider = try providerRegistry.provider(for: account, credentialStore: credentialStore)
            account.domainCount = try await provider.testConnection()
            account.lastTestedAt = .now
            account.status = .connected
            try context.save()
            reload()
        } catch {
            if let existingCredential {
                try? credentialStore.save(existingCredential, for: account.id)
            } else {
                try? credentialStore.delete(for: account.id)
            }
            providerRegistry.remove(accountID: account.id)
            throw error
        }
    }

    func deleteConnection(accountID: UUID) throws {
        guard let account = account(id: accountID) else { return }

        for entry in recordIndex where entry.accountID == accountID {
            context.delete(entry)
        }
        for domain in domains where domain.accountID == accountID {
            for link in tagLinks where link.domainID == domain.id {
                context.delete(link)
            }
            context.delete(domain)
        }
        context.delete(account)
        try credentialStore.delete(for: accountID)
        providerRegistry.remove(accountID: accountID)
        try context.save()
        reload()
    }

    func syncAllDomains() async {
        isWorking = true
        defer { isWorking = false }

        for account in accounts where account.status != .disabled {
            do {
                try await syncDomains(accountID: account.id)
            } catch {
                account.status = .needsAttention
                lastErrorMessage = safeMessage(for: error)
                try? context.save()
            }
        }
        reload()
    }

    func syncDomains(accountID: UUID) async throws {
        guard let account = account(id: accountID) else {
            throw DNSProviderError.authenticationFailed
        }

        let operation = beginOperation(accountID: accountID, action: .syncDomains)
        account.status = .syncing
        try context.save()

        do {
            let provider = try providerRegistry.provider(for: account, credentialStore: credentialStore)
            let providerDomains = try await provider.listDomains()
            let now = Date.now
            let remoteIDs = Set(providerDomains.map(\.id))

            for providerDomain in providerDomains {
                if let existing = domains.first(where: {
                    $0.accountID == accountID && $0.providerDomainID == providerDomain.id
                }) {
                    existing.name = providerDomain.name
                    existing.recordCount = providerDomain.recordCount
                    existing.expiresAt = providerDomain.expiresAt
                    existing.isActive = true
                    existing.lastSyncedAt = now
                    existing.updatedAt = now
                } else {
                    context.insert(
                        ManagedDomain(
                            accountID: accountID,
                            providerDomainID: providerDomain.id,
                            name: providerDomain.name,
                            expiresAt: providerDomain.expiresAt,
                            recordCount: providerDomain.recordCount,
                            lastSyncedAt: now
                        )
                    )
                }
            }

            for domain in domains where domain.accountID == accountID {
                if !remoteIDs.contains(domain.providerDomainID) {
                    domain.isActive = false
                    domain.updatedAt = now
                }
            }

            account.domainCount = providerDomains.count
            account.lastSyncedAt = now
            account.status = .connected
            finish(operation, status: .success, message: "同步 \(providerDomains.count) 个域名")
            try context.save()
            reload()
        } catch {
            account.status = .needsAttention
            finish(operation, status: .failed, message: safeMessage(for: error))
            try? context.save()
            reload()
            throw error
        }
    }

    func records(for domainID: UUID, forceRefresh: Bool = false) async throws -> [ProviderDNSRecord] {
        guard let domain = domain(id: domainID), let account = account(id: domain.accountID) else {
            throw DNSProviderError.domainNotFound
        }

        if !forceRefresh,
           let syncedAt = domain.recordsLastSyncedAt,
           Date.now.timeIntervalSince(syncedAt) < recordCacheTTL {
            return indexedRecords(domainID: domainID)
        }

        let operation = beginOperation(
            accountID: account.id,
            domain: domain,
            action: .syncRecords
        )

        do {
            let provider = try providerRegistry.provider(for: account, credentialStore: credentialStore)
            let records = try await provider.listRecords(domain: domain.name)
            replaceIndex(for: domain, with: records)
            finish(operation, status: .success, message: "同步 \(records.count) 条解析")
            try context.save()
            reload()
            return records
        } catch {
            finish(operation, status: .failed, message: safeMessage(for: error))
            try? context.save()
            reload()
            throw error
        }
    }

    @discardableResult
    func createRecord(domainID: UUID, draft: DNSRecordDraft) async throws -> ProviderDNSRecord {
        let (domain, account, provider) = try providerContext(domainID: domainID)
        try DNSRecordValidator.validate(draft, capabilities: provider.capabilities)
        let operation = beginOperation(accountID: account.id, domain: domain, action: .createRecord)

        do {
            let record = try await provider.createRecord(domain: domain.name, draft: draft)
            context.insert(DNSRecordIndexEntry(accountID: account.id, domainID: domain.id, domainName: domain.name, record: record))
            domain.recordCount = (domain.recordCount ?? indexedRecords(domainID: domain.id).count) + 1
            domain.recordsLastSyncedAt = nil
            operation.providerRecordID = record.id
            insertSnapshot(operationID: operation.id, before: nil, after: record)
            finish(operation, status: .success, message: "新增 \(record.type.rawValue) 记录")
            try context.save()
            reload()
            return record
        } catch {
            finish(operation, status: .failed, message: safeMessage(for: error))
            try? context.save()
            reload()
            throw error
        }
    }

    @discardableResult
    func updateRecord(
        domainID: UUID,
        recordID: String,
        draft: DNSRecordDraft
    ) async throws -> ProviderDNSRecord {
        let (domain, account, provider) = try providerContext(domainID: domainID)
        try DNSRecordValidator.validate(draft, capabilities: provider.capabilities)
        let currentRecords = try await records(for: domainID)
        guard let before = currentRecords.first(where: { $0.id == recordID }) else {
            throw DNSProviderError.recordNotFound
        }
        let operation = beginOperation(accountID: account.id, domain: domain, action: .updateRecord, providerRecordID: recordID)

        do {
            let updated = try await provider.updateRecord(domain: domain.name, recordID: recordID, draft: draft)
            upsertIndex(accountID: account.id, domain: domain, record: updated)
            domain.recordsLastSyncedAt = nil
            insertSnapshot(operationID: operation.id, before: before, after: updated)
            finish(operation, status: .success, message: "修改 \(updated.type.rawValue) 记录")
            try context.save()
            reload()
            return updated
        } catch {
            finish(operation, status: .failed, message: safeMessage(for: error))
            try? context.save()
            reload()
            throw error
        }
    }

    func deleteRecord(domainID: UUID, recordID: String) async throws {
        let (domain, account, provider) = try providerContext(domainID: domainID)
        let currentRecords = try await records(for: domainID)
        guard let before = currentRecords.first(where: { $0.id == recordID }) else {
            throw DNSProviderError.recordNotFound
        }
        let operation = beginOperation(accountID: account.id, domain: domain, action: .deleteRecord, providerRecordID: recordID)

        do {
            try await provider.deleteRecord(domain: domain.name, recordID: recordID)
            for entry in recordIndex where entry.domainID == domain.id && entry.providerRecordID == recordID {
                context.delete(entry)
            }
            domain.recordCount = max(0, (domain.recordCount ?? currentRecords.count) - 1)
            domain.recordsLastSyncedAt = nil
            insertSnapshot(operationID: operation.id, before: before, after: nil)
            finish(operation, status: .success, message: "删除 \(before.type.rawValue) 记录")
            try context.save()
            reload()
        } catch {
            finish(operation, status: .failed, message: safeMessage(for: error))
            try? context.save()
            reload()
            throw error
        }
    }

    func restore(operationID: UUID) async throws {
        guard let source = operations.first(where: { $0.id == operationID }), source.status == .success else {
            throw DNSProviderError.provider("只能恢复已成功的操作")
        }
        guard let domainID = source.domainID else {
            throw DNSProviderError.domainNotFound
        }
        let (domain, account, provider) = try providerContext(domainID: domainID)
        guard let snapshot = snapshot(operationID: source.id) else {
            throw DNSProviderError.provider("操作快照不存在")
        }
        let operation = beginOperation(
            accountID: account.id,
            domain: domain,
            action: .restore,
            providerRecordID: source.providerRecordID,
            restoreSourceOperationID: source.id
        )

        do {
            switch source.action {
            case .createRecord:
                guard let recordID = source.providerRecordID else { throw DNSProviderError.recordNotFound }
                let current = try await records(for: domain.id, forceRefresh: true)
                    .first(where: { $0.id == recordID })
                try await provider.deleteRecord(domain: domain.name, recordID: recordID)
                insertSnapshot(operationID: operation.id, before: current, after: nil)
            case .updateRecord:
                guard
                    let recordID = source.providerRecordID,
                    let before = decodeRecord(snapshot.beforeData)
                else { throw DNSProviderError.recordNotFound }
                let current = try await records(for: domain.id, forceRefresh: true)
                    .first(where: { $0.id == recordID })
                let restored = try await provider.updateRecord(domain: domain.name, recordID: recordID, draft: before.draft)
                insertSnapshot(operationID: operation.id, before: current, after: restored)
            case .deleteRecord:
                guard let before = decodeRecord(snapshot.beforeData) else { throw DNSProviderError.recordNotFound }
                let restored = try await provider.createRecord(domain: domain.name, draft: before.draft)
                operation.providerRecordID = restored.id
                insertSnapshot(operationID: operation.id, before: nil, after: restored)
            case .restore, .syncDomains, .syncRecords:
                throw DNSProviderError.provider("当前操作不支持再次恢复")
            }

            _ = try await records(for: domain.id, forceRefresh: true)
            finish(operation, status: .success, message: "已恢复“\(source.action.title)”")
            try context.save()
            reload()
        } catch {
            finish(operation, status: .failed, message: safeMessage(for: error))
            try? context.save()
            reload()
            throw error
        }
    }

    func setFavorite(domainID: UUID, isFavorite: Bool) throws {
        guard let domain = domain(id: domainID) else { return }
        domain.isFavorite = isFavorite
        domain.updatedAt = .now
        try context.save()
        reload()
    }

    func updateDomainMetadata(
        domainID: UUID,
        projectID: UUID?,
        tagIDs: Set<UUID>,
        note: String
    ) throws {
        guard let domain = domain(id: domainID) else { return }
        domain.projectID = projectID
        domain.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        domain.updatedAt = .now

        for link in tagLinks where link.domainID == domainID {
            context.delete(link)
        }
        for tagID in tagIDs where tags.contains(where: { $0.id == tagID }) {
            context.insert(DomainTagLink(domainID: domainID, tagID: tagID))
        }
        try context.save()
        reload()
    }

    @discardableResult
    func createProject(name: String, colorName: String = "blue") throws -> DNSProject {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw DNSProviderError.provider("项目名称不能为空") }
        guard !projects.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) else {
            throw DNSProviderError.provider("项目名称已存在")
        }
        let project = DNSProject(name: cleanName, colorName: colorName)
        context.insert(project)
        try context.save()
        reload()
        return project
    }

    @discardableResult
    func createTag(name: String, colorName: String = "blue") throws -> DNSTag {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { throw DNSProviderError.provider("标签名称不能为空") }
        guard !tags.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) else {
            throw DNSProviderError.provider("标签名称已存在")
        }
        let tag = DNSTag(name: cleanName, colorName: colorName)
        context.insert(tag)
        try context.save()
        reload()
        return tag
    }

    func deleteProject(id: UUID) throws {
        guard let project = projects.first(where: { $0.id == id }) else { return }
        for domain in domains where domain.projectID == id {
            domain.projectID = nil
            domain.updatedAt = .now
        }
        context.delete(project)
        try context.save()
        reload()
    }

    func deleteTag(id: UUID) throws {
        guard let tag = tags.first(where: { $0.id == id }) else { return }
        for link in tagLinks where link.tagID == id {
            context.delete(link)
        }
        context.delete(tag)
        try context.save()
        reload()
    }

    func createDatabaseBackup() throws -> URL {
        try context.save()
        return try AppDatabase.createBackup()
    }

    func filteredDomains(searchText: String, filters: DomainFilters) -> [ManagedDomain] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return domains.filter { domain in
            guard domain.isActive else { return false }
            guard filters.accountID == nil || domain.accountID == filters.accountID else { return false }
            guard !filters.favoritesOnly || domain.isFavorite else { return false }
            guard filters.projectID == nil || domain.projectID == filters.projectID else { return false }
            if let provider = filters.provider {
                guard account(id: domain.accountID)?.provider == provider else { return false }
            }
            if let tagID = filters.tagID {
                guard tagLinks.contains(where: { $0.domainID == domain.id && $0.tagID == tagID }) else { return false }
            }
            guard !query.isEmpty else { return true }

            let projectName = projects.first(where: { $0.id == domain.projectID })?.name ?? ""
            let tagNames = tagsForDomain(domain.id).map(\.name).joined(separator: " ")
            let accountName = account(id: domain.accountID)?.name ?? ""
            return [domain.name, domain.note, projectName, tagNames, accountName]
                .contains { $0.localizedStandardContains(query) }
        }
    }

    func globalSearch(_ text: String) -> GlobalSearchResults {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return GlobalSearchResults(domains: [], records: []) }

        let domainResults = domains.compactMap { domain -> DomainSearchResult? in
            let project = projects.first { $0.id == domain.projectID }
            let domainTags = tagsForDomain(domain.id)
            let values = [domain.name, domain.note, project?.name ?? ""] + domainTags.map(\.name)
            guard values.contains(where: { $0.localizedStandardContains(query) }) else { return nil }
            return DomainSearchResult(domain: domain, account: account(id: domain.accountID), project: project, tags: domainTags)
        }

        let recordResults = recordIndex.compactMap { entry -> RecordSearchResult? in
            let values = [entry.domainName, entry.name, entry.typeRawValue, entry.value]
            guard values.contains(where: { $0.localizedStandardContains(query) }) else { return nil }
            return RecordSearchResult(entry: entry, account: account(id: entry.accountID))
        }

        return GlobalSearchResults(domains: domainResults, records: recordResults)
    }

    func reverseLookup(ipAddress: String) -> [RecordSearchResult] {
        let ip = ipAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        return recordIndex.compactMap { entry in
            guard (entry.recordType == .a || entry.recordType == .aaaa), entry.value == ip else { return nil }
            return RecordSearchResult(entry: entry, account: account(id: entry.accountID))
        }
    }

    func account(id: UUID) -> DNSAccount? {
        accounts.first { $0.id == id }
    }

    func domain(id: UUID) -> ManagedDomain? {
        domains.first { $0.id == id }
    }

    func project(id: UUID?) -> DNSProject? {
        guard let id else { return nil }
        return projects.first { $0.id == id }
    }

    func tagsForDomain(_ domainID: UUID) -> [DNSTag] {
        let tagIDs = Set(tagLinks.filter { $0.domainID == domainID }.map(\.tagID))
        return tags.filter { tagIDs.contains($0.id) }
    }

    func canRestore(_ operation: DNSOperationLog) -> Bool {
        operation.status == .success
            && operation.restoreSourceOperationID == nil
            && [.createRecord, .updateRecord, .deleteRecord].contains(operation.action)
    }

    func capabilities(for domainID: UUID) throws -> DNSProviderCapabilities {
        try providerContext(domainID: domainID).2.capabilities
    }

    private func indexedRecords(domainID: UUID) -> [ProviderDNSRecord] {
        recordIndex
            .filter { $0.domainID == domainID }
            .map(\.providerRecord)
            .sorted {
                if $0.name == $1.name { return $0.type.rawValue < $1.type.rawValue }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
    }

    private func providerContext(domainID: UUID) throws -> (ManagedDomain, DNSAccount, any DNSProvider) {
        guard let domain = domain(id: domainID), let account = account(id: domain.accountID) else {
            throw DNSProviderError.domainNotFound
        }
        return (domain, account, try providerRegistry.provider(for: account, credentialStore: credentialStore))
    }

    private func replaceIndex(for domain: ManagedDomain, with records: [ProviderDNSRecord]) {
        for entry in recordIndex where entry.domainID == domain.id {
            context.delete(entry)
        }
        let now = Date.now
        for record in records {
            context.insert(
                DNSRecordIndexEntry(
                    accountID: domain.accountID,
                    domainID: domain.id,
                    domainName: domain.name,
                    record: record,
                    lastSyncedAt: now
                )
            )
        }
        domain.recordCount = records.count
        domain.recordsLastSyncedAt = now
        domain.updatedAt = now
    }

    private func upsertIndex(accountID: UUID, domain: ManagedDomain, record: ProviderDNSRecord) {
        if let entry = recordIndex.first(where: {
            $0.domainID == domain.id && $0.providerRecordID == record.id
        }) {
            entry.name = record.name
            entry.typeRawValue = record.type.rawValue
            entry.value = record.value
            entry.ttl = record.ttl
            entry.line = record.line
            entry.priority = record.priority
            entry.weight = record.weight
            entry.isEnabled = record.isEnabled
            entry.lastSyncedAt = .now
        } else {
            context.insert(
                DNSRecordIndexEntry(
                    accountID: accountID,
                    domainID: domain.id,
                    domainName: domain.name,
                    record: record
                )
            )
        }
    }

    private func beginOperation(
        accountID: UUID,
        domain: ManagedDomain? = nil,
        action: DNSOperationAction,
        providerRecordID: String? = nil,
        restoreSourceOperationID: UUID? = nil
    ) -> DNSOperationLog {
        let operation = DNSOperationLog(
            accountID: accountID,
            domainID: domain?.id,
            domainName: domain?.name ?? "",
            action: action,
            providerRecordID: providerRecordID,
            restoreSourceOperationID: restoreSourceOperationID
        )
        context.insert(operation)
        return operation
    }

    private func finish(_ operation: DNSOperationLog, status: DNSOperationStatus, message: String) {
        operation.status = status
        operation.message = message
        operation.completedAt = .now
    }

    private func insertSnapshot(
        operationID: UUID,
        before: ProviderDNSRecord?,
        after: ProviderDNSRecord?
    ) {
        context.insert(
            DNSSnapshot(
                operationID: operationID,
                beforeData: before.flatMap { try? JSONEncoder().encode($0) },
                afterData: after.flatMap { try? JSONEncoder().encode($0) }
            )
        )
    }

    private func snapshot(operationID: UUID) -> DNSSnapshot? {
        let snapshots = (try? context.fetch(FetchDescriptor<DNSSnapshot>())) ?? []
        return snapshots.first { $0.operationID == operationID }
    }

    private func decodeRecord(_ data: Data?) -> ProviderDNSRecord? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(ProviderDNSRecord.self, from: data)
    }

    private func validateAccountName(_ name: String) throws {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            throw DNSProviderError.provider("账号名称不能为空")
        }
        guard !accounts.contains(where: { $0.name.caseInsensitiveCompare(cleanName) == .orderedSame }) else {
            throw DNSProviderError.provider("账号名称已存在")
        }
    }

    private func safeMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            return description
        }
        return "操作失败，请检查网络与服务商状态。"
    }
}
