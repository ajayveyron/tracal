import Foundation
import Security

/// Seeds the private gateway URL + bearer from build-time config so a personal
/// production build does not require pasting secrets into Settings.
///
/// Sources (first non-empty wins for URL, same for token):
/// 1. Process environment (Simulator / Xcode scheme)
/// 2. Info.plist build settings (`TRACAL_GATEWAY_BASE_URL`, `TRACAL_GATEWAY_DEVICE_TOKEN`)
///
/// The raw token is written once into the device Keychain and never read back
/// into UserDefaults. Prefer `Config/Local.xcconfig` (gitignored) for personal
/// builds; do not commit production bearer tokens.
enum GatewayAutoProvision {
    static let deviceTokenInfoKey = "TRACAL_GATEWAY_DEVICE_TOKEN"
    static let deviceTokenEnvironmentKey = "TRACAL_GATEWAY_DEVICE_TOKEN"

    @discardableResult
    static func applyIfNeeded(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        userDefaults: UserDefaults = .standard,
        tokenStore: VertexGatewayTokenStore = VertexGatewayTokenStore()
    ) -> Bool {
        var didChange = false

        if let url = resolvedBaseURL(bundle: bundle, environment: environment) {
            let existing = userDefaults.string(forKey: VertexGatewayConfiguration.userDefaultsBaseURLKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if existing.isEmpty {
                userDefaults.set(url.absoluteString, forKey: VertexGatewayConfiguration.userDefaultsBaseURLKey)
                didChange = true
            }
        }

        if
            let token = resolvedDeviceToken(bundle: bundle, environment: environment),
            !keychainHasToken(service: tokenStore.service, account: tokenStore.account)
        {
            do {
                try tokenStore.store(token)
                didChange = true
            } catch {
                // Leave Settings as the recovery path if Keychain write fails.
            }
        }

        return didChange
    }

    static func resolvedBaseURL(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> URL? {
        let candidates = [
            environment[VertexGatewayConfiguration.runtimeBaseURLKey],
            environment["TRACAL_GATEWAY_URL"],
            bundle.object(forInfoDictionaryKey: VertexGatewayConfiguration.runtimeBaseURLKey) as? String,
            bundle.object(forInfoDictionaryKey: "TRACAL_GATEWAY_URL") as? String,
        ]
        for raw in candidates {
            guard
                let value = sanitizeBuildSetting(raw),
                let url = URL(string: value),
                let scheme = url.scheme?.lowercased(),
                ["https", "http"].contains(scheme),
                url.host != nil
            else {
                continue
            }
            return url
        }
        return nil
    }

    static func resolvedDeviceToken(
        bundle: Bundle = .main,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        let candidates = [
            environment[deviceTokenEnvironmentKey],
            bundle.object(forInfoDictionaryKey: deviceTokenInfoKey) as? String,
        ]
        for raw in candidates {
            if let value = sanitizeBuildSetting(raw), value.count >= 32 {
                return value
            }
        }
        return nil
    }

    private static func keychainHasToken(
        service: String,
        account: String
    ) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    private static func sanitizeBuildSetting(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty || value.contains("$(") { return nil }
        return value
    }
}
