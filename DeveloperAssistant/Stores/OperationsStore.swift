import Foundation
import Observation
import SwiftData

@MainActor @Observable
final class OperationsStore {
    private let context: ModelContext
    var certificates: [ManagedCertificate] = []
    var deployments: [DeploymentRecord] = []
    var startupErrorMessage: String?
    var lastErrorMessage: String?

    init(container: ModelContainer, startupErrorMessage: String? = nil) {
        context = ModelContext(container); self.startupErrorMessage = startupErrorMessage; reload()
    }

    static func bootstrap() -> OperationsStore {
        do { return OperationsStore(container: try AppDatabase.makeContainer()) }
        catch {
            do { return OperationsStore(container: try AppDatabase.makeContainer(inMemory: true), startupErrorMessage: error.localizedDescription) }
            catch { preconditionFailure("无法创建运维数据库：\(error)") }
        }
    }

    var expiringCertificateCount: Int { certificates.filter { $0.status != .valid }.count }

    func reload() {
        do {
            certificates = try context.fetch(FetchDescriptor<ManagedCertificate>()).sorted { $0.expiresAt < $1.expiresAt }
            deployments = try context.fetch(FetchDescriptor<DeploymentRecord>()).sorted { $0.deployedAt > $1.deployedAt }
            lastErrorMessage = nil
        } catch { lastErrorMessage = error.localizedDescription }
    }

    func saveCertificate(_ draft: CertificateDraft, id: UUID? = nil) throws {
        var draft = draft
        draft.name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.domains = draft.domains.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.name.isEmpty, !draft.domains.isEmpty else { throw ValidationError.required }
        if let id, let item = certificates.first(where: { $0.id == id }) { item.apply(draft) }
        else { context.insert(ManagedCertificate(draft: draft)) }
        try context.save(); reload()
    }

    func deleteCertificate(_ id: UUID) throws {
        if let item = certificates.first(where: { $0.id == id }) { context.delete(item); try context.save(); reload() }
    }

    func addDeployment(_ draft: DeploymentDraft) throws {
        var draft = draft
        draft.project = draft.project.trimmingCharacters(in: .whitespacesAndNewlines)
        draft.version = draft.version.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !draft.project.isEmpty, !draft.version.isEmpty else { throw ValidationError.required }
        context.insert(DeploymentRecord(draft: draft)); try context.save(); reload()
    }

    func deleteDeployment(_ id: UUID) throws {
        if let item = deployments.first(where: { $0.id == id }) { context.delete(item); try context.save(); reload() }
    }

    enum ValidationError: LocalizedError { case required; var errorDescription: String? { "名称、域名、项目或版本等必填信息不能为空。" } }
}
