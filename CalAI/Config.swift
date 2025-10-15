import Foundation

enum AIProvider: String, CaseIterable {
    case anthropic = "Anthropic"
    case openai = "OpenAI"

    var displayName: String {
        return self.rawValue
    }
}

enum AIOutputMode: String, CaseIterable {
    case textOnly = "Text Only"
    case voiceAndText = "Voice & Text"
    case voiceOnly = "Voice Only"
}

struct Config {
    private static let anthropicAPIKeyKeychainKey = "anthropic_api_key"
    private static let openaiAPIKeyKeychainKey = "openai_api_key"
    private static let anthropicAPIKeyUserDefaultsKey = "AnthropicAPIKey" // Legacy - for migration
    private static let openaiAPIKeyUserDefaultsKey = "OpenAIAPIKey" // Legacy - for migration
    private static let aiProviderUserDefaultsKey = "AIProvider"
    private static let aiOutputModeUserDefaultsKey = "AIOutputMode"
    private static let migrationCompletedKey = "api_keys_migration_completed"

    // MARK: - Migration
    private static func migrateAPIKeysIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migrationCompletedKey) else {
            return // Migration already completed
        }

        print("🔄 Starting API keys migration to secure storage...")

        // Migrate Anthropic API key
        if let anthropicKey = UserDefaults.standard.string(forKey: anthropicAPIKeyUserDefaultsKey),
           !anthropicKey.isEmpty {
            do {
                try SecureStorage.store(key: anthropicAPIKeyKeychainKey, value: anthropicKey)
                UserDefaults.standard.removeObject(forKey: anthropicAPIKeyUserDefaultsKey)
                print("✅ Migrated Anthropic API key to Keychain")
            } catch {
                print("❌ Failed to migrate Anthropic API key: \(error)")
            }
        }

        // Migrate OpenAI API key
        if let openaiKey = UserDefaults.standard.string(forKey: openaiAPIKeyUserDefaultsKey),
           !openaiKey.isEmpty {
            do {
                try SecureStorage.store(key: openaiAPIKeyKeychainKey, value: openaiKey)
                UserDefaults.standard.removeObject(forKey: openaiAPIKeyUserDefaultsKey)
                print("✅ Migrated OpenAI API key to Keychain")
            } catch {
                print("❌ Failed to migrate OpenAI API key: \(error)")
            }
        }

        UserDefaults.standard.set(true, forKey: migrationCompletedKey)
        print("✅ API keys migration completed")
    }

    // MARK: - AI Provider Selection
    static var aiProvider: AIProvider {
        get {
            let providerString = UserDefaults.standard.string(forKey: aiProviderUserDefaultsKey) ?? AIProvider.anthropic.rawValue
            return AIProvider(rawValue: providerString) ?? .anthropic
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: aiProviderUserDefaultsKey)
        }
    }

    // MARK: - AI Output Mode
    static var aiOutputMode: AIOutputMode {
        get {
            let modeString = UserDefaults.standard.string(forKey: aiOutputModeUserDefaultsKey) ?? AIOutputMode.voiceAndText.rawValue
            return AIOutputMode(rawValue: modeString) ?? .voiceAndText
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: aiOutputModeUserDefaultsKey)
        }
    }

    // MARK: - API Keys (Secure Keychain Storage)
    static var anthropicAPIKey: String {
        get {
            migrateAPIKeysIfNeeded()
            do {
                return try SecureStorage.retrieve(key: anthropicAPIKeyKeychainKey)
            } catch {
                return ""
            }
        }
        set {
            do {
                if newValue.isEmpty {
                    try? SecureStorage.delete(key: anthropicAPIKeyKeychainKey)
                } else {
                    try SecureStorage.store(key: anthropicAPIKeyKeychainKey, value: newValue)
                }
            } catch {
                print("❌ Failed to store Anthropic API key: \(error)")
            }
        }
    }

    static var openaiAPIKey: String {
        get {
            migrateAPIKeysIfNeeded()
            do {
                return try SecureStorage.retrieve(key: openaiAPIKeyKeychainKey)
            } catch {
                return ""
            }
        }
        set {
            do {
                if newValue.isEmpty {
                    try? SecureStorage.delete(key: openaiAPIKeyKeychainKey)
                } else {
                    try SecureStorage.store(key: openaiAPIKeyKeychainKey, value: newValue)
                }
            } catch {
                print("❌ Failed to store OpenAI API key: \(error)")
            }
        }
    }

    // MARK: - Key Validation
    static var hasValidAPIKey: Bool {
        switch aiProvider {
        case .anthropic:
            return hasAnthropicKey
        case .openai:
            return hasOpenAIKey
        }
    }

    static var hasAnthropicKey: Bool {
        let key = anthropicAPIKey
        return !key.isEmpty && key.hasPrefix("sk-ant-")
    }

    static var hasOpenAIKey: Bool {
        let key = openaiAPIKey
        return !key.isEmpty && key.hasPrefix("sk-")
    }

    static var currentAPIKey: String {
        switch aiProvider {
        case .anthropic:
            return anthropicAPIKey
        case .openai:
            return openaiAPIKey
        }
    }
    
    // MARK: - Model Selection
    
    static let openAIModel = "gpt-4o"
    static let anthropicModel = "claude-3-5-sonnet-20240620"
    
    static var selectedModel: String {
        switch aiProvider {
        case .anthropic:
            return anthropicModel
        case .openai:
            return openAIModel
        }
    }
}