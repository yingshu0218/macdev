import Foundation
import SwiftData

enum AppDatabase {
    static let schema = Schema([
        DNSAccount.self,
        ManagedDomain.self,
        DNSProject.self,
        DNSTag.self,
        DomainTagLink.self,
        DNSRecordIndexEntry.self,
        DNSSnapshot.self,
        DNSOperationLog.self,
        ManagedServer.self,
        ManagedCertificate.self,
        DeploymentRecord.self
    ])

    static var storageDirectoryURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "DeveloperAssistant", directoryHint: .isDirectory)
    }

    static var storeURL: URL {
        storageDirectoryURL.appending(path: "DeveloperAssistant.sqlite")
    }

    static var backupDirectoryURL: URL {
        storageDirectoryURL.appending(path: "Backups", directoryHint: .isDirectory)
    }

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                "DeveloperAssistant",
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            try FileManager.default.createDirectory(
                at: storageDirectoryURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            configuration = ModelConfiguration(
                "DeveloperAssistant",
                schema: schema,
                url: storeURL
            )
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    static func createBackup() throws -> URL {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        let destination = backupDirectoryURL
            .appending(path: "backup-\(formatter.string(from: .now))", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: destination,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let sourceFiles = [
            storeURL,
            URL(fileURLWithPath: storeURL.path + "-wal"),
            URL(fileURLWithPath: storeURL.path + "-shm")
        ]
        var copiedAnyFile = false
        for source in sourceFiles where FileManager.default.fileExists(atPath: source.path) {
            try FileManager.default.copyItem(
                at: source,
                to: destination.appending(path: source.lastPathComponent)
            )
            copiedAnyFile = true
        }
        guard copiedAnyFile else {
            throw CocoaError(.fileNoSuchFile)
        }
        return destination
    }
}
