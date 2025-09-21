import SwiftUI

struct AITabView: View {
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var aiManager: AIManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @State private var conversationHistory: [ConversationItem] = []
    @State private var isProcessing = false

    var body: some View {
        VStack(spacing: 0) {
            if conversationHistory.isEmpty {
                VStack {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .padding(.top, 16)
                        .padding(.bottom, 8)

                    Text("AI Assistant")
                        .dynamicFont(size: 28, weight: .bold, fontManager: fontManager)

                    Text("Try saying something like:")
                        .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                        .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 8) {
                        ExampleCommand(text: "Create meeting tomorrow at 2pm", fontManager: fontManager)
                        ExampleCommand(text: "Schedule lunch with John on Friday", fontManager: fontManager)
                        ExampleCommand(text: "Show my events for this week", fontManager: fontManager)
                        ExampleCommand(text: "What do I have today?", fontManager: fontManager)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    Spacer()
                }
                .padding(.horizontal)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(conversationHistory, id: \.id) { item in
                            ConversationBubble(item: item, fontManager: fontManager)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.horizontal)
                }
            }

            VStack {
                if isProcessing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Processing...")
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 8)
                }

                VoiceInputButton(
                    voiceManager: voiceManager,
                    aiManager: aiManager,
                    calendarManager: calendarManager,
                    fontManager: fontManager,
                    onTranscript: { transcript in
                        print("🗣️ Transcript received in AITabView: \(transcript)")
                        addUserMessage(transcript)
                    },
                    onResponse: { response in
                        print("🤖 AI response received in AITabView: \(response.message)")
                        addAIResponse(response)
                    }
                )
            }
            .padding()
        }
    }

    private func addUserMessage(_ message: String) {
        let item = ConversationItem(
            id: UUID(),
            message: message,
            isUser: true,
            timestamp: Date()
        )
        conversationHistory.append(item)
        isProcessing = true
    }

    private func addAIResponse(_ response: AIResponse) {
        let item = ConversationItem(
            id: UUID(),
            message: response.message,
            isUser: false,
            timestamp: Date()
        )
        conversationHistory.append(item)
        isProcessing = false
    }
}

struct ConversationItem {
    let id: UUID
    let message: String
    let isUser: Bool
    let timestamp: Date
}

struct ConversationBubble: View {
    let item: ConversationItem
    let fontManager: FontManager

    var body: some View {
        HStack {
            if item.isUser { Spacer() }

            VStack(alignment: item.isUser ? .trailing : .leading, spacing: 4) {
                Text(item.message)
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .padding(12)
                    .background(item.isUser ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(item.isUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(formatTime(item.timestamp))
                    .dynamicFont(size: 11, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }

            if !item.isUser { Spacer() }
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ExampleCommand: View {
    let text: String
    let fontManager: FontManager

    var body: some View {
        HStack {
            Image(systemName: "quote.bubble")
                .foregroundColor(.blue)
                .font(.caption)
            Text(text)
                .dynamicFont(size: 12, fontManager: fontManager)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

