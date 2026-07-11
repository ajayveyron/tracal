import Foundation
import Security

enum ProviderCredentialError: Error, Hashable, Sendable {
    case missingCredential
    case invalidCredential
    case keychainFailure(OSStatus)
}

protocol ProviderCredentialReading: Sendable {
    func credential(for provider: AIProvider) throws -> String
}

struct ProviderCredentialStore: ProviderCredentialReading, Sendable {
    static let service = "com.ajaypawriya.tracal.ai-provider"
    private static let installationMarker = "publicProviderCredentialsInitialized"

    private let service: String

    init(service: String = Self.service) {
        self.service = service
    }

    func contains(_ provider: AIProvider) -> Bool {
        let query = identity(for: provider).merging([
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]) { _, new in new }
        return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    func credential(for provider: AIProvider) throws -> String {
        let query = identity(for: provider).merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]) { _, new in new }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status != errSecItemNotFound else {
            throw ProviderCredentialError.missingCredential
        }
        guard status == errSecSuccess else {
            throw ProviderCredentialError.keychainFailure(status)
        }
        guard
            let data = result as? Data,
            let value = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            value.count >= 16,
            value.count <= 512
        else {
            throw ProviderCredentialError.invalidCredential
        }
        return value
    }

    func store(_ credential: String, for provider: AIProvider) throws {
        let value = credential.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 16, value.count <= 512, let data = value.data(using: .utf8) else {
            throw ProviderCredentialError.invalidCredential
        }

        let identity = identity(for: provider)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(identity as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw ProviderCredentialError.keychainFailure(updateStatus)
        }

        let insertion = identity.merging(attributes) { _, new in new }
        let insertionStatus = SecItemAdd(insertion as CFDictionary, nil)
        guard insertionStatus == errSecSuccess else {
            throw ProviderCredentialError.keychainFailure(insertionStatus)
        }
    }

    func delete(_ provider: AIProvider) throws {
        let status = SecItemDelete(identity(for: provider) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ProviderCredentialError.keychainFailure(status)
        }
    }

    func deleteAll() throws {
        for provider in AIProvider.allCases {
            try delete(provider)
        }
    }

    /// Keychain values may outlive an uninstall. A missing sandbox marker means
    /// this is a fresh installation, so stale credentials are removed before
    /// onboarding. The legacy personal-gateway bearer is removed as well.
    func prepareFreshInstallation(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: Self.installationMarker) else { return }
        try? deleteAll()
        deleteLegacyGatewayCredential()
        defaults.set(true, forKey: Self.installationMarker)
    }

    private func identity(for provider: AIProvider) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: provider.rawValue,
        ]
    }

    private func deleteLegacyGatewayCredential() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.ajaypawriya.tracal.vertex-gateway",
            kSecAttrAccount as String: "bearer-token-v1",
        ]
        SecItemDelete(query as CFDictionary)
    }
}
