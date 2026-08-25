import Foundation

enum GitAuthenticationMode: String, Codable, CaseIterable, Identifiable {
    case httpsToken, ssh
    var id: String { rawValue }
    var title: String { self == .httpsToken ? "HTTPS Token" : "SSH（本机配置）" }
}

struct GitBackupConfiguration: Codable, Equatable {
    var repositoryURL = ""
    var branch = "backup/macos"
    var authenticationMode: GitAuthenticationMode = .httpsToken
    var accountName = "git"
}

struct GitBackupManifest: Codable, Equatable {
    let format: String
    let schemaVersion: Int
    let platform: String
    let createdAt: Date
    let payloadSHA256: String
    let encryption: String
}

struct EncryptedBackupEnvelope: Codable {
    let version: Int
    let salt: Data
    let sealedData: Data
}

struct PortableBackupPackage: Codable {
    let schemaVersion: Int
    let createdAt: Date
    let dnsAccounts: [DNSAccountBackup]
    let domains: [DomainBackup]
    let projects: [ProjectBackup]
    let tags: [TagBackup]
    let domainTags: [DomainTagBackup]
    let servers: [ServerBackup]
    let certificates: [CertificateBackup]
    let deployments: [DeploymentBackup]

    struct DNSAccountBackup: Codable { let id: UUID; let provider: String; let name: String }
    struct DomainBackup: Codable { let id: UUID; let accountID: UUID; let providerDomainID: String; let name: String; let projectID: UUID?; let note: String; let isFavorite: Bool; let isActive: Bool; let expiresAt: Date? }
    struct ProjectBackup: Codable { let id: UUID; let name: String; let colorName: String }
    struct TagBackup: Codable { let id: UUID; let name: String; let colorName: String }
    struct DomainTagBackup: Codable { let domainID: UUID; let tagID: UUID }
    struct ServerBackup: Codable { let id: UUID; let name: String; let provider: String; let host: String; let port: Int; let username: String; let environment: String; let project: String; let region: String; let operatingSystem: String; let tags: String; let note: String; let expiresAt: Date?; let isFavorite: Bool }
    struct CertificateBackup: Codable { let id: UUID; let name: String; let domains: String; let issuer: String; let expiresAt: Date; let deploymentLocation: String; let note: String }
    struct DeploymentBackup: Codable { let id: UUID; let project: String; let version: String; let environment: String; let result: String; let serverID: UUID?; let operatorName: String; let deployedAt: Date; let summary: String; let rollbackVersion: String }
}

struct GitBackupRevision: Identifiable, Hashable {
    let id: String
    let date: Date?
    let subject: String
}
