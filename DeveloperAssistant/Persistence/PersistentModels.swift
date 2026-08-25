import Foundation
import SwiftData

@Model
final class DNSAccount {
    var id: UUID
    var providerRawValue: String
    var name: String
    var statusRawValue: String
    var domainCount: Int
    var lastTestedAt: Date?
    var lastSyncedAt: Date?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        provider: DNSProviderKind,
        name: String,
        status: DNSAccountStatus = .connected,
        domainCount: Int = 0,
        lastTestedAt: Date? = nil,
        lastSyncedAt: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.providerRawValue = provider.rawValue
        self.name = name
        self.statusRawValue = status.rawValue
        self.domainCount = domainCount
        self.lastTestedAt = lastTestedAt
        self.lastSyncedAt = lastSyncedAt
        self.createdAt = createdAt
    }

    var provider: DNSProviderKind {
        get { DNSProviderKind(rawValue: providerRawValue) ?? .mock }
        set { providerRawValue = newValue.rawValue }
    }

    var status: DNSAccountStatus {
        get { DNSAccountStatus(rawValue: statusRawValue) ?? .needsAttention }
        set { statusRawValue = newValue.rawValue }
    }
}

@Model
final class ManagedDomain {
    var id: UUID
    var accountID: UUID
    var providerDomainID: String
    var name: String
    var projectID: UUID?
    var note: String
    var isFavorite: Bool
    var isActive: Bool
    var expiresAt: Date?
    var recordCount: Int?
    var lastSyncedAt: Date?
    var recordsLastSyncedAt: Date?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        accountID: UUID,
        providerDomainID: String,
        name: String,
        projectID: UUID? = nil,
        note: String = "",
        isFavorite: Bool = false,
        isActive: Bool = true,
        expiresAt: Date? = nil,
        recordCount: Int? = nil,
        lastSyncedAt: Date? = nil,
        recordsLastSyncedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.accountID = accountID
        self.providerDomainID = providerDomainID
        self.name = name
        self.projectID = projectID
        self.note = note
        self.isFavorite = isFavorite
        self.isActive = isActive
        self.expiresAt = expiresAt
        self.recordCount = recordCount
        self.lastSyncedAt = lastSyncedAt
        self.recordsLastSyncedAt = recordsLastSyncedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class DNSProject {
    var id: UUID
    var name: String
    var colorName: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorName: String = "blue",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class DNSTag {
    var id: UUID
    var name: String
    var colorName: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        colorName: String = "blue",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.colorName = colorName
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class DomainTagLink {
    var id: UUID
    var domainID: UUID
    var tagID: UUID

    init(id: UUID = UUID(), domainID: UUID, tagID: UUID) {
        self.id = id
        self.domainID = domainID
        self.tagID = tagID
    }
}

@Model
final class DNSRecordIndexEntry {
    var id: UUID
    var accountID: UUID
    var domainID: UUID
    var domainName: String
    var providerRecordID: String
    var name: String
    var typeRawValue: String
    var value: String
    var ttl: Int
    var line: String?
    var priority: Int?
    var weight: Int?
    var isEnabled: Bool
    var lastSyncedAt: Date

    init(
        id: UUID = UUID(),
        accountID: UUID,
        domainID: UUID,
        domainName: String,
        record: ProviderDNSRecord,
        lastSyncedAt: Date = .now
    ) {
        self.id = id
        self.accountID = accountID
        self.domainID = domainID
        self.domainName = domainName
        self.providerRecordID = record.id
        self.name = record.name
        self.typeRawValue = record.type.rawValue
        self.value = record.value
        self.ttl = record.ttl
        self.line = record.line
        self.priority = record.priority
        self.weight = record.weight
        self.isEnabled = record.isEnabled
        self.lastSyncedAt = lastSyncedAt
    }

    var recordType: DNSRecordType {
        DNSRecordType(rawValue: typeRawValue) ?? .a
    }

    var providerRecord: ProviderDNSRecord {
        ProviderDNSRecord(
            id: providerRecordID,
            name: name,
            type: recordType,
            value: value,
            ttl: ttl,
            line: line,
            priority: priority,
            weight: weight,
            isEnabled: isEnabled
        )
    }
}

@Model
final class DNSSnapshot {
    var id: UUID
    var operationID: UUID
    var beforeData: Data?
    var afterData: Data?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        operationID: UUID,
        beforeData: Data?,
        afterData: Data?,
        createdAt: Date = .now
    ) {
        self.id = id
        self.operationID = operationID
        self.beforeData = beforeData
        self.afterData = afterData
        self.createdAt = createdAt
    }
}

@Model
final class DNSOperationLog {
    var id: UUID
    var accountID: UUID
    var domainID: UUID?
    var domainName: String
    var actionRawValue: String
    var statusRawValue: String
    var providerRecordID: String?
    var message: String
    var restoreSourceOperationID: UUID?
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        accountID: UUID,
        domainID: UUID? = nil,
        domainName: String = "",
        action: DNSOperationAction,
        status: DNSOperationStatus = .pending,
        providerRecordID: String? = nil,
        message: String = "",
        restoreSourceOperationID: UUID? = nil,
        createdAt: Date = .now,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.domainID = domainID
        self.domainName = domainName
        self.actionRawValue = action.rawValue
        self.statusRawValue = status.rawValue
        self.providerRecordID = providerRecordID
        self.message = message
        self.restoreSourceOperationID = restoreSourceOperationID
        self.createdAt = createdAt
        self.completedAt = completedAt
    }

    var action: DNSOperationAction {
        get { DNSOperationAction(rawValue: actionRawValue) ?? .syncDomains }
        set { actionRawValue = newValue.rawValue }
    }

    var status: DNSOperationStatus {
        get { DNSOperationStatus(rawValue: statusRawValue) ?? .failed }
        set { statusRawValue = newValue.rawValue }
    }
}
