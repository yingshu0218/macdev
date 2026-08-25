import Foundation

enum DNSProviderKind: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case dnspod
    case alidns
    case mock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dnspod: "DNSPod"
        case .alidns: "阿里云 DNS"
        case .mock: "本地演示"
        }
    }

    var systemImage: String {
        switch self {
        case .dnspod: "cloud"
        case .alidns: "cloud.fill"
        case .mock: "macwindow"
        }
    }
}

enum DNSAccountStatus: String, Codable, CaseIterable, Sendable {
    case connected
    case needsAttention
    case syncing
    case disabled

    var title: String {
        switch self {
        case .connected: "已连接"
        case .needsAttention: "需要处理"
        case .syncing: "同步中"
        case .disabled: "已停用"
        }
    }
}

enum DNSRecordType: String, Codable, CaseIterable, Hashable, Identifiable, Sendable {
    case a = "A"
    case aaaa = "AAAA"
    case cname = "CNAME"
    case mx = "MX"
    case txt = "TXT"
    case ns = "NS"
    case srv = "SRV"
    case caa = "CAA"

    var id: String { rawValue }

    var requiresPriority: Bool {
        self == .mx || self == .srv
    }
}

enum DNSOperationAction: String, Codable, CaseIterable, Sendable {
    case createRecord
    case updateRecord
    case deleteRecord
    case restore
    case syncDomains
    case syncRecords

    var title: String {
        switch self {
        case .createRecord: "新增解析"
        case .updateRecord: "修改解析"
        case .deleteRecord: "删除解析"
        case .restore: "恢复操作"
        case .syncDomains: "同步域名"
        case .syncRecords: "同步解析"
        }
    }
}

enum DNSOperationStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case success
    case failed

    var title: String {
        switch self {
        case .pending: "执行中"
        case .success: "成功"
        case .failed: "失败"
        }
    }
}

struct DNSProviderCredential: Codable, Equatable, Sendable {
    let provider: DNSProviderKind
    let accessKeyID: String
    let accessKeySecret: String

    var isComplete: Bool {
        switch provider {
        case .dnspod, .alidns:
            !accessKeyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !accessKeySecret.isEmpty
        case .mock:
            true
        }
    }
}

struct ProviderDomain: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let recordCount: Int?
    let expiresAt: Date?
}

struct DNSRecordDraft: Codable, Hashable, Sendable {
    var name: String
    var type: DNSRecordType
    var value: String
    var ttl: Int
    var line: String?
    var priority: Int?
    var weight: Int?
    var isEnabled: Bool

    static let empty = DNSRecordDraft(
        name: "@",
        type: .a,
        value: "",
        ttl: 600,
        line: nil,
        priority: nil,
        weight: nil,
        isEnabled: true
    )
}

struct ProviderDNSRecord: Codable, Hashable, Identifiable, Sendable {
    let id: String
    var name: String
    var type: DNSRecordType
    var value: String
    var ttl: Int
    var line: String?
    var priority: Int?
    var weight: Int?
    var isEnabled: Bool

    var draft: DNSRecordDraft {
        DNSRecordDraft(
            name: name,
            type: type,
            value: value,
            ttl: ttl,
            line: line,
            priority: priority,
            weight: weight,
            isEnabled: isEnabled
        )
    }
}

struct DNSProviderCapabilities: Sendable {
    let supportedRecordTypes: Set<DNSRecordType>
    let supportsLine: Bool
    let supportsWeight: Bool
    let supportsDisableRecord: Bool
    let ttlRange: ClosedRange<Int>

    static let standard = DNSProviderCapabilities(
        supportedRecordTypes: Set(DNSRecordType.allCases),
        supportsLine: true,
        supportsWeight: true,
        supportsDisableRecord: true,
        ttlRange: 1...86_400
    )
}
