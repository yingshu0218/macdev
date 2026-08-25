import Foundation

struct DomainSearchResult: Identifiable {
    let domain: ManagedDomain
    let account: DNSAccount?
    let project: DNSProject?
    let tags: [DNSTag]

    var id: UUID { domain.id }
}

struct RecordSearchResult: Identifiable {
    let entry: DNSRecordIndexEntry
    let account: DNSAccount?

    var id: UUID { entry.id }
}

struct GlobalSearchResults {
    let domains: [DomainSearchResult]
    let records: [RecordSearchResult]

    var isEmpty: Bool {
        domains.isEmpty && records.isEmpty
    }
}

struct DomainFilters: Equatable {
    var accountID: UUID?
    var provider: DNSProviderKind?
    var projectID: UUID?
    var tagID: UUID?
    var favoritesOnly = false
}
