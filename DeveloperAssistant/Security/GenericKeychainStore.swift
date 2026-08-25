import Foundation
import Security

struct GenericKeychainStore: Sendable {
    let service: String

    func save(_ value: String, account: String) throws {
        let data = Data(value.utf8); let query = base(account)
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let add = SecItemAdd(item as CFDictionary, nil); guard add == errSecSuccess else { throw CredentialStoreError.keychain(add) }
        } else if status != errSecSuccess { throw CredentialStoreError.keychain(status) }
    }

    func load(account: String) throws -> String? {
        var query = base(account); query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?; let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw CredentialStoreError.keychain(status) }
        return String(data: data, encoding: .utf8)
    }

    private func base(_ account: String) -> [String: Any] { [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account] }
}
