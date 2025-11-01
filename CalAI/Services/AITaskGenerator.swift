import Foundation
import SwiftAnthropic
import EventKit

// MARK: - AI Task Generation Models

struct GeneratedTask: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var priority: TaskPriority
    var category: TaskCategory
    var timing: TaskTiming
    var estimatedMinutes: Int?
    var tags: [String]

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        priority: TaskPriority = .medium,
        category: TaskCategory = .preparation,
        timing: TaskTiming = .before(hours: 24),
        estimatedMinutes: Int? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.category = category
        self.timing = timing
        self.estimatedMinutes = estimatedMinutes
        self.tags = tags
    }

    // Convert to EventTask
    func toEventTask(linkedEventId: String) -> EventTask {
        EventTask(
            title: title,
            description: description,
            priority: priority,
            category: category,
            timing: timing,
            estimatedMinutes: estimatedMinutes,
            tags: tags,
            linkedEventId: linkedEventId
        )
    }
}

struct TaskGenerationResult {
    let tasks: [GeneratedTask]
    let message: String
}

// MARK: - AI Task Generator Service

class AITaskGenerator {
    private let conversationalAI: ConversationalAIService

    init() {
        self.conversationalAI = ConversationalAIService()
    }

    // MARK: - Task Generation

    func generateTasks(for event: UnifiedEvent) async throws -> TaskGenerationResult {
        print("🤖 Generating AI tasks for event: \(event.title)")

        let prompt = buildTaskGenerationPrompt(for: event)
        print("📝 Prompt: \(prompt)")

        do {
            // Use processCommand instead of chat
            let action = try await conversationalAI.processCommand(prompt, calendarEvents: [])
            let response = action.message
            print("✅ AI Response received: \(response)")

            let tasks = parseTasksFromResponse(response, eventId: event.id)

            let message = tasks.isEmpty
                ? "I couldn't generate any tasks for this event. Please try adding some manually."
                : "Generated \(tasks.count) \(tasks.count == 1 ? "task" : "tasks") to help you prepare!"

            return TaskGenerationResult(tasks: tasks, message: message)
        } catch {
            print("❌ AI Task Generation Error: \(error)")
            throw error
        }
    }

    // MARK: - Prompt Building

    private func buildTaskGenerationPrompt(for event: UnifiedEvent) -> String {
        let eventType = detectAIEventType(event)
        let basePrompt = getBasePromptForAIEventType(eventType)

        var prompt = """
        \(basePrompt)

        Event Details:
        - Title: \(event.title)
        - Date: \(formatEventDate(event.startDate))
        - Time: \(formatEventTime(event))
        """

        if let location = event.location, !location.isEmpty {
            prompt += "\n- Location: \(location)"
        }

        if let notes = event.description, !notes.isEmpty {
            prompt += "\n- Notes: \(notes)"
        }

        prompt += """


        Please generate 3-7 specific, actionable preparation tasks for this event. For each task, provide:
        1. A clear, concise title (max 60 characters)
        2. Optional description with helpful details
        3. Priority (Low, Medium, or High)
        4. Category (Preparation, Logistics, Materials, Research, Documents, etc.)
        5. Timing (how many hours before the event to complete it)
        6. Estimated time in minutes

        Format each task EXACTLY as JSON on a single line like this:
        {"title":"Task title here","description":"Optional details","priority":"Medium","category":"Preparation","timing_hours":24,"estimated_minutes":15}

        One task per line. Do not include any other text or explanation.
        """

        return prompt
    }

    private func detectAIEventType(_ event: UnifiedEvent) -> AIEventType {
        let title = event.title.lowercased()
        let description = event.description?.lowercased() ?? ""
        let combined = title + " " + description

        // Meeting indicators
        if combined.contains("meeting") || combined.contains("call") ||
           combined.contains("standup") || combined.contains("sync") ||
           combined.contains("1:1") || combined.contains("interview") {
            return .meeting
        }

        // Travel indicators
        if combined.contains("flight") || combined.contains("trip") ||
           combined.contains("travel") || combined.contains("vacation") ||
           combined.contains("airport") {
            return .travel
        }

        // Appointment indicators
        if combined.contains("doctor") || combined.contains("dentist") ||
           combined.contains("appointment") || combined.contains("medical") {
            return .appointment
        }

        // Event indicators
        if combined.contains("conference") || combined.contains("workshop") ||
           combined.contains("seminar") || combined.contains("presentation") {
            return .conference
        }

        // Personal indicators
        if combined.contains("birthday") || combined.contains("anniversary") ||
           combined.contains("party") || combined.contains("celebration") {
            return .personal
        }

        return .general
    }

    private func getBasePromptForAIEventType(_ type: AIEventType) -> String {
        switch type {
        case .meeting:
            return "You are a helpful assistant creating preparation tasks for a meeting."
        case .travel:
            return "You are a helpful assistant creating preparation and packing tasks for travel."
        case .appointment:
            return "You are a helpful assistant creating reminder tasks for an appointment."
        case .conference:
            return "You are a helpful assistant creating preparation tasks for attending a conference or event."
        case .personal:
            return "You are a helpful assistant creating preparation tasks for a personal event."
        case .general:
            return "You are a helpful assistant creating preparation tasks for an upcoming event."
        }
    }

    // MARK: - Response Parsing

    private func parseTasksFromResponse(_ response: String, eventId: String) -> [GeneratedTask] {
        var tasks: [GeneratedTask] = []
        let lines = response.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

            // Skip empty lines or lines that don't start with {
            guard !trimmed.isEmpty, trimmed.hasPrefix("{") else { continue }

            if let task = parseJSONTask(trimmed) {
                tasks.append(task)
            }
        }

        print("📋 Parsed \(tasks.count) tasks from AI response")
        return tasks
    }

    private func parseJSONTask(_ json: String) -> GeneratedTask? {
        guard let data = json.data(using: .utf8) else { return nil }

        do {
            if let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                guard let title = dict["title"] as? String else { return nil }

                let description = dict["description"] as? String
                let priorityString = dict["priority"] as? String ?? "Medium"
                let categoryString = dict["category"] as? String ?? "Preparation"
                let timingHours = dict["timing_hours"] as? Int ?? 24
                let estimatedMinutes = dict["estimated_minutes"] as? Int

                let priority = TaskPriority(rawValue: priorityString) ?? .medium
                let category = TaskCategory(rawValue: categoryString) ?? .preparation
                let timing = TaskTiming.before(hours: timingHours)

                return GeneratedTask(
                    title: title,
                    description: description,
                    priority: priority,
                    category: category,
                    timing: timing,
                    estimatedMinutes: estimatedMinutes,
                    tags: ["AI-Generated"]
                )
            }
        } catch {
            print("❌ JSON parsing error: \(error)")
        }

        return nil
    }

    // MARK: - Formatting Helpers

    private func formatEventDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatEventTime(_ event: UnifiedEvent) -> String {
        if event.isAllDay {
            return "All day"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: event.startDate)) - \(formatter.string(from: event.endDate))"
    }
}

// MARK: - AI Event Type Detection

private enum AIEventType {
    case meeting
    case travel
    case appointment
    case conference
    case personal
    case general
}
