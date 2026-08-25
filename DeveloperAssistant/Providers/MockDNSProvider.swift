import Foundation

actor MockDNSProvider: DNSProvider {
    nonisolated let kind = DNSProviderKind.mock
    nonisolated let capabilities = DNSProviderCapabilities.standard

    private var domains: [ProviderDomain]
    private var recordsByDomain: [String: [ProviderDNSRecord]]
    private var nextRecordID = 100

    nonisolated static func stableSeed(for accountID: UUID) -> Int {
        let hash = accountID.uuidString.utf8.reduce(2_166_136_261) { value, byte in
            (value ^ Int(byte)) &* 16_777_619
        }
        return (hash & 0x7fff_ffff) % 10_000
    }

    init(seed: Int = 0) {
        let suffix = seed == 0 ? "" : "-\(seed)"
        let firstDomain = "example\(suffix).com"
        let secondDomain = "dev-helper\(suffix).app"

        domains = [
            ProviderDomain(id: "domain-1\(suffix)", name: firstDomain, recordCount: 3, expiresAt: Calendar.current.date(byAdding: .day, value: 120, to: .now)),
            ProviderDomain(id: "domain-2\(suffix)", name: secondDomain, recordCount: 2, expiresAt: nil)
        ]
        recordsByDomain = [
            firstDomain: [
                ProviderDNSRecord(id: "1", name: "@", type: .a, value: "203.0.113.10", ttl: 600, line: "默认", priority: nil, weight: nil, isEnabled: true),
                ProviderDNSRecord(id: "2", name: "www", type: .cname, value: "example.com.", ttl: 600, line: "默认", priority: nil, weight: nil, isEnabled: true),
                ProviderDNSRecord(id: "3", name: "@", type: .txt, value: "v=spf1 -all", ttl: 600, line: "默认", priority: nil, weight: nil, isEnabled: true)
            ],
            secondDomain: [
                ProviderDNSRecord(id: "4", name: "@", type: .aaaa, value: "2001:db8::10", ttl: 600, line: "默认", priority: nil, weight: nil, isEnabled: true),
                ProviderDNSRecord(id: "5", name: "api", type: .a, value: "203.0.113.20", ttl: 300, line: "默认", priority: nil, weight: nil, isEnabled: true)
            ]
        ]
    }

    func testConnection() async throws -> Int {
        domains.count
    }

    func listDomains() async throws -> [ProviderDomain] {
        domains
    }

    func listRecords(domain: String) async throws -> [ProviderDNSRecord] {
        guard let records = recordsByDomain[domain] else {
            throw DNSProviderError.domainNotFound
        }
        return records
    }

    func createRecord(domain: String, draft: DNSRecordDraft) async throws -> ProviderDNSRecord {
        try DNSRecordValidator.validate(draft, capabilities: capabilities)
        guard recordsByDomain[domain] != nil else {
            throw DNSProviderError.domainNotFound
        }

        nextRecordID += 1
        let record = ProviderDNSRecord(
            id: String(nextRecordID),
            name: draft.name,
            type: draft.type,
            value: draft.value,
            ttl: draft.ttl,
            line: draft.line,
            priority: draft.priority,
            weight: draft.weight,
            isEnabled: draft.isEnabled
        )
        recordsByDomain[domain, default: []].append(record)
        updateRecordCount(for: domain)
        return record
    }

    func updateRecord(domain: String, recordID: String, draft: DNSRecordDraft) async throws -> ProviderDNSRecord {
        try DNSRecordValidator.validate(draft, capabilities: capabilities)
        guard var records = recordsByDomain[domain] else {
            throw DNSProviderError.domainNotFound
        }
        guard let index = records.firstIndex(where: { $0.id == recordID }) else {
            throw DNSProviderError.recordNotFound
        }

        let record = ProviderDNSRecord(
            id: recordID,
            name: draft.name,
            type: draft.type,
            value: draft.value,
            ttl: draft.ttl,
            line: draft.line,
            priority: draft.priority,
            weight: draft.weight,
            isEnabled: draft.isEnabled
        )
        records[index] = record
        recordsByDomain[domain] = records
        return record
    }

    func deleteRecord(domain: String, recordID: String) async throws {
        guard var records = recordsByDomain[domain] else {
            throw DNSProviderError.domainNotFound
        }
        guard let index = records.firstIndex(where: { $0.id == recordID }) else {
            throw DNSProviderError.recordNotFound
        }
        records.remove(at: index)
        recordsByDomain[domain] = records
        updateRecordCount(for: domain)
    }

    private func updateRecordCount(for domain: String) {
        guard let domainIndex = domains.firstIndex(where: { $0.name == domain }) else { return }
        let existing = domains[domainIndex]
        domains[domainIndex] = ProviderDomain(
            id: existing.id,
            name: existing.name,
            recordCount: recordsByDomain[domain]?.count,
            expiresAt: existing.expiresAt
        )
    }
}
