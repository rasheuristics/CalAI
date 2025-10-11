import SwiftUI
import Foundation
import Combine
import EventKit

// MARK: - Event Task Models

/// Universal event task system (extends Meeting Preparation to all event types)
struct EventTask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var description: String?
    var isCompleted: Bool
    var priority: TaskPriority
    var category: TaskCategory
    var timing: TaskTiming
    var estimatedMinutes: Int?
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        description: String? = nil,
        isCompleted: Bool = false,
        priority: TaskPriority = .medium,
        category: TaskCategory = .preparation,
        timing: TaskTiming = .before(hours: 24),
        estimatedMinutes: Int? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.priority = priority
        self.category = category
        self.timing = timing
        self.estimatedMinutes = estimatedMinutes
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

enum TaskPriority: String, Codable, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: String {
        switch self {
        case .high: return "red"
        case .medium: return "orange"
        case .low: return "blue"
        }
    }

    var icon: String {
        switch self {
        case .high: return "exclamationmark.circle.fill"
        case .medium: return "exclamationmark.circle"
        case .low: return "circle"
        }
    }
}

enum TaskCategory: String, Codable, CaseIterable {
    case preparation = "Preparation"
    case logistics = "Logistics"
    case materials = "Materials"
    case followUp = "Follow-up"
    case reminder = "Reminder"
    case research = "Research"
    case packing = "Packing"
    case documents = "Documents"
    case health = "Health"
    case communication = "Communication"

    var icon: String {
        switch self {
        case .preparation: return "list.bullet.clipboard"
        case .logistics: return "car.fill"
        case .materials: return "folder.fill"
        case .followUp: return "arrow.turn.down.right"
        case .reminder: return "bell.fill"
        case .research: return "magnifyingglass"
        case .packing: return "suitcase.fill"
        case .documents: return "doc.text.fill"
        case .health: return "cross.case.fill"
        case .communication: return "message.fill"
        }
    }
}

enum TaskTiming: Codable, Hashable {
    case before(hours: Int)
    case during
    case after(hours: Int)
    case specific(date: Date)

    var description: String {
        switch self {
        case .before(let hours):
            if hours < 24 {
                return "\(hours) hour\(hours == 1 ? "" : "s") before"
            } else {
                let days = hours / 24
                return "\(days) day\(days == 1 ? "" : "s") before"
            }
        case .during:
            return "During event"
        case .after(let hours):
            if hours < 24 {
                return "\(hours) hour\(hours == 1 ? "" : "s") after"
            } else {
                let days = hours / 24
                return "\(days) day\(days == 1 ? "" : "s") after"
            }
        case .specific(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Event Type Detection

enum EventType: String, Codable, CaseIterable {
    case meeting = "Meeting"
    case medical = "Medical"
    case travel = "Travel"
    case flight = "Flight"
    case interview = "Interview"
    case social = "Social"
    case workout = "Workout"
    case errand = "Errand"
    case deadline = "Deadline"
    case appointment = "Appointment"
    case generic = "Event"

    var icon: String {
        switch self {
        case .meeting: return "person.2.fill"
        case .medical: return "cross.case.fill"
        case .travel: return "airplane"
        case .flight: return "airplane.departure"
        case .interview: return "person.crop.circle.badge.questionmark"
        case .social: return "person.3.fill"
        case .workout: return "figure.run"
        case .errand: return "cart.fill"
        case .deadline: return "clock.fill"
        case .appointment: return "calendar.badge.clock"
        case .generic: return "calendar"
        }
    }

    /// Detect event type from title and description
    static func detect(from title: String, description: String? = nil) -> EventType {
        let combined = (title + " " + (description ?? "")).lowercased()

        // Medical
        if combined.contains("doctor") || combined.contains("dr.") ||
           combined.contains("dentist") || combined.contains("medical") ||
           combined.contains("appointment") || combined.contains("checkup") ||
           combined.contains("physical") || combined.contains("clinic") {
            return .medical
        }

        // Flight/Travel
        if combined.contains("flight") || combined.contains("airline") ||
           combined.contains("departure") || combined.contains("arrival") {
            return .flight
        }

        if combined.contains("trip") || combined.contains("travel") ||
           combined.contains("vacation") || combined.contains("hotel") {
            return .travel
        }

        // Interview
        if combined.contains("interview") {
            return .interview
        }

        // Meeting (use existing MeetingCategory logic)
        if combined.contains("meeting") || combined.contains("call") ||
           combined.contains("sync") || combined.contains("standup") ||
           combined.contains("1:1") || combined.contains("review") {
            return .meeting
        }

        // Workout
        if combined.contains("workout") || combined.contains("gym") ||
           combined.contains("exercise") || combined.contains("training") ||
           combined.contains("yoga") || combined.contains("run") {
            return .workout
        }

        // Social
        if combined.contains("lunch") || combined.contains("dinner") ||
           combined.contains("brunch") || combined.contains("coffee") ||
           combined.contains("drinks") || combined.contains("party") {
            return .social
        }

        // Errand
        if combined.contains("pickup") || combined.contains("drop off") ||
           combined.contains("grocery") || combined.contains("shopping") ||
           combined.contains("bank") || combined.contains("post office") {
            return .errand
        }

        // Deadline
        if combined.contains("deadline") || combined.contains("due") ||
           combined.contains("submit") || combined.contains("deliver") {
            return .deadline
        }

        return .generic
    }
}

// MARK: - Task Templates

struct TaskTemplate {
    let eventType: EventType
    let tasks: [EventTask]

    static let templates: [EventType: [EventTask]] = [
        .medical: [
            EventTask(
                title: "Bring insurance card",
                description: "Don't forget your health insurance card",
                priority: .high,
                category: .documents,
                timing: .during
            ),
            EventTask(
                title: "Bring photo ID",
                description: "Driver's license or passport",
                priority: .high,
                category: .documents,
                timing: .during
            ),
            EventTask(
                title: "List current medications",
                description: "Prepare a list of all medications you're taking",
                priority: .medium,
                category: .preparation,
                timing: .before(hours: 24)
            ),
            EventTask(
                title: "Write down symptoms/questions",
                description: "Note any symptoms or questions for the doctor",
                priority: .medium,
                category: .preparation,
                timing: .before(hours: 24)
            ),
            EventTask(
                title: "Arrive 15 minutes early",
                description: "Time for paperwork and check-in",
                priority: .medium,
                category: .logistics,
                timing: .during
            )
        ],

        .flight: [
            EventTask(
                title: "Online check-in",
                description: "Check in 24 hours before departure",
                priority: .high,
                category: .logistics,
                timing: .before(hours: 24)
            ),
            EventTask(
                title: "Download boarding pass",
                description: "Save boarding pass to wallet or print",
                priority: .high,
                category: .documents,
                timing: .before(hours: 12)
            ),
            EventTask(
                title: "Pack carry-on essentials",
                description: "Medications, chargers, important documents",
                priority: .high,
                category: .packing,
                timing: .before(hours: 24)
            ),
            EventTask(
                title: "Check TSA wait times",
                description: "Verify security wait times at airport",
                priority: .medium,
                category: .logistics,
                timing: .before(hours: 3)
            ),
            EventTask(
                title: "Confirm transportation to airport",
                description: "Uber/Lyft/parking arrangements",
                priority: .high,
                category: .logistics,
                timing: .before(hours: 24)
            )
        ],

        .interview: [
            EventTask(
                title: "Research company",
                description: "Study company background, mission, recent news",
                priority: .high,
                category: .research,
                timing: .before(hours: 48)
            ),
            EventTask(
                title: "Prepare STAR stories",
                description: "Prepare examples using Situation-Task-Action-Result format",
                priority: .high,
                category: .preparation,
                timing: .before(hours: 24)
            ),
            EventTask(
                title: "Print resume copies",
                description: "Bring 2-3 printed copies of resume",
                priority: .medium,
                category: .materials,
                timing: .before(hours: 24)
            ),
            EventTask(
                title: "Prepare questions to ask",
                description: "Have thoughtful questions ready for interviewer",
                priority: .high,
                category: .preparation,
                timing: .before(hours: 24)
            ),
            EventTask(
                title: "Test video setup (if virtual)",
                description: "Check camera, microphone, internet connection",
                priority: .high,
                category: .logistics,
                timing: .before(hours: 2)
            ),
            EventTask(
                title: "Send thank-you email",
                description: "Follow up within 24 hours",
                priority: .high,
                category: .followUp,
                timing: .after(hours: 4)
            )
        ],

        .travel: [
            EventTask(
                title: "Check passport/ID validity",
                description: "Ensure travel documents are valid",
                priority: .high,
                category: .documents,
                timing: .before(hours: 168) // 1 week
            ),
            EventTask(
                title: "Pack essentials",
                description: "Clothing, toiletries, chargers, medications",
                priority: .high,
                category: .packing,
                timing: .before(hours: 24)
            ),
            EventTask(
                title: "Confirm hotel reservation",
                description: "Verify booking and address",
                priority: .medium,
                category: .logistics,
                timing: .before(hours: 48)
            ),
            EventTask(
                title: "Set up travel alerts",
                description: "Notify bank/credit cards of travel",
                priority: .medium,
                category: .preparation,
                timing: .before(hours: 72)
            )
        ],

        .meeting: [
            EventTask(
                title: "Review agenda",
                description: "Familiarize yourself with meeting topics",
                priority: .medium,
                category: .preparation,
                timing: .before(hours: 2)
            ),
            EventTask(
                title: "Prepare materials",
                description: "Gather any necessary documents or presentations",
                priority: .medium,
                category: .materials,
                timing: .before(hours: 4)
            )
        ]
    ]

    static func getTasks(for eventType: EventType) -> [EventTask] {
        return templates[eventType] ?? []
    }
}

// MARK: - Event Tasks Container

/// Container for all tasks associated with an event
struct EventTasks: Codable {
    let eventId: String
    var tasks: [EventTask]
    var eventType: EventType
    var autoGenerated: Bool

    var pendingTasks: [EventTask] {
        tasks.filter { !$0.isCompleted }
    }

    var completedTasks: [EventTask] {
        tasks.filter { $0.isCompleted }
    }

    var completionPercentage: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(completedTasks.count) / Double(tasks.count) * 100
    }
}

// MARK: - Task Generation Settings

enum TaskGenerationMode: String, Codable, CaseIterable {
    case manual = "Manual Only"
    case suggest = "Suggest Tasks"
    case autoCreate = "Auto-Create Tasks"

    var description: String {
        switch self {
        case .manual:
            return "You create all tasks manually"
        case .suggest:
            return "AI suggests tasks, you confirm"
        case .autoCreate:
            return "AI creates tasks automatically, you can edit"
        }
    }
}

struct TaskGenerationSettings: Codable {
    var mode: TaskGenerationMode
    var enabledEventTypes: Set<EventType>
    var showPreEventTasksDays: Int
    var showPostEventTasksDays: Int
    var enableNotifications: Bool

    static let `default` = TaskGenerationSettings(
        mode: .suggest,
        enabledEventTypes: Set(EventType.allCases),
        showPreEventTasksDays: 7,
        showPostEventTasksDays: 3,
        enableNotifications: true
    )
}

extension TaskGenerationSettings {
    enum CodingKeys: String, CodingKey {
        case mode
        case enabledEventTypes
        case showPreEventTasksDays
        case showPostEventTasksDays
        case enableNotifications
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        mode = try container.decode(TaskGenerationMode.self, forKey: .mode)

        let eventTypesArray = try container.decode([EventType].self, forKey: .enabledEventTypes)
        enabledEventTypes = Set(eventTypesArray)

        showPreEventTasksDays = try container.decode(Int.self, forKey: .showPreEventTasksDays)
        showPostEventTasksDays = try container.decode(Int.self, forKey: .showPostEventTasksDays)
        enableNotifications = try container.decode(Bool.self, forKey: .enableNotifications)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(mode, forKey: .mode)
        try container.encode(Array(enabledEventTypes), forKey: .enabledEventTypes)
        try container.encode(showPreEventTasksDays, forKey: .showPreEventTasksDays)
        try container.encode(showPostEventTasksDays, forKey: .showPostEventTasksDays)
        try container.encode(enableNotifications, forKey: .enableNotifications)
    }
}

// MARK: - Event Task Manager

/// Manages all event tasks across the app
class EventTaskManager: ObservableObject {
    static let shared = EventTaskManager()

    @Published private(set) var eventTasks: [String: EventTasks] = [:]
    @Published var settings: TaskGenerationSettings = .default

    private let userDefaults = UserDefaults.standard
    private let tasksKey = "eventTasks"
    private let settingsKey = "taskGenerationSettings"

    private init() {
        loadFromStorage()
    }

    // MARK: - Task Operations

    /// Get tasks for a specific event
    func getTasks(for eventId: String) -> EventTasks? {
        return eventTasks[eventId]
    }

    /// Get pending task count for an event (for badge display)
    func getPendingTaskCount(for eventId: String) -> Int {
        return eventTasks[eventId]?.pendingTasks.count ?? 0
    }

    /// Add a task to an event
    func addTask(_ task: EventTask, to eventId: String) {
        if var tasks = eventTasks[eventId] {
            tasks.tasks.append(task)
            eventTasks[eventId] = tasks
        } else {
            // Create new EventTasks container
            let eventType = EventType.generic // Will be updated when ensureTasksExist is called
            eventTasks[eventId] = EventTasks(
                eventId: eventId,
                tasks: [task],
                eventType: eventType,
                autoGenerated: false
            )
        }
        saveToStorage()
    }

    /// Toggle task completion
    func toggleTaskCompletion(_ taskId: UUID, in eventId: String) {
        guard var tasks = eventTasks[eventId] else { return }

        if let index = tasks.tasks.firstIndex(where: { $0.id == taskId }) {
            var task = tasks.tasks[index]
            task.isCompleted.toggle()
            task.completedAt = task.isCompleted ? Date() : nil
            tasks.tasks[index] = task
            eventTasks[eventId] = tasks
            saveToStorage()
        }
    }

    /// Delete a task
    func deleteTask(_ taskId: UUID, from eventId: String) {
        guard var tasks = eventTasks[eventId] else { return }

        tasks.tasks.removeAll { $0.id == taskId }
        eventTasks[eventId] = tasks
        saveToStorage()
    }

    /// Delete all tasks for an event
    func deleteTasks(for eventId: String) {
        eventTasks.removeValue(forKey: eventId)
        saveToStorage()
    }

    // MARK: - Auto-Generation

    /// Ensure tasks exist for an event (auto-generate if needed)
    func ensureTasksExist(for event: UnifiedEvent) {
        // If tasks already exist, do nothing
        guard eventTasks[event.id] == nil else { return }

        // Check settings
        guard settings.mode != .manual else { return }

        // Detect event type
        let eventType = EventType.detect(from: event.title, description: event.description)

        // Check if this event type is enabled
        guard settings.enabledEventTypes.contains(eventType) else { return }

        // Get template tasks
        let templateTasks = TaskTemplate.getTasks(for: eventType)

        guard !templateTasks.isEmpty else { return }

        // Auto-create or just mark for suggestion
        if settings.mode == .autoCreate {
            eventTasks[event.id] = EventTasks(
                eventId: event.id,
                tasks: templateTasks,
                eventType: eventType,
                autoGenerated: true
            )
            saveToStorage()
        }
        // For .suggest mode, AISuggestionsView will handle showing suggestions
    }

    // MARK: - Settings

    /// Update task generation settings
    func updateSettings(_ newSettings: TaskGenerationSettings) {
        settings = newSettings
        saveSettingsToStorage()
    }

    /// Toggle event type in settings
    func toggleEventType(_ eventType: EventType) {
        if settings.enabledEventTypes.contains(eventType) {
            settings.enabledEventTypes.remove(eventType)
        } else {
            settings.enabledEventTypes.insert(eventType)
        }
        saveSettingsToStorage()
    }

    // MARK: - Persistence

    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(eventTasks) {
            userDefaults.set(encoded, forKey: tasksKey)
        }
    }

    private func loadFromStorage() {
        if let data = userDefaults.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([String: EventTasks].self, from: data) {
            eventTasks = decoded
        }

        if let settingsData = userDefaults.data(forKey: settingsKey),
           let decodedSettings = try? JSONDecoder().decode(TaskGenerationSettings.self, from: settingsData) {
            settings = decodedSettings
        }
    }

    private func saveSettingsToStorage() {
        if let encoded = try? JSONEncoder().encode(settings) {
            userDefaults.set(encoded, forKey: settingsKey)
        }
    }
}

// MARK: - Task Badge View

/// Small badge showing pending task count for an event
struct TaskBadgeView: View {
    let count: Int

    var body: some View {
        if count > 0 {
            HStack(spacing: 4) {
                Image(systemName: "checklist")
                    .font(.system(size: 10, weight: .semibold))
                Text("\(count)")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(badgeColor)
            )
        }
    }

    private var badgeColor: Color {
        if count >= 5 {
            return .red
        } else if count >= 3 {
            return .orange
        } else {
            return .blue
        }
    }
}

// MARK: - Event Tasks Tab View

/// Tasks tab within EventShareView - manages event-specific tasks
struct EventTasksTabView: View {
    let event: UnifiedEvent
    @ObservedObject var fontManager: FontManager

    @StateObject private var taskManager = EventTaskManager.shared
    @State private var showingAddTask = false
    @State private var showingAISuggestions = false

    private var eventTasks: EventTasks? {
        taskManager.getTasks(for: event.id)
    }

    private var eventType: EventType {
        EventType.detect(from: event.title, description: event.description)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Event Type Header
                eventTypeHeader

                // Progress if tasks exist
                if let tasks = eventTasks, !tasks.tasks.isEmpty {
                    progressSection(tasks: tasks)
                }

                // Tasks List or Empty State
                if let tasks = eventTasks, !tasks.tasks.isEmpty {
                    tasksListSection(tasks: tasks)
                } else {
                    emptyStateSection
                }

                // Action Buttons
                actionButtons
            }
            .padding()
        }
        .onAppear {
            // Auto-generate tasks if needed
            taskManager.ensureTasksExist(for: event)
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(event: event, fontManager: fontManager) { newTask in
                taskManager.addTask(newTask, to: event.id)
            }
        }
        .sheet(isPresented: $showingAISuggestions) {
            AISuggestionsView(event: event, fontManager: fontManager) { selectedTasks in
                for task in selectedTasks {
                    taskManager.addTask(task, to: event.id)
                }
            }
        }
    }

    // MARK: - Event Type Header

    private var eventTypeHeader: some View {
        HStack {
            Image(systemName: eventType.icon)
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 4) {
                Text(eventType.rawValue)
                    .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.secondary)

                Text(formatEventTime())
                    .dynamicFont(size: 12, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Progress Section

    private func progressSection(tasks: EventTasks) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Task Progress")
                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)

                Spacer()

                Text("\(tasks.completedTasks.count) of \(tasks.tasks.count)")
                    .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: tasks.completionPercentage, total: 100)
                .tint(.blue)

            if tasks.completionPercentage == 100 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All tasks complete!")
                        .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)
                        .foregroundColor(.green)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    // MARK: - Tasks List

    private func tasksListSection(tasks: EventTasks) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tasks")
                .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)

            ForEach(tasks.tasks) { task in
                TaskRow(task: task, fontManager: fontManager) {
                    taskManager.toggleTaskCompletion(task.id, in: event.id)
                } onDelete: {
                    taskManager.deleteTask(task.id, from: event.id)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Tasks Yet")
                .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            Text("Add tasks to prepare for this event")
                .dynamicFont(size: 14, fontManager: fontManager)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // AI Suggestions Button
            Button(action: { showingAISuggestions = true }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Get AI Task Suggestions")
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }

            // Manual Add Task Button
            Button(action: { showingAddTask = true }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Task Manually")
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                }
                .foregroundColor(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Helpers

    private func formatEventTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        if event.isAllDay {
            formatter.timeStyle = .none
            return formatter.string(from: event.startDate)
        } else {
            return "\(formatter.string(from: event.startDate)) - \(formatTime(event.endDate))"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Task Row

struct TaskRow: View {
    let task: EventTask
    @ObservedObject var fontManager: FontManager
    var onToggle: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }

            // Task Content
            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .overlay(
                        GeometryReader { geometry in
                            if task.isCompleted {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(.secondary)
                                    .offset(y: geometry.size.height / 2)
                            }
                        }
                    )

                if let description = task.description {
                    Text(description)
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }

                // Task Metadata
                HStack(spacing: 8) {
                    // Priority Badge
                    HStack(spacing: 4) {
                        Image(systemName: task.priority.icon)
                            .font(.system(size: 10))
                        Text(task.priority.rawValue)
                            .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                    }
                    .foregroundColor(priorityColor(task.priority))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(priorityColor(task.priority).opacity(0.15))
                    .cornerRadius(6)

                    // Category
                    HStack(spacing: 4) {
                        Image(systemName: task.category.icon)
                            .font(.system(size: 10))
                        Text(task.category.rawValue)
                            .dynamicFont(size: 12, fontManager: fontManager)
                    }
                    .foregroundColor(.secondary)

                    // Timing
                    Text(task.timing.description)
                        .dynamicFont(size: 12, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// MARK: - Event Details Tab View

/// Details tab within EventShareView - fully editable event details matching EditEventView
struct EventDetailsTabView: View {
    let event: UnifiedEvent
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage: Bool = false

    var body: some View {
        Form {
            Section("Event Details") {
                TextField("Title", text: $title)
                    .dynamicFont(size: 17, fontManager: fontManager)

                TextField("Location", text: $location)
                    .dynamicFont(size: 17, fontManager: fontManager)
            }

            Section("Date & Time") {
                Toggle("All Day", isOn: $isAllDay)
                    .dynamicFont(size: 17, fontManager: fontManager)

                if !isAllDay {
                    DatePicker("Starts", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        .dynamicFont(size: 17, fontManager: fontManager)

                    DatePicker("Ends", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                        .dynamicFont(size: 17, fontManager: fontManager)
                } else {
                    DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                        .dynamicFont(size: 17, fontManager: fontManager)

                    DatePicker("Ends", selection: $endDate, displayedComponents: .date)
                        .dynamicFont(size: 17, fontManager: fontManager)
                }
            }

            Section("Notes") {
                TextEditor(text: $notes)
                    .dynamicFont(size: 17, fontManager: fontManager)
                    .frame(minHeight: 100)
            }

            Section("Calendar Source") {
                HStack {
                    Text("Source:")
                        .dynamicFont(size: 17, fontManager: fontManager)

                    Spacer()

                    Text(event.sourceLabel)
                        .dynamicFont(size: 17, weight: .medium, fontManager: fontManager)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(6)
                }
            }

            // Save Button Section
            Section {
                Button(action: {
                    saveEvent()
                }) {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Save Changes")
                                .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                        }
                        Spacer()
                    }
                }
                .disabled(title.isEmpty || isLoading)
            }

            if let errorMessage = errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .dynamicFont(size: 14, fontManager: fontManager)
                }
            }

            if showSuccessMessage {
                Section {
                    Text("✓ Event updated successfully")
                        .foregroundColor(.green)
                        .dynamicFont(size: 14, fontManager: fontManager)
                }
            }
        }
        .onAppear {
            loadEventData()
        }
        .onChange(of: startDate) { newValue in
            if endDate <= newValue {
                endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
            }
        }
    }

    // MARK: - Helper Methods

    private func loadEventData() {
        title = event.title
        location = event.location ?? ""
        notes = event.description ?? ""
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
    }

    private func saveEvent() {
        guard !title.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        showSuccessMessage = false

        let updatedEvent = UnifiedEvent(
            id: event.id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location.isEmpty ? nil : location,
            description: notes.isEmpty ? nil : notes,
            isAllDay: isAllDay,
            source: event.source,
            organizer: event.organizer,
            originalEvent: event.originalEvent
        )

        updateEventInCalendar(updatedEvent) { success, error in
            DispatchQueue.main.async {
                isLoading = false

                if success {
                    // Refresh calendar data to reflect changes
                    calendarManager.refreshAllCalendars()
                    showSuccessMessage = true

                    // Hide success message after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        showSuccessMessage = false
                    }
                } else {
                    errorMessage = error ?? "Failed to update event"
                }
            }
        }
    }

    private func updateEventInCalendar(_ updatedEvent: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        switch updatedEvent.source {
        case .ios:
            updateIOSEvent(updatedEvent, completion: completion)
        case .google:
            updateGoogleEvent(updatedEvent, completion: completion)
        case .outlook:
            updateOutlookEvent(updatedEvent, completion: completion)
        }
    }

    private func updateIOSEvent(_ updatedEvent: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        guard let ekEvent = updatedEvent.originalEvent as? EKEvent else {
            completion(false, "Could not find original iOS event")
            return
        }

        // Update the EKEvent with new data
        ekEvent.title = updatedEvent.title
        ekEvent.location = updatedEvent.location
        ekEvent.notes = updatedEvent.description
        ekEvent.startDate = updatedEvent.startDate
        ekEvent.endDate = updatedEvent.endDate
        ekEvent.isAllDay = updatedEvent.isAllDay

        do {
            try calendarManager.eventStore.save(ekEvent, span: .thisEvent)
            print("✅ Successfully updated iOS event: \(updatedEvent.title)")
            completion(true, nil)
        } catch {
            print("❌ Failed to update iOS event: \(error)")
            completion(false, error.localizedDescription)
        }
    }

    private func updateGoogleEvent(_ updatedEvent: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        // Convert UnifiedEvent to GoogleEvent for updating
        let googleEvent = GoogleEvent(
            id: updatedEvent.id,
            title: updatedEvent.title,
            startDate: updatedEvent.startDate,
            endDate: updatedEvent.endDate,
            location: updatedEvent.location,
            description: updatedEvent.description,
            calendarId: "primary", // Default calendar ID
            organizer: nil
        )

        calendarManager.googleCalendarManager?.updateEvent(googleEvent) { success, error in
            completion(success, error)
        }
    }

    private func updateOutlookEvent(_ updatedEvent: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        // Convert UnifiedEvent to OutlookEvent for updating
        let outlookEvent = OutlookEvent(
            id: updatedEvent.id,
            title: updatedEvent.title,
            startDate: updatedEvent.startDate,
            endDate: updatedEvent.endDate,
            location: updatedEvent.location,
            description: updatedEvent.description,
            calendarId: "primary-calendar", // Default calendar ID
            organizer: nil
        )

        calendarManager.outlookCalendarManager?.updateEvent(outlookEvent) { success, error in
            completion(success, error)
        }
    }
}

// MARK: - Add Task View

/// View for manually adding a task to an event
struct AddTaskView: View {
    let event: UnifiedEvent
    @ObservedObject var fontManager: FontManager
    var onSave: (EventTask) -> Void

    @Environment(\.dismiss) var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var priority: TaskPriority = .medium
    @State private var category: TaskCategory = .preparation
    @State private var timingSelection: TimingType = .before
    @State private var hoursBeforeAfter: Int = 24
    @State private var estimatedMinutes: String = ""

    enum TimingType: String, CaseIterable {
        case before = "Before Event"
        case during = "During Event"
        case after = "After Event"
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task Details")) {
                    TextField("Task Title", text: $title)
                        .dynamicFont(size: 16, fontManager: fontManager)

                    TextField("Description (optional)", text: $description)
                        .dynamicFont(size: 16, fontManager: fontManager)
                }

                Section(header: Text("Priority")) {
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priority.icon)
                                Text(priority.rawValue)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }

                Section(header: Text("Timing")) {
                    Picker("When", selection: $timingSelection) {
                        ForEach(TimingType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    if timingSelection != .during {
                        HStack {
                            Stepper(value: $hoursBeforeAfter, in: 1...168) {
                                HStack {
                                    Text("\(hoursBeforeAfter) hours")
                                    if hoursBeforeAfter >= 24 {
                                        Text("(\(hoursBeforeAfter / 24) day\(hoursBeforeAfter / 24 == 1 ? "" : "s"))")
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section(header: Text("Estimated Time (optional)")) {
                    TextField("Minutes", text: $estimatedMinutes)
                        .keyboardType(.numberPad)
                        .dynamicFont(size: 16, fontManager: fontManager)
                }
            }
            .navigationTitle("Add Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private func saveTask() {
        let timing: TaskTiming
        switch timingSelection {
        case .before:
            timing = .before(hours: hoursBeforeAfter)
        case .during:
            timing = .during
        case .after:
            timing = .after(hours: hoursBeforeAfter)
        }

        let task = EventTask(
            title: title,
            description: description.isEmpty ? nil : description,
            isCompleted: false,
            priority: priority,
            category: category,
            timing: timing,
            estimatedMinutes: Int(estimatedMinutes)
        )

        onSave(task)
        dismiss()
    }
}

// MARK: - AI Suggestions View

/// View for displaying and selecting AI-suggested tasks
struct AISuggestionsView: View {
    let event: UnifiedEvent
    @ObservedObject var fontManager: FontManager
    var onSelect: ([EventTask]) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedTasks: Set<UUID> = []
    @State private var suggestedTasks: [EventTask] = []
    @State private var isLoading: Bool = true

    private var eventType: EventType {
        EventType.detect(from: event.title, description: event.description)
    }

    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    loadingView
                } else if suggestedTasks.isEmpty {
                    emptyView
                } else {
                    suggestionsListView
                }
            }
            .navigationTitle("AI Task Suggestions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Selected") {
                        let selected = suggestedTasks.filter { selectedTasks.contains($0.id) }
                        onSelect(selected)
                        dismiss()
                    }
                    .disabled(selectedTasks.isEmpty)
                }
            }
            .onAppear {
                loadSuggestions()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)

            Text("Analyzing event for relevant tasks...")
                .dynamicFont(size: 16, fontManager: fontManager)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkles.rectangle.stack")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No Suggestions Available")
                .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)

            Text("We couldn't generate specific tasks for this event type")
                .dynamicFont(size: 14, fontManager: fontManager)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: - Suggestions List

    private var suggestionsListView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: eventType.icon)
                        .foregroundColor(.purple)
                    Text(eventType.rawValue)
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                }

                Text("Select the tasks you want to add")
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)

                Button(action: selectAll) {
                    HStack {
                        Image(systemName: selectedTasks.count == suggestedTasks.count ? "checkmark.square.fill" : "square")
                        Text(selectedTasks.count == suggestedTasks.count ? "Deselect All" : "Select All")
                            .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)
                    }
                    .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
            .padding()
            .background(Color(.systemGray6))

            // Task List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(suggestedTasks) { task in
                        SuggestionRow(
                            task: task,
                            isSelected: selectedTasks.contains(task.id),
                            fontManager: fontManager
                        ) {
                            toggleSelection(task.id)
                        }
                    }
                }
                .padding()
            }
        }
    }

    // MARK: - Actions

    private func loadSuggestions() {
        isLoading = true

        // Get template-based suggestions
        suggestedTasks = TaskTemplate.getTasks(for: eventType)

        // Simulate loading delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isLoading = false
            // Auto-select all by default
            selectedTasks = Set(suggestedTasks.map { $0.id })
        }
    }

    private func toggleSelection(_ id: UUID) {
        if selectedTasks.contains(id) {
            selectedTasks.remove(id)
        } else {
            selectedTasks.insert(id)
        }
    }

    private func selectAll() {
        if selectedTasks.count == suggestedTasks.count {
            selectedTasks.removeAll()
        } else {
            selectedTasks = Set(suggestedTasks.map { $0.id })
        }
    }
}

// MARK: - Suggestion Row

struct SuggestionRow: View {
    let task: EventTask
    let isSelected: Bool
    @ObservedObject var fontManager: FontManager
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Checkbox
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .gray)

                // Task Content
                VStack(alignment: .leading, spacing: 6) {
                    Text(task.title)
                        .dynamicFont(size: 16, fontManager: fontManager)
                        .foregroundColor(.primary)

                    if let description = task.description {
                        Text(description)
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }

                    // Metadata
                    HStack(spacing: 8) {
                        // Priority
                        HStack(spacing: 4) {
                            Image(systemName: task.priority.icon)
                                .font(.system(size: 10))
                            Text(task.priority.rawValue)
                                .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                        }
                        .foregroundColor(priorityColor(task.priority))

                        // Category
                        HStack(spacing: 4) {
                            Image(systemName: task.category.icon)
                                .font(.system(size: 10))
                            Text(task.category.rawValue)
                                .dynamicFont(size: 12, fontManager: fontManager)
                        }
                        .foregroundColor(.secondary)

                        // Timing
                        Text(task.timing.description)
                            .dynamicFont(size: 12, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }
}

// MARK: - Task Settings View

/// Settings view for Event Tasks configuration
struct TaskSettingsView: View {
    @ObservedObject var fontManager: FontManager
    @StateObject private var taskManager = EventTaskManager.shared

    var body: some View {
        Form {
            // Task Generation Mode
            Section(header: Text("Task Generation")) {
                Picker("Mode", selection: Binding(
                    get: { taskManager.settings.mode },
                    set: { newMode in
                        var settings = taskManager.settings
                        settings.mode = newMode
                        taskManager.updateSettings(settings)
                    }
                )) {
                    ForEach(TaskGenerationMode.allCases, id: \.self) { mode in
                        VStack(alignment: .leading) {
                            Text(mode.rawValue)
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                        .tag(mode)
                    }
                }

                Text(taskManager.settings.mode.description)
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }

            // Event Type Templates
            Section(header: Text("Event Type Templates")) {
                ForEach(EventType.allCases, id: \.self) { eventType in
                    Toggle(isOn: Binding(
                        get: { taskManager.settings.enabledEventTypes.contains(eventType) },
                        set: { _ in taskManager.toggleEventType(eventType) }
                    )) {
                        HStack {
                            Image(systemName: eventType.icon)
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text(eventType.rawValue)
                                .dynamicFont(size: 16, fontManager: fontManager)
                        }
                    }
                }
            }

            // Timing Preferences
            Section(header: Text("Task Visibility")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Show pre-event tasks")
                        .dynamicFont(size: 16, fontManager: fontManager)

                    Stepper(value: Binding(
                        get: { taskManager.settings.showPreEventTasksDays },
                        set: { newValue in
                            var settings = taskManager.settings
                            settings.showPreEventTasksDays = newValue
                            taskManager.updateSettings(settings)
                        }
                    ), in: 1...30) {
                        Text("\(taskManager.settings.showPreEventTasksDays) day\(taskManager.settings.showPreEventTasksDays == 1 ? "" : "s") before")
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Show post-event tasks")
                        .dynamicFont(size: 16, fontManager: fontManager)

                    Stepper(value: Binding(
                        get: { taskManager.settings.showPostEventTasksDays },
                        set: { newValue in
                            var settings = taskManager.settings
                            settings.showPostEventTasksDays = newValue
                            taskManager.updateSettings(settings)
                        }
                    ), in: 1...14) {
                        Text("\(taskManager.settings.showPostEventTasksDays) day\(taskManager.settings.showPostEventTasksDays == 1 ? "" : "s") after")
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Notifications
            Section(header: Text("Notifications")) {
                Toggle(isOn: Binding(
                    get: { taskManager.settings.enableNotifications },
                    set: { newValue in
                        var settings = taskManager.settings
                        settings.enableNotifications = newValue
                        taskManager.updateSettings(settings)
                    }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Task Reminders")
                            .dynamicFont(size: 16, fontManager: fontManager)
                        Text("Get notified about incomplete tasks")
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Info Section
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("About Event Tasks")
                            .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                    }

                    Text("Event Tasks help you prepare for upcoming events with smart, context-aware checklists.")
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    Text("Tasks are automatically suggested based on event type (medical appointments, flights, interviews, etc.) and can be customized to your needs.")
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Event Tasks")
        .navigationBarTitleDisplayMode(.inline)
    }
}
