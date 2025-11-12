import Foundation
import Security

/// Secure storage utility for sensitive data using iOS Keychain
class SecureStorage {

    // MARK: - Configuration

    /// App's bundle identifier (must match Xcode project)
    private static let bundleIdentifier = "ai.heucalendar.app"

    /// Keychain access group for sharing data (must match entitlements)
    private static let keychainAccessGroup = "ai.heucalendar.app"

    // MARK: - Error Types
    enum KeychainError: Error {
        case itemNotFound
        case duplicateItem
        case unexpectedItemData
        case unhandledError(status: OSStatus)

        var localizedDescription: String {
            switch self {
            case .itemNotFound:
                return "Item not found in keychain"
            case .duplicateItem:
                return "Item already exists in keychain"
            case .unexpectedItemData:
                return "Unexpected keychain item data"
            case .unhandledError(let status):
                return "Keychain error with status: \(status) (\(SecureStorage.statusMessage(for: status)))"
            }
        }
    }

    /// Get human-readable error message for keychain status code
    private static func statusMessage(for status: OSStatus) -> String {
        switch status {
        case errSecSuccess: return "Success"
        case errSecItemNotFound: return "Item not found"
        case errSecDuplicateItem: return "Duplicate item"
        case errSecAuthFailed: return "Authentication failed"
        case -34018: return "Missing entitlement or keychain access group"
        case errSecInteractionNotAllowed: return "User interaction not allowed"
        case errSecMissingEntitlement: return "Missing entitlement"
        default: return "Unknown error"
        }
    }

    // MARK: - Storage Keys
    struct Keys {
        static let googleAccessToken = "google_access_token"
        static let googleRefreshToken = "google_refresh_token"
        static let outlookAccessToken = "outlook_access_token"
        static let outlookRefreshToken = "outlook_refresh_token"
        static let anthropicAPIKey = "anthropic_api_key"
        static let userPreferences = "user_preferences"
    }

    // MARK: - Public Methods

    /// Store a string value securely in the keychain
    /// - Parameters:
    ///   - key: The key to store the value under
    ///   - value: The string value to store
    /// - Throws: KeychainError if storage fails
    static func store(key: String, value: String) throws {
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.unexpectedItemData
        }

        // First, delete any existing item with the same key
        try? delete(key: key)

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: bundleIdentifier,
            kSecValueData as String: valueData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        // Add keychain access group for device (not needed on simulator)
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = keychainAccessGroup
        #endif

        let status = SecItemAdd(query as CFDictionary, nil)

        guard status == errSecSuccess else {
            print("❌ Keychain store failed for key '\(key)': \(Self.statusMessage(for: status)) (\(status))")
            if status == errSecDuplicateItem {
                throw KeychainError.duplicateItem
            } else {
                throw KeychainError.unhandledError(status: status)
            }
        }

        print("✅ Securely stored value for key: \(key)")
    }

    /// Retrieve a string value from the keychain
    /// - Parameter key: The key to retrieve the value for
    /// - Returns: The stored string value
    /// - Throws: KeychainError if retrieval fails
    static func retrieve(key: String) throws -> String {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: bundleIdentifier,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        // Add keychain access group for device (not needed on simulator)
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = keychainAccessGroup
        #endif

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                throw KeychainError.itemNotFound
            } else {
                print("❌ Keychain retrieve failed for key '\(key)': \(Self.statusMessage(for: status)) (\(status))")
                throw KeychainError.unhandledError(status: status)
            }
        }

        guard let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedItemData
        }

        return value
    }

    /// Delete a value from the keychain
    /// - Parameter key: The key to delete
    /// - Throws: KeychainError if deletion fails
    static func delete(key: String) throws {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: bundleIdentifier
        ]

        // Add keychain access group for device (not needed on simulator)
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = keychainAccessGroup
        #endif

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            print("❌ Keychain delete failed for key '\(key)': \(Self.statusMessage(for: status)) (\(status))")
            throw KeychainError.unhandledError(status: status)
        }

        print("✅ Deleted secure value for key: \(key)")
    }

    /// Check if a key exists in the keychain
    /// - Parameter key: The key to check
    /// - Returns: True if the key exists, false otherwise
    static func exists(key: String) -> Bool {
        do {
            _ = try retrieve(key: key)
            return true
        } catch {
            return false
        }
    }

    /// Update an existing value in the keychain
    /// - Parameters:
    ///   - key: The key to update
    ///   - value: The new value
    /// - Throws: KeychainError if update fails
    static func update(key: String, value: String) throws {
        guard let valueData = value.data(using: .utf8) else {
            throw KeychainError.unexpectedItemData
        }

        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecAttrService as String: bundleIdentifier
        ]

        // Add keychain access group for device (not needed on simulator)
        #if !targetEnvironment(simulator)
        query[kSecAttrAccessGroup as String] = keychainAccessGroup
        #endif

        let updateFields: [String: Any] = [
            kSecValueData as String: valueData
        ]

        let status = SecItemUpdate(query as CFDictionary, updateFields as CFDictionary)

        guard status == errSecSuccess else {
            if status == errSecItemNotFound {
                // If item doesn't exist, create it instead
                try store(key: key, value: value)
                return
            } else {
                print("❌ Keychain update failed for key '\(key)': \(Self.statusMessage(for: status)) (\(status))")
                throw KeychainError.unhandledError(status: status)
            }
        }

        print("✅ Updated secure value for key: \(key)")
    }

    // MARK: - Migration Helper

    /// Migrate data from UserDefaults to Keychain
    /// - Parameter keys: Array of keys to migrate
    static func migrateFromUserDefaults(keys: [String]) {
        for key in keys {
            if let value = UserDefaults.standard.string(forKey: key) {
                do {
                    try store(key: key, value: value)
                    UserDefaults.standard.removeObject(forKey: key)
                    print("🔄 Migrated \(key) from UserDefaults to Keychain")
                } catch {
                    print("❌ Failed to migrate \(key): \(error.localizedDescription)")
                }
            }
        }
    }

    /// Perform complete app migration from UserDefaults to secure storage
    static func performAppMigration() {
        print("🔄 Starting app data migration to secure storage...")

        // Migrate any existing API keys or sensitive data
        let sensitiveKeys = [
            "anthropic_api_key",
            "google_client_id",
            "microsoft_client_id"
        ]

        migrateFromUserDefaults(keys: sensitiveKeys)

        // Mark migration as completed
        UserDefaults.standard.set(true, forKey: "secure_storage_migration_completed")
        print("✅ App data migration to secure storage completed")
    }

    /// Check if migration has been completed
    static func isMigrationCompleted() -> Bool {
        return UserDefaults.standard.bool(forKey: "secure_storage_migration_completed")
    }

    // MARK: - Convenience Methods for Common Operations

    /// Store Google authentication tokens
    static func storeGoogleTokens(accessToken: String, refreshToken: String?) throws {
        try store(key: Keys.googleAccessToken, value: accessToken)
        if let refreshToken = refreshToken {
            try store(key: Keys.googleRefreshToken, value: refreshToken)
        }
    }

    /// Retrieve Google authentication tokens
    static func getGoogleTokens() throws -> (accessToken: String, refreshToken: String?) {
        let accessToken = try retrieve(key: Keys.googleAccessToken)
        let refreshToken = try? retrieve(key: Keys.googleRefreshToken)
        return (accessToken, refreshToken)
    }

    /// Store Outlook authentication tokens
    static func storeOutlookTokens(accessToken: String, refreshToken: String?) throws {
        try store(key: Keys.outlookAccessToken, value: accessToken)
        if let refreshToken = refreshToken {
            try store(key: Keys.outlookRefreshToken, value: refreshToken)
        }
    }

    /// Retrieve Outlook authentication tokens
    static func getOutlookTokens() throws -> (accessToken: String, refreshToken: String?) {
        let accessToken = try retrieve(key: Keys.outlookAccessToken)
        let refreshToken = try? retrieve(key: Keys.outlookRefreshToken)
        return (accessToken, refreshToken)
    }

    /// Clear all stored authentication tokens
    static func clearAllTokens() {
        let tokenKeys = [
            Keys.googleAccessToken,
            Keys.googleRefreshToken,
            Keys.outlookAccessToken,
            Keys.outlookRefreshToken
        ]

        for key in tokenKeys {
            try? delete(key: key)
        }

        print("🧹 Cleared all authentication tokens")
    }
}