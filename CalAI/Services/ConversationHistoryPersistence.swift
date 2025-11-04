import Foundation

/// Persists conversation history to disk for continuity across app sessions
class ConversationHistoryPersistence {

    // MARK: - Types

    struct PersistedConversation: Codable {
        let messages: [ConversationContextManager.Message]
        let lastUpdated: Date
        let sessionId: String

        init(messages: [ConversationContextManager.Message], sessionId: String = UUID().uuidString) {
            self.messages = messages
            self.lastUpdated = Date()
            self.sessionId = sessionId
        }
    }

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let conversationFileName = "conversation_history.json"
    private let maxConversationAge: TimeInterval = 86400 // 24 hours

    // MARK: - File Path

    private var conversationFileURL: URL? {
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return documentsDirectory.appendingPathComponent(conversationFileName)
    }

    // MARK: - Save

    func saveConversation(messages: [ConversationContextManager.Message]) {
        guard let fileURL = conversationFileURL else {
            print("❌ ConversationPersistence: Could not get file URL")
            return
        }

        let conversation = PersistedConversation(messages: messages)

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(conversation)
            try data.write(to: fileURL, options: [.atomic])
            print("✅ ConversationPersistence: Saved \(messages.count) messages")
        } catch {
            print("❌ ConversationPersistence: Save failed - \(error)")
        }
    }

    // MARK: - Load

    func loadConversation() -> [ConversationContextManager.Message]? {
        guard let fileURL = conversationFileURL else {
            print("❌ ConversationPersistence: Could not get file URL")
            return nil
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("ℹ️ ConversationPersistence: No saved conversation found")
            return nil
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let conversation = try decoder.decode(PersistedConversation.self, from: data)

            // Check if conversation is too old
            let age = Date().timeIntervalSince(conversation.lastUpdated)
            if age > maxConversationAge {
                print("🗑️ ConversationPersistence: Conversation expired (age: \(Int(age/3600))h)")
                clearConversation()
                return nil
            }

            print("✅ ConversationPersistence: Loaded \(conversation.messages.count) messages (session: \(conversation.sessionId.prefix(8)))")
            return conversation.messages
        } catch {
            print("❌ ConversationPersistence: Load failed - \(error)")
            return nil
        }
    }

    // MARK: - Clear

    func clearConversation() {
        guard let fileURL = conversationFileURL else {
            return
        }

        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
                print("✅ ConversationPersistence: Cleared conversation history")
            }
        } catch {
            print("❌ ConversationPersistence: Clear failed - \(error)")
        }
    }

    // MARK: - Auto-Save

    func setupAutoSave(contextManager: ConversationContextManager, interval: TimeInterval = 30) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak contextManager, weak self] _ in
            guard let contextManager = contextManager, let self = self else { return }
            self.saveConversation(messages: contextManager.getMessageHistory())
        }
    }
}
