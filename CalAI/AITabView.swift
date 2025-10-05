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
                        // AI Brain icon with mic next to it
                        HStack(alignment: .bottom, spacing: 2) {
                            // Mic icon positioned next to the brain's "mouth"
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
                            .offset(y: 2) // Move down to align top of mic with lips

                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                        }
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
                                    onCategoryDoubleTap: { tappedCategory in
                                        handleCategoryDoubleTap(tappedCategory)
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
            // Add a message to trigger conversation view
            let message = "📝 Opening \(text) form..."
            let item = ConversationItem(
                id: UUID(),
                message: message,
                isUser: false,
                timestamp: Date()
            )
            conversationHistory.append(item)

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
        } else if lowerCommand.contains("delete") && lowerCommand.contains("event") {
            return .deleteEvent
        } else if lowerCommand.contains("schedule") && lowerCommand.contains("event") {
            return .createEvent
        } else if lowerCommand.contains("block") && lowerCommand.contains("time") {
            return .blockTime
        }

        // Return nil for query commands (show events, find event, etc.)
        return nil
    }

    private func handleCategoryDoubleTap(_ category: CommandCategory) {
        switch category {
        case .eventQueries:
            // Show Event Queries & Search form
            // Add a message to trigger conversation view
            let message = "🔍 Opening Event Search..."
            let item = ConversationItem(
                id: UUID(),
                message: message,
                isUser: false,
                timestamp: Date()
            )
            conversationHistory.append(item)

            withAnimation(.easeInOut(duration: 0.3)) {
                showingInlineForm = true
                currentFormType = .eventQueries
            }
        case .attendeeManagement:
            // Handle Attendee Management - placeholder for now
            let message = "Attendee Management functionality will be implemented here"
            let item = ConversationItem(
                id: UUID(),
                message: message,
                isUser: false,
                timestamp: Date()
            )
            conversationHistory.append(item)
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
    case deleteEvent
    case blockTime
    case scheduleEvent
    case eventQueries
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
                    print("🔔 Double-tap detected on category: \(category.rawValue)")
                    onCategoryDoubleTap?(category)
                }
            }
            .onLongPressGesture(minimumDuration: 0.05, maximumDistance: .infinity, pressing: { pressing in
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
    @State private var eventURL = ""
    @State private var selectedCalendar: String = ""
    @State private var availableCalendars: [EKCalendar] = []
    @State private var showingEventSearch = false
    @State private var searchQuery = ""
    @State private var searchResults: [UnifiedEvent] = []
    @State private var selectedRepeat: RepeatOption = .none
    @State private var attendees: [EventAttendee] = []
    @State private var newAttendeeEmail = ""
    @State private var showingAttendeeInput = false
    @State private var sendInvitations = true
    @State private var attachments: [AttachmentItem] = []
    @State private var showingDocumentPicker = false
    @State private var showingLocationPicker = false
    @State private var selectedEventForDelete: UnifiedEvent?

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

                        if formType == .deleteEvent {
                            Button("Delete") {
                                deleteEvent()
                            }
                            .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                            .foregroundColor(.red)
                            .disabled(title.isEmpty)
                        } else if formType != .eventQueries {
                            Button("Save") {
                                saveEvent()
                            }
                            .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                            .disabled(title.isEmpty)
                        } else {
                            Button("Done") {
                                onCancel()
                            }
                            .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        }
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
                        if formType == .deleteEvent {
                            // Event Search Interface for Delete
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Search Event to Delete")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                HStack {
                                    TextField("Search events...", text: $searchQuery)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .dynamicFont(size: 16, fontManager: fontManager)
                                        .onChange(of: searchQuery) { query in
                                            searchEvents(query)
                                        }

                                    Button("Search") {
                                        searchEvents(searchQuery)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }

                            // Search Results for Delete
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

                            // Selected event display
                            if !title.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Selected Event")
                                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                        .foregroundColor(.primary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(title)
                                            .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)

                                        if !location.isEmpty {
                                            HStack {
                                                Image(systemName: "location.fill")
                                                    .foregroundColor(.secondary)
                                                    .font(.caption)
                                                Text(location)
                                                    .dynamicFont(size: 14, fontManager: fontManager)
                                                    .foregroundColor(.secondary)
                                            }
                                        }

                                        HStack {
                                            Image(systemName: "calendar")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                            Text("\(formatDate(startDate)) - \(formatDate(endDate))")
                                                .dynamicFont(size: 14, fontManager: fontManager)
                                                .foregroundColor(.secondary)
                                        }

                                        if !notes.isEmpty {
                                            Text(notes)
                                                .dynamicFont(size: 14, fontManager: fontManager)
                                                .foregroundColor(.secondary)
                                                .lineLimit(3)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        } else if formType == .eventQueries {
                            // Event Search Interface
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Search Events")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                HStack {
                                    TextField("Search events by title, location, or description...", text: $searchQuery)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .dynamicFont(size: 16, fontManager: fontManager)
                                        .onChange(of: searchQuery) { query in
                                            searchEvents(query)
                                        }

                                    Button("Search") {
                                        searchEvents(searchQuery)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                            }

                            // Location Filter
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Location Filter")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                TextField("Filter by location", text: $location)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .dynamicFont(size: 16, fontManager: fontManager)
                            }

                            // Calendar Selection
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Select Calendar")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                Picker("Select Calendar", selection: $selectedCalendar) {
                                    Text("All Calendars").tag("")
                                    Text("iOS Calendars").tag("ios")
                                    Text("Google Calendar").tag("google")
                                    Text("Outlook Calendar").tag("outlook")

                                    if !availableCalendars.isEmpty {
                                        Divider()
                                        ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                            Text(calendar.title)
                                                .tag(calendar.calendarIdentifier)
                                        }
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }

                            // Date Range Filter
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Date Range")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                HStack {
                                    VStack(alignment: .leading) {
                                        Text("From")
                                            .dynamicFont(size: 12, fontManager: fontManager)
                                            .foregroundColor(.secondary)
                                        DatePicker("", selection: $startDate, displayedComponents: [.date])
                                            .datePickerStyle(.compact)
                                    }

                                    VStack(alignment: .leading) {
                                        Text("To")
                                            .dynamicFont(size: 12, fontManager: fontManager)
                                            .foregroundColor(.secondary)
                                        DatePicker("", selection: $endDate, displayedComponents: [.date])
                                            .datePickerStyle(.compact)
                                    }
                                }
                            }

                            // Search Results
                            if !searchResults.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Search Results (\(searchResults.count) found)")
                                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                        .foregroundColor(.primary)

                                    ScrollView {
                                        LazyVStack(spacing: 8) {
                                            ForEach(searchResults) { event in
                                                VStack(alignment: .leading, spacing: 4) {
                                                    HStack {
                                                        VStack(alignment: .leading) {
                                                            Text(event.title)
                                                                .dynamicFont(size: 15, weight: .semibold, fontManager: fontManager)
                                                            Text(event.duration)
                                                                .dynamicFont(size: 12, fontManager: fontManager)
                                                                .foregroundColor(.secondary)
                                                            if let loc = event.location, !loc.isEmpty {
                                                                Text("📍 \(loc)")
                                                                    .dynamicFont(size: 12, fontManager: fontManager)
                                                                    .foregroundColor(.secondary)
                                                            }
                                                        }
                                                        Spacer()
                                                        VStack {
                                                            Text(event.sourceLabel)
                                                                .dynamicFont(size: 10, weight: .medium, fontManager: fontManager)
                                                                .foregroundColor(.secondary)
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 2)
                                                                .background(Color(.systemGray5))
                                                                .cornerRadius(4)
                                                        }
                                                    }
                                                }
                                                .padding(12)
                                                .background(Color(.systemGray6))
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                    }
                                    .frame(maxHeight: 300)
                                }
                            } else if !searchQuery.isEmpty {
                                VStack {
                                    Image(systemName: "magnifyingglass")
                                        .font(.system(size: 30))
                                        .foregroundColor(.gray)
                                    Text("No events found")
                                        .dynamicFont(size: 14, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 20)
                            }
                        } else {
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
                        }

                        if formType != .eventQueries {
                            // Location field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Location")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                Button(action: {
                                    showingLocationPicker = true
                                }) {
                                    HStack {
                                        if location.isEmpty {
                                            Text("Add location")
                                                .dynamicFont(size: 16, fontManager: fontManager)
                                                .foregroundColor(.secondary)
                                        } else {
                                            Text(location)
                                                .dynamicFont(size: 16, fontManager: fontManager)
                                                .foregroundColor(.blue)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(PlainButtonStyle())
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
                                    .dynamicFont(size: 14, fontManager: fontManager)

                                if !isAllDay {
                                    VStack(spacing: 12) {
                                        HStack {
                                            Text("Start:")
                                                .dynamicFont(size: 12, fontManager: fontManager)
                                                .frame(width: 50, alignment: .leading)
                                            DatePicker("", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                                                .labelsHidden()
                                                .scaleEffect(0.9)
                                        }

                                        HStack {
                                            Text("End:")
                                                .dynamicFont(size: 12, fontManager: fontManager)
                                                .frame(width: 50, alignment: .leading)
                                            DatePicker("", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                                                .labelsHidden()
                                                .scaleEffect(0.9)
                                        }
                                    }
                                } else {
                                    DatePicker("Date", selection: $startDate, displayedComponents: [.date])
                                        .labelsHidden()
                                        .scaleEffect(0.9)
                                }
                            }

                            // Repeat section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Repeat")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                Picker("Repeat", selection: $selectedRepeat) {
                                    ForEach(RepeatOption.allCases) { option in
                                        Text(option.displayName)
                                            .dynamicFont(size: 16, fontManager: fontManager)
                                            .tag(option)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                            }

                            // Attendees section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Invites & Attendees")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                if attendees.isEmpty {
                                    Button(action: {
                                        showingAttendeeInput = true
                                    }) {
                                        HStack {
                                            Image(systemName: "person.badge.plus")
                                                .foregroundColor(.blue)
                                            Text("Add Attendees")
                                                .dynamicFont(size: 16, fontManager: fontManager)
                                                .foregroundColor(.blue)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(attendees) { attendee in
                                            HStack {
                                                Image(systemName: "person.circle")
                                                    .foregroundColor(.secondary)
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(attendee.displayName)
                                                        .dynamicFont(size: 16, fontManager: fontManager)
                                                    Text(attendee.email)
                                                        .dynamicFont(size: 12, fontManager: fontManager)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Button(action: {
                                                    removeAttendee(attendee)
                                                }) {
                                                    Image(systemName: "minus.circle.fill")
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }

                                        Button(action: {
                                            showingAttendeeInput = true
                                        }) {
                                            HStack {
                                                Image(systemName: "plus")
                                                    .foregroundColor(.blue)
                                                Text("Add More")
                                                    .dynamicFont(size: 16, fontManager: fontManager)
                                                    .foregroundColor(.blue)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }

                                        Toggle("Send Invitations", isOn: $sendInvitations)
                                            .dynamicFont(size: 16, fontManager: fontManager)
                                    }
                                }
                            }

                            // URL field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("URL")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                TextField("Event URL", text: $eventURL)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .dynamicFont(size: 16, fontManager: fontManager)
                                    .keyboardType(.URL)
                                    .autocapitalization(.none)
                            }

                            // Attachments section
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Attachments")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                if attachments.isEmpty {
                                    Button(action: {
                                        showingDocumentPicker = true
                                    }) {
                                        HStack {
                                            Image(systemName: "paperclip")
                                                .foregroundColor(.blue)
                                            Text("Add Attachment")
                                                .dynamicFont(size: 16, fontManager: fontManager)
                                                .foregroundColor(.blue)
                                            Spacer()
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(Color.gray.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                } else {
                                    VStack(spacing: 8) {
                                        ForEach(attachments) { attachment in
                                            HStack {
                                                Image(systemName: "doc")
                                                    .foregroundColor(.secondary)
                                                Text(attachment.name)
                                                    .dynamicFont(size: 16, fontManager: fontManager)
                                                Spacer()
                                                Button(action: {
                                                    removeAttachment(attachment)
                                                }) {
                                                    Image(systemName: "trash")
                                                        .foregroundColor(.red)
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }

                                        Button(action: {
                                            showingDocumentPicker = true
                                        }) {
                                            HStack {
                                                Image(systemName: "plus")
                                                    .foregroundColor(.blue)
                                                Text("Add More")
                                                    .dynamicFont(size: 16, fontManager: fontManager)
                                                    .foregroundColor(.blue)
                                                Spacer()
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(Color.gray.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                    }
                                }
                            }

                            // Notes field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes")
                                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                TextEditor(text: $notes)
                                    .dynamicFont(size: 16, fontManager: fontManager)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
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
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(
                selectedLocation: $location,
                fontManager: fontManager,
                onLocationSelected: { selectedLocation in
                    location = selectedLocation
                    showingLocationPicker = false
                },
                onCancel: {
                    showingLocationPicker = false
                }
            )
        }
        .sheet(isPresented: $showingAttendeeInput) {
            AttendeeInputView(
                newAttendeeEmail: $newAttendeeEmail,
                onAdd: { email in
                    addAttendee(email: email)
                    showingAttendeeInput = false
                },
                onCancel: {
                    newAttendeeEmail = ""
                    showingAttendeeInput = false
                }
            )
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { urls in
                for url in urls {
                    addAttachment(from: url)
                }
            }
        }
    }

    private var formTitle: String {
        switch formType {
        case .createEvent, .scheduleEvent:
            return "Create Event"
        case .updateEvent:
            return "Update Event"
        case .deleteEvent:
            return "Delete Event"
        case .blockTime:
            return "Block Time"
        case .eventQueries:
            return "Event Queries & Search"
        }
    }

    private var formDescription: String {
        switch formType {
        case .createEvent, .scheduleEvent:
            return "Create a new calendar event with details"
        case .updateEvent:
            return "Update the selected calendar event"
        case .deleteEvent:
            return "Search and delete a calendar event"
        case .blockTime:
            return "Block time on your calendar"
        case .eventQueries:
            return "Search and find events in your calendars"
        }
    }

    private var formIcon: String {
        switch formType {
        case .createEvent, .scheduleEvent:
            return "calendar.badge.plus"
        case .updateEvent:
            return "calendar.badge.clock"
        case .deleteEvent:
            return "calendar.badge.exclamationmark"
        case .blockTime:
            return "calendar.badge.minus"
        case .eventQueries:
            return "magnifyingglass.circle"
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

        // Store selected event for deletion
        if formType == .deleteEvent {
            selectedEventForDelete = event
        }
    }

    private func addAttendee(email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty,
              trimmedEmail.contains("@"),
              !attendees.contains(where: { $0.email == trimmedEmail }) else {
            return
        }

        let name = extractDisplayName(from: trimmedEmail)
        let attendee = EventAttendee(email: trimmedEmail, name: name.isEmpty ? nil : name)
        attendees.append(attendee)
        newAttendeeEmail = ""
    }

    private func removeAttendee(_ attendee: EventAttendee) {
        attendees.removeAll { $0.id == attendee.id }
    }

    private func extractDisplayName(from email: String) -> String {
        let localPart = email.components(separatedBy: "@").first ?? ""
        let nameParts = localPart.components(separatedBy: ".")

        if nameParts.count >= 2 {
            let firstName = nameParts[0].capitalized
            let lastName = nameParts[1].capitalized
            return "\(firstName) \(lastName)"
        } else {
            return localPart.capitalized
        }
    }

    private func addAttachment(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Failed to access security scoped resource")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let attachment = AttachmentItem(
                name: url.lastPathComponent,
                url: url,
                data: data
            )
            attachments.append(attachment)
        } catch {
            print("❌ Failed to read attachment: \(error)")
        }
    }

    private func removeAttachment(_ attachment: AttachmentItem) {
        attachments.removeAll { $0.id == attachment.id }
    }

    private func deleteEvent() {
        guard !title.isEmpty, let eventToDelete = selectedEventForDelete else {
            print("⚠️ No event selected for deletion")
            return
        }

        // Create CalendarCommand for deletion
        let command = CalendarCommand(
            type: .deleteEvent,
            title: nil,
            startDate: nil,
            endDate: nil,
            location: nil,
            notes: nil,
            eventId: eventToDelete.id
        )

        // Create AI response for processing
        let response = AICalendarResponse(
            message: "Event '\(title)' deleted successfully",
            command: command,
            requiresConfirmation: false,
            confirmationMessage: nil
        )

        // Process through calendar manager
        calendarManager.handleAICalendarResponse(response)

        // Notify parent of success
        onSave(true)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

