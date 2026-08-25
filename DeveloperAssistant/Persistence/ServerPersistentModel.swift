import Foundation
import SwiftData

@Model
final class ManagedServer {
    var id: UUID
    var name: String
    var providerRawValue: String
    var host: String
    var port: Int
    var username: String
    var environmentRawValue: String
    var project: String
    var region: String
    var operatingSystem: String
    var tags: String
    var note: String
    var statusRawValue: String
    var latencyMilliseconds: Int?
    var lastCheckedAt: Date?
    var expiresAt: Date?
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        draft: ServerDraft,
        status: ServerHealthStatus = .unknown,
        latencyMilliseconds: Int? = nil,
        lastCheckedAt: Date? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = draft.name
        self.providerRawValue = draft.provider.rawValue
        self.host = draft.host
        self.port = draft.port
        self.username = draft.username
        self.environmentRawValue = draft.environment.rawValue
        self.project = draft.project
        self.region = draft.region
        self.operatingSystem = draft.operatingSystem
        self.tags = draft.tags
        self.note = draft.note
        self.statusRawValue = status.rawValue
        self.latencyMilliseconds = latencyMilliseconds
        self.lastCheckedAt = lastCheckedAt
        self.expiresAt = draft.expiresAt
        self.isFavorite = draft.isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var provider: ServerProvider {
        get { ServerProvider(rawValue: providerRawValue) ?? .other }
        set { providerRawValue = newValue.rawValue }
    }

    var environment: ServerEnvironment {
        get { ServerEnvironment(rawValue: environmentRawValue) ?? .production }
        set { environmentRawValue = newValue.rawValue }
    }

    var status: ServerHealthStatus {
        get { ServerHealthStatus(rawValue: statusRawValue) ?? .unknown }
        set { statusRawValue = newValue.rawValue }
    }

    var draft: ServerDraft {
        ServerDraft(
            name: name,
            provider: provider,
            host: host,
            port: port,
            username: username,
            environment: environment,
            project: project,
            region: region,
            operatingSystem: operatingSystem,
            tags: tags,
            note: note,
            expiresAt: expiresAt,
            isFavorite: isFavorite
        )
    }

    var sshCommand: String {
        let cleanUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let destination = cleanUsername.isEmpty ? host : "\(cleanUsername)@\(host)"
        return port == 22 ? "ssh \(destination)" : "ssh -p \(port) \(destination)"
    }

    var tagList: [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func apply(_ draft: ServerDraft) {
        name = draft.name
        provider = draft.provider
        host = draft.host
        port = draft.port
        username = draft.username
        environment = draft.environment
        project = draft.project
        region = draft.region
        operatingSystem = draft.operatingSystem
        tags = draft.tags
        note = draft.note
        expiresAt = draft.expiresAt
        isFavorite = draft.isFavorite
        updatedAt = .now
    }
}
