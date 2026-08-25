import Foundation
import Security

protocol CredentialStore: Sendable {
    func save(_ credential: DNSProviderCredential, for accountID: UUID) throws
    func load(for accountID: UUID) throws -> DNSProviderCredential?
    func delete(for accountID: UUID) throws
}

enum CredentialStoreError: LocalizedError {
    case encodingFailed
    case decodingFailed
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            "无法加密编码服务商凭证。"
        case .decodingFailed:
            "服务商凭证已损坏，请重新输入。"
        case .keychain(let status):
            "Keychain 操作失败（\(status)）。"
        }
    }
}

final class KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    private let service: String

    init(service: String = "com.infinity.developer-assistant.provider-credentials") {
        self.service = service
    }

    func save(_ credential: DNSProviderCredential, for accountID: UUID) throws {
        guard let data = try? JSONEncoder().encode(credential) else {
            throw CredentialStoreError.encodingFailed
        }

        let query = baseQuery(accountID: accountID)
        let attributes: [String: Any] = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)

        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw CredentialStoreError.keychain(addStatus)
            }
        } else if updateStatus != errSecSuccess {
            throw CredentialStoreError.keychain(updateStatus)
        }
    }

    func load(for accountID: UUID) throws -> DNSProviderCredential? {
        var query = baseQuery(accountID: accountID)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw CredentialStoreError.keychain(status)
        }
        guard let credential = try? JSONDecoder().decode(DNSProviderCredential.self, from: data) else {
            throw CredentialStoreError.decodingFailed
        }
        return credential
    }

    func delete(for accountID: UUID) throws {
        let status = SecItemDelete(baseQuery(accountID: accountID) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.keychain(status)
        }
    }

    private func baseQuery(accountID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: accountID.uuidString
        ]
    }
}

final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [UUID: DNSProviderCredential] = [:]

    func save(_ credential: DNSProviderCredential, for accountID: UUID) throws {
        lock.withLock {
            storage[accountID] = credential
        }
    }

    func load(for accountID: UUID) throws -> DNSProviderCredential? {
        lock.withLock { storage[accountID] }
    }

    func delete(for accountID: UUID) throws {
        _ = lock.withLock {
            storage.removeValue(forKey: accountID)
        }
    }
}
