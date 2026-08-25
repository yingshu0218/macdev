import SwiftData
import XCTest
@testable import DeveloperAssistant

final class DNSProviderTests: XCTestCase {
    func testAlibabaCloudSignerMatchesOfficialV3Example() throws {
        let formatter = ISO8601DateFormatter()
        let date = try XCTUnwrap(formatter.date(from: "2023-10-26T10:22:32Z"))

        let request = AlibabaCloudSigner.signedRequest(
            host: "ecs.cn-shanghai.aliyuncs.com",
            action: "RunInstances",
            version: "2014-05-26",
            query: ["ImageId": "win2019_1809_x64_dtc_zh-cn_40G_alibase_20230811.vhd", "RegionId": "cn-shanghai"],
            accessKeyID: "YourAccessKeyId",
            accessKeySecret: "YourAccessKeySecret",
            date: date,
            nonce: "3156853299f313e23d1673dc12e1703d"
        )

        let authorization = try XCTUnwrap(request.value(forHTTPHeaderField: "Authorization"))
        XCTAssertTrue(authorization.hasSuffix("Signature=06563a9e1b43f5dfe96b81484da74bceab24a1d853912eee15083a6f0f3283c0"))
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-acs-date"), "2023-10-26T10:22:32Z")
    }

    func testTencentCloudSignerIsDeterministicAndRedactsSecrets() throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let payload = Data("{\"Limit\":1}".utf8)
        let headers = TencentCloudSigner.headers(
            host: "dnspod.tencentcloudapi.com",
            service: "dnspod",
            action: "DescribeDomainList",
            version: "2021-03-23",
            payload: payload,
            secretID: "test-secret-id",
            secretKey: "test-secret-key",
            date: date
        )

        XCTAssertEqual(headers["X-TC-Timestamp"], "1700000000")
        XCTAssertTrue(try XCTUnwrap(headers["Authorization"]).contains("Credential=test-secret-id/2023-11-14/dnspod/tc3_request"))
        XCTAssertFalse(try XCTUnwrap(headers["Authorization"]).contains("test-secret-key"))
    }

    func testValidatorRequiresPriorityForMX() {
        var draft = DNSRecordDraft.empty
        draft.type = .mx
        draft.value = "mail.example.com."

        XCTAssertThrowsError(try DNSRecordValidator.validate(draft, capabilities: .standard)) { error in
            XCTAssertEqual(error as? DNSProviderError, .invalidRecord("MX 记录需要优先级"))
        }
    }

    func testMockProviderCRUD() async throws {
        let provider = MockDNSProvider()
        let domains = try await provider.listDomains()
        let domain = try XCTUnwrap(domains.first?.name)
        let initialRecords = try await provider.listRecords(domain: domain)
        let initialCount = initialRecords.count

        var draft = DNSRecordDraft.empty
        draft.name = "api-v2"
        draft.value = "203.0.113.88"
        let created = try await provider.createRecord(domain: domain, draft: draft)
        let recordsAfterCreate = try await provider.listRecords(domain: domain)
        XCTAssertEqual(recordsAfterCreate.count, initialCount + 1)

        draft.value = "203.0.113.89"
        let updated = try await provider.updateRecord(domain: domain, recordID: created.id, draft: draft)
        XCTAssertEqual(updated.value, "203.0.113.89")

        try await provider.deleteRecord(domain: domain, recordID: created.id)
        let recordsAfterDelete = try await provider.listRecords(domain: domain)
        XCTAssertEqual(recordsAfterDelete.count, initialCount)
    }

    func testMockSeedIsStableForAccountID() {
        let id = UUID(uuidString: "8A4B4B4D-1384-4C30-AF22-DA0FEFF05C99")!
        XCTAssertEqual(MockDNSProvider.stableSeed(for: id), MockDNSProvider.stableSeed(for: id))
        XCTAssertTrue((0..<10_000).contains(MockDNSProvider.stableSeed(for: id)))
    }
}

@MainActor
final class DNSStoreTests: XCTestCase {
    func testDemoConnectionFullRecordLifecycleAndRestore() async throws {
        let container = try AppDatabase.makeContainer(inMemory: true)
        let store = DNSStore(
            container: container,
            credentialStore: InMemoryCredentialStore(),
            providerRegistry: ProviderRegistry()
        )

        _ = try await store.addDemoConnection(name: "测试演示")
        XCTAssertEqual(store.accounts.count, 1)
        XCTAssertEqual(store.domains.count, 2)

        let domain = try XCTUnwrap(store.domains.first)
        let initialRecords = try await store.records(for: domain.id)

        var createRestoreDraft = DNSRecordDraft.empty
        createRestoreDraft.name = "temporary"
        createRestoreDraft.value = "203.0.113.122"
        let temporary = try await store.createRecord(domainID: domain.id, draft: createRestoreDraft)
        let createOperation = try XCTUnwrap(store.operations.first { $0.action == .createRecord && $0.providerRecordID == temporary.id })
        try await store.restore(operationID: createOperation.id)
        let recordsAfterCreateRestore = try await store.records(for: domain.id)
        XCTAssertFalse(recordsAfterCreateRestore.contains { $0.id == temporary.id })

        var draft = DNSRecordDraft.empty
        draft.name = "restore-me"
        draft.value = "203.0.113.123"
        let created = try await store.createRecord(domainID: domain.id, draft: draft)
        XCTAssertTrue(store.globalSearch("203.0.113.123").records.contains { $0.entry.providerRecordID == created.id })
        XCTAssertEqual(store.reverseLookup(ipAddress: "203.0.113.123").count, 1)

        draft.value = "203.0.113.124"
        _ = try await store.updateRecord(domainID: domain.id, recordID: created.id, draft: draft)
        let recordsAfterUpdate = try await store.records(for: domain.id)
        XCTAssertTrue(recordsAfterUpdate.contains { $0.id == created.id && $0.value == "203.0.113.124" })

        let updateOperation = try XCTUnwrap(store.operations.first { $0.action == .updateRecord && $0.providerRecordID == created.id })
        try await store.restore(operationID: updateOperation.id)
        let recordsAfterUpdateRestore = try await store.records(for: domain.id)
        XCTAssertTrue(recordsAfterUpdateRestore.contains { $0.id == created.id && $0.value == "203.0.113.123" })

        try await store.deleteRecord(domainID: domain.id, recordID: created.id)
        let deleteOperation = try XCTUnwrap(store.operations.first { $0.action == .deleteRecord && $0.providerRecordID == created.id })
        try await store.restore(operationID: deleteOperation.id)
        let recordsAfterDeleteRestore = try await store.records(for: domain.id)
        XCTAssertEqual(recordsAfterDeleteRestore.count, initialRecords.count + 1)
    }

    func testProjectsTagsNotesAndFiltering() async throws {
        let store = DNSStore(
            container: try AppDatabase.makeContainer(inMemory: true),
            credentialStore: InMemoryCredentialStore(),
            providerRegistry: ProviderRegistry()
        )
        _ = try await store.addDemoConnection(name: "分类测试")
        let domain = try XCTUnwrap(store.domains.first)
        let project = try store.createProject(name: "官网")
        let tag = try store.createTag(name: "生产")

        try store.updateDomainMetadata(
            domainID: domain.id,
            projectID: project.id,
            tagIDs: [tag.id],
            note: "主站入口"
        )
        try store.setFavorite(domainID: domain.id, isFavorite: true)

        let filters = DomainFilters(projectID: project.id, tagID: tag.id, favoritesOnly: true)
        XCTAssertEqual(store.filteredDomains(searchText: "主站", filters: filters).map(\.id), [domain.id])
        XCTAssertEqual(store.globalSearch("生产").domains.map(\.id), [domain.id])
    }
}
