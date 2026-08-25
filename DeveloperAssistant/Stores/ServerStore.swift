import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ServerStore {
    private let context: ModelContext
    private let reachability: ServerReachabilityService

    var servers: [ManagedServer] = []
    var checkingServerIDs: Set<UUID> = []
    var startupErrorMessage: String?
    var lastErrorMessage: String?

    init(
        container: ModelContainer,
        reachability: ServerReachabilityService = ServerReachabilityService(),
        startupErrorMessage: String? = nil
    ) {
        self.context = ModelContext(container)
        self.reachability = reachability
        self.startupErrorMessage = startupErrorMessage
        reload()
    }

    static func bootstrap() -> ServerStore {
        do {
            return ServerStore(container: try AppDatabase.makeContainer())
        } catch {
            let message = "服务器资产数据库无法打开，当前使用临时内存数据：\(error.localizedDescription)"
            do {
                return ServerStore(
                    container: try AppDatabase.makeContainer(inMemory: true),
                    startupErrorMessage: message
                )
            } catch {
                preconditionFailure("无法创建服务器资产数据库：\(error)")
            }
        }
    }

    var onlineCount: Int { servers.filter { $0.status == .online }.count }
    var expiringSoonCount: Int {
        let deadline = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
        return servers.filter { server in
            guard let expiresAt = server.expiresAt else { return false }
            return expiresAt <= deadline
        }.count
    }

    func reload() {
        do {
            servers = try context.fetch(FetchDescriptor<ManagedServer>())
                .sorted { lhs, rhs in
                    if lhs.isFavorite != rhs.isFavorite { return lhs.isFavorite }
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            lastErrorMessage = nil
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    @discardableResult
    func add(_ draft: ServerDraft) throws -> ManagedServer {
        let normalized = try validated(draft)
        let server = ManagedServer(draft: normalized)
        context.insert(server)
        try saveAndReload()
        return server
    }

    func update(serverID: UUID, draft: ServerDraft) throws {
        guard let server = server(id: serverID) else { return }
        server.apply(try validated(draft))
        try saveAndReload()
    }

    func delete(serverID: UUID) throws {
        guard let server = server(id: serverID) else { return }
        context.delete(server)
        try saveAndReload()
    }

    func setFavorite(serverID: UUID, isFavorite: Bool) throws {
        guard let server = server(id: serverID) else { return }
        server.isFavorite = isFavorite
        server.updatedAt = .now
        try saveAndReload()
    }

    func check(serverID: UUID) async {
        guard let server = server(id: serverID), !checkingServerIDs.contains(serverID) else { return }
        checkingServerIDs.insert(serverID)
        defer { checkingServerIDs.remove(serverID) }

        let result = await reachability.check(host: server.host, port: server.port)
        switch result {
        case .reachable(let latencyMilliseconds):
            server.status = .online
            server.latencyMilliseconds = latencyMilliseconds
        case .unreachable:
            server.status = .offline
            server.latencyMilliseconds = nil
        }
        server.lastCheckedAt = .now
        server.updatedAt = .now
        do {
            try saveAndReload()
        } catch {
            lastErrorMessage = error.localizedDescription
        }
    }

    func checkAll() async {
        let ids = servers.map(\.id)
        for id in ids {
            await check(serverID: id)
        }
    }

    func server(id: UUID?) -> ManagedServer? {
        guard let id else { return nil }
        return servers.first { $0.id == id }
    }

    private func validated(_ draft: ServerDraft) throws -> ServerDraft {
        var result = draft
        result.name = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.host = result.host.trimmingCharacters(in: .whitespacesAndNewlines)
        result.username = result.username.trimmingCharacters(in: .whitespacesAndNewlines)
        result.project = result.project.trimmingCharacters(in: .whitespacesAndNewlines)
        result.region = result.region.trimmingCharacters(in: .whitespacesAndNewlines)
        result.operatingSystem = result.operatingSystem.trimmingCharacters(in: .whitespacesAndNewlines)
        result.tags = result.tags.trimmingCharacters(in: .whitespacesAndNewlines)
        result.note = result.note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.name.isEmpty else { throw ServerValidationError.missingName }
        guard !result.host.isEmpty else { throw ServerValidationError.missingHost }
        guard (1...65_535).contains(result.port) else { throw ServerValidationError.invalidPort }
        return result
    }

    private func saveAndReload() throws {
        try context.save()
        reload()
    }
}
