import Foundation
import EventKit
import Combine

// MARK: - Task Recurrence Models

enum TaskRecurrenceFrequency: String, Codable, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
    case beforeEachEvent = "Before Each Event"

    var icon: String {
        switch self {
        case .daily: return "sun.max.fill"
        case .weekly: return "calendar.badge.clock"
        case .biweekly: return "calendar"
        case .monthly: return "calendar.circle"
        case .beforeEachEvent: return "arrow.triangle.2.circlepath"
        }
    }
}

struct TaskRecurrence: Codable, Hashable {
    var frequency: TaskRecurrenceFrequency
    var endDate: Date?
    var linkedEventPattern: String? // For recurring event matching

    init(frequency: TaskRecurrenceFrequency, endDate: Date? = nil, linkedEventPattern: String? = nil) {
        self.frequency = frequency
        self.endDate = endDate
        self.linkedEventPattern = linkedEventPattern
    }
}

// MARK: - Automation Template

struct AutomationTemplate: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String?
    var priority: TaskPriority
    var category: TaskCategory
    var timing: TaskTiming
    var estimatedMinutes: Int?
    var tags: [String]
    var recurrence: TaskRecurrence?
    var eventPattern: String? // Pattern to match events (e.g., "standup", "review")
    var autoSchedule: Bool

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        priority: TaskPriority = .medium,
        category: TaskCategory = .preparation,
        timing: TaskTiming = .before(hours: 24),
        estimatedMinutes: Int? = nil,
        tags: [String] = [],
        recurrence: TaskRecurrence? = nil,
        eventPattern: String? = nil,
        autoSchedule: Bool = false
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.priority = priority
        self.category = category
        self.timing = timing
        self.estimatedMinutes = estimatedMinutes
        self.tags = tags
        self.recurrence = recurrence
        self.eventPattern = eventPattern
        self.autoSchedule = autoSchedule
    }

    // Create task from template
    func createTask(linkedEventId: String?, scheduledTime: Date? = nil) -> EventTask {
        EventTask(
            title: title,
            description: description,
            priority: priority,
            category: category,
            timing: timing,
            estimatedMinutes: estimatedMinutes,
            tags: tags + ["Template-Generated"],
            linkedEventId: linkedEventId,
            duration: estimatedMinutes.map { TimeInterval($0 * 60) },
            scheduledTime: scheduledTime
        )
    }
}

// MARK: - Task Automation Service

class TaskAutomationService: ObservableObject {
    static let shared = TaskAutomationService()

    private let userDefaults = UserDefaults.standard
    private let templatesKey = "taskTemplates"

    @Published var templates: [AutomationTemplate] = []

    private init() {
        loadTemplates()
    }

    // MARK: - Template Management

    func addTemplate(_ template: AutomationTemplate) {
        templates.append(template)
        saveTemplates()
        print("✅ Added task template: \(template.title)")
    }

    func updateTemplate(_ template: AutomationTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
            saveTemplates()
            print("✅ Updated task template: \(template.title)")
        }
    }

    func deleteTemplate(_ templateId: UUID) {
        templates.removeAll { $0.id == templateId }
        saveTemplates()
        print("🗑️ Deleted task template")
    }

    private func saveTemplates() {
        if let encoded = try? JSONEncoder().encode(templates) {
            userDefaults.set(encoded, forKey: templatesKey)
        }
    }

    private func loadTemplates() {
        if let data = userDefaults.data(forKey: templatesKey),
           let decoded = try? JSONDecoder().decode([AutomationTemplate].self, from: data) {
            templates = decoded
            print("📋 Loaded \(templates.count) task templates")
        }
    }

    // MARK: - Automatic Task Generation

    func generateAutomaticTasks(for event: UnifiedEvent, taskManager: EventTaskManager) {
        print("🤖 Checking for automatic tasks for: \(event.title)")

        // Find matching templates
        let matchingTemplates = findMatchingTemplates(for: event)

        for template in matchingTemplates {
            // Calculate scheduled time if auto-schedule enabled
            let scheduledTime = template.autoSchedule ? calculateScheduledTime(for: event, timing: template.timing) : nil

            // Create task from template
            let task = template.createTask(linkedEventId: event.id, scheduledTime: scheduledTime)

            // Add to task manager
            taskManager.addTask(task, to: event.id)

            print("✅ Auto-generated task: \(task.title)")
        }
    }

    private func findMatchingTemplates(for event: UnifiedEvent) -> [AutomationTemplate] {
        templates.filter { template in
            // Check if template has event pattern matching
            guard let pattern = template.eventPattern else { return false }

            let eventTitle = event.title.lowercased()
            let patternLower = pattern.lowercased()

            return eventTitle.contains(patternLower)
        }
    }

    private func calculateScheduledTime(for event: UnifiedEvent, timing: TaskTiming) -> Date? {
        switch timing {
        case .before(let hours):
            return event.startDate.addingTimeInterval(-TimeInterval(hours * 3600))
        case .after(let hours):
            return event.endDate.addingTimeInterval(TimeInterval(hours * 3600))
        case .during:
            return event.startDate
        case .specific(let date):
            return date
        }
    }

    // MARK: - Smart Scheduling

    func suggestOptimalTimeSlot(
        for task: EventTask,
        on date: Date,
        events: [UnifiedEvent],
        existingTasks: [(task: EventTask, eventId: String)]
    ) -> Date? {
        guard let duration = task.duration else { return nil }

        print("🔍 Finding optimal time slot for: \(task.title)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let workStart = calendar.date(byAdding: .hour, value: 9, to: startOfDay)!
        let workEnd = calendar.date(byAdding: .hour, value: 17, to: startOfDay)!

        // Find free slots
        var currentTime = workStart

        while currentTime.addingTimeInterval(duration) <= workEnd {
            let proposedEndTime = currentTime.addingTimeInterval(duration)

            // Check if slot conflicts with events
            let conflictsWithEvents = events.contains { event in
                let eventStart = event.startDate
                let eventEnd = event.endDate

                return (currentTime >= eventStart && currentTime < eventEnd) ||
                       (proposedEndTime > eventStart && proposedEndTime <= eventEnd) ||
                       (currentTime <= eventStart && proposedEndTime >= eventEnd)
            }

            // Check if slot conflicts with scheduled tasks
            let conflictsWithTasks = existingTasks.contains { (scheduledTask, _) in
                guard let taskTime = scheduledTask.scheduledTime,
                      let taskDuration = scheduledTask.duration else { return false }

                let taskEnd = taskTime.addingTimeInterval(taskDuration)

                return (currentTime >= taskTime && currentTime < taskEnd) ||
                       (proposedEndTime > taskTime && proposedEndTime <= taskEnd) ||
                       (currentTime <= taskTime && proposedEndTime >= taskEnd)
            }

            if !conflictsWithEvents && !conflictsWithTasks {
                print("✅ Found optimal slot: \(formatTime(currentTime))")
                return currentTime
            }

            // Move to next 15-minute slot
            currentTime = currentTime.addingTimeInterval(900) // 15 minutes
        }

        print("⚠️ No free slots found")
        return nil
    }

    // MARK: - Pattern Detection

    func detectTaskPatterns(from history: [EventTask]) -> [AutomationTemplate] {
        print("🔍 Detecting task patterns from \(history.count) tasks")

        var detectedTemplates: [AutomationTemplate] = []

        // Group tasks by title similarity
        var taskGroups: [String: [EventTask]] = [:]

        for task in history {
            let normalizedTitle = task.title.lowercased().trimmingCharacters(in: .whitespaces)
            taskGroups[normalizedTitle, default: []].append(task)
        }

        // Find recurring patterns (tasks that appear 3+ times)
        for (title, tasks) in taskGroups where tasks.count >= 3 {
            // Calculate average values
            let avgPriority = mostCommon(tasks.map { $0.priority }) ?? .medium
            let avgCategory = mostCommon(tasks.map { $0.category }) ?? .preparation
            let avgTiming = mostCommon(tasks.map { $0.timing }) ?? .before(hours: 24)

            let template = AutomationTemplate(
                title: title.capitalized,
                priority: avgPriority,
                category: avgCategory,
                timing: avgTiming,
                tags: ["Pattern-Detected"],
                autoSchedule: true
            )

            detectedTemplates.append(template)
            print("📋 Detected pattern: \(title) (appears \(tasks.count) times)")
        }

        return detectedTemplates
    }

    private func mostCommon<T: Hashable>(_ items: [T]) -> T? {
        let counts = items.reduce(into: [:]) { $0[$1, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    // MARK: - Helpers

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Default Templates

    func createDefaultTemplates() {
        let defaults: [AutomationTemplate] = [
            AutomationTemplate(
                title: "Review meeting agenda",
                priority: .high,
                category: .preparation,
                timing: .before(hours: 2),
                estimatedMinutes: 15,
                tags: ["Meeting"],
                eventPattern: "meeting",
                autoSchedule: true
            ),
            AutomationTemplate(
                title: "Prepare presentation materials",
                priority: .high,
                category: .materials,
                timing: .before(hours: 24),
                estimatedMinutes: 60,
                tags: ["Presentation"],
                eventPattern: "presentation",
                autoSchedule: true
            ),
            AutomationTemplate(
                title: "Check-in for flight",
                priority: .high,
                category: .logistics,
                timing: .before(hours: 24),
                estimatedMinutes: 10,
                tags: ["Travel"],
                eventPattern: "flight",
                autoSchedule: true
            ),
            AutomationTemplate(
                title: "Review call notes",
                priority: .medium,
                category: .followUp,
                timing: .after(hours: 1),
                estimatedMinutes: 10,
                tags: ["Call"],
                eventPattern: "call",
                autoSchedule: false
            )
        ]

        for template in defaults {
            if !templates.contains(where: { $0.title == template.title }) {
                addTemplate(template)
            }
        }

        print("✅ Created \(defaults.count) default templates")
    }
}
