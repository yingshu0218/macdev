import Foundation
import SwiftData

@Model
final class ManagedCertificate {
    @Attribute(.unique) var id: UUID
    var name: String
    var domains: String
    var issuer: String
    var expiresAt: Date
    var deploymentLocation: String
    var note: String
    var createdAt: Date
    var updatedAt: Date

    init(draft: CertificateDraft) {
        id = UUID(); name = draft.name; domains = draft.domains; issuer = draft.issuer
        expiresAt = draft.expiresAt; deploymentLocation = draft.deploymentLocation; note = draft.note
        createdAt = .now; updatedAt = .now
    }

    var status: CertificateStatus {
        if expiresAt < .now { return .expired }
        let warning = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
        return expiresAt <= warning ? .expiring : .valid
    }

    func apply(_ draft: CertificateDraft) {
        name = draft.name; domains = draft.domains; issuer = draft.issuer; expiresAt = draft.expiresAt
        deploymentLocation = draft.deploymentLocation; note = draft.note; updatedAt = .now
    }
}

@Model
final class DeploymentRecord {
    @Attribute(.unique) var id: UUID
    var project: String
    var version: String
    var environmentRawValue: String
    var resultRawValue: String
    var serverID: UUID?
    var operatorName: String
    var deployedAt: Date
    var summary: String
    var rollbackVersion: String
    var createdAt: Date

    init(draft: DeploymentDraft) {
        id = UUID(); project = draft.project; version = draft.version
        environmentRawValue = draft.environment.rawValue; resultRawValue = draft.result.rawValue
        serverID = draft.serverID; operatorName = draft.operatorName; deployedAt = draft.deployedAt
        summary = draft.summary; rollbackVersion = draft.rollbackVersion; createdAt = .now
    }

    var environment: DeploymentEnvironment { DeploymentEnvironment(rawValue: environmentRawValue) ?? .production }
    var result: DeploymentResult { DeploymentResult(rawValue: resultRawValue) ?? .succeeded }
}
