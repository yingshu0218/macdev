import Foundation

protocol DNSProvider: Sendable {
    var kind: DNSProviderKind { get }
    var capabilities: DNSProviderCapabilities { get }

    func testConnection() async throws -> Int
    func listDomains() async throws -> [ProviderDomain]
    func listRecords(domain: String) async throws -> [ProviderDNSRecord]
    func createRecord(domain: String, draft: DNSRecordDraft) async throws -> ProviderDNSRecord
    func updateRecord(domain: String, recordID: String, draft: DNSRecordDraft) async throws -> ProviderDNSRecord
    func deleteRecord(domain: String, recordID: String) async throws
}

enum DNSProviderError: LocalizedError, Equatable {
    case authenticationFailed
    case permissionDenied
    case domainNotFound
    case recordNotFound
    case invalidRecord(String)
    case rateLimited
    case network(String)
    case provider(String)
    case unsupportedProvider

    var errorDescription: String? {
        switch self {
        case .authenticationFailed: "凭证无效或已过期。"
        case .permissionDenied: "当前凭证没有执行此操作的权限。"
        case .domainNotFound: "服务商中不存在这个域名。"
        case .recordNotFound: "服务商中不存在这条解析记录。"
        case .invalidRecord(let message): "解析记录无效：\(message)"
        case .rateLimited: "服务商请求过于频繁，请稍后再试。"
        case .network(let message): "网络请求失败：\(message)"
        case .provider(let message): "服务商返回错误：\(message)"
        case .unsupportedProvider: "当前版本尚未实现这个服务商。"
        }
    }
}

enum DNSRecordValidator {
    static func validate(_ draft: DNSRecordDraft, capabilities: DNSProviderCapabilities) throws {
        let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let value = draft.value.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty else {
            throw DNSProviderError.invalidRecord("主机记录不能为空")
        }
        guard !value.isEmpty else {
            throw DNSProviderError.invalidRecord("记录值不能为空")
        }
        guard capabilities.supportedRecordTypes.contains(draft.type) else {
            throw DNSProviderError.invalidRecord("服务商不支持 \(draft.type.rawValue) 类型")
        }
        guard capabilities.ttlRange.contains(draft.ttl) else {
            throw DNSProviderError.invalidRecord("TTL 必须在 \(capabilities.ttlRange.lowerBound)–\(capabilities.ttlRange.upperBound) 之间")
        }
        if draft.type.requiresPriority, draft.priority == nil {
            throw DNSProviderError.invalidRecord("\(draft.type.rawValue) 记录需要优先级")
        }
    }
}
