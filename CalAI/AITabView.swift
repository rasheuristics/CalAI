import SwiftUI

struct AITabView: View {
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var aiManager: AIManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @State private var conversationHistory: [ConversationItem] = []
    @State private var isProcessing = false
    @State private var pendingResponse: AICalendarResponse?
    @State private var showingConfirmation = false

    var body: some View {
        ZStack {
            // Background that extends to all edges
            Color(.systemGroupedBackground)
                .ignoresSafeArea(.all)

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

                        Text("(Double-tap any command to execute)")
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(CommandCategory.allCases, id: \.self) { category in
                                CommandCategoryCard(
                                    category: category,
                                    fontManager: fontManager,
                                    onCommandSelected: { command in
                                        executeExampleCommand(command)
                                    }
                                )
                            }
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
                    .refreshable {
                        clearConversation()
                    }
                }

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
            }

            // Mic button at bottom center
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    VoiceInputButton(
                        voiceManager: voiceManager,
                        aiManager: aiManager,
                        calendarManager: calendarManager,
                        fontManager: fontManager,
                        onTranscript: { transcript in
                            print("🗣️ Transcript received in AITabView: '\(transcript)'")
                            print("📝 Adding user message to conversation")
                            addUserMessage(transcript)
                        },
                        onResponse: { response in
                            print("🤖 AI response received in AITabView: \(response.message)")
                            if let command = response.command {
                                print("🎯 Response command: \(command.type)")
                                print("📅 Event title: \(command.title ?? "nil")")
                                print("⏰ Start date: \(command.startDate?.description ?? "nil")")
                            }

                            if response.requiresConfirmation {
                                print("⚠️ Response requires confirmation")
                                pendingResponse = response
                                showingConfirmation = true
                            } else {
                                addAIResponse(response)
                                executeAIAction(response)
                            }
                        }
                    )
                    Spacer()
                }
                .padding(.bottom, 20)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AvailabilityResult"))) { notification in
            if let message = notification.userInfo?["message"] as? String {
                print("🔔 Received availability result notification: \(message)")
                let item = ConversationItem(
                    id: UUID(),
                    message: message,
                    isUser: false,
                    timestamp: Date()
                )
                conversationHistory.append(item)
                isProcessing = false
            }
        }
        .alert("Confirm Action", isPresented: $showingConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingResponse = nil
            }
            Button("Confirm") {
                if let response = pendingResponse {
                    addAIResponse(response)
                    executeAIAction(response)
                }
                pendingResponse = nil
            }
        } message: {
            Text(pendingResponse?.confirmationMessage ?? "Do you want to proceed with this action?")
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

    private func addAIResponse(_ response: AICalendarResponse) {
        let item = ConversationItem(
            id: UUID(),
            message: response.message,
            isUser: false,
            timestamp: Date()
        )
        conversationHistory.append(item)
        isProcessing = false
    }

    private func executeAIAction(_ response: AICalendarResponse) {
        calendarManager.handleAICalendarResponse(response)
    }

    private func executeExampleCommand(_ text: String) {
        print("🔮 Example command double-tapped: '\(text)'")

        // Check if this is a template command (contains brackets)
        if text.contains("[") && text.contains("]") {
            // This is a template - show instruction message instead of processing
            let instructionMessage = "Please say: '\(text.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: ""))' with your specific details.\n\nFor example:\n• Replace [title] with your event name\n• Replace [time] with when you want it\n• Replace [person] with attendee names"

            let instructionItem = ConversationItem(
                id: UUID(),
                message: instructionMessage,
                isUser: false,
                timestamp: Date()
            )
            conversationHistory.append(instructionItem)
            return
        }

        // Add the command as a user message to conversation
        addUserMessage(text)

        // Process the command through AI
        aiManager.processVoiceCommand(text) { result in
            print("🎯 AI processing completed for example command: \(result.message)")

            if result.requiresConfirmation {
                print("⚠️ Example command requires confirmation")
                pendingResponse = result
                showingConfirmation = true
            } else {
                addAIResponse(result)
                executeAIAction(result)
            }
        }
    }

    private func clearConversation() {
        print("🗑️ Clearing conversation history - returning to first page")
        withAnimation(.easeInOut(duration: 0.5)) {
            conversationHistory.removeAll()
            isProcessing = false
            pendingResponse = nil
        }
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

// MARK: - Command Category Data Structures

enum CommandCategory: String, CaseIterable {
    case eventManagement = "Event Management"
    case eventQueries = "Event Queries & Search"
    case attendeeManagement = "Attendee Management"
    case recurringEvents = "Recurring Events"
    case scheduleManagement = "Schedule Management"
    case helpSupport = "Help & Support"

    var icon: String {
        switch self {
        case .eventManagement: return "calendar.badge.plus"
        case .eventQueries: return "magnifyingglass.circle"
        case .attendeeManagement: return "person.2.circle"
        case .recurringEvents: return "repeat.circle"
        case .scheduleManagement: return "calendar.circle"
        case .helpSupport: return "questionmark.circle"
        }
    }

    var description: String {
        switch self {
        case .eventManagement: return "Create, update, and manage events"
        case .eventQueries: return "Search and find events"
        case .attendeeManagement: return "Manage event participants"
        case .recurringEvents: return "Set up repeating events"
        case .scheduleManagement: return "Manage your schedule"
        case .helpSupport: return "Get help and support"
        }
    }

    var commands: [String] {
        switch self {
        case .eventManagement:
            return [
                "Create [title] at [time]",
                "Schedule [title] with [person] at [time]",
                "Update [title] meeting to [new time]",
                "Delete [title] meeting at [time]",
                "Move [title] meeting to [new time]",
                "Extend [title] meeting by [duration]"
            ]
        case .eventQueries:
            return [
                "What do I have [today/tomorrow/date]",
                "Show my events for [timeframe]",
                "Find my [title] meeting",
                "Check my availability [when]",
                "What's my schedule for [date]"
            ]
        case .attendeeManagement:
            return [
                "Add [person] to [title] meeting",
                "Remove [person] from [title] meeting",
                "Invite [people] to [title] meeting",
                "Who's attending [title] meeting"
            ]
        case .recurringEvents:
            return [
                "Set up weekly [title] at [time]",
                "Create daily [title] at [time]",
                "Schedule monthly [title] at [time]",
                "Make [title] meeting recurring"
            ]
        case .scheduleManagement:
            return [
                "Clear my schedule [when]",
                "Block [duration] for [purpose] at [time]",
                "Show my workload summary",
                "Find [duration] slot for [title]",
                "Reserve [duration] for [purpose] [when]"
            ]
        case .helpSupport:
            return [
                "Help",
                "Show available commands",
                "What can I do with CalAI",
                "How do I create events"
            ]
        }
    }
}

// MARK: - Command Category Card View

struct CommandCategoryCard: View {
    let category: CommandCategory
    let fontManager: FontManager
    let onCommandSelected: (String) -> Void

    @State private var isExpanded = false
    @State private var isPressed = false

    var body: some View {
        VStack(spacing: 0) {
            // Main category header
            HStack {
                Image(systemName: category.icon)
                    .foregroundColor(.blue)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.primary)

                    Text(category.description)
                        .dynamicFont(size: 11, fontManager: fontManager)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.blue)
                    .font(.caption)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.blue.opacity(isPressed ? 0.15 : 0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})

            // Dropdown commands
            if isExpanded {
                VStack(spacing: 6) {
                    ForEach(category.commands, id: \.self) { command in
                        CommandItem(
                            text: command,
                            fontManager: fontManager,
                            onDoubleTap: {
                                onCommandSelected(command)
                                // Collapse after selection
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isExpanded = false
                                }
                            }
                        )
                    }
                }
                .padding(.top, 8)
                .padding(.horizontal, 4)
                .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Command Item View

struct CommandItem: View {
    let text: String
    let fontManager: FontManager
    let onDoubleTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        HStack {
            Image(systemName: "quote.bubble")
                .foregroundColor(.blue)
                .font(.caption2)

            Text(text)
                .dynamicFont(size: 12, fontManager: fontManager)
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            Image(systemName: "play.circle")
                .foregroundColor(.blue)
                .font(.caption2)
                .opacity(0.6)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.blue.opacity(isPressed ? 0.15 : 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture(count: 2) {
            print("👆👆 Double-tap detected on command: '\(text)'")
            onDoubleTap()
        }
        .onTapGesture(count: 1) {
            print("👆 Single tap on command (hint: double-tap to execute)")
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Legacy ExampleCommand (kept for compatibility)

struct ExampleCommand: View {
    let text: String
    let fontManager: FontManager
    let onDoubleTap: ((String) -> Void)?

    init(text: String, fontManager: FontManager, onDoubleTap: ((String) -> Void)? = nil) {
        self.text = text
        self.fontManager = fontManager
        self.onDoubleTap = onDoubleTap
    }

    @State private var isPressed = false

    var body: some View {
        HStack {
            Image(systemName: "quote.bubble")
                .foregroundColor(.blue)
                .font(.caption)
            Text(text)
                .dynamicFont(size: 12, fontManager: fontManager)
            Spacer()
            if onDoubleTap != nil {
                Image(systemName: "play.circle")
                    .foregroundColor(.blue)
                    .font(.caption2)
                    .opacity(0.6)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(isPressed ? 0.2 : 0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture(count: 2) {
            print("👆👆 Double-tap detected on example command: '\(text)'")
            onDoubleTap?(text)
        }
        .onTapGesture(count: 1) {
            print("👆 Single tap on example command (hint: double-tap to execute)")
        }
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

