import SwiftUI
import EventKit

struct AITabView: View {
    @ObservedObject var voiceManager: VoiceManager
    @ObservedObject var aiManager: AIManager
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @ObservedObject var appearanceManager: AppearanceManager
    @State private var conversationHistory: [ConversationItem] = []
    @State private var isProcessing = false
    @State private var pendingResponse: AICalendarResponse?
    @State private var showingConfirmation = false

    // Inline form states
    @State private var showingInlineForm = false
    @State private var currentFormType: InlineFormType?
    @State private var selectedEventForEdit: UnifiedEvent?

    var body: some View {
        ZStack {
            // Transparent background to show main gradient
            Color.clear
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

                        HStack {
                            Image(systemName: "hand.tap")
                                .foregroundColor(.blue)
                                .font(.caption2)
                            Text("Double-tap any command to execute")
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(CommandCategory.allCases, id: \.self) { category in
                                CommandCategoryCard(
                                    category: category,
                                    fontManager: fontManager,
                                    appearanceManager: appearanceManager,
                                    onCommandSelected: { command in
                                        executeExampleCommand(command)
                                    },
                                    onCategoryDoubleTap: { category in
                                        handleCategoryDoubleTap(category)
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
                    if showingInlineForm {
                        // Show inline form
                        InlineFormView(
                            formType: currentFormType ?? .createEvent,
                            calendarManager: calendarManager,
                            fontManager: fontManager,
                            eventToEdit: selectedEventForEdit,
                            onSave: { success in
                                if success {
                                    showingInlineForm = false
                                    currentFormType = nil
                                    selectedEventForEdit = nil

                                    // Add success message to conversation
                                    let successMessage = "✅ Event saved successfully!"
                                    let item = ConversationItem(
                                        id: UUID(),
                                        message: successMessage,
                                        isUser: false,
                                        timestamp: Date()
                                    )
                                    conversationHistory.append(item)
                                }
                            },
                            onCancel: {
                                showingInlineForm = false
                                currentFormType = nil
                                selectedEventForEdit = nil
                            }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(conversationHistory, id: \.id) { item in
                                    ConversationBubble(item: item, fontManager: fontManager, appearanceManager: appearanceManager)
                                }
                            }
                            .padding(.top, 8)
                            .padding(.horizontal)
                        }
                        .refreshable {
                            clearConversation()
                        }
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
                        appearanceManager: appearanceManager,
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

        // Determine if this should trigger an inline form
        let formType = getFormType(for: text)

        if let formType = formType {
            // Show inline form
            withAnimation(.easeInOut(duration: 0.3)) {
                currentFormType = formType
                showingInlineForm = true
            }
        } else {
            // Handle non-form commands (queries, help, etc.)
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
    }

    private func getFormType(for command: String) -> InlineFormType? {
        let lowerCommand = command.lowercased()

        if lowerCommand.contains("create") && lowerCommand.contains("event") {
            return .createEvent
        } else if lowerCommand.contains("update") && lowerCommand.contains("event") {
            return .updateEvent
        } else if lowerCommand.contains("schedule") && lowerCommand.contains("event") {
            return .createEvent
        } else if lowerCommand.contains("block") && lowerCommand.contains("time") {
            return .blockTime
        }

        // Return nil for query commands (show events, find event, etc.)
        return nil
    }

    private func handleCategoryDoubleTap(_ category: CommandCategory) {
        print("👆👆 Category double-tapped: \(category.rawValue)")

        // For now, we'll add a placeholder message and implement functionality later
        let message = "\(category.rawValue) functionality will be implemented here"
        let item = ConversationItem(
            id: UUID(),
            message: message,
            isUser: false,
            timestamp: Date()
        )
        conversationHistory.append(item)

        // TODO: Implement specific functionality for each category
        switch category {
        case .eventQueries:
            // Handle Event Queries & Search
            break
        case .attendeeManagement:
            // Handle Attendee Management
            break
        case .recurringEvents:
            // Handle Recurring Events
            break
        case .scheduleManagement:
            // Handle Schedule Management
            break
        case .helpSupport:
            // Handle Help & Support
            break
        case .eventManagement:
            // This shouldn't be called since Event Management uses dropdown
            break
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
    let appearanceManager: AppearanceManager

    var body: some View {
        HStack {
            if item.isUser { Spacer() }

            VStack(alignment: item.isUser ? .trailing : .leading, spacing: 4) {
                Text(item.message)
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .padding(12)
                    .background(
                        Group {
                            if item.isUser {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.blue)
                            } else {
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.thinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(appearanceManager.ultraThinGlass))
                                    )
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(
                                    LinearGradient(
                                        colors: item.isUser ?
                                            [.white.opacity(0.6), .white.opacity(0.2)] :
                                            [.white.opacity(appearanceManager.strokeOpacity), .white.opacity(appearanceManager.strokeOpacity * 0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: .black.opacity(appearanceManager.shadowOpacity), radius: 8, x: 0, y: 4)
                    )
                    .foregroundColor(item.isUser ? .white : .primary)

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

// MARK: - Inline Form Types

enum InlineFormType {
    case createEvent
    case updateEvent
    case blockTime
    case scheduleEvent
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
                "Create event",
                "Update event",
                "Delete event",
                "Move event",
                "Extend event",
                "Schedule event"
            ]
        case .eventQueries:
            return [
                "Show my events",
                "Find event",
                "Check availability",
                "View schedule",
                "Search events"
            ]
        case .attendeeManagement:
            return [
                "Add attendee",
                "Remove attendee",
                "Invite people",
                "View attendees"
            ]
        case .recurringEvents:
            return [
                "Create recurring event",
                "Set up weekly meeting",
                "Schedule daily standup",
                "Make event recurring"
            ]
        case .scheduleManagement:
            return [
                "Clear schedule",
                "Block time",
                "Show workload",
                "Find time slot",
                "Reserve time"
            ]
        case .helpSupport:
            return [
                "Help",
                "Show commands",
                "View documentation",
                "Get support"
            ]
        }
    }
}

// MARK: - Command Category Card View

struct CommandCategoryCard: View {
    let category: CommandCategory
    let fontManager: FontManager
    let appearanceManager: AppearanceManager
    let onCommandSelected: (String) -> Void
    let onCategoryDoubleTap: ((CommandCategory) -> Void)?

    @State private var isExpanded = false
    @State private var isPressed = false

    init(category: CommandCategory, fontManager: FontManager, appearanceManager: AppearanceManager, onCommandSelected: @escaping (String) -> Void, onCategoryDoubleTap: ((CommandCategory) -> Void)? = nil) {
        self.category = category
        self.fontManager = fontManager
        self.appearanceManager = appearanceManager
        self.onCommandSelected = onCommandSelected
        self.onCategoryDoubleTap = onCategoryDoubleTap
    }

    private var headerBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(isPressed ? (appearanceManager.blueAccentOpacity * 3) : appearanceManager.blueAccentOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(appearanceManager.strokeOpacity),
                                .white.opacity(appearanceManager.strokeOpacity * 0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(appearanceManager.shadowOpacity), radius: 12, x: 0, y: 6)
    }

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

                if category == .eventManagement {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.blue)
                        .font(.caption)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                } else {
                    Image(systemName: "hand.tap")
                        .foregroundColor(.blue)
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(headerBackground)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            .onTapGesture(count: category == .eventManagement ? 1 : 2) {
                if category == .eventManagement {
                    // Single tap for Event Management - toggle expansion
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isExpanded.toggle()
                    }
                } else {
                    // Double tap for other categories - direct activation
                    onCategoryDoubleTap?(category)
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
                            appearanceManager: appearanceManager,
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
            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(appearanceManager.glassOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(appearanceManager.strokeOpacity),
                                    .white.opacity(appearanceManager.strokeOpacity * 0.2)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: .black.opacity(appearanceManager.shadowOpacity), radius: 20, x: 0, y: 10)
        )
    }
}

// MARK: - Command Item View

struct CommandItem: View {
    let text: String
    let fontManager: FontManager
    let appearanceManager: AppearanceManager
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
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(isPressed ? (appearanceManager.blueAccentOpacity * 2) : appearanceManager.ultraThinGlass))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(appearanceManager.strokeOpacity * 0.6),
                                    .white.opacity(appearanceManager.strokeOpacity * 0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: .black.opacity(appearanceManager.shadowOpacity * 0.7), radius: 6, x: 0, y: 3)
        )
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture(count: 2) {
            print("👆👆 Double-tap detected on command: '\(text)'")
            onDoubleTap()
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
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}

// MARK: - Inline Form View

struct InlineFormView: View {
    let formType: InlineFormType
    let calendarManager: CalendarManager
    let fontManager: FontManager
    let eventToEdit: UnifiedEvent?
    let onSave: (Bool) -> Void
    let onCancel: () -> Void

    @State private var title = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600) // 1 hour later
    @State private var isAllDay = false
    @State private var location = ""
    @State private var notes = ""
    @State private var selectedCalendar: String = ""
    @State private var availableCalendars: [EKCalendar] = []
    @State private var showingEventSearch = false
    @State private var searchQuery = ""
    @State private var searchResults: [UnifiedEvent] = []

    var body: some View {
        NavigationView {
            ScrollView(.vertical, showsIndicators: true, content: {
                VStack(spacing: 20) {
                    // Header with Cancel and Save buttons
                    HStack {
                        Button("Cancel") {
                            onCancel()
                        }
                        .dynamicFont(size: 16, fontManager: fontManager)

                        Spacer()

                        Button("Save") {
                            saveEvent()
                        }
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        .disabled(title.isEmpty)
                    }
                    .padding(.horizontal)

                    // Form header
                    VStack(spacing: 8) {
                        Image(systemName: formIcon)
                            .font(.system(size: 40))
                            .foregroundColor(.blue)

                        Text(formTitle)
                            .dynamicFont(size: 24, weight: .bold, fontManager: fontManager)

                        Text(formDescription)
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // Form fields
                    VStack(spacing: 16) {
                        // Title field with event search for update
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                .foregroundColor(.primary)

                            if formType == .updateEvent {
                                HStack {
                                    TextField("Search events...", text: $searchQuery)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .dynamicFont(size: 16, fontManager: fontManager)
                                        .onChange(of: searchQuery) { query in
                                            searchEvents(query)
                                        }

                                    Button("Search") {
                                        showingEventSearch.toggle()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }

                                if !searchResults.isEmpty {
                                    ScrollView {
                                        LazyVStack {
                                            ForEach(searchResults) { event in
                                                Button(action: {
                                                    selectEvent(event)
                                                }) {
                                                    HStack {
                                                        VStack(alignment: .leading) {
                                                            Text(event.title)
                                                                .font(.headline)
                                                            Text(event.duration)
                                                                .font(.caption)
                                                                .foregroundColor(.secondary)
                                                        }
                                                        Spacer()
                                                        Text(event.sourceLabel)
                                                            .font(.caption2)
                                                    }
                                                    .padding(8)
                                                    .background(Color.gray.opacity(0.1))
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                                }
                                                .buttonStyle(PlainButtonStyle())
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 200)
                                }
                            } else {
                                TextField("Event title", text: $title)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .dynamicFont(size: 16, fontManager: fontManager)
                            }
                        }

                        // Location field (moved under title)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Location")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                .foregroundColor(.primary)

                            TextField("Enter location", text: $location)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }

                        // Calendar selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Calendar")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                .foregroundColor(.primary)

                            if availableCalendars.isEmpty {
                                Text("Default Calendar")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .dynamicFont(size: 16, fontManager: fontManager)
                            } else {
                                Picker("Select Calendar", selection: $selectedCalendar) {
                                    ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                        Text(calendar.title)
                                            .tag(calendar.calendarIdentifier)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }
                        }

                        // Date and time fields
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Date & Time")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                .foregroundColor(.primary)

                            Toggle("All Day", isOn: $isAllDay)
                                .dynamicFont(size: 16, fontManager: fontManager)

                            if !isAllDay {
                                VStack(spacing: 12) {
                                    HStack {
                                        Text("Start:")
                                            .dynamicFont(size: 14, fontManager: fontManager)
                                            .frame(width: 50, alignment: .leading)
                                        DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                            .labelsHidden()
                                    }

                                    HStack {
                                        Text("End:")
                                            .dynamicFont(size: 14, fontManager: fontManager)
                                            .frame(width: 50, alignment: .leading)
                                        DatePicker("", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                                            .labelsHidden()
                                    }
                                }
                            } else {
                                DatePicker("Date", selection: $startDate, displayedComponents: [.date])
                                    .labelsHidden()
                            }
                        }


                        // Notes field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                .foregroundColor(.primary)

                            TextField("Optional notes", text: $notes)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .dynamicFont(size: 16, fontManager: fontManager)
                                .lineLimit(6)
                        }
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: 80)
                }
            })
            .navigationTitle("")
            .navigationBarHidden(true)
        }
        .onAppear {
            loadEventData()
            loadAvailableCalendars()
            // Auto-adjust end date when start date changes
            if eventToEdit == nil {
                endDate = startDate.addingTimeInterval(3600)
            }
        }
        .onChange(of: startDate) { newValue in
            if eventToEdit == nil {
                endDate = newValue.addingTimeInterval(3600)
            }
        }
        .onChange(of: isAllDay) { newValue in
            if newValue {
                // Set to beginning/end of day for all-day events
                let calendar = Calendar.current
                startDate = calendar.startOfDay(for: startDate)
                endDate = calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
            }
        }
    }

    private var formTitle: String {
        switch formType {
        case .createEvent, .scheduleEvent:
            return "Create Event"
        case .updateEvent:
            return "Update Event"
        case .blockTime:
            return "Block Time"
        }
    }

    private var formDescription: String {
        switch formType {
        case .createEvent, .scheduleEvent:
            return "Create a new calendar event with details"
        case .updateEvent:
            return "Update the selected calendar event"
        case .blockTime:
            return "Block time on your calendar"
        }
    }

    private var formIcon: String {
        switch formType {
        case .createEvent, .scheduleEvent:
            return "calendar.badge.plus"
        case .updateEvent:
            return "calendar.badge.clock"
        case .blockTime:
            return "calendar.badge.minus"
        }
    }

    private func loadEventData() {
        guard let event = eventToEdit else {
            // For new events, set reasonable defaults
            if formType == .blockTime {
                title = "Blocked Time"
            }
            return
        }

        // Load existing event data for editing
        title = event.title
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        location = event.location ?? ""
        notes = event.description ?? ""
    }

    private func saveEvent() {
        // Create CalendarCommand for the AI system
        let command = CalendarCommand(
            type: formType == .updateEvent ? .updateEvent : .createEvent,
            title: title.isEmpty ? nil : title,
            startDate: startDate,
            endDate: endDate,
            location: location.isEmpty ? nil : location,
            notes: notes.isEmpty ? nil : notes,
            eventId: eventToEdit?.id
        )

        // Create AI response for processing
        let response = AICalendarResponse(
            message: formType == .updateEvent ? "Event updated successfully" : "Event created successfully",
            command: command,
            requiresConfirmation: false,
            confirmationMessage: nil
        )

        // Process through calendar manager
        calendarManager.handleAICalendarResponse(response)

        // Notify parent of success
        onSave(true)
    }

    private func loadAvailableCalendars() {
        availableCalendars = calendarManager.eventStore.calendars(for: .event)

        if let defaultCalendar = calendarManager.eventStore.defaultCalendarForNewEvents {
            selectedCalendar = defaultCalendar.calendarIdentifier
        } else if let firstCalendar = availableCalendars.first {
            selectedCalendar = firstCalendar.calendarIdentifier
        }
    }

    private func searchEvents(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        searchResults = calendarManager.unifiedEvents.filter { event in
            event.title.lowercased().contains(query.lowercased())
        }
    }

    private func selectEvent(_ event: UnifiedEvent) {
        title = event.title
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        location = event.location ?? ""
        notes = event.description ?? ""
        searchQuery = event.title
        searchResults = []
    }
}

