import SwiftData
import XCTest
@testable import DeveloperAssistant

@MainActor
final class OperationsStoreTests: XCTestCase {
    func testCertificateLifecycleAndStatus() throws {
        let store = OperationsStore(container: try AppDatabase.makeContainer(inMemory: true))
        var draft = CertificateDraft()
        draft.name = "官网证书"; draft.domains = "example.com"; draft.issuer = "Let's Encrypt"
        draft.expiresAt = Calendar.current.date(byAdding: .day, value: 10, to: .now)!
        try store.saveCertificate(draft)
        XCTAssertEqual(store.certificates.count, 1)
        XCTAssertEqual(store.certificates[0].status, .expiring)
        draft.name = "生产证书"
        try store.saveCertificate(draft, id: store.certificates[0].id)
        XCTAssertEqual(store.certificates[0].name, "生产证书")
        try store.deleteCertificate(store.certificates[0].id)
        XCTAssertTrue(store.certificates.isEmpty)
    }

    func testDeploymentPersistsServerRelation() throws {
        let store = OperationsStore(container: try AppDatabase.makeContainer(inMemory: true))
        let serverID = UUID()
        var draft = DeploymentDraft()
        draft.project = "官网"; draft.version = "v1.2.0"; draft.serverID = serverID; draft.result = .rolledBack
        try store.addDeployment(draft)
        XCTAssertEqual(store.deployments.first?.serverID, serverID)
        XCTAssertEqual(store.deployments.first?.result, .rolledBack)
    }
}
