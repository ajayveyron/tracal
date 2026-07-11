import Foundation

public enum AIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI
    case anthropic
    case gemini

    public var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI: "OpenAI"
        case .anthropic: "Anthropic"
        case .gemini: "Gemini"
        }
    }

    var defaultModel: String {
        switch self {
        case .openAI: "gpt-5.4-mini"
        case .anthropic: "claude-haiku-4-5-20251001"
        case .gemini: "gemini-3.5-flash"
        }
    }

    var apiKeyURL: URL {
        switch self {
        case .openAI: URL(string: "https://platform.openai.com/api-keys")!
        case .anthropic: URL(string: "https://console.anthropic.com/settings/keys")!
        case .gemini: URL(string: "https://aistudio.google.com/apikey")!
        }
    }

    var billingURL: URL {
        switch self {
        case .openAI: URL(string: "https://platform.openai.com/settings/organization/billing/overview")!
        case .anthropic: URL(string: "https://console.anthropic.com/settings/billing")!
        case .gemini: URL(string: "https://aistudio.google.com/usage")!
        }
    }

    var systemImage: String {
        switch self {
        case .openAI: "circle.hexagongrid"
        case .anthropic: "a.circle"
        case .gemini: "sparkle"
        }
    }
}

struct AIProviderPreferences: @unchecked Sendable {
    static let activeProviderKey = "activeAIProvider"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var activeProvider: AIProvider {
        get {
            guard
                let value = defaults.string(forKey: Self.activeProviderKey),
                let provider = AIProvider(rawValue: value)
            else {
                return .gemini
            }
            return provider
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.activeProviderKey)
        }
    }

    func model(for provider: AIProvider) -> String {
        let value = defaults.string(forKey: modelKey(for: provider))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Self.isValidModelID(value) ? value : provider.defaultModel
    }

    func setModel(_ model: String, for provider: AIProvider) {
        let value = model.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isValidModelID(value), value != provider.defaultModel {
            defaults.set(value, forKey: modelKey(for: provider))
        } else {
            defaults.removeObject(forKey: modelKey(for: provider))
        }
    }

    func hasConsent(for provider: AIProvider) -> Bool {
        defaults.bool(forKey: consentKey(for: provider))
    }

    func setConsent(_ value: Bool, for provider: AIProvider) {
        defaults.set(value, forKey: consentKey(for: provider))
    }

    func reset() {
        defaults.removeObject(forKey: Self.activeProviderKey)
        for provider in AIProvider.allCases {
            defaults.removeObject(forKey: modelKey(for: provider))
            defaults.removeObject(forKey: consentKey(for: provider))
        }
    }

    private func modelKey(for provider: AIProvider) -> String {
        "aiProvider.\(provider.rawValue).model"
    }

    private func consentKey(for provider: AIProvider) -> String {
        "aiProvider.\(provider.rawValue).consent"
    }

    private static func isValidModelID(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 120 else { return false }
        return value.unicodeScalars.allSatisfy {
            CharacterSet.alphanumerics
                .union(CharacterSet(charactersIn: "._-"))
                .contains($0)
        }
    }
}
