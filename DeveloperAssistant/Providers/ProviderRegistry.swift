import Foundation

@MainActor
final class ProviderRegistry {
    private var providers: [UUID: any DNSProvider] = [:]

    func register(_ provider: any DNSProvider, for accountID: UUID) {
        providers[accountID] = provider
    }

    func remove(accountID: UUID) {
        providers.removeValue(forKey: accountID)
    }

    func provider(
        for account: DNSAccount,
        credentialStore: any CredentialStore
    ) throws -> any DNSProvider {
        if let provider = providers[account.id] {
            return provider
        }

        switch account.provider {
        case .mock:
            let provider = MockDNSProvider(seed: MockDNSProvider.stableSeed(for: account.id))
            providers[account.id] = provider
            return provider
        case .dnspod:
            guard let credential = try credentialStore.load(for: account.id) else {
                throw DNSProviderError.authenticationFailed
            }
            let provider = TencentCloudDNSProvider(credential: credential)
            providers[account.id] = provider
            return provider
        case .alidns:
            guard let credential = try credentialStore.load(for: account.id) else {
                throw DNSProviderError.authenticationFailed
            }
            let provider = AlibabaCloudDNSProvider(credential: credential)
            providers[account.id] = provider
            return provider
        }
    }
}
