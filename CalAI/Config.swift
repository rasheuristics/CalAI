import Foundation

enum AIProvider: String, CaseIterable {
    case anthropic = "Anthropic"
    case openai = "OpenAI"

    var displayName: String {
        return self.rawValue
    }
}

struct Config {
    private static let anthropicAPIKeyUserDefaultsKey = "AnthropicAPIKey"
    private static let openaiAPIKeyUserDefaultsKey = "OpenAIAPIKey"
    private static let aiProviderUserDefaultsKey = "AIProvider"

    // AI Provider Selection
    static var aiProvider: AIProvider {
        get {
            let providerString = UserDefaults.standard.string(forKey: aiProviderUserDefaultsKey) ?? AIProvider.anthropic.rawValue
            return AIProvider(rawValue: providerString) ?? .anthropic
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: aiProviderUserDefaultsKey)
        }
    }

    // Anthropic API Key
    static var anthropicAPIKey: String {
        get {
            return UserDefaults.standard.string(forKey: anthropicAPIKeyUserDefaultsKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: anthropicAPIKeyUserDefaultsKey)
        }
    }

    // OpenAI API Key
    static var openaiAPIKey: String {
        get {
            return UserDefaults.standard.string(forKey: openaiAPIKeyUserDefaultsKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: openaiAPIKeyUserDefaultsKey)
        }
    }

    static var hasValidAPIKey: Bool {
        switch aiProvider {
        case .anthropic:
            let key = anthropicAPIKey
            return !key.isEmpty && key.hasPrefix("sk-ant-")
        case .openai:
            let key = openaiAPIKey
            return !key.isEmpty && key.hasPrefix("sk-")
        }
    }

    static var currentAPIKey: String {
        switch aiProvider {
        case .anthropic:
            return anthropicAPIKey
        case .openai:
            return openaiAPIKey
        }
    }
}