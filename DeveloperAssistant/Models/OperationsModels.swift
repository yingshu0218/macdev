import Foundation

enum CertificateStatus: String, Codable, CaseIterable, Identifiable {
    case valid, expiring, expired
    var id: String { rawValue }
    var title: String { switch self { case .valid: "有效"; case .expiring: "即将到期"; case .expired: "已过期" } }
    var systemImage: String { switch self { case .valid: "checkmark.shield.fill"; case .expiring: "calendar.badge.exclamationmark"; case .expired: "xmark.shield.fill" } }
}

struct CertificateDraft {
    var name = ""
    var domains = ""
    var issuer = ""
    var expiresAt = Calendar.current.date(byAdding: .month, value: 3, to: .now) ?? .now
    var deploymentLocation = ""
    var note = ""
}

enum DeploymentEnvironment: String, Codable, CaseIterable, Identifiable {
    case production, staging, testing, development
    var id: String { rawValue }
    var title: String { switch self { case .production: "生产"; case .staging: "预发布"; case .testing: "测试"; case .development: "开发" } }
}

enum DeploymentResult: String, Codable, CaseIterable, Identifiable {
    case succeeded, failed, rolledBack, running
    var id: String { rawValue }
    var title: String { switch self { case .succeeded: "成功"; case .failed: "失败"; case .rolledBack: "已回滚"; case .running: "进行中" } }
    var systemImage: String { switch self { case .succeeded: "checkmark.circle.fill"; case .failed: "xmark.circle.fill"; case .rolledBack: "arrow.uturn.backward.circle.fill"; case .running: "clock.fill" } }
}

struct DeploymentDraft {
    var project = ""
    var version = ""
    var environment: DeploymentEnvironment = .production
    var result: DeploymentResult = .succeeded
    var serverID: UUID?
    var operatorName = ""
    var deployedAt = Date.now
    var summary = ""
    var rollbackVersion = ""
}
