import XCTest
@testable import DeveloperAssistant

@MainActor
final class ServerStoreTests: XCTestCase {
    func testServerLifecyclePersistsNormalizedDraft() throws {
        let store = ServerStore(container: try AppDatabase.makeContainer(inMemory: true))
        let server = try store.add(
            ServerDraft(
                name: "  Production API  ",
                provider: .aliyun,
                host: "  api.example.com  ",
                port: 2222,
                username: " deploy ",
                environment: .production,
                project: " Website ",
                region: " Hangzhou ",
                operatingSystem: " Ubuntu 24.04 ",
                tags: "Web, API",
                note: " Primary node ",
                isFavorite: true
            )
        )

        XCTAssertEqual(server.name, "Production API")
        XCTAssertEqual(server.host, "api.example.com")
        XCTAssertEqual(server.sshCommand, "ssh -p 2222 deploy@api.example.com")
        XCTAssertEqual(store.servers.count, 1)

        var updated = server.draft
        updated.name = "Production API 2"
        updated.environment = .staging
        try store.update(serverID: server.id, draft: updated)
        XCTAssertEqual(store.server(id: server.id)?.name, "Production API 2")
        XCTAssertEqual(store.server(id: server.id)?.environment, .staging)

        try store.delete(serverID: server.id)
        XCTAssertTrue(store.servers.isEmpty)
    }

    func testValidationRejectsMissingHostAndInvalidPort() throws {
        let store = ServerStore(container: try AppDatabase.makeContainer(inMemory: true))

        XCTAssertThrowsError(try store.add(ServerDraft(name: "Server"))) { error in
            XCTAssertEqual(error as? ServerValidationError, .missingHost)
        }

        XCTAssertThrowsError(
            try store.add(ServerDraft(name: "Server", host: "example.com", port: 70_000))
        ) { error in
            XCTAssertEqual(error as? ServerValidationError, .invalidPort)
        }
    }
}
