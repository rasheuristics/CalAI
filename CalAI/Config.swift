import Foundation

struct Config {
    private static let apiKeyUserDefaultsKey = "AnthropicAPIKey"

    static var anthropicAPIKey: String {
        get {
            return UserDefaults.standard.string(forKey: apiKeyUserDefaultsKey) ?? ""
        }
        set {
            UserDefaults.standard.set(newValue, forKey: apiKeyUserDefaultsKey)
        }
    }

    static var hasValidAPIKey: Bool {
        let key = anthropicAPIKey
        return !key.isEmpty && key.hasPrefix("sk-ant-")
    }
}