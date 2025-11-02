import Foundation
import SwiftAnthropic
import EventKit

// MARK: - Data Structures

struct ConversationItem: Identifiable {
    let id: UUID
    let message: String
    let isUser: Bool
    let timestamp: Date
    let eventResults: [EventResult]?

    init(id: UUID = UUID(), message: String, isUser: Bool, timestamp: Date = Date(), eventResults: [EventResult]? = nil) {
        self.id = id
        self.message = message
        self.isUser = isUser
        self.timestamp = timestamp
        self.eventResults = eventResults
    }
}

enum AIError: Error {
    case invalidResponse
    case apiError(String)
    case networkError
    case authenticationError
    case rateLimitError
    case timeoutError
    case noAPIKeyConfigured

    var userFriendlyMessage: String {
        switch self {
        case .invalidResponse:
            return "I received an unexpected response. Please try again."
        case .apiError(let message):
            return "I encountered an error: \(message)"
        case .networkError:
            return "I'm having trouble connecting. Please check your internet connection."
        case .authenticationError:
            return "There's an issue with the API configuration. Please check your settings."
        case .rateLimitError:
            return "I've received too many requests. Please wait a moment and try again."
        case .timeoutError:
            return "The request took too long. Please try again."
        case .noAPIKeyConfigured:
            return "Please configure your API key in Settings to use AI features."
        }
    }
}

// Represents the state of a multi-turn conversation
enum ConversationState: Equatable, CustomStringConvertible {
    case idle // Waiting for a new command
    case awaitingConfirmation // AI has asked a yes/no question and is waiting for a reply
    case creatingEvent(ExtractedEntities, missingField: String) // In the middle of creating an event, waiting for missing info

    var description: String {
        switch self {
        case .idle:
            return "idle"
        case .awaitingConfirmation:
            return "awaitingConfirmation"
        case .creatingEvent(_, let missingField):
            return "creatingEvent(missingField: \(missingField))"
        }
    }

    static func == (lhs: ConversationState, rhs: ConversationState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.awaitingConfirmation, .awaitingConfirmation):
            return true
        case (.creatingEvent(_, let lhsField), .creatingEvent(_, let rhsField)):
            return lhsField == rhsField
        default:
            return false
        }
    }
}

class AIManager: ObservableObject {
    @Published var isProcessing = false

    // State management for multi-turn conversations
    @Published var conversationState: ConversationState = .idle
    @Published var pendingCommand: CalendarCommand? = nil

    // Conversation context retention
    private var lastQueryTimeRange: (start: Date, end: Date)?
    private var lastQueryEvents: [UnifiedEvent] = []
    private var conversationContext: [String] = [] // Recent user queries
    private let maxContextMessages = 3 // Keep last 3 messages for context

    private let parser: NaturalLanguageParser
    private let smartEventParser: SmartEventParser
    private let voiceResponseGenerator: VoiceResponseGenerator
    private let conversationalAI: ConversationalAIService
    private var enhancedConversationalAI: EnhancedConversationalAI?
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    init() {
        self.parser = NaturalLanguageParser()
        self.smartEventParser = SmartEventParser()
        self.voiceResponseGenerator = VoiceResponseGenerator()
        self.conversationalAI = ConversationalAIService()

        // Initialize enhanced conversational AI (using OpenAI backend)
        self.enhancedConversationalAI = EnhancedConversationalAI(aiService: self.conversationalAI)
        print("✅ Enhanced Conversational AI with memory enabled (OpenAI backend)")
    }

    // MARK: - Enhanced Conversational Processing

    func processConversationalCommand(
        _ transcript: String,
        calendarEvents: [UnifiedEvent],
        completion: @escaping (AICalendarResponse) -> Void
    ) {
        guard let enhancedAI = enhancedConversationalAI else {
            // Fall back to standard processing
            processVoiceCommand(transcript, calendarEvents: calendarEvents, completion: completion)
            return
        }

        print("💬 Using Enhanced Conversational AI with memory")
        isProcessing = true

        Task {
            do {
                // Process with conversation memory
                let response = try await enhancedAI.processWithMemory(
                    message: transcript,
                    calendarEvents: calendarEvents
                )

                print("✅ Enhanced AI Response:")
                print("   Intent: \(response.intent)")
                print("   Message: \(response.message)")
                print("   Parameters: \(response.parameters)")
                print("   Needs clarification: \(response.needsClarification)")

                // Handle query intent specially to include event list
                let calendarResponse: AICalendarResponse
                if response.intent == "query" {
                    // Extract time range and filter events for query responses
                    let (startDate, endDate) = extractTimeRange(from: transcript)
                    let relevantEvents = calendarEvents.filter { event in
                        event.startDate >= startDate && event.startDate < endDate
                    }.sorted { $0.startDate < $1.startDate }

                    print("📅 Query found \(relevantEvents.count) events in range")

                    // Use VoiceResponseGenerator to create proper natural language response with full day narrative
                    let voiceResponse = voiceResponseGenerator.generateQueryResponse(
                        events: relevantEvents,
                        timeRange: (start: startDate, end: endDate)
                    )

                    let fullMessage = voiceResponse.fullMessage
                    print("✅ Generated full day narrative: \(fullMessage)")

                    // Convert events to EventResult format
                    let eventResults = relevantEvents.map { event in
                        EventResult(
                            id: event.id,
                            title: event.title,
                            startDate: event.startDate,
                            endDate: event.endDate,
                            location: event.location,
                            source: event.source.rawValue,
                            color: nil
                        )
                    }

                    let command = CalendarCommand(
                        type: .queryEvents,
                        queryStartDate: startDate,
                        queryEndDate: endDate
                    )

                    calendarResponse = AICalendarResponse(
                        message: fullMessage,
                        command: command,
                        eventResults: eventResults,
                        shouldContinueListening: voiceResponse.followUp != nil
                    )
                } else {
                    // For non-query intents, use standard response
                    calendarResponse = AICalendarResponse(
                        message: response.message,
                        shouldContinueListening: response.shouldContinueListening
                    )

                    // Execute actions - pass original transcript for fallback extraction
                    await executeEnhancedAction(
                        type: response.intent,
                        parameters: response.parameters,
                        originalTranscript: transcript,
                        response: calendarResponse
                    )
                }

                await MainActor.run {
                    self.isProcessing = false
                    completion(calendarResponse)
                }

            } catch {
                print("❌ Enhanced AI processing error: \(error)")
                await MainActor.run {
                    self.isProcessing = false
                    completion(AICalendarResponse(
                        message: "I had trouble understanding that. Could you rephrase?",
                        shouldContinueListening: true
                    ))
                }
            }
        }
    }

    private func executeEnhancedAction(
        type: String,
        parameters: [String: ConversationalAIService.AnyCodableValue],
        originalTranscript: String,
        response: AICalendarResponse
    ) async {
        print("🎬 Executing action: \(type)")
        print("📋 Parameters: \(parameters)")
        print("📝 Original transcript: \(originalTranscript)")

        // Convert AnyCodableValue parameters to strings for easier access
        var stringParams = parameters.mapValues { value -> String in
            switch value {
            case .string(let str):
                return str
            case .int(let int):
                return "\(int)"
            case .double(let double):
                return "\(double)"
            case .bool(let bool):
                return "\(bool)"
            case .date(let date):
                return "\(date)"
            case .array(let arr):
                return "\(arr)"
            case .dictionary(let dict):
                return "\(dict)"
            case .null:
                return ""
            }
        }

        // If parameters are empty but this looks like a task creation, extract from transcript
        if (type == "create" || type.contains("task")) && parameters.isEmpty {
            print("⚠️ Empty parameters - attempting fallback extraction from transcript")
            stringParams = extractTaskFromTranscript(originalTranscript)
        }

        switch type {
        case "createEvent":
            // Handle event creation
            if let title = stringParams["title"],
               let startDateStr = stringParams["startDate"] {
                print("📅 Creating event: \(title) at \(startDateStr)")
                // Implementation will come from existing event creation logic
            }

        case "create", "createTask", "create_task":
            // Handle task creation
            print("🎯 Creating task from enhanced AI...")

            guard let title = stringParams["title"] else {
                print("⚠️ No title found in parameters!")
                return
            }

            // If title is empty, skip
            if title.trimmingCharacters(in: .whitespaces).isEmpty {
                print("⚠️ Title is empty after extraction!")
                return
            }

            print("📝 Task title: \(title)")

            // Extract priority
            let priorityStr = stringParams["priority"] ?? "medium"
            let priority = TaskPriority(rawValue: priorityStr.capitalized) ?? .medium
            print("   Priority: \(priority.rawValue)")

            // Extract description
            let description = stringParams["description"]

            // Extract scheduled time
            var scheduledTime: Date?
            if let scheduledTimeStr = stringParams["scheduled_time"] ?? stringParams["scheduledTime"] {
                scheduledTime = ISO8601DateFormatter().date(from: scheduledTimeStr)
                print("   Scheduled time: \(scheduledTime?.description ?? "none")")
            }

            // Extract due date
            var dueDate: Date?
            if let dueDateStr = stringParams["due_date"] ?? stringParams["dueDate"] {
                dueDate = ISO8601DateFormatter().date(from: dueDateStr)
                print("   Due date: \(dueDate?.description ?? "none")")
            }

            // Extract duration
            let durationMinutes = Int(stringParams["duration_minutes"] ?? stringParams["durationMinutes"] ?? "")

            // If task has scheduled time but no duration, set a default duration of 30 minutes
            var duration: TimeInterval?
            if let _ = scheduledTime {
                let minutes = durationMinutes ?? 30  // Default to 30 minutes
                duration = TimeInterval(minutes * 60)
            }

            // Create the task
            let task = EventTask(
                title: title,
                description: description,
                priority: priority,
                estimatedMinutes: durationMinutes,
                dueDate: dueDate,
                scheduledTime: scheduledTime,
                duration: duration
            )

            EventTaskManager.shared.addTask(task, to: "standalone_tasks")
            print("✅ Task created and added to standalone_tasks")

            // Verify it was added
            let tasks = EventTaskManager.shared.getTasks(for: "standalone_tasks")
            print("📊 Total standalone tasks now: \(tasks?.tasks.count ?? 0)")

        case "querySchedule":
            // Schedule query already handled in message
            print("📊 Schedule query completed")

        default:
            print("⚠️ Unknown action type: \(type)")
        }
    }

    // MARK: - Context Management

    private func addToContext(_ message: String) {
        conversationContext.append(message)
        if conversationContext.count > maxContextMessages {
            conversationContext.removeFirst()
        }
        print("💭 Context updated: \(conversationContext)")
    }

    private func buildContextPrompt() -> String {
        guard !conversationContext.isEmpty else {
            return ""
        }
        return "\nRecent conversation context:\n" + conversationContext.enumerated().map { index, msg in
            "[\(index + 1)] \(msg)"
        }.joined(separator: "\n") + "\n"
    }

    // MARK: - Main Command Processing

    func processVoiceCommand(_ transcript: String, conversationHistory: [ConversationItem] = [], calendarEvents: [UnifiedEvent] = [], calendarManager: CalendarManager? = nil, completion: @escaping (AICalendarResponse) -> Void) {
        print("🧠 AI Manager processing transcript: \"\(transcript)\"")
        print("🔄 Current conversation state: \(conversationState)")
        isProcessing = true

        if conversationState == .awaitingConfirmation {
            print("✋ Handling confirmation response")
            handleConfirmation(transcript: transcript, completion: completion)
            return
        }

        // Check if we're in the middle of creating an event
        if case .creatingEvent(let entities, let missingField) = conversationState {
            print("📝 Continuing event creation - filling in: \(missingField)")
            print("📝 Current entities: title=\(entities.title ?? "nil"), attendees=\(entities.attendeeNames), time=\(entities.time?.description ?? "nil")")
            handleEventClarification(transcript: transcript, entities: entities, missingField: missingField, completion: completion)
            return
        }

        print("🆕 Starting new command processing")

        let cleanTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTranscript.isEmpty else {
            let response = AICalendarResponse(message: "I didn't catch that. Please try again.")
            DispatchQueue.main.async {
                self.isProcessing = false
                completion(response)
            }
            return
        }

        // Add to conversation context
        addToContext(cleanTranscript)

        // Check processing mode and route accordingly
        let processingMode = Config.aiProcessingMode
        print("⚙️ Processing mode: \(processingMode.displayName)")

        Task {
            do {
                // ROUTING BASED ON PROCESSING MODE
                switch processingMode {
                case .fullLLM:
                    // Full LLM Mode: Always use conversational AI
                    try await handleWithConversationalAI(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)
                    return

                case .hybrid:
                    // Hybrid Mode: Try pattern-based first, fallback to LLM if complex
                    let shouldUseLLM = isComplexCommand(cleanTranscript)
                    if shouldUseLLM {
                        print("🤖 Hybrid: Routing to LLM (complex command)")
                        try await handleWithConversationalAI(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)
                        return
                    } else {
                        print("⚡ Hybrid: Using pattern-based (simple command)")
                        // Continue to pattern-based processing below
                    }

                case .patternBased:
                    // Pattern-Based Mode: Use existing implementation
                    print("📋 Pattern-based processing")
                    // Continue to pattern-based processing below
                }

                // PATTERN-BASED PROCESSING (for patternBased mode and hybrid-simple commands)
                let intent = classifyIntent(from: cleanTranscript)
                print("🎯 Classified intent: \(intent)")

                switch intent {
                case .query:
                    // Handle calendar queries (what's on my schedule, etc.)
                    try await handleQuery(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .create:
                    // Handle event creation using SmartEventParser
                    await handleEventCreation(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .modify:
                    // Handle event modifications (reschedule, edit, update)
                    await handleModify(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .delete:
                    // Handle event deletion/cancellation
                    await handleDelete(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .search:
                    // Handle event search (find specific events)
                    await handleSearch(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .availability:
                    // Handle availability queries (am I free at X?)
                    await handleAvailability(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .analytics:
                    // Handle analytics/summary queries
                    await handleAnalytics(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .contextAware:
                    // Handle context-aware queries (do I have time for lunch?)
                    await handleContextAware(transcript: cleanTranscript, calendarEvents: calendarEvents, calendarManager: calendarManager, completion: completion)

                case .focusTime:
                    // Handle focus time / smart blocking
                    await handleFocusTime(transcript: cleanTranscript, completion: completion)

                case .conflicts:
                    // Handle conflict detection
                    await handleConflicts(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .batch:
                    // Handle batch operations
                    await handleBatch(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .weather:
                    // Handle weather queries
                    await handleWeather(transcript: cleanTranscript, completion: completion)

                case .createTask:
                    // Handle task creation
                    await handleCreateTask(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .listTasks:
                    // Handle listing tasks
                    await handleListTasks(transcript: cleanTranscript, calendarEvents: calendarEvents, completion: completion)

                case .updateTask:
                    // Handle task updates
                    await handleUpdateTask(transcript: cleanTranscript, completion: completion)

                case .completeTask:
                    // Handle task completion
                    await handleCompleteTask(transcript: cleanTranscript, completion: completion)

                case .conversation:
                    // Handle general conversation
                    try await handleConversation(transcript: cleanTranscript, completion: completion)
                }

            } catch {
                print("❌ Error processing voice command: \(error)")
                let errorMessage = handleError(error)
                let errorResponse = AICalendarResponse(message: errorMessage)
                await MainActor.run {
                    self.isProcessing = false
                    completion(errorResponse)
                }
            }
        }
    }

    // MARK: - Conversational AI Handling

    private func handleWithConversationalAI(
        transcript: String,
        calendarEvents: [UnifiedEvent],
        completion: @escaping (AICalendarResponse) -> Void
    ) async throws {
        print("🤖 Processing with Conversational AI... (Provider: \(Config.aiProvider.displayName))")

        // Route to appropriate AI service based on user's selection
        let action: ConversationalAIService.AIAction

        switch Config.aiProvider {
        case .onDevice:
            if #available(iOS 26.0, *) {
                // Use on-device Foundation Models
                print("📱 Using On-Device AI (Foundation Models)")
                action = try await processWithOnDeviceAI(transcript: transcript, calendarEvents: calendarEvents)
            } else {
                // Fallback to cloud if on-device not available
                print("⚠️ On-device AI not available, falling back to cloud provider")
                action = try await conversationalAI.processCommand(transcript, calendarEvents: calendarEvents)
            }

        case .anthropic, .openai:
            // Use cloud-based AI (OpenAI or Anthropic)
            print("☁️ Using Cloud AI (\(Config.aiProvider.displayName))")
            action = try await conversationalAI.processCommand(transcript, calendarEvents: calendarEvents)
        }

        print("✅ AI Action: intent=\(action.intent), needsClarification=\(action.needsClarification)")

        // Convert AI action to calendar response
        let response = await convertAIActionToResponse(action, calendarEvents: calendarEvents, originalTranscript: transcript)

        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    // MARK: - On-Device AI Processing (iOS 26+)

    @available(iOS 26.0, *)
    private func processWithOnDeviceAI(
        transcript: String,
        calendarEvents: [UnifiedEvent]
    ) async throws -> ConversationalAIService.AIAction {
        let onDeviceAction = try await OnDeviceAIService.shared.processCommand(transcript, calendarEvents: calendarEvents)

        // Convert OnDeviceAIService.AIAction to ConversationalAIService.AIAction
        // Build parameters dictionary from individual fields
        var parameters: [String: ConversationalAIService.AnyCodableValue] = [:]

        if let startDate = onDeviceAction.startDate {
            parameters["startDate"] = .string(startDate)
        }
        if let endDate = onDeviceAction.endDate {
            parameters["endDate"] = .string(endDate)
        }
        if let title = onDeviceAction.title {
            parameters["title"] = .string(title)
        }
        if let location = onDeviceAction.location {
            parameters["location"] = .string(location)
        }

        return ConversationalAIService.AIAction(
            intent: onDeviceAction.intent,
            parameters: parameters,
            message: onDeviceAction.message,
            needsClarification: onDeviceAction.needsClarification,
            clarificationQuestion: onDeviceAction.clarificationQuestion,
            shouldContinueListening: onDeviceAction.shouldContinueListening,
            referencedEventIds: onDeviceAction.referencedEventIds
        )
    }

    private func convertAIActionToResponse(
        _ action: ConversationalAIService.AIAction,
        calendarEvents: [UnifiedEvent],
        originalTranscript: String
    ) async -> AICalendarResponse {

        print("🔄 Converting AI action to response")
        print("   Intent: \(action.intent)")
        print("   Message: \(action.message)")
        print("   Parameters: \(action.parameters)")

        // Handle clarification requests
        if action.needsClarification {
            return AICalendarResponse(
                message: action.clarificationQuestion ?? action.message,
                shouldContinueListening: true
            )
        }

        // Convert intent to calendar command
        var command: CalendarCommand? = nil

        switch action.intent {
        case "query":
            print("🔍 Processing query intent...")

            // Extract and parse dates
            let startDateStr = action.parameters["start_date"]?.stringValue
            let endDateStr = action.parameters["end_date"]?.stringValue

            print("📅 Date parameters: start=\(startDateStr ?? "nil"), end=\(endDateStr ?? "nil")")

            if let startDateStr = startDateStr,
               let endDateStr = endDateStr,
               let startDate = ISO8601DateFormatter().date(from: startDateStr),
               let endDate = ISO8601DateFormatter().date(from: endDateStr) {

                print("✅ Dates parsed successfully: \(startDate) to \(endDate)")

                let relevantEvents = calendarEvents.filter { $0.startDate >= startDate && $0.startDate < endDate }

                print("📋 Found \(relevantEvents.count) events in range")

                // Use VoiceResponseGenerator for rich narrative responses
                let voiceResponse = voiceResponseGenerator.generateQueryResponse(
                    events: relevantEvents,
                    timeRange: (start: startDate, end: endDate)
                )

                print("🗣️ Generated rich narrative: \(voiceResponse.fullMessage.prefix(100))...")

                let eventResults = relevantEvents.map { event in
                    EventResult(
                        id: event.id,
                        title: event.title,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        location: event.location,
                        source: event.source.rawValue,
                        color: nil
                    )
                }

                command = CalendarCommand(type: .queryEvents, queryStartDate: startDate, queryEndDate: endDate)

                return AICalendarResponse(
                    message: voiceResponse.fullMessage,  // Use rich narrative instead of action.message
                    command: command,
                    eventResults: eventResults,
                    shouldContinueListening: voiceResponse.followUp != nil
                )
            } else {
                print("⚠️ Query intent detected but date parsing failed")
                print("   Attempting to extract dates ourselves from user query")

                // Fallback: Try to extract time range ourselves
                let (extractedStart, extractedEnd) = extractTimeRange(from: originalTranscript)

                print("📅 Extracted dates: \(extractedStart) to \(extractedEnd)")

                let relevantEvents = calendarEvents.filter { $0.startDate >= extractedStart && $0.startDate < extractedEnd }

                print("📋 Found \(relevantEvents.count) events in extracted range")

                // Use VoiceResponseGenerator even in fallback case
                let voiceResponse = voiceResponseGenerator.generateQueryResponse(
                    events: relevantEvents,
                    timeRange: (start: extractedStart, end: extractedEnd)
                )

                print("🗣️ Generated rich narrative (fallback): \(voiceResponse.fullMessage.prefix(100))...")

                let eventResults = relevantEvents.map { event in
                    EventResult(
                        id: event.id,
                        title: event.title,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        location: event.location,
                        source: event.source.rawValue,
                        color: nil
                    )
                }

                command = CalendarCommand(type: .queryEvents, queryStartDate: extractedStart, queryEndDate: extractedEnd)

                return AICalendarResponse(
                    message: voiceResponse.fullMessage,  // Use rich narrative in fallback too
                    command: command,
                    eventResults: eventResults,
                    shouldContinueListening: voiceResponse.followUp != nil
                )
            }

        case "create":
            if let title = action.parameters["title"]?.stringValue,
               let startTimeStr = action.parameters["start_time"]?.stringValue {

                // Parse date with flexible ISO8601 formatter
                let startTime = parseFlexibleISO8601Date(startTimeStr)

                if let startTime = startTime {
                    let duration = action.parameters["duration_minutes"]?.intValue ?? 60
                    let endTime = startTime.addingTimeInterval(TimeInterval(duration * 60))

                    command = CalendarCommand(
                        type: .createEvent,
                        title: title,
                        startDate: startTime,
                        endDate: endTime,
                        location: action.parameters["location"]?.stringValue,
                        notes: action.parameters["notes"]?.stringValue
                    )

                    print("✅ Created calendar command: \(title) at \(startTime)")
                } else {
                    print("❌ Failed to parse date: \(startTimeStr)")
                }
            } else {
                print("❌ Missing title or start_time in create action")
            }

        case "delete":
            if let eventId = action.parameters["event_id"]?.stringValue {
                command = CalendarCommand(type: .deleteEvent, eventId: eventId)
            }

        case "modify":
            if let eventId = action.parameters["event_id"]?.stringValue {
                var newStartDate: Date? = nil
                if let newStartStr = action.parameters["new_start_time"]?.stringValue {
                    newStartDate = ISO8601DateFormatter().date(from: newStartStr)
                }

                command = CalendarCommand(
                    type: .updateEvent,
                    eventId: eventId,
                    newStartDate: newStartDate,
                    newTitle: action.parameters["new_title"]?.stringValue
                )
            }

        case "weather":
            print("🌦️ Processing weather intent...")

            // Check if there's a date parameter for forecast
            let weatherDate: Date?
            if let dateStr = action.parameters["date"]?.stringValue {
                weatherDate = ISO8601DateFormatter().date(from: dateStr)
                print("📅 Weather date parameter: \(dateStr) -> \(weatherDate?.description ?? "nil")")
            } else {
                weatherDate = nil
                print("📅 No date parameter - fetching current weather")
            }

            // Fetch weather and return response
            return await withCheckedContinuation { continuation in
                let fetchCompletion: (Result<WeatherData, Error>) -> Void = { result in
                    switch result {
                    case .success(let weatherData):
                        print("✅ Weather fetched successfully: \(weatherData.temperatureFormatted)")

                        // Build a natural weather response with date context
                        var weatherMessage: String
                        if let date = weatherDate {
                            let calendar = Calendar.current
                            let formatter = DateFormatter()

                            if calendar.isDateInToday(date) {
                                weatherMessage = "Today's weather: "
                            } else if calendar.isDateInTomorrow(date) {
                                weatherMessage = "Tomorrow's forecast: "
                            } else {
                                formatter.dateStyle = .full
                                formatter.timeStyle = .none
                                weatherMessage = "Weather for \(formatter.string(from: date)): "
                            }
                        } else {
                            weatherMessage = "It's currently "
                        }

                        weatherMessage += weatherData.temperatureFormatted

                        if !weatherData.condition.isEmpty {
                            weatherMessage += " and \(weatherData.condition.lowercased())"
                        }

                        if weatherData.high != weatherData.temperature || weatherData.low != weatherData.temperature {
                            let highTemp = String(format: "%.0f°", weatherData.high)
                            let lowTemp = String(format: "%.0f°", weatherData.low)
                            weatherMessage += ", with a high of \(highTemp) and a low of \(lowTemp)"
                        }

                        if weatherData.precipitationChance > 0 {
                            weatherMessage += ". There's a \(weatherData.precipitationChance)% chance of precipitation"
                        }

                        weatherMessage += "."

                        let response = AICalendarResponse(
                            message: weatherMessage,
                            shouldContinueListening: false
                        )
                        continuation.resume(returning: response)

                    case .failure(let error):
                        print("❌ Weather fetch failed: \(error.localizedDescription)")

                        // Provide helpful error message
                        var errorMessage = "I couldn't fetch the weather right now. "
                        let nsError = error as NSError

                        if nsError.code == 3 {
                            errorMessage += "Please enable location access in Settings to get weather information."
                        } else if nsError.code == 8 {
                            errorMessage += "I can only provide forecasts up to 10 days in the future."
                        } else {
                            errorMessage += error.localizedDescription
                        }

                        let response = AICalendarResponse(
                            message: errorMessage,
                            shouldContinueListening: false
                        )
                        continuation.resume(returning: response)
                    }
                }

                // Call appropriate weather service method
                if let date = weatherDate {
                    WeatherService.shared.fetchWeatherForDate(date, completion: fetchCompletion)
                } else {
                    WeatherService.shared.fetchCurrentWeather(completion: fetchCompletion)
                }
            }

        case "create_task":
            print("✅ Processing create_task intent...")
            print("📋 Task parameters received: \(action.parameters)")

            guard let title = action.parameters["title"]?.stringValue else {
                print("⚠️ No title found in parameters!")
                return AICalendarResponse(
                    message: "I need a title for the task. What should the task be called?",
                    shouldContinueListening: true
                )
            }

            print("📝 Task title: \(title)")

            // Extract task parameters
            let description = action.parameters["description"]?.stringValue
            let priorityStr = action.parameters["priority"]?.stringValue ?? "medium"
            let priority = TaskPriority(rawValue: priorityStr.capitalized) ?? .medium
            let project = action.parameters["project"]?.stringValue
            let durationMinutes = action.parameters["duration_minutes"]?.intValue

            // Extract tags
            var tags: [String] = []
            if case .array(let tagsArray) = action.parameters["tags"] {
                tags = tagsArray.compactMap { $0.stringValue }
            }

            // Extract due date or scheduled time
            var dueDate: Date?
            var scheduledTime: Date?

            if let dueDateStr = action.parameters["due_date"]?.stringValue {
                dueDate = ISO8601DateFormatter().date(from: dueDateStr)
                print("📅 Due date parsed: \(dueDate?.description ?? "nil")")
            }

            if let scheduledTimeStr = action.parameters["scheduled_time"]?.stringValue {
                scheduledTime = ISO8601DateFormatter().date(from: scheduledTimeStr)
                print("⏰ Scheduled time parsed: \(scheduledTime?.description ?? "nil")")
            }

            // Extract event ID if this is an event-related task
            let eventId = action.parameters["event_id"]?.stringValue

            // If task has scheduled time but no duration, set a default duration of 30 minutes
            var duration: TimeInterval?
            if let _ = scheduledTime {
                let minutes = durationMinutes ?? 30  // Default to 30 minutes
                duration = TimeInterval(minutes * 60)
            }

            // Create the task
            let task = EventTask(
                title: title,
                description: description,
                priority: priority,
                estimatedMinutes: durationMinutes,
                dueDate: dueDate,
                project: project,
                tags: tags,
                scheduledTime: scheduledTime,
                duration: duration
            )

            print("🎯 Creating task: \(task.title)")
            print("   Priority: \(task.priority.rawValue)")
            print("   Due date: \(task.dueDate?.description ?? "none")")
            print("   Scheduled time: \(task.scheduledTime?.description ?? "none")")
            print("   Duration: \(task.duration?.description ?? "none")")

            // Add task to appropriate location
            if let eventId = eventId {
                EventTaskManager.shared.addTask(task, to: eventId)
                print("✅ Task added to event \(eventId)")
            } else {
                // For standalone tasks, use a special "standalone" event ID
                EventTaskManager.shared.addTask(task, to: "standalone_tasks")
                print("✅ Standalone task created and added to 'standalone_tasks'")

                // Verify it was added
                let tasks = EventTaskManager.shared.getTasks(for: "standalone_tasks")
                print("📊 Total standalone tasks now: \(tasks?.tasks.count ?? 0)")
            }

            return AICalendarResponse(
                message: action.message,
                shouldContinueListening: false
            )

        case "list_tasks", "update_task", "complete_task":
            // These intents are handled - return the AI's message
            print("✅ Processing \(action.intent) intent...")
            return AICalendarResponse(
                message: action.message,
                shouldContinueListening: action.shouldContinueListening
            )

        default:
            // Conversation or unknown intent
            print("ℹ️ Default case - intent: \(action.intent)")
            break
        }

        // FALLBACK: This returns the basic Anthropic message
        print("⚠️ FALLBACK RETURN")
        print("   Intent: \(action.intent)")
        print("   Message: \(action.message)")
        print("   This should only happen for non-query intents or failed date parsing")

        // If this is a query intent that somehow got here, generate a proper response
        if action.intent == "query" {
            print("🔧 Query intent in fallback - generating proper response")
            let (extractedStart, extractedEnd) = extractTimeRange(from: originalTranscript)
            let relevantEvents = calendarEvents.filter { $0.startDate >= extractedStart && $0.startDate < extractedEnd }

            let voiceResponse = voiceResponseGenerator.generateQueryResponse(
                events: relevantEvents,
                timeRange: (start: extractedStart, end: extractedEnd)
            )

            let eventResults = relevantEvents.map { event in
                EventResult(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    source: event.source.rawValue,
                    color: nil
                )
            }

            return AICalendarResponse(
                message: voiceResponse.fullMessage,
                command: CalendarCommand(type: .queryEvents, queryStartDate: extractedStart, queryEndDate: extractedEnd),
                eventResults: eventResults,
                shouldContinueListening: voiceResponse.followUp != nil
            )
        }

        return AICalendarResponse(
            message: action.message,
            command: command,
            shouldContinueListening: action.shouldContinueListening
        )
    }

    private func isComplexCommand(_ transcript: String) -> Bool {
        let lowercased = transcript.lowercased()

        // Pronouns and references that need context
        let contextIndicators = [
            "it", "this", "that", "them", "those",
            "the meeting", "the event", "the appointment",
            "first one", "second one", "last one", "next one",
            "earlier", "before", "previous"
        ]

        for indicator in contextIndicators {
            if lowercased.contains(indicator) {
                print("🔍 Complex command detected: contains '\(indicator)'")
                return true
            }
        }

        // Multiple operations in one command
        if (lowercased.contains("and") || lowercased.contains("then")) &&
           (lowercased.contains("cancel") || lowercased.contains("move") || lowercased.contains("schedule")) {
            print("🔍 Complex command detected: multiple operations")
            return true
        }

        // Ambiguous commands that benefit from LLM understanding
        let ambiguousPatterns = [
            "do i have time",
            "can i fit",
            "how's my",
            "am i busy",
            "what should i"
        ]

        for pattern in ambiguousPatterns {
            if lowercased.contains(pattern) {
                print("🔍 Complex command detected: ambiguous pattern '\(pattern)'")
                return true
            }
        }

        print("✅ Simple command - using pattern-based")
        return false
    }

    // MARK: - Error Handling

    private func handleError(_ error: Error) -> String {
        // Check if it's our custom AIError
        if let aiError = error as? AIError {
            return aiError.userFriendlyMessage
        }

        // Check for OnDeviceAI errors
        if let nsError = error as NSError?, nsError.domain == "OnDeviceAI" {
            return nsError.localizedDescription
        }

        // Check for network errors
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return AIError.networkError.userFriendlyMessage
            case .timedOut:
                return AIError.timeoutError.userFriendlyMessage
            case .userAuthenticationRequired:
                return AIError.authenticationError.userFriendlyMessage
            default:
                return "I encountered a network issue: \(urlError.localizedDescription)"
            }
        }

        // Generic fallback - include error details for debugging
        let errorMessage = error.localizedDescription
        print("⚠️ Unhandled error in AIManager: \(errorMessage)")
        return "Sorry, I had trouble processing that: \(errorMessage)"
    }

    private func retryWithBackoff<T>(
        maxRetries: Int = 2,
        initialDelay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        var delay = initialDelay

        for attempt in 1...maxRetries {
            do {
                return try await operation()
            } catch let error as URLError where error.code == .timedOut || error.code == .networkConnectionLost {
                lastError = error
                print("⚠️ Attempt \(attempt) failed with network error, retrying in \(delay)s...")

                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2 // Exponential backoff
            } catch {
                // For non-network errors, don't retry
                throw error
            }
        }

        // If we've exhausted all retries, throw the last error
        throw lastError ?? AIError.invalidResponse
    }

    // MARK: - Intent Classification

    private enum UserIntent {
        case query        // Asking about schedule/events ("What's my schedule?")
        case create       // Creating new events ("Schedule a meeting")
        case modify       // Modifying existing events ("Move my 2pm meeting")
        case delete       // Deleting/canceling events ("Cancel my meeting")
        case search       // Finding specific events ("When is my dentist appointment?")
        case availability // Checking free time ("Am I free at 2pm?")
        case analytics    // Schedule analytics ("How many meetings this week?")
        case contextAware // Context-aware queries ("Do I have time for lunch?")
        case focusTime    // Smart blocking ("Block focus time tomorrow")
        case conflicts    // Conflict detection ("Show me conflicts today")
        case batch        // Batch operations ("Move all Monday meetings")
        case weather      // Weather queries ("What's the weather?")
        case createTask   // Create a new task ("Add a task to buy groceries")
        case listTasks    // List tasks ("What are my tasks?")
        case updateTask   // Update task ("Set the grocery task to high priority")
        case completeTask // Complete task ("Mark the grocery task as done")
        case conversation // General chat
    }

    private func classifyIntent(from text: String) -> UserIntent {
        let lowercased = text.lowercased()

        // PRIORITY 1: Delete/Cancel patterns (most specific - check first)
        let deletePatterns = [
            ("cancel", 10), ("delete", 10), ("remove", 10), ("clear", 8)
        ]
        var deleteScore = 0
        for (keyword, weight) in deletePatterns {
            if lowercased.contains(keyword) {
                deleteScore += weight
                print("🗑️ Delete keyword found: '\(keyword)'")
                return .delete // Immediate return for delete commands
            }
        }

        // PRIORITY 2: Batch operations (very specific - "all" indicator)
        let batchPatterns = [
            ("move all", 15), ("clear all", 15), ("cancel all", 15),
            ("delete all", 15), ("accept all", 15), ("decline all", 15),
            ("remove all", 15)
        ]
        var batchScore = 0
        for (keyword, weight) in batchPatterns {
            if lowercased.contains(keyword) {
                batchScore += weight
                print("📦 Batch keyword found: '\(keyword)'")
                return .batch // Immediate return for batch commands
            }
        }

        // PRIORITY 3: Task patterns (very specific - check early)
        let taskPatterns = [
            ("create.*task", 10), ("add.*task", 10), ("new task", 10),
            ("make.*task", 8), ("task.*called", 8), ("task.*named", 8),
            ("complete.*task", 10), ("finish.*task", 10), ("mark.*done", 10),
            ("mark.*complete", 10), ("list.*task", 10), ("show.*task", 10),
            ("my tasks", 10), ("what.*tasks", 10), ("update.*task", 8),
            ("change.*task", 8), ("set.*priority", 10)
        ]
        for (keyword, weight) in taskPatterns {
            if lowercased.range(of: keyword, options: .regularExpression) != nil {
                print("✅ Task keyword found: '\(keyword)'")

                // Determine specific task intent
                if lowercased.contains("complete") || lowercased.contains("finish") || lowercased.contains("done") {
                    return .completeTask
                } else if lowercased.contains("list") || lowercased.contains("show") || lowercased.contains("what") {
                    return .listTasks
                } else if lowercased.contains("update") || lowercased.contains("change") || lowercased.contains("set") {
                    return .updateTask
                } else {
                    return .createTask
                }
            }
        }

        // PRIORITY 4: Weather patterns (very specific - check early)
        let weatherPatterns = [
            ("weather", 10), ("temperature", 10), ("forecast", 10),
            ("how.*hot", 8), ("how.*cold", 8), ("raining", 8),
            ("sunny", 7), ("cloudy", 7), ("what.*temp", 8)
        ]
        var weatherScore = 0
        for (keyword, weight) in weatherPatterns {
            if lowercased.range(of: keyword, options: .regularExpression) != nil {
                weatherScore += weight
                print("🌦️ Weather keyword found: '\(keyword)'")
                return .weather // Immediate return for weather commands
            }
        }

        // PRIORITY 5: Analytics patterns (counting, statistics)
        let analyticsPatterns = [
            ("how many", 10), ("how much", 10), ("what's my busiest", 10),
            ("compare", 8), ("what percentage", 10), ("show me.*trends", 8),
            ("hours.*in meetings", 8), ("meeting trends", 8)
        ]
        var analyticsScore = 0
        for (keyword, weight) in analyticsPatterns {
            if lowercased.range(of: keyword, options: .regularExpression) != nil {
                analyticsScore += weight
                print("📊 Analytics keyword found: '\(keyword)'")
            }
        }
        if analyticsScore >= 8 {
            return .analytics
        }

        // PRIORITY 4: Conflict detection patterns
        let conflictPatterns = [
            ("conflicts", 10), ("overlaps", 10), ("double.?book", 10),
            ("find a time that works", 8), ("when are.*both free", 8),
            ("suggest a better time", 7), ("resolve.*conflict", 10)
        ]
        var conflictScore = 0
        for (keyword, weight) in conflictPatterns {
            if lowercased.range(of: keyword, options: .regularExpression) != nil {
                conflictScore += weight
                print("⚠️ Conflict keyword found: '\(keyword)'")
            }
        }
        if conflictScore >= 7 {
            return .conflicts
        }

        // PRIORITY 5: Focus time / Smart blocking patterns
        let focusTimePatterns = [
            ("block focus", 10), ("block.*time", 8), ("protect.*lunch", 8),
            ("add buffer", 8), ("prep time", 7), ("deep work", 8),
            ("wind.?down time", 7), ("focus time", 10)
        ]
        var focusTimeScore = 0
        for (keyword, weight) in focusTimePatterns {
            if lowercased.range(of: keyword, options: .regularExpression) != nil {
                focusTimeScore += weight
                print("🎯 Focus time keyword found: '\(keyword)'")
            }
        }
        if focusTimeScore >= 7 {
            return .focusTime
        }

        // PRIORITY 6: Context-aware patterns (specific flow questions)
        let contextAwarePatterns = [
            ("time for lunch", 8), ("squeeze in", 8), ("time to eat", 8),
            ("back.?to.?back", 8), ("what should i prepare", 8),
            ("time for.*workout", 7), ("needs my attention", 7)
        ]
        var contextAwareScore = 0
        for (keyword, weight) in contextAwarePatterns {
            if lowercased.range(of: keyword, options: .regularExpression) != nil {
                contextAwareScore += weight
                print("🧠 Context-aware keyword found: '\(keyword)'")
            }
        }
        if contextAwareScore >= 7 {
            return .contextAware
        }

        // PRIORITY 7: Modify/Reschedule patterns (very specific)
        let modifyPatterns = [
            ("move", 10), ("reschedule", 10), ("change", 8), ("update", 8),
            ("edit", 8), ("push", 7), ("shift", 7), ("extend", 6),
            ("shorten", 6), ("add.*to my", 5) // "add John to my meeting"
        ]
        var modifyScore = 0
        for (keyword, weight) in modifyPatterns {
            if lowercased.range(of: keyword, options: .regularExpression) != nil {
                modifyScore += weight
                print("✏️ Modify keyword found: '\(keyword)'")
            }
        }
        if modifyScore >= 8 {
            return .modify
        }

        // PRIORITY 8: Availability patterns (specific question about free time)
        let availabilityPatterns = [
            ("am i free", 10), ("am i available", 10), ("do i have time", 8),
            ("can i fit", 8), ("when am i free", 10), ("when's my next free", 10),
            ("what's my first available", 10), ("find me an hour", 8),
            ("what time slots are open", 8), ("when can i schedule", 7)
        ]
        var availabilityScore = 0
        for (keyword, weight) in availabilityPatterns {
            if lowercased.contains(keyword) {
                availabilityScore += weight
                print("📅 Availability keyword found: '\(keyword)'")
            }
        }
        if availabilityScore >= 7 {
            return .availability
        }

        // PRIORITY 9: Search patterns (looking for specific event)
        let searchPatterns = [
            ("when is my", 10), ("when's my", 10), ("find my", 10),
            ("where is my", 10), ("search for", 10), ("who's invited", 8),
            ("what's the location", 8), ("how long is", 7)
        ]
        var searchScore = 0
        for (keyword, weight) in searchPatterns {
            if lowercased.contains(keyword) {
                searchScore += weight
                print("🔍 Search keyword found: '\(keyword)'")
            }
        }
        // Boost if asking "when is" about specific event
        if (lowercased.contains("when is") || lowercased.contains("when's")) &&
           !lowercased.contains("my schedule") && !lowercased.contains("my next") {
            searchScore += 5
        }
        if searchScore >= 7 {
            return .search
        }

        // PRIORITY 10: Query patterns (general schedule questions)
        let queryPatterns = [
            // Schedule inquiry phrases
            ("what's my schedule", 8), ("what do i have", 8), ("what am i doing", 8),
            ("do i have anything", 7), ("show me", 6), ("what's on my calendar", 8),
            ("what's happening", 6), ("what's next", 7), ("what's my next", 7),
            ("what's coming up", 7), ("what's my week", 7), ("what time does", 5),
            // Question words (weaker signals)
            ("what", 2), ("what's", 2), ("show", 3), ("tell me", 3)
        ]
        var queryScore = 0
        for (keyword, weight) in queryPatterns {
            if lowercased.contains(keyword) {
                queryScore += weight
            }
        }
        // Boost query score if starts with question words
        if lowercased.hasPrefix("what") || lowercased.hasPrefix("show") {
            queryScore += 4
        }

        // PRIORITY 11: Create patterns (creating new events)
        let createPatterns = [
            // Strong creation verbs with context
            ("schedule a", 10), ("schedule.*meeting", 10), ("add.*appointment", 10),
            ("create an event", 10), ("book time", 10), ("set up a", 10),
            // Event type mentions with action
            (".*meeting.*at", 6), (".*appointment.*at", 6), (".*lunch.*at", 6)
        ]
        var createScore = 0
        for (keyword, weight) in createPatterns {
            if lowercased.range(of: keyword, options: .regularExpression) != nil {
                createScore += weight
            }
        }

        // Only boost create score if NOT a query context
        let isQueryContext = lowercased.contains("my schedule") ||
                             lowercased.contains("the schedule") ||
                             lowercased.contains("what's on") ||
                             lowercased.contains("what am i") ||
                             lowercased.contains("do i have")

        if !isQueryContext {
            // Boost create score if contains time indicators and action verbs
            if (lowercased.contains(" at ") || lowercased.contains(" on ")) &&
               (lowercased.contains("schedule") || lowercased.contains("book") ||
                lowercased.contains("add") || lowercased.contains("create")) {
                createScore += 5
            }
            // Boost if contains "with" (participants)
            if lowercased.contains(" with ") &&
               (lowercased.contains("meeting") || lowercased.contains("call") || lowercased.contains("lunch")) {
                createScore += 3
            }
        }

        // PRIORITY 12: Conversation patterns
        let conversationPatterns = [
            ("hello", 10), ("hi", 10), ("hey", 10), ("good morning", 10),
            ("good afternoon", 10), ("good evening", 10), ("thanks", 10),
            ("thank you", 10), ("goodbye", 10), ("bye", 10), ("help", 8)
        ]
        var conversationScore = 0
        for (keyword, weight) in conversationPatterns {
            if lowercased.contains(keyword) && !lowercased.contains("meeting") {
                conversationScore += weight
            }
        }

        print("📊 Intent scores - Query: \(queryScore), Create: \(createScore), Modify: \(modifyScore), Delete: \(deleteScore), Search: \(searchScore), Availability: \(availabilityScore), Analytics: \(analyticsScore), Context: \(contextAwareScore), Focus: \(focusTimeScore), Conflicts: \(conflictScore), Batch: \(batchScore), Conversation: \(conversationScore)")

        // Return intent with highest score (with thresholds)
        // Note: delete and batch already returned early if detected
        let scores = [
            ("conversation", conversationScore, 8),
            ("analytics", analyticsScore, 8),  // Fixed: should be 8, not 0
            ("conflicts", conflictScore, 7),
            ("focusTime", focusTimeScore, 7),
            ("contextAware", contextAwareScore, 7),
            ("search", searchScore, 5),
            ("availability", availabilityScore, 5),
            ("modify", modifyScore, 5),
            ("create", createScore, 3),
            ("query", queryScore, 0)
        ]

        for (intentName, score, threshold) in scores {
            if score >= threshold {
                switch intentName {
                case "conversation": return .conversation
                case "analytics": return .analytics
                case "conflicts": return .conflicts
                case "focusTime": return .focusTime
                case "contextAware": return .contextAware
                case "search": return .search
                case "availability": return .availability
                case "modify": return .modify
                case "create": return .create
                case "query": return .query
                default: break
                }
            }
        }

        // Default: if uncertain, treat as query
        return .query
    }

    // MARK: - Event Creation Handling

    private func handleEventCreation(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async {
        print("📝 Handling event creation with SmartEventParser")

        // Parse the command using SmartEventParser
        let parseResult = smartEventParser.parse(transcript)

        switch parseResult {
        case .success(let entities, let confirmation):
            print("✅ SmartEventParser success with high confidence")

            // Convert ExtractedEntities to CalendarCommand (with conflict check)
            let (calendarCommand, conflicts) = await convertToCalendarCommand(entities, calendarEvents: calendarEvents)

            guard let command = calendarCommand else {
                let errorResponse = AICalendarResponse(message: "I couldn't create the event. Please try again with more details.")
                await MainActor.run {
                    self.isProcessing = false
                    completion(errorResponse)
                }
                return
            }

            // Generate response using VoiceResponseGenerator
            let voiceResponse = voiceResponseGenerator.generateCreateResponse(
                eventTitle: entities.title ?? "event",
                eventDate: entities.time ?? Date(),
                duration: entities.duration,
                conflicts: conflicts,
                allEvents: calendarEvents
            )

            let requiresConfirmation = self.commandRequiresConfirmation(command)

            var aiResponse = AICalendarResponse(
                message: voiceResponse.fullMessage,
                command: command,
                requiresConfirmation: requiresConfirmation,
                confirmationMessage: voiceResponse.fullMessage,
                shouldContinueListening: voiceResponse.followUp != nil
            )

            if Config.aiOutputMode == .voiceOnly && requiresConfirmation {
                print("🎤 Voice-only mode: Awaiting confirmation")
                self.pendingCommand = command
                self.conversationState = .awaitingConfirmation
                aiResponse.command = nil // Clear command for this turn
            }

            await MainActor.run {
                self.isProcessing = false
                completion(aiResponse)
            }

        case .needsClarification(let entities, let question):
            print("❓ SmartEventParser needs clarification: \(question)")

            // Store partial entities and set conversation state
            if let missingField = entities.missingFields.first {
                await MainActor.run {
                    self.conversationState = .creatingEvent(entities, missingField: missingField)
                    print("💾 Stored partial event, waiting for: \(missingField)")
                }
            }

            let aiResponse = AICalendarResponse(message: question)

            await MainActor.run {
                self.isProcessing = false
                completion(aiResponse)
            }

        case .failure(let message):
            print("❌ SmartEventParser failed: \(message)")

            // Fallback to old parser
            print("🔄 Falling back to original NaturalLanguageParser")
            do {
                let parsedEvent = try await self.parser.parseEvent(from: transcript)

                let calendarCommand = CalendarCommand(
                    type: .createEvent,
                    title: parsedEvent.title,
                    startDate: parsedEvent.startDate,
                    endDate: parsedEvent.endDate,
                    location: parsedEvent.location,
                    participants: parsedEvent.attendees
                )

                let aiResponse = AICalendarResponse(
                    message: self.generateResponseMessage(for: calendarCommand),
                    command: calendarCommand
                )

                await MainActor.run {
                    self.isProcessing = false
                    completion(aiResponse)
                }
            } catch {
                let errorResponse = AICalendarResponse(message: message)
                await MainActor.run {
                    self.isProcessing = false
                    completion(errorResponse)
                }
            }
        }
    }

    // Convert ExtractedEntities to CalendarCommand
    private func convertToCalendarCommand(_ entities: ExtractedEntities, calendarEvents: [UnifiedEvent] = []) async -> (command: CalendarCommand?, conflicts: [UnifiedEvent]) {
        // Ensure we have minimum required fields
        guard let title = entities.title,
              let startDate = entities.time else {
            print("⚠️ Missing required fields: title or time")
            return (nil, [])
        }

        // Calculate end date
        let endDate: Date
        if let duration = entities.duration {
            endDate = startDate.addingTimeInterval(duration)
        } else {
            // Default to 1 hour
            endDate = startDate.addingTimeInterval(3600)
        }

        // Check for conflicts
        let conflicts = voiceResponseGenerator.checkConflicts(
            newEventStart: startDate,
            newEventEnd: endDate,
            in: calendarEvents
        )

        // Match attendee names to emails
        var participantEmails: [String] = []
        if !entities.attendeeNames.isEmpty {
            participantEmails = await matchAttendeesToEmails(entities.attendeeNames)
        }

        let command = CalendarCommand(
            type: .createEvent,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: entities.location,
            participants: participantEmails.isEmpty ? nil : participantEmails
        )

        return (command, conflicts)
    }

    // Match attendee names to contact emails
    private func matchAttendeesToEmails(_ names: [String]) async -> [String] {
        var emails: [String] = []

        for name in names {
            // Handle special groups
            if name.hasPrefix("@") {
                // Skip for now, would need team/group management
                print("⚠️ Skipping group: \(name)")
                continue
            }

            // Search contacts
            let contacts = await parser.searchContacts(query: name)
            if let bestMatch = contacts.first, !contacts.isEmpty {
                if let email = bestMatch.email {
                    emails.append(email)
                    print("✅ Matched '\(name)' to \(email)")
                } else {
                    print("⚠️ Contact '\(name)' found but has no email")
                }
            } else {
                print("⚠️ No contact found for '\(name)'")
            }
        }

        return emails
    }

    // MARK: - Event Clarification Handling

    private func handleEventClarification(transcript: String, entities: ExtractedEntities, missingField: String, completion: @escaping (AICalendarResponse) -> Void) {
        print("📝 Processing clarification for field: \(missingField)")
        print("📝 User response: \(transcript)")

        Task {
            // Create a mutable copy of entities to update
            var updatedEntities = entities

            // Update entities based on which field was missing
            switch missingField.lowercased() {
            case "attendees", "invitees", "participants":
                // Extract attendee names from the response
                let names = smartEventParser.extractAttendeeNames(from: transcript)
                if !names.isEmpty {
                    updatedEntities.attendeeNames.append(contentsOf: names)
                    print("✅ Added attendees: \(names.joined(separator: ", "))")
                }

            case "time", "when", "date":
                // Parse time from the response
                if let time = smartEventParser.extractTime(from: transcript) {
                    updatedEntities.time = time
                    print("✅ Set time to: \(time)")
                }

            case "location", "where", "place":
                // Extract location from the response
                if let location = smartEventParser.extractLocation(from: transcript) {
                    updatedEntities.location = location
                    print("✅ Set location to: \(location)")
                }

            case "title", "name":
                // Use the response as the title
                let title = smartEventParser.generateTitle(from: transcript, eventType: nil)
                updatedEntities.title = title
                print("✅ Set title to: \(title ?? "nil")")

            default:
                print("⚠️ Unknown missing field: \(missingField)")
            }

            // Remove the field we just filled from missing fields
            updatedEntities.missingFields.removeAll { $0.lowercased() == missingField.lowercased() }

            // Check if there are still missing required fields
            let requiredFields = ["title", "time"]
            let stillMissing = requiredFields.filter { field in
                switch field {
                case "title": return updatedEntities.title == nil
                case "time": return updatedEntities.time == nil
                default: return false
                }
            }

            if !stillMissing.isEmpty {
                // Still need more information
                let nextMissingField = stillMissing.first!
                updatedEntities.missingFields = stillMissing

                print("⏭️ Still missing fields: \(stillMissing.joined(separator: ", "))")
                print("❓ Asking about next field: \(nextMissingField)")

                await MainActor.run {
                    self.conversationState = .creatingEvent(updatedEntities, missingField: nextMissingField)
                    print("💾 Updated conversation state to .creatingEvent with field: \(nextMissingField)")
                }

                // Generate next question
                let question = generateClarificationQuestion(for: nextMissingField, entities: updatedEntities)
                let response = AICalendarResponse(message: question)

                await MainActor.run {
                    self.isProcessing = false
                    completion(response)
                }

            } else {
                // We have all required fields - create the event
                print("✅ All required fields filled, creating event...")

                let (calendarCommand, conflicts) = await convertToCalendarCommand(updatedEntities, calendarEvents: [])

                guard let command = calendarCommand else {
                    let errorResponse = AICalendarResponse(message: "Sorry, I couldn't create that event. Please try again.")
                    await MainActor.run {
                        self.conversationState = .idle
                        print("🔄 Reset conversation state to .idle (conversion error)")
                        self.isProcessing = false
                        completion(errorResponse)
                    }
                    return
                }

                // Generate response using VoiceResponseGenerator
                let voiceResponse = voiceResponseGenerator.generateCreateResponse(
                    eventTitle: updatedEntities.title ?? "event",
                    eventDate: updatedEntities.time ?? Date(),
                    duration: updatedEntities.duration,
                    conflicts: conflicts,
                    allEvents: []
                )

                let response = AICalendarResponse(
                    message: voiceResponse.fullMessage,
                    command: command,
                    shouldContinueListening: voiceResponse.followUp != nil
                )

                await MainActor.run {
                    self.conversationState = .idle
                    print("🔄 Reset conversation state to .idle (event created)")
                    self.isProcessing = false
                    completion(response)
                }
            }
        }
    }

    private func generateClarificationQuestion(for field: String, entities: ExtractedEntities) -> String {
        switch field.lowercased() {
        case "title", "name":
            return "What would you like to call this event?"
        case "time", "when", "date":
            return "When should this event be scheduled?"
        case "attendees", "invitees", "participants":
            return "Who should I invite to this event?"
        case "location", "where", "place":
            return "Where will this event take place?"
        default:
            return "Can you provide more details about the \(field)?"
        }
    }

    private func generateEventConfirmation(_ entities: ExtractedEntities) -> String {
        var parts: [String] = []

        if let title = entities.title {
            parts.append(title)
        }

        if !entities.attendeeNames.isEmpty {
            parts.append("with \(entities.attendeeNames.joined(separator: ", "))")
        }

        if let time = entities.time {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            parts.append("on \(formatter.string(from: time))")
        }

        if let location = entities.location {
            parts.append("at \(location)")
        }

        let confirmation = "Got it! Creating \(parts.joined(separator: " "))"
        return confirmation
    }

    // MARK: - Query Handling

    private func handleQuery(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async throws {
        print("📅 Handling calendar query: \(transcript)")

        // Extract time range from query
        let (startDate, endDate) = extractTimeRange(from: transcript)
        print("📅 Query time range: \(startDate) to \(endDate)")

        // Filter events in the specified time range
        let relevantEvents = calendarEvents.filter { event in
            event.startDate >= startDate && event.startDate < endDate
        }.sorted { $0.startDate < $1.startDate }

        print("📅 Found \(relevantEvents.count) events in range")

        // Use VoiceResponseGenerator to create response
        let voiceResponse = voiceResponseGenerator.generateQueryResponse(
            events: relevantEvents,
            timeRange: (start: startDate, end: endDate)
        )

        let responseText = voiceResponse.fullMessage
        print("✅ Generated response: \(responseText)")

        // Convert events to EventResult format
        let eventResults = relevantEvents.map { event in
            EventResult(
                id: event.id,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                source: event.source.rawValue,
                color: nil
            )
        }

        let command = CalendarCommand(
            type: .queryEvents,
            queryStartDate: startDate,
            queryEndDate: endDate
        )

        let response = AICalendarResponse(
            message: responseText,
            command: command,
            eventResults: eventResults,
            shouldContinueListening: voiceResponse.followUp != nil
        )

        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    private func stripDatesFromResponse(_ text: String) -> String {
        var result = text

        // Remove common date patterns that might appear before/after times
        let datePatterns = [
            // "on [Month] [Day]" or "on [Month] [Day], [Year]" - with optional "st/nd/rd/th"
            #"\bon\s+(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?(?:,\s*\d{4})?\s+"#,
            #"\bon\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,\s*\d{4})?\s+"#,

            // Just "[Month] [Day]" anywhere - without "on", with optional comma/year
            #"\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?(?:,\s*\d{4})?\s+(?=at)"#,
            #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?(?:,\s*\d{4})?\s+(?=at)"#,

            // "[Month] [Day]," with comma (more general)
            #"\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?,\s+"#,
            #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?,\s+"#,

            // "on [Weekday]" patterns
            #"\bon\s+(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday)\s+"#,

            // Numeric date patterns like "1/14" or "01/14/2025"
            #"\b\d{1,2}/\d{1,2}(?:/\d{2,4})?\s+"#,

            // "[Month] [Day]" without comma, followed by space and "at"
            #"\b(?:January|February|March|April|May|June|July|August|September|October|November|December)\s+\d{1,2}(?:st|nd|rd|th)?\s+(?=at\s+\d)"#,
            #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Sept|Oct|Nov|Dec)\.?\s+\d{1,2}(?:st|nd|rd|th)?\s+(?=at\s+\d)"#
        ]

        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
            }
        }

        // Clean up extra spaces
        result = result.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)

        print("🧹 After date stripping: \(result)")
        return result
    }

    private func stripListsFromResponse(_ text: String) -> String {
        print("📥 Input to stripListsFromResponse: \(text)")

        // Split into lines
        let lines = text.components(separatedBy: .newlines)
        var cleanedLines: [String] = []
        var foundListSection = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip lines that are bulleted or numbered lists
            // Patterns: "- Event", "• Event", "* Event", "1. Event", "2) Event", "**Event**"
            let isBulletedList = trimmed.hasPrefix("-") ||
                                 trimmed.hasPrefix("•") ||
                                 trimmed.hasPrefix("*") ||
                                 trimmed.hasPrefix("–") ||  // en dash
                                 trimmed.hasPrefix("—")     // em dash
            let isNumberedList = trimmed.range(of: #"^\d+[\.\)\:]"#, options: .regularExpression) != nil

            // Also detect "Here's" or "Here are" or "Schedule:" which often precede lists
            let isListHeader = trimmed.lowercased().contains("here's your") ||
                              trimmed.lowercased().contains("here are") ||
                              trimmed.lowercased().hasPrefix("schedule:") ||
                              trimmed.lowercased().hasPrefix("events:")

            if isBulletedList || isNumberedList {
                print("🗑️ Removing list line: \(trimmed)")
                foundListSection = true
            } else if isListHeader && foundListSection {
                print("🗑️ Removing list header: \(trimmed)")
            } else if !trimmed.isEmpty {
                cleanedLines.append(line)
            }
        }

        // Join back and clean up extra whitespace
        let result = cleanedLines.joined(separator: "\n")
            .replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        print("📤 Output from stripListsFromResponse: \(result)")
        return result
    }

    private func extractTimeRange(from text: String) -> (start: Date, end: Date) {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()

        // Specific time of day (more specific than full day)
        if lowercased.contains("this morning") {
            let startOfDay = calendar.startOfDay(for: now)
            let noon = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!
            return (startOfDay, noon)
        }

        if lowercased.contains("this afternoon") {
            let startOfDay = calendar.startOfDay(for: now)
            let noon = calendar.date(byAdding: .hour, value: 12, to: startOfDay)!
            let evening = calendar.date(byAdding: .hour, value: 17, to: startOfDay)!
            return (noon, evening)
        }

        if lowercased.contains("this evening") || lowercased.contains("tonight") {
            let startOfDay = calendar.startOfDay(for: now)
            let evening = calendar.date(byAdding: .hour, value: 17, to: startOfDay)!
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (evening, endOfDay)
        }

        // Today (general - full day)
        if lowercased.contains("today") || lowercased.contains("my day") {
            let startOfDay = calendar.startOfDay(for: now)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        }

        // Tomorrow
        if lowercased.contains("tomorrow") {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let startOfDay = calendar.startOfDay(for: tomorrow)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        }

        // Yesterday (for queries about past)
        if lowercased.contains("yesterday") {
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            let startOfDay = calendar.startOfDay(for: yesterday)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            return (startOfDay, endOfDay)
        }

        // This week
        if lowercased.contains("this week") || (lowercased.contains("week") && !lowercased.contains("next")) {
            let startOfWeek = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: now).date!
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
        }

        // Next week
        if lowercased.contains("next week") {
            let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now)!
            let startOfWeek = calendar.dateComponents([.calendar, .yearForWeekOfYear, .weekOfYear], from: nextWeek).date!
            let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfWeek)!
            return (startOfWeek, endOfWeek)
        }

        // This month
        if lowercased.contains("this month") || lowercased.contains("month") {
            let startOfMonth = calendar.dateComponents([.year, .month], from: now)
            let startDate = calendar.date(from: startOfMonth)!
            let endDate = calendar.date(byAdding: DateComponents(month: 1), to: startDate)!
            return (startDate, endDate)
        }

        // Specific day names (Monday, Tuesday, etc.)
        let weekdays = ["monday": 2, "tuesday": 3, "wednesday": 4, "thursday": 5, "friday": 6, "saturday": 7, "sunday": 1]
        for (dayName, targetWeekday) in weekdays {
            if lowercased.contains(dayName) {
                // Find next occurrence of this weekday
                var targetDate = now
                while calendar.component(.weekday, from: targetDate) != targetWeekday {
                    targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate)!
                }
                let startOfDay = calendar.startOfDay(for: targetDate)
                let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
                return (startOfDay, endOfDay)
            }
        }

        // Default: today
        let startOfDay = calendar.startOfDay(for: now)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        return (startOfDay, endOfDay)
    }

    private func generateSimpleQueryResponse(events: [UnifiedEvent], startDate: Date, endDate: Date) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(startDate)
        let isTomorrow = calendar.isDateInTomorrow(startDate)
        let isThisWeek = calendar.isDate(startDate, equalTo: Date(), toGranularity: .weekOfYear)

        // Greeting based on time reference
        var greeting = ""
        if isToday {
            let hour = calendar.component(.hour, from: Date())
            if hour < 12 {
                greeting = "Good morning! "
            } else if hour < 17 {
                greeting = "Good afternoon! "
            } else {
                greeting = "Good evening! "
            }
        }

        let timeReferenceDate = isToday ? "today" : (isTomorrow ? "tomorrow" : "on \(dateFormatter.string(from: startDate))")

        // Empty schedule
        if events.isEmpty {
            if isToday {
                return "\(greeting)You have a clear schedule today. Enjoy your free time!"
            } else {
                return "You don't have any events \(timeReferenceDate). Your schedule is clear."
            }
        }

        let eventCount = events.count
        let eventWord = eventCount == 1 ? "event" : "events"

        // Opening
        var response = "\(greeting)Here's what your day looks like. "

        // Describe events conversationally
        if eventCount == 1 {
            let event = events[0]
            let time = timeFormatter.string(from: event.startDate)
            response += "You have \(event.title) at \(time)"
            if let location = event.location, !location.isEmpty {
                response += " at \(location)"
            }
            response += "."
        } else if eventCount == 2 {
            let first = events[0]
            let second = events[1]
            let time1 = timeFormatter.string(from: first.startDate)
            let time2 = timeFormatter.string(from: second.startDate)

            response += "You start with \(first.title) at \(time1), "
            response += "followed by \(second.title) at \(time2)."
        } else {
            // 3+ events
            let first = events[0]
            let last = events[eventCount - 1]
            let time1 = timeFormatter.string(from: first.startDate)
            let timeLast = timeFormatter.string(from: last.startDate)

            response += "You have \(eventCount) events. "
            response += "You start with \(first.title) at \(time1)"

            // Middle events
            if eventCount > 2 {
                let middle = events[1..<eventCount-1]
                for event in middle {
                    let time = timeFormatter.string(from: event.startDate)
                    response += ", followed by \(event.title) at \(time)"
                }
            }

            response += ", and wrap up with \(last.title) at \(timeLast)."
        }

        return response
    }

    private func generateQueryPrompt(transcript: String, events: [UnifiedEvent], startDate: Date, endDate: Date) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        timeFormatter.dateStyle = .none

        // Limit to top 10 events to reduce token usage
        let limitedEvents = Array(events.prefix(10))
        let hasMoreEvents = events.count > 10

        var eventsDescription = ""
        if limitedEvents.isEmpty {
            eventsDescription = "No events"
        } else {
            eventsDescription = limitedEvents.map { event in
                let timeStr = timeFormatter.string(from: event.startDate)
                return "\(event.title) at \(timeStr)"
            }.joined(separator: ", ")
            if hasMoreEvents {
                eventsDescription += " (+\(events.count - 10) more)"
            }
        }

        // Only add context if it exists and is relevant
        let contextPrompt = conversationContext.isEmpty ? "" : "Context: \(conversationContext.joined(separator: "; "))\n"

        return """
        \(contextPrompt)Q: "\(transcript)"
        Events: \(eventsDescription)

        Respond conversationally with greeting, event summary (TITLE + TIME only, no dates/lists), and closing. Natural flow, 1-2 sentences.
        """
    }

    // MARK: - Conversation Handling

    private func handleConversation(transcript: String, completion: @escaping (AICalendarResponse) -> Void) async throws {
        print("💬 Handling general conversation: \(transcript)")

        // Generate a friendly conversational response (with fallback)
        let responseText: String
        do {
            let prompt = "User: \"\(transcript)\"\nRespond briefly and naturally as a calendar assistant."

            responseText = try await parser.generateText(prompt: prompt, maxTokens: 50)
        } catch {
            print("⚠️ LLM conversation generation failed: \(error.localizedDescription)")
            print("📝 Using simple fallback response")
            // Simple pattern-based fallback
            responseText = generateSimpleConversationResponse(transcript: transcript)
        }

        let response = AICalendarResponse(message: responseText)

        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    private func generateSimpleConversationResponse(transcript: String) -> String {
        let lowercased = transcript.lowercased()

        // Greetings
        if lowercased.contains("hello") || lowercased.contains("hi ") || lowercased.starts(with: "hi") {
            return "Hello! How can I help you with your calendar today?"
        }

        // Thanks
        if lowercased.contains("thank") {
            return "You're welcome! Let me know if you need anything else."
        }

        // Goodbye
        if lowercased.contains("bye") || lowercased.contains("goodbye") {
            return "Goodbye! Have a great day!"
        }

        // Help
        if lowercased.contains("help") {
            return "I can help you view your schedule, create events, and answer questions about your calendar. Just ask me anything!"
        }

        // Default
        return "I'm here to help with your calendar. Try asking 'What's on my schedule today?' or 'Create a meeting tomorrow at 2pm'."
    }

    // MARK: - Modify Event Handling

    private func handleModify(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async {
        print("✏️ Handling modify command: \(transcript)")

        // Extract which event to modify
        let eventReference = extractEventReference(from: transcript, in: calendarEvents)

        if let event = eventReference {
            // Found the event - now determine what to modify
            let response = AICalendarResponse(
                message: "I found '\(event.title)'. To modify it, please use the Edit button in the event details, or tell me specifically what you'd like to change.",
                eventResults: [EventResult(
                    id: event.id,
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    source: event.source.rawValue,
                    color: nil
                )]
            )

            await MainActor.run {
                self.isProcessing = false
                completion(response)
            }
        } else {
            let response = AICalendarResponse(message: "I couldn't find that event. Can you be more specific about which event you'd like to modify?")
            await MainActor.run {
                self.isProcessing = false
                completion(response)
            }
        }
    }

    // MARK: - Delete Event Handling

    private func handleDelete(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async {
        print("🗑️ Handling delete command: \(transcript)")

        // Extract which event to delete
        let eventReference = extractEventReference(from: transcript, in: calendarEvents)

        if let event = eventReference {
            let command = CalendarCommand(
                type: .deleteEvent,
                eventId: event.id,
                searchQuery: event.title
            )

            // Use VoiceResponseGenerator to create response
            let voiceResponse = voiceResponseGenerator.generateDeleteResponse(
                eventTitle: event.title,
                eventDate: event.startDate,
                allEvents: calendarEvents
            )

            let response = AICalendarResponse(
                message: voiceResponse.fullMessage,
                command: command,
                shouldContinueListening: voiceResponse.followUp != nil
            )

            await MainActor.run {
                self.isProcessing = false
                completion(response)
            }
        } else {
            let response = AICalendarResponse(message: "I couldn't find that event to delete. Which event did you want to cancel?")
            await MainActor.run {
                self.isProcessing = false
                completion(response)
            }
        }
    }

    // MARK: - Search Event Handling

    private func handleSearch(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async {
        print("🔍 Handling search command: \(transcript)")

        // Extract search query
        let searchQuery = extractSearchQuery(from: transcript)
        print("🔍 Search query: \(searchQuery)")

        // Search for matching events
        let matchingEvents = calendarEvents.filter { event in
            let titleMatch = event.title.lowercased().contains(searchQuery.lowercased())
            let locationMatch = event.location?.lowercased().contains(searchQuery.lowercased()) ?? false
            return titleMatch || locationMatch
        }.sorted { $0.startDate < $1.startDate }

        // Use VoiceResponseGenerator to create response
        let voiceResponse = voiceResponseGenerator.generateSearchResponse(
            query: searchQuery,
            results: matchingEvents
        )

        let eventResults = matchingEvents.map { event in
            EventResult(
                id: event.id,
                title: event.title,
                startDate: event.startDate,
                endDate: event.endDate,
                location: event.location,
                source: event.source.rawValue,
                color: nil
            )
        }

        let response = AICalendarResponse(
            message: voiceResponse.fullMessage,
            eventResults: eventResults,
            shouldContinueListening: voiceResponse.followUp != nil
        )

        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    // MARK: - Availability Handling

    private func handleAvailability(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async {
        print("📅 Handling availability query: \(transcript)")

        // Extract time range from query
        let (startDate, endDate) = extractTimeRange(from: transcript)

        // Find events in that range
        let eventsInRange = calendarEvents.filter { event in
            event.startDate >= startDate && event.startDate < endDate
        }.sorted { $0.startDate < $1.startDate }

        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        if eventsInRange.isEmpty {
            let dayReference = calendar.isDateInToday(startDate) ? "today" : "then"
            let response = AICalendarResponse(message: "Yes, you're free \(dayReference). You don't have any events scheduled.")
            await MainActor.run {
                self.isProcessing = false
                completion(response)
            }
        } else {
            // Find gaps between events
            var message = "You have \(eventsInRange.count) event\(eventsInRange.count == 1 ? "" : "s") scheduled. "

            // Show first event time
            if let firstEvent = eventsInRange.first {
                message += "Your first event is at \(timeFormatter.string(from: firstEvent.startDate))"
            }

            // Find free slots
            var freeSlots: [(start: Date, end: Date)] = []

            // Before first event
            if let firstEvent = eventsInRange.first, firstEvent.startDate > startDate {
                freeSlots.append((startDate, firstEvent.startDate))
            }

            // Between events
            for i in 0..<eventsInRange.count-1 {
                let currentEnd = eventsInRange[i].endDate
                let nextStart = eventsInRange[i+1].startDate
                if nextStart > currentEnd {
                    freeSlots.append((currentEnd, nextStart))
                }
            }

            // After last event
            if let lastEvent = eventsInRange.last, lastEvent.endDate < endDate {
                freeSlots.append((lastEvent.endDate, endDate))
            }

            if !freeSlots.isEmpty {
                message += ". You're free "
                let slotDescriptions = freeSlots.prefix(3).map { slot in
                    "from \(timeFormatter.string(from: slot.start)) to \(timeFormatter.string(from: slot.end))"
                }
                message += slotDescriptions.joined(separator: ", ")
                message += "."
            }

            let response = AICalendarResponse(message: message)
            await MainActor.run {
                self.isProcessing = false
                completion(response)
            }
        }
    }

    // MARK: - Helper Methods for New Handlers

    private func extractEventReference(from text: String, in events: [UnifiedEvent]) -> UnifiedEvent? {
        let lowercased = text.lowercased()
        let now = Date()
        let calendar = Calendar.current

        // Look for time reference like "my 2pm meeting" or "3:30 event"
        if let timeMatch = lowercased.range(of: #"\b(\d{1,2}):?(\d{2})?\s*(am|pm)?\b"#, options: .regularExpression) {
            let timeString = String(lowercased[timeMatch])
            print("🕐 Found time reference: \(timeString)")

            // Find event at or near that time
            for event in events.sorted(by: { $0.startDate < $1.startDate }) {
                let eventHour = calendar.component(.hour, from: event.startDate)
                let eventMinute = calendar.component(.minute, from: event.startDate)

                // Convert timeString to comparable hour
                if timeString.contains(String(eventHour)) || timeString.contains(String(format: "%d", eventHour % 12)) {
                    return event
                }
            }
        }

        // Look for "next" event
        if lowercased.contains("next") || lowercased.contains("upcoming") {
            return events.filter { $0.startDate > now }.sorted { $0.startDate < $1.startDate }.first
        }

        // Look for event title match
        let words = lowercased.components(separatedBy: .whitespacesAndNewlines)
        for event in events {
            let eventTitleWords = event.title.lowercased().components(separatedBy: .whitespacesAndNewlines)
            let matchingWords = words.filter { word in
                eventTitleWords.contains(where: { $0.contains(word) && word.count > 3 })
            }
            if matchingWords.count >= 1 {
                return event
            }
        }

        // Look for today's events if "today" mentioned
        if lowercased.contains("today") {
            return events.filter { calendar.isDateInToday($0.startDate) }.sorted { $0.startDate < $1.startDate }.first
        }

        return nil
    }

    private func extractSearchQuery(from text: String) -> String {
        let lowercased = text.lowercased()

        // Remove search trigger words
        let triggers = ["when is my", "when's my", "find my", "where is my", "search for", "find", "search"]
        var cleaned = lowercased

        for trigger in triggers {
            cleaned = cleaned.replacingOccurrences(of: trigger, with: "")
        }

        // Clean up
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")

        // Remove common filler words
        let fillers = ["the", "my", "a", "an"]
        let words = cleaned.components(separatedBy: " ")
        let meaningfulWords = words.filter { !fillers.contains($0) && !$0.isEmpty }

        return meaningfulWords.joined(separator: " ")
    }

    // MARK: - Analytics Handling

    private func handleAnalytics(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async {
        print("📊 Handling analytics query: \(transcript)")

        let lowercased = transcript.lowercased()
        let calendar = Calendar.current
        let now = Date()

        // Determine time range for analysis
        let (startDate, endDate) = extractTimeRange(from: transcript)

        let eventsInRange = calendarEvents.filter { event in
            event.startDate >= startDate && event.startDate < endDate
        }.sorted { $0.startDate < $1.startDate }

        var message = ""

        // "How many meetings"
        if lowercased.contains("how many") {
            let count = eventsInRange.count
            let timeRef = calendar.isDateInToday(startDate) ? "today" :
                         calendar.isDateInTomorrow(startDate) ? "tomorrow" :
                         lowercased.contains("week") ? "this week" :
                         lowercased.contains("month") ? "this month" : "in that period"

            message = "You have \(count) event\(count == 1 ? "" : "s") \(timeRef)."
        }
        // "How much free time" or "hours in meetings"
        else if lowercased.contains("how much") || lowercased.contains("hours") {
            let totalMinutes = eventsInRange.reduce(0) { total, event in
                let duration = event.endDate.timeIntervalSince(event.startDate) / 60
                return total + Int(duration)
            }

            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60

            if lowercased.contains("free time") {
                // Calculate free time
                let dayDuration = Int(endDate.timeIntervalSince(startDate) / 60)
                let freeMinutes = dayDuration - totalMinutes
                let freeHours = freeMinutes / 60
                let freeMins = freeMinutes % 60

                message = "You have \(freeHours) hour\(freeHours == 1 ? "" : "s")"
                if freeMins > 0 {
                    message += " and \(freeMins) minute\(freeMins == 1 ? "" : "s")"
                }
                message += " of free time."
            } else {
                message = "You're in meetings for \(hours) hour\(hours == 1 ? "" : "s")"
                if minutes > 0 {
                    message += " and \(minutes) minute\(minutes == 1 ? "" : "s")"
                }
                message += "."
            }
        }
        // "What's my busiest day"
        else if lowercased.contains("busiest") {
            // Group events by day
            var eventsByDay: [Date: [UnifiedEvent]] = [:]
            for event in eventsInRange {
                let dayStart = calendar.startOfDay(for: event.startDate)
                if eventsByDay[dayStart] == nil {
                    eventsByDay[dayStart] = []
                }
                eventsByDay[dayStart]?.append(event)
            }

            if let busiestDay = eventsByDay.max(by: { $0.value.count < $1.value.count }) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                let dayName = formatter.string(from: busiestDay.key)

                message = "Your busiest day is \(dayName) with \(busiestDay.value.count) event\(busiestDay.value.count == 1 ? "" : "s")."
            } else {
                message = "You don't have any events scheduled."
            }
        }
        // Generic summary
        else {
            message = "You have \(eventsInRange.count) event\(eventsInRange.count == 1 ? "" : "s") scheduled."
        }

        let response = AICalendarResponse(message: message)
        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    // MARK: - Context-Aware Handling

    private func handleContextAware(transcript: String, calendarEvents: [UnifiedEvent], calendarManager: CalendarManager?, completion: @escaping (AICalendarResponse) -> Void) async {
        print("🧠 Handling context-aware query: \(transcript)")

        let lowercased = transcript.lowercased()
        let calendar = Calendar.current
        let now = Date()

        let todayEvents = calendarEvents.filter { event in
            calendar.isDateInToday(event.startDate)
        }.sorted { $0.startDate < $1.startDate }

        let upcomingEvents = todayEvents.filter { $0.startDate > now }

        var message = ""

        // "Do I have time for lunch"
        if lowercased.contains("time for lunch") || lowercased.contains("time to eat") {
            let lunchStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: now)!
            let lunchEnd = calendar.date(bySettingHour: 14, minute: 0, second: 0, of: now)!

            let lunchTimeEvents = todayEvents.filter { event in
                event.startDate < lunchEnd && event.endDate > lunchStart
            }

            if lunchTimeEvents.isEmpty {
                message = "Yes, you have time for lunch. You're free between 12 PM and 2 PM."
            } else if let nextEvent = upcomingEvents.first {
                let timeUntilNext = nextEvent.startDate.timeIntervalSince(now) / 60
                if timeUntilNext >= 30 {
                    message = "Yes, you have about \(Int(timeUntilNext)) minutes before your next meeting."
                } else {
                    message = "You only have \(Int(timeUntilNext)) minutes until your next meeting. It might be tight."
                }
            }
        }
        // "Can I squeeze in a workout" or similar
        else if lowercased.contains("squeeze in") || lowercased.contains("time for.*workout") {
            if let nextEvent = upcomingEvents.first {
                let minutesAvailable = Int(nextEvent.startDate.timeIntervalSince(now) / 60)

                if minutesAvailable >= 60 {
                    message = "Yes, you have \(minutesAvailable) minutes before your next meeting at \(DateFormatter.localizedString(from: nextEvent.startDate, dateStyle: .none, timeStyle: .short))."
                } else if minutesAvailable >= 30 {
                    message = "You have \(minutesAvailable) minutes, which might be enough for a quick session."
                } else {
                    message = "You only have \(minutesAvailable) minutes before your next meeting. It's pretty tight."
                }
            } else {
                message = "Yes, you're free for the rest of the day."
            }
        }
        // "Back to back meetings"
        else if lowercased.contains("back") && lowercased.contains("back") {
            var hasBackToBack = false
            for i in 0..<todayEvents.count-1 {
                let gap = todayEvents[i+1].startDate.timeIntervalSince(todayEvents[i].endDate)
                if gap < 300 { // Less than 5 minutes
                    hasBackToBack = true
                    break
                }
            }

            if hasBackToBack {
                message = "Yes, you have back-to-back meetings today."
            } else {
                message = "No, you have breaks between your meetings today."
            }
        }
        // "What should I prepare for tomorrow"
        else if lowercased.contains("prepare") {
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
            let tomorrowEvents = calendarEvents.filter { event in
                calendar.isDate(event.startDate, inSameDayAs: tomorrow)
            }.sorted { $0.startDate < $1.startDate }

            if tomorrowEvents.isEmpty {
                message = "You don't have anything scheduled tomorrow."
            } else {
                let eventTitles = tomorrowEvents.prefix(3).map { $0.title }.joined(separator: ", ")
                message = "Tomorrow you have \(tomorrowEvents.count) event\(tomorrowEvents.count == 1 ? "" : "s"): \(eventTitles)."
            }
        }
        // "What needs my attention"
        else if lowercased.contains("needs my attention") || lowercased.contains("need my attention") {
            if let manager = calendarManager {
                message = manager.analyzeAttentionItems()
            } else {
                message = "I need access to your calendar manager to analyze attention items."
            }
        }
        // Generic context
        else {
            if upcomingEvents.isEmpty {
                message = "You're free for the rest of the day."
            } else if let nextEvent = upcomingEvents.first {
                let minutesUntil = Int(nextEvent.startDate.timeIntervalSince(now) / 60)
                message = "Your next event is in \(minutesUntil) minutes: \(nextEvent.title)."
            }
        }

        let response = AICalendarResponse(message: message)
        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    // MARK: - Focus Time Handling

    private func handleFocusTime(transcript: String, completion: @escaping (AICalendarResponse) -> Void) async {
        print("🎯 Handling focus time request: \(transcript)")

        let lowercased = transcript.lowercased()

        // Extract duration if specified
        var duration = 120 // Default 2 hours
        if lowercased.contains("1 hour") || lowercased.contains("one hour") {
            duration = 60
        } else if let match = lowercased.range(of: #"(\d+)\s*hours?"#, options: .regularExpression) {
            let numStr = String(lowercased[match]).components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            if let hours = Int(numStr) {
                duration = hours * 60
            }
        }

        // Determine type of block
        var blockTitle = "Focus Time"
        if lowercased.contains("deep work") {
            blockTitle = "Deep Work"
        } else if lowercased.contains("prep time") {
            blockTitle = "Prep Time"
        } else if lowercased.contains("lunch") {
            blockTitle = "Lunch"
            duration = 60
        }

        let message = "I'd suggest using the calendar to manually block '\(blockTitle)' for \(duration / 60) hour\(duration == 60 ? "" : "s"). You can create this event yourself or ask me to 'Schedule \(blockTitle) tomorrow at [time]'."

        let response = AICalendarResponse(message: message)
        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    // MARK: - Conflicts Handling

    private func handleConflicts(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async {
        print("⚠️ Handling conflict detection: \(transcript)")

        let (startDate, endDate) = extractTimeRange(from: transcript)

        let eventsInRange = calendarEvents.filter { event in
            event.startDate >= startDate && event.startDate < endDate
        }.sorted { $0.startDate < $1.startDate }

        // Find overlapping events
        var conflicts: [(UnifiedEvent, UnifiedEvent)] = []
        for i in 0..<eventsInRange.count {
            for j in (i+1)..<eventsInRange.count {
                let event1 = eventsInRange[i]
                let event2 = eventsInRange[j]

                // Check if they overlap
                if event1.endDate > event2.startDate && event2.endDate > event1.startDate {
                    conflicts.append((event1, event2))
                }
            }
        }

        let message: String
        if conflicts.isEmpty {
            message = "No scheduling conflicts found. Your calendar looks good."
        } else {
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short

            let conflictDesc = conflicts.prefix(3).map { pair in
                "\(pair.0.title) and \(pair.1.title) at \(timeFormatter.string(from: pair.0.startDate))"
            }.joined(separator: ", ")

            message = "Found \(conflicts.count) conflict\(conflicts.count == 1 ? "" : "s"): \(conflictDesc)."
        }

        let response = AICalendarResponse(message: message)
        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    // MARK: - Batch Operations Handling

    private func handleBatch(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async {
        print("📦 Handling batch operation: \(transcript)")

        let lowercased = transcript.lowercased()

        // Determine operation type
        let operation: String
        if lowercased.contains("move all") || lowercased.contains("reschedule all") {
            operation = "move"
        } else if lowercased.contains("cancel all") || lowercased.contains("delete all") {
            operation = "delete"
        } else if lowercased.contains("clear all") {
            operation = "clear"
        } else {
            operation = "modify"
        }

        // Extract scope (which events)
        let (startDate, endDate) = extractTimeRange(from: transcript)
        let eventsInRange = calendarEvents.filter { event in
            event.startDate >= startDate && event.startDate < endDate
        }

        let message = "Batch operations require manual confirmation. You have \(eventsInRange.count) event\(eventsInRange.count == 1 ? "" : "s") matching your criteria. Please use the calendar interface to \(operation) them individually."

        let response = AICalendarResponse(message: message)
        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    private func handleWeather(transcript: String, completion: @escaping (AICalendarResponse) -> Void) async {
        print("🌦️ Handling weather query: \(transcript)")

        // Extract date from transcript if present
        let weatherDate = extractWeatherDate(from: transcript)
        if let date = weatherDate {
            print("📅 Extracted weather date: \(date)")
        } else {
            print("📅 No date found - fetching current weather")
        }

        // Fetch weather using WeatherService
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let fetchCompletion: (Result<WeatherData, Error>) -> Void = { [weak self] result in
                guard let self = self else {
                    continuation.resume()
                    return
                }

                switch result {
                case .success(let weatherData):
                    print("✅ Weather fetched successfully: \(weatherData.temperatureFormatted)")

                    // Build a natural weather response with date context
                    var weatherMessage: String
                    if let date = weatherDate {
                        let calendar = Calendar.current
                        let formatter = DateFormatter()

                        if calendar.isDateInToday(date) {
                            weatherMessage = "Today's weather: "
                        } else if calendar.isDateInTomorrow(date) {
                            weatherMessage = "Tomorrow's forecast: "
                        } else {
                            formatter.dateStyle = .full
                            formatter.timeStyle = .none
                            weatherMessage = "Weather for \(formatter.string(from: date)): "
                        }
                    } else {
                        weatherMessage = "It's currently "
                    }

                    weatherMessage += weatherData.temperatureFormatted

                    if !weatherData.condition.isEmpty {
                        weatherMessage += " and \(weatherData.condition.lowercased())"
                    }

                    if weatherData.high != weatherData.temperature || weatherData.low != weatherData.temperature {
                        let highTemp = String(format: "%.0f°", weatherData.high)
                        let lowTemp = String(format: "%.0f°", weatherData.low)
                        weatherMessage += ", with a high of \(highTemp) and a low of \(lowTemp)"
                    }

                    if weatherData.precipitationChance > 0 {
                        weatherMessage += ". There's a \(weatherData.precipitationChance)% chance of precipitation"
                    }

                    weatherMessage += "."

                    let response = AICalendarResponse(message: weatherMessage, shouldContinueListening: false)
                    Task { @MainActor in
                        self.isProcessing = false
                        completion(response)
                        continuation.resume()
                    }

                case .failure(let error):
                    print("❌ Weather fetch failed: \(error.localizedDescription)")

                    // Provide helpful error message
                    var errorMessage = "I couldn't fetch the weather right now. "
                    let nsError = error as NSError

                    if nsError.code == 3 {
                        errorMessage += "Please enable location access in Settings to get weather information."
                    } else if nsError.code == 8 {
                        errorMessage += "I can only provide forecasts up to 10 days in the future."
                    } else {
                        errorMessage += error.localizedDescription
                    }

                    let response = AICalendarResponse(message: errorMessage, shouldContinueListening: false)
                    Task { @MainActor in
                        self.isProcessing = false
                        completion(response)
                        continuation.resume()
                    }
                }
            }

            // Call appropriate weather service method
            if let date = weatherDate {
                WeatherService.shared.fetchWeatherForDate(date, completion: fetchCompletion)
            } else {
                WeatherService.shared.fetchCurrentWeather(completion: fetchCompletion)
            }
        }
    }

    // Extract date from weather query transcript
    private func extractWeatherDate(from text: String) -> Date? {
        let lowercased = text.lowercased()
        let calendar = Calendar.current
        let now = Date()

        // Tomorrow
        if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        }

        // Days of the week
        let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
        for (index, weekday) in weekdays.enumerated() {
            if lowercased.contains(weekday) {
                // Find the next occurrence of this weekday
                let currentWeekday = calendar.component(.weekday, from: now)
                var daysToAdd = (index + 1) - currentWeekday
                if daysToAdd <= 0 {
                    daysToAdd += 7 // Next week
                }
                return calendar.date(byAdding: .day, value: daysToAdd, to: now)
            }
        }

        // "next [weekday]"
        if lowercased.contains("next") {
            for (index, weekday) in weekdays.enumerated() {
                if lowercased.contains(weekday) {
                    let currentWeekday = calendar.component(.weekday, from: now)
                    var daysToAdd = (index + 1) - currentWeekday
                    if daysToAdd <= 0 {
                        daysToAdd += 7
                    }
                    daysToAdd += 7 // Add another week for "next"
                    return calendar.date(byAdding: .day, value: daysToAdd, to: now)
                }
            }
        }

        return nil
    }

    // MARK: - Task Handling

    private func handleCreateTask(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async {
        print("✅ Handling create task: \(transcript)")

        // Extract task details from transcript
        let lowercased = transcript.lowercased()

        // Extract title (simple extraction - remove common task keywords)
        var title = transcript
        let prefixes = ["create task", "add task", "new task", "create a task", "add a task", "make a task"]
        for prefix in prefixes {
            if let range = lowercased.range(of: prefix) {
                title = String(transcript[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
                break
            }
        }

        // Extract priority
        var priority: TaskPriority = .medium
        if lowercased.contains("high priority") || lowercased.contains("urgent") || lowercased.contains("important") {
            priority = .high
        } else if lowercased.contains("low priority") {
            priority = .low
        }

        // Create the task
        let task = EventTask(
            title: title,
            priority: priority
        )

        // Add to standalone tasks
        EventTaskManager.shared.addTask(task, to: "standalone_tasks")

        let message = "I've created a \(priority.rawValue.lowercased()) priority task: \(title)"
        let response = AICalendarResponse(message: message, shouldContinueListening: false)

        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    private func handleListTasks(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async {
        print("✅ Handling list tasks: \(transcript)")

        // Get all standalone tasks
        let standaloneTasks = EventTaskManager.shared.getTasks(for: "standalone_tasks")?.tasks ?? []

        var message: String
        if standaloneTasks.isEmpty {
            message = "You don't have any tasks yet."
        } else {
            let pendingTasks = standaloneTasks.filter { !$0.isCompleted }
            let completedTasks = standaloneTasks.filter { $0.isCompleted }

            if pendingTasks.isEmpty {
                message = "All \(standaloneTasks.count) task\(standaloneTasks.count == 1 ? "" : "s") completed! Great work!"
            } else {
                message = "You have \(pendingTasks.count) pending task\(pendingTasks.count == 1 ? "" : "s"):\n\n"
                for (index, task) in pendingTasks.enumerated() {
                    message += "\(index + 1). \(task.title) (\(task.priority.rawValue) priority)\n"
                }

                if !completedTasks.isEmpty {
                    message += "\nAnd \(completedTasks.count) completed task\(completedTasks.count == 1 ? "" : "s")."
                }
            }
        }

        let response = AICalendarResponse(message: message, shouldContinueListening: false)
        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    private func handleUpdateTask(transcript: String, completion: @escaping (AICalendarResponse) -> Void) async {
        print("✅ Handling update task: \(transcript)")

        let message = "Task updating through voice is coming soon. For now, please use the task interface to update task properties."
        let response = AICalendarResponse(message: message, shouldContinueListening: false)

        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    private func handleCompleteTask(transcript: String, completion: @escaping (AICalendarResponse) -> Void) async {
        print("✅ Handling complete task: \(transcript)")

        let message = "Task completion through voice is coming soon. For now, please use the task interface to mark tasks as complete."
        let response = AICalendarResponse(message: message, shouldContinueListening: false)

        await MainActor.run {
            self.isProcessing = false
            completion(response)
        }
    }

    // MARK: - Confirmation Flow Handling

    private func handleConfirmation(transcript: String, completion: @escaping (AICalendarResponse) -> Void) {
        let lowercased = transcript.lowercased()
        var response: AICalendarResponse

        let positiveKeywords = ["yes", "yep", "yeah", "correct", "confirm", "do it", "okay", "ok"]
        if positiveKeywords.contains(where: lowercased.contains) {
            if let commandToExecute = self.pendingCommand {
                print("✅ User confirmed action. Executing command.")
                response = AICalendarResponse(message: "Okay, done.", command: commandToExecute)
            } else {
                response = AICalendarResponse(message: "Sorry, I forgot what we were doing. Please start over.")
            }
        } else {
            print("❌ User cancelled action.")
            response = AICalendarResponse(message: "Okay, cancelling.")
        }

        resetConversationState()
        
        DispatchQueue.main.async {
            self.isProcessing = false
            completion(response)
        }
    }
    
    func resetConversationState() {
        self.pendingCommand = nil
        self.conversationState = .idle
        self.conversationContext.removeAll()
        self.lastQueryTimeRange = nil
        self.lastQueryEvents.removeAll()
        self.conversationalAI.clearContext()  // Clear conversational AI context
        print("🔄 Reset conversation state and cleared AI context")
        print("🔄 Conversation state and context reset to idle.")
    }

    // MARK: - Helper Methods

    private func parseFlexibleISO8601Date(_ dateString: String) -> Date? {
        // Try standard ISO8601 with timezone first
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: dateString) {
            return date
        }

        // Try without timezone (assume local time)
        // OpenAI often returns dates like "2025-10-19T13:00:00" without timezone
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.timeZone = TimeZone.current
        formatter.locale = Locale(identifier: "en_US_POSIX")

        if let date = formatter.date(from: dateString) {
            print("✅ Parsed date without timezone: \(dateString) -> \(date)")
            return date
        }

        // Try with additional format variations
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        if let date = formatter.date(from: dateString) {
            print("✅ Parsed date with milliseconds: \(dateString) -> \(date)")
            return date
        }

        print("❌ Failed to parse date: \(dateString)")
        return nil
    }

    private func commandRequiresConfirmation(_ command: CalendarCommand) -> Bool {
        switch command.type {
        case .createEvent, .deleteEvent, .updateEvent, .rescheduleEvent, .clearSchedule, .moveEvent:
            return true
        default:
            return false
        }
    }

    private func generateConfirmationMessage(for command: CalendarCommand) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        switch command.type {
        case .createEvent:
            let title = command.title ?? "your event"
            if let date = command.startDate {
                return "So you want me to create an event titled '\(title)' for \(formatter.string(from: date))?"
            } else {
                return "So you want me to create an event titled '\(title)'?"
            }
        case .deleteEvent:
            let title = command.searchQuery ?? "this event"
            return "Are you sure you want to delete '\(title)'?"
        default:
            return "Are you sure you want to proceed?"
        }
    }
    
    private func generateResponseMessage(for command: CalendarCommand) -> String {
        switch command.type {
        case .createEvent:
            return "Okay, I'll create an event for '\(command.title ?? "your event")'..."
        case .queryEvents:
            return "Let me check your calendar..."
        default:
            return "Got it, I'll take care of that..."
        }
    }

    // MARK: - Phase 4: AI Task Generation

    func generateTasksForEvent(_ event: UnifiedEvent) async throws -> TaskGenerationResult {
        let taskGenerator = AITaskGenerator()
        return try await taskGenerator.generateTasks(for: event)
    }

    // MARK: - Task Extraction Fallback

    private func extractTaskFromTranscript(_ transcript: String) -> [String: String] {
        print("🔍 Extracting task details from transcript: \(transcript)")
        var params: [String: String] = [:]

        let lowercased = transcript.lowercased()

        // Extract title - remove task creation keywords
        var title = transcript
        let taskPrefixes = ["create a task", "create task", "add a task", "add task", "new task", "make a task", "make task"]
        for prefix in taskPrefixes {
            if let range = lowercased.range(of: prefix) {
                title = String(transcript[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Remove time indicators from title to clean it up
        let timeKeywords = ["for", "at", "by", "tomorrow", "today", "tonight", "am", "pm"]
        var cleanTitle = title
        for keyword in timeKeywords {
            if let range = cleanTitle.lowercased().range(of: " \(keyword) ") {
                cleanTitle = String(cleanTitle[..<range.lowerBound])
                break
            }
        }

        params["title"] = cleanTitle.trimmingCharacters(in: .whitespaces)
        print("📝 Extracted title: \(params["title"] ?? "")")

        // Extract scheduled time using SmartEventParser's time extraction
        let parser = SmartEventParser()
        let parseResult = parser.parse(transcript)

        // Extract entities from parse result
        let entities: ExtractedEntities?
        switch parseResult {
        case .success(let extractedEntities, _):
            entities = extractedEntities
        case .needsClarification(let extractedEntities, _):
            entities = extractedEntities
        case .failure:
            entities = nil
        }

        if let startTime = entities?.time {
            let formatter = ISO8601DateFormatter()
            params["scheduled_time"] = formatter.string(from: startTime)
            print("⏰ Extracted scheduled time: \(startTime)")
        }

        // Extract priority
        if lowercased.contains("high priority") || lowercased.contains("urgent") || lowercased.contains("important") {
            params["priority"] = "High"
        } else if lowercased.contains("low priority") {
            params["priority"] = "Low"
        } else {
            params["priority"] = "Medium"
        }

        return params
    }

}


