import SwiftUI
import Foundation
import Combine
import EventKit
import CoreLocation
import MapKit

// MARK: - Event Task Models

/// Subtask model
struct EventSubtask: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
    }
}

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
    var dueDate: Date?
    var subtasks: [EventSubtask]

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
        completedAt: Date? = nil,
        dueDate: Date? = nil,
        subtasks: [EventSubtask] = []
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
        self.dueDate = dueDate
        self.subtasks = subtasks
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

    /// Update an existing task
    func updateTask(_ updatedTask: EventTask, for eventId: String) {
        guard var tasks = eventTasks[eventId] else { return }

        if let index = tasks.tasks.firstIndex(where: { $0.id == updatedTask.id }) {
            tasks.tasks[index] = updatedTask
            eventTasks[eventId] = tasks
            saveToStorage()
        }
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

    // Task entry fields
    @State private var newTaskTitle: String = ""
    @State private var newTaskDescription: String = ""
    @State private var newTaskDueDate: Date = Date()
    @State private var newTaskPriority: TaskPriority = .medium
    @State private var showTaskDetails: Bool = false
    @State private var showDatePicker: Bool = false
    @FocusState private var isTaskFieldFocused: Bool

    // Task edit sheet
    @State private var showingTaskEdit = false
    @State private var selectedTask: EventTask?

    private var eventTasks: EventTasks? {
        taskManager.getTasks(for: event.id)
    }

    private var eventType: EventType {
        EventType.detect(from: event.title, description: event.description)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Tasks List
                ScrollView {
                    VStack(spacing: 12) {
                        // Event Type Header (compact)
                        eventTypeHeaderCompact

                        // AI Suggestion Button (at top)
                        aiSuggestionButton

                        // Tasks List
                        if let tasks = eventTasks, !tasks.tasks.isEmpty {
                            tasksListSection(tasks: tasks)
                        } else {
                            emptyStateSection
                        }
                    }
                    .padding()
                    .padding(.bottom, 80) // Space for floating button
                }

                // Inline Task Entry (appears when adding)
                if showingAddTask {
                    taskEntryView
                }
            }

            // Floating Plus Button
            if !showingAddTask {
                floatingPlusButton
            }
        }
        .onAppear {
            // Auto-generate tasks if needed
            taskManager.ensureTasksExist(for: event)
        }
        .sheet(isPresented: $showingAISuggestions) {
            AISuggestionsSheetView(event: event, fontManager: fontManager) { selectedTasks in
                for task in selectedTasks {
                    taskManager.addTask(task, to: event.id)
                }
            }
        }
        .sheet(isPresented: $showingTaskEdit) {
            if let selectedTask = selectedTask {
                TaskEditSheet(
                    task: selectedTask,
                    fontManager: fontManager,
                    eventId: event.id
                )
            }
        }
    }

    // MARK: - Event Type Header (Compact)

    private var eventTypeHeaderCompact: some View {
        HStack {
            Image(systemName: eventType.icon)
                .font(.body)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                    .lineLimit(1)

                Text(formatEventTime())
                    .dynamicFont(size: 11, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
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
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTask = task
                    showingTaskEdit = true
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

    // MARK: - AI Suggestion Button

    private var aiSuggestionButton: some View {
        Button(action: { showingAISuggestions = true }) {
            HStack {
                Image(systemName: "sparkles")
                Text("AI Task Suggestions")
                    .dynamicFont(size: 15, weight: .medium, fontManager: fontManager)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
            }
            .foregroundColor(.purple)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.purple.opacity(0.1))
            .cornerRadius(10)
        }
    }

    // MARK: - Floating Plus Button

    private var floatingPlusButton: some View {
        Button(action: {
            showingAddTask = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTaskFieldFocused = true
            }
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Task Entry View (Google Tasks Style)

    private var taskEntryView: some View {
        VStack(spacing: 0) {
            // Task Title Field
            HStack(alignment: .top, spacing: 12) {
                Button(action: {
                    // Save task
                    saveNewTask()
                }) {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
                .padding(.top, 12)

                TextField("New Task", text: $newTaskTitle)
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .focused($isTaskFieldFocused)
                    .padding(.top, 12)
            }
            .padding(.horizontal, 16)

            // Task Details (expandable)
            if showTaskDetails {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    TextEditor(text: $newTaskDescription)
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .frame(minHeight: 60, maxHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                .padding(.horizontal, 16)
            }

            // Date Picker Sheet
            if showDatePicker {
                VStack(spacing: 0) {
                    Divider()
                    DatePicker("Due Date", selection: $newTaskDueDate, displayedComponents: [.date, .hourAndMinute])
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .padding()
                }
            }

            // Action Bar
            HStack(spacing: 20) {
                // Add Details Button
                Button(action: {
                    showTaskDetails.toggle()
                }) {
                    Image(systemName: showTaskDetails ? "note.text.badge.plus" : "note.text")
                        .font(.system(size: 20))
                        .foregroundColor(showTaskDetails ? .blue : .gray)
                }

                // Date/Time Button
                Button(action: {
                    showDatePicker.toggle()
                }) {
                    Image(systemName: showDatePicker ? "calendar.badge.clock" : "calendar")
                        .font(.system(size: 20))
                        .foregroundColor(showDatePicker ? .blue : .gray)
                }

                // Priority Button
                Menu {
                    Button(action: { newTaskPriority = .high }) {
                        Label("High", systemImage: "exclamationmark.3")
                    }
                    Button(action: { newTaskPriority = .medium }) {
                        Label("Medium", systemImage: "exclamationmark.2")
                    }
                    Button(action: { newTaskPriority = .low }) {
                        Label("Low", systemImage: "exclamationmark")
                    }
                } label: {
                    Image(systemName: priorityIcon(newTaskPriority))
                        .font(.system(size: 20))
                        .foregroundColor(priorityColor(newTaskPriority))
                }

                Spacer()

                // Save Button
                Button(action: {
                    saveNewTask()
                }) {
                    Text("Save")
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(newTaskTitle.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(20)
                }
                .disabled(newTaskTitle.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.systemGray4)),
            alignment: .top
        )
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

    private func saveNewTask() {
        guard !newTaskTitle.isEmpty else { return }

        let timing = calculateTaskTiming()
        let category = detectTaskCategory()

        let newTask = EventTask(
            title: newTaskTitle,
            description: newTaskDescription.isEmpty ? nil : newTaskDescription,
            isCompleted: false,
            priority: newTaskPriority,
            category: category,
            timing: timing,
            estimatedMinutes: nil
        )

        taskManager.addTask(newTask, to: event.id)

        // Reset form
        newTaskTitle = ""
        newTaskDescription = ""
        newTaskDueDate = Date()
        newTaskPriority = .medium
        showTaskDetails = false
        showDatePicker = false
        showingAddTask = false
    }

    private func calculateTaskTiming() -> TaskTiming {
        let timeUntilEvent = event.startDate.timeIntervalSince(newTaskDueDate)
        let hoursUntilEvent = timeUntilEvent / 3600

        if hoursUntilEvent > 0 {
            return .before(hours: Int(hoursUntilEvent))
        } else if hoursUntilEvent < -2 {
            return .after(hours: Int(-hoursUntilEvent))
        } else {
            return .during
        }
    }

    private func detectTaskCategory() -> TaskCategory {
        let titleLower = newTaskTitle.lowercased()

        if titleLower.contains("review") || titleLower.contains("prepare") || titleLower.contains("research") {
            return .preparation
        } else if titleLower.contains("email") || titleLower.contains("call") || titleLower.contains("contact") {
            return .communication
        } else if titleLower.contains("book") || titleLower.contains("reserve") || titleLower.contains("order") {
            return .logistics
        } else if titleLower.contains("document") || titleLower.contains("report") || titleLower.contains("notes") {
            return .documents
        } else {
            return .preparation
        }
    }

    private func priorityIcon(_ priority: TaskPriority) -> String {
        switch priority {
        case .high: return "exclamationmark.3"
        case .medium: return "exclamationmark.2"
        case .low: return "exclamationmark"
        }
    }

    private func priorityColor(_ priority: TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .gray
        }
    }

    // Helper function to determine calendar source icon
    private func calendarSourceIcon(for calendar: EKCalendar) -> String {
        let sourceTitle = calendar.source.title.lowercased()

        if sourceTitle.contains("google") || sourceTitle.contains("gmail") {
            return "globe"
        } else if sourceTitle.contains("outlook") || sourceTitle.contains("microsoft") || sourceTitle.contains("exchange") {
            return "envelope"
        } else {
            return "calendar"
        }
    }

    // Helper function to determine calendar source color
    private func calendarSourceColor(for calendar: EKCalendar) -> Color {
        let sourceTitle = calendar.source.title.lowercased()

        if sourceTitle.contains("google") || sourceTitle.contains("gmail") {
            return Color(red: 66/255, green: 133/255, blue: 244/255) // Google Blue
        } else if sourceTitle.contains("outlook") || sourceTitle.contains("microsoft") || sourceTitle.contains("exchange") {
            return Color(red: 0/255, green: 120/255, blue: 212/255) // Outlook Blue
        } else {
            return Color(red: 255/255, green: 45/255, blue: 85/255) // iOS Calendar Red
        }
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

// MARK: - Task Edit Sheet

/// Wrapper view for TaskEditView that manages state for sheet presentation
struct TaskEditSheet: View {
    let task: EventTask
    @ObservedObject var fontManager: FontManager
    let eventId: String

    @StateObject private var taskManager = EventTaskManager.shared
    @State private var editableTask: EventTask
    @Environment(\.dismiss) private var dismiss

    init(task: EventTask, fontManager: FontManager, eventId: String) {
        self.task = task
        self.fontManager = fontManager
        self.eventId = eventId
        _editableTask = State(initialValue: task)
    }

    var body: some View {
        TaskEditView(
            task: $editableTask,
            fontManager: fontManager,
            onSave: { updatedTask in
                taskManager.updateTask(updatedTask, for: eventId)
                dismiss()
            },
            onDelete: {
                taskManager.deleteTask(task.id, from: eventId)
                dismiss()
            }
        )
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

    // New fields for comprehensive editing
    @State private var selectedCalendar: EKCalendar?
    @State private var availableCalendars: [EKCalendar] = []
    @State private var eventURL: String = ""
    @State private var recurrenceRule: EKRecurrenceRule?
    @State private var showRecurrencePicker: Bool = false
    @State private var attendees: [String] = []
    @State private var newAttendee: String = ""
    @State private var showAddAttendee: Bool = false
    @State private var attachmentURLs: [URL] = []
    @State private var showAttachmentPicker: Bool = false
    @State private var structuredLocation: CLLocation?
    @State private var useCustomColor: Bool = false
    @State private var customColor: Color = EventColorManager.predefinedColors[0]
    @StateObject private var colorManager = EventColorManager.shared
    @State private var showingDeleteConfirmation: Bool = false
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Form {
            Section("Event Details") {
                TextField("Title", text: $title)
                    .dynamicFont(size: 17, fontManager: fontManager)

                // Location Field with Map Preview
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Location", text: $location)
                            .dynamicFont(size: 17, fontManager: fontManager)

                        if event.source == .ios {
                            Button(action: {
                                geocodeLocation()
                            }) {
                                Image(systemName: "location.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }

                    // Small Map Preview (like iOS Calendar)
                    if let geoLocation = structuredLocation {
                        Button(action: {
                            openInMaps()
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                // Map preview using Map from MapKit
                                Map(coordinateRegion: .constant(MKCoordinateRegion(
                                    center: geoLocation.coordinate,
                                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                                )), annotationItems: [MapLocation(coordinate: geoLocation.coordinate)]) { location in
                                    MapMarker(coordinate: location.coordinate, tint: .red)
                                }
                                .frame(height: 120)
                                .cornerRadius(8)
                                .disabled(true)

                                // "Open in Maps" indicator
                                HStack(spacing: 4) {
                                    Image(systemName: "map.fill")
                                        .font(.system(size: 10))
                                    Text("Tap to open")
                                        .dynamicFont(size: 10, fontManager: fontManager)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.9))
                                .cornerRadius(4)
                                .padding(8)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            // Calendar Selection (iOS events only)
            if event.source == .ios, !availableCalendars.isEmpty {
                Section("Calendar") {
                    NavigationLink {
                        List {
                            ForEach(availableCalendars, id: \.calendarIdentifier) { calendar in
                                Button {
                                    selectedCalendar = calendar
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: calendarSourceIcon(for: calendar))
                                            .font(.system(size: 20))
                                            .foregroundStyle(calendarSourceColor(for: calendar))

                                        Circle()
                                            .fill(Color(cgColor: calendar.cgColor))
                                            .frame(width: 12, height: 12)

                                        Text(calendar.title)
                                            .dynamicFont(size: 17, fontManager: fontManager)
                                            .foregroundColor(.primary)

                                        Spacer()

                                        if selectedCalendar?.calendarIdentifier == calendar.calendarIdentifier {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .navigationTitle("Select Calendar")
                        .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        HStack {
                            Text("Calendar")
                                .dynamicFont(size: 17, fontManager: fontManager)
                            Spacer()
                            if let selected = selectedCalendar {
                                HStack(spacing: 8) {
                                    Image(systemName: calendarSourceIcon(for: selected))
                                        .font(.system(size: 16))
                                        .foregroundStyle(calendarSourceColor(for: selected))

                                    Circle()
                                        .fill(Color(cgColor: selected.cgColor))
                                        .frame(width: 12, height: 12)

                                    Text(selected.title)
                                        .dynamicFont(size: 17, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section {
                Toggle("Use Custom Color", isOn: $useCustomColor)
                    .dynamicFont(size: 17, fontManager: fontManager)
                    .onChange(of: useCustomColor) { newValue in
                        // Update immediately for live preview
                        colorManager.setUseCustomColor(newValue, for: event.id)
                        if !newValue {
                            colorManager.removeCustomColor(for: event.id)
                        }
                    }

                if useCustomColor {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Event Color")
                            .dynamicFont(size: 13, weight: .semibold, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        // Predefined colors grid
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                            ForEach(EventColorManager.predefinedColors.indices, id: \.self) { index in
                                let color = EventColorManager.predefinedColors[index]
                                Button {
                                    customColor = color
                                    // Update immediately for live preview
                                    colorManager.setCustomColor(color, for: event.id)
                                } label: {
                                    ZStack {
                                        Circle()
                                            .fill(color)
                                            .frame(width: 44, height: 44)

                                        if customColor.toHex() == color.toHex() {
                                            Image(systemName: "checkmark")
                                                .foregroundColor(.white)
                                                .font(.system(size: 16, weight: .bold))
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                } else {
                    HStack {
                        Text("Using calendar color")
                            .dynamicFont(size: 15, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Spacer()

                        if let calendar = selectedCalendar {
                            Circle()
                                .fill(Color(cgColor: calendar.cgColor))
                                .frame(width: 24, height: 24)
                        }
                    }
                }
            } header: {
                Text("Event Card Color")
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

            // URL Section
            Section("URL") {
                TextField("Event URL", text: $eventURL)
                    .dynamicFont(size: 17, fontManager: fontManager)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            // Recurrence/Repeat Section (iOS events only)
            if event.source == .ios {
                Section("Repeat") {
                    if let rule = recurrenceRule {
                        HStack {
                            Text(recurrenceRuleDescription(rule))
                                .dynamicFont(size: 17, fontManager: fontManager)
                            Spacer()
                            Button("Edit") {
                                showRecurrencePicker = true
                            }
                            .dynamicFont(size: 17, fontManager: fontManager)
                        }
                    } else {
                        Button("Add Repeat Rule") {
                            showRecurrencePicker = true
                        }
                        .dynamicFont(size: 17, fontManager: fontManager)
                    }
                }
                .sheet(isPresented: $showRecurrencePicker) {
                    RecurrencePickerView(
                        recurrenceRule: $recurrenceRule,
                        fontManager: fontManager
                    )
                }
            }

            // Attendees & Invitees Section (iOS events only)
            if event.source == .ios {
                Section("Invitees & Attendees") {
                    ForEach(attendees, id: \.self) { attendee in
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                            Text(attendee)
                                .dynamicFont(size: 17, fontManager: fontManager)
                            Spacer()
                            Button(action: {
                                removeAttendee(attendee)
                            }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }

                    Button(action: {
                        showAddAttendee = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Attendee")
                                .dynamicFont(size: 17, fontManager: fontManager)
                        }
                    }
                }
                .alert("Add Attendee", isPresented: $showAddAttendee) {
                    TextField("Email or name", text: $newAttendee)
                    Button("Add") {
                        if !newAttendee.isEmpty {
                            attendees.append(newAttendee)
                            newAttendee = ""
                        }
                    }
                    Button("Cancel", role: .cancel) {
                        newAttendee = ""
                    }
                }
            }

            // Attachments Section (iOS events only)
            if event.source == .ios {
                Section("Attachments") {
                    if attachmentURLs.isEmpty {
                        Text("No attachments")
                            .dynamicFont(size: 17, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(attachmentURLs, id: \.self) { url in
                            HStack {
                                Image(systemName: "paperclip")
                                    .foregroundColor(.blue)
                                Text(url.lastPathComponent)
                                    .dynamicFont(size: 17, fontManager: fontManager)
                                Spacer()
                                Button(action: {
                                    removeAttachment(url)
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                            }
                        }
                    }

                    Button(action: {
                        showAttachmentPicker = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Attachment")
                                .dynamicFont(size: 17, fontManager: fontManager)
                        }
                    }
                }
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

            // Delete Event Section
            Section {
                Button(action: {
                    showingDeleteConfirmation = true
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("Delete Event")
                            .dynamicFont(size: 17, fontManager: fontManager)
                        Spacer()
                    }
                    .foregroundColor(.red)
                }
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
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Are you sure you want to delete this event? This action cannot be undone.")
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

        // Load iOS-specific fields
        if event.source == .ios, let ekEvent = event.originalEvent as? EKEvent {
            // Load available calendars
            let calendars = calendarManager.eventStore.calendars(for: .event)
            availableCalendars = calendars.filter { $0.allowsContentModifications }

            // Set current calendar
            selectedCalendar = ekEvent.calendar

            // Load URL
            if let url = ekEvent.url {
                eventURL = url.absoluteString
            }

            // Load recurrence rule
            recurrenceRule = ekEvent.recurrenceRules?.first

            // Load attendees
            if let ekAttendees = ekEvent.attendees {
                attendees = ekAttendees.compactMap { participant in
                    // participant.url is non-optional URL
                    let urlString = participant.url.absoluteString
                    if urlString.hasPrefix("mailto:") {
                        return urlString.replacingOccurrences(of: "mailto:", with: "")
                    }
                    return participant.name ?? urlString
                }
            }

            // Note: EKEvent.attachments is not available in EventKit API
            // Attachments are not accessible programmatically

            // Load structured location
            if let structured = ekEvent.structuredLocation {
                structuredLocation = structured.geoLocation
            }
        }

        // Load custom color settings
        useCustomColor = colorManager.shouldUseCustomColor(for: event.id)
        if let savedColor = colorManager.getCustomColor(for: event.id) {
            customColor = savedColor
        }
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
            originalEvent: event.originalEvent,
            calendarId: event.calendarId,
            calendarName: event.calendarName,
            calendarColor: event.calendarColor
        )

        updateEventInCalendar(updatedEvent) { success, error in
            DispatchQueue.main.async {
                isLoading = false

                if success {
                    // Save custom color settings
                    colorManager.setUseCustomColor(useCustomColor, for: event.id)
                    if useCustomColor {
                        colorManager.setCustomColor(customColor, for: event.id)
                    } else {
                        colorManager.removeCustomColor(for: event.id)
                    }

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

        // Update basic event data
        ekEvent.title = updatedEvent.title
        ekEvent.location = updatedEvent.location
        ekEvent.notes = updatedEvent.description
        ekEvent.startDate = updatedEvent.startDate
        ekEvent.endDate = updatedEvent.endDate
        ekEvent.isAllDay = updatedEvent.isAllDay

        // Update calendar if changed
        if let newCalendar = selectedCalendar, newCalendar.calendarIdentifier != ekEvent.calendar.calendarIdentifier {
            ekEvent.calendar = newCalendar
        }

        // Update URL
        if !eventURL.isEmpty, let url = URL(string: eventURL) {
            ekEvent.url = url
        } else {
            ekEvent.url = nil
        }

        // Update recurrence rule
        if let rule = recurrenceRule {
            ekEvent.recurrenceRules = [rule]
        } else {
            ekEvent.recurrenceRules = nil
        }

        // Note: Attendees cannot be directly modified in EventKit
        // They are managed by the calendar server
        // We add them to notes for reference
        if !attendees.isEmpty {
            let attendeeNote = "\n\nAttendees: " + attendees.joined(separator: ", ")
            if let existingNotes = ekEvent.notes {
                // Remove old attendee list if present
                let notesWithoutAttendees = existingNotes.components(separatedBy: "\n\nAttendees:").first ?? existingNotes
                ekEvent.notes = notesWithoutAttendees + attendeeNote
            } else {
                ekEvent.notes = attendeeNote
            }
        }

        // Update structured location
        if let geoLocation = structuredLocation {
            let structuredLoc = EKStructuredLocation(title: location)
            structuredLoc.geoLocation = geoLocation
            ekEvent.structuredLocation = structuredLoc
        } else {
            ekEvent.structuredLocation = nil
        }

        // Note: Attachments in EventKit are read-only
        // They cannot be added or modified programmatically

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

    // MARK: - Delete Event

    private func deleteEvent() {
        isLoading = true
        errorMessage = nil

        switch event.source {
        case .ios:
            deleteIOSEvent()
        case .google:
            deleteGoogleEvent()
        case .outlook:
            deleteOutlookEvent()
        }
    }

    private func deleteIOSEvent() {
        guard let ekEvent = event.originalEvent as? EKEvent else {
            errorMessage = "Could not find original iOS event"
            isLoading = false
            return
        }

        do {
            try calendarManager.eventStore.remove(ekEvent, span: .thisEvent)
            print("✅ Successfully deleted iOS event")

            // Delete from Core Data cache
            CoreDataManager.shared.permanentlyDeleteEvent(eventId: event.id, source: .ios)

            // Refresh events
            calendarManager.loadAllUnifiedEvents()

            isLoading = false
            dismiss()
        } catch {
            print("❌ Failed to delete iOS event: \(error.localizedDescription)")
            errorMessage = "Failed to delete event: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func deleteGoogleEvent() {
        guard let googleManager = calendarManager.googleCalendarManager else {
            errorMessage = "Google Calendar not connected"
            isLoading = false
            return
        }

        // Track deletion to prevent reappearance
        calendarManager.deletedEventIds.insert(event.id)

        Task {
            let success = await googleManager.deleteEvent(eventId: event.id)

            await MainActor.run {
                // Delete from Core Data cache regardless of server success
                CoreDataManager.shared.permanentlyDeleteEvent(eventId: event.id, source: .google)

                if success {
                    print("✅ Google event deleted successfully from server and cache")
                    calendarManager.loadAllUnifiedEvents()
                    isLoading = false
                    dismiss()
                } else {
                    print("⚠️ Failed to delete from Google server, but removed from local cache")
                    calendarManager.loadAllUnifiedEvents()
                    isLoading = false
                    dismiss()
                }
            }
        }
    }

    private func deleteOutlookEvent() {
        guard let outlookManager = calendarManager.outlookCalendarManager else {
            errorMessage = "Outlook Calendar not connected"
            isLoading = false
            return
        }

        // Track deletion to prevent reappearance
        calendarManager.deletedEventIds.insert(event.id)

        Task {
            let success = await outlookManager.deleteEvent(eventId: event.id)

            await MainActor.run {
                // Delete from Core Data cache regardless of server success
                CoreDataManager.shared.permanentlyDeleteEvent(eventId: event.id, source: .outlook)

                if success {
                    print("✅ Outlook event deleted successfully from server and cache")
                    calendarManager.loadAllUnifiedEvents()
                    isLoading = false
                    dismiss()
                } else {
                    print("⚠️ Failed to delete from Outlook server, but removed from local cache")
                    calendarManager.loadAllUnifiedEvents()
                    isLoading = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Helper Methods for New Fields

    private func removeAttendee(_ attendee: String) {
        attendees.removeAll { $0 == attendee }
    }

    private func removeAttachment(_ url: URL) {
        attachmentURLs.removeAll { $0 == url }
    }

    private func geocodeLocation() {
        // Convert the location string to coordinates using CLGeocoder
        guard !location.isEmpty else {
            errorMessage = "Please enter a location first"
            return
        }

        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to geocode location: \(error.localizedDescription)"
                }
                return
            }

            if let placemark = placemarks?.first, let location = placemark.location {
                DispatchQueue.main.async {
                    self.structuredLocation = location
                }
            } else {
                DispatchQueue.main.async {
                    self.errorMessage = "Could not find coordinates for location"
                }
            }
        }
    }

    private func openInMaps() {
        guard let geoLocation = structuredLocation else { return }

        let coordinate = geoLocation.coordinate
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = location

        // Open in Apple Maps - this allows Maps to use learned routes and provide traffic updates
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

    private func recurrenceRuleDescription(_ rule: EKRecurrenceRule) -> String {
        let frequency: String
        switch rule.frequency {
        case .daily:
            frequency = "Daily"
        case .weekly:
            frequency = "Weekly"
        case .monthly:
            frequency = "Monthly"
        case .yearly:
            frequency = "Yearly"
        @unknown default:
            frequency = "Custom"
        }

        let interval = rule.interval
        if interval == 1 {
            return frequency
        } else {
            return "Every \(interval) \(frequency.lowercased())"
        }
    }

    // Helper function to determine calendar source icon
    private func calendarSourceIcon(for calendar: EKCalendar) -> String {
        let sourceTitle = calendar.source.title.lowercased()

        if sourceTitle.contains("google") || sourceTitle.contains("gmail") {
            return "globe"
        } else if sourceTitle.contains("outlook") || sourceTitle.contains("microsoft") || sourceTitle.contains("exchange") {
            return "envelope"
        } else {
            return "calendar"
        }
    }

    // Helper function to determine calendar source color
    private func calendarSourceColor(for calendar: EKCalendar) -> Color {
        let sourceTitle = calendar.source.title.lowercased()

        if sourceTitle.contains("google") || sourceTitle.contains("gmail") {
            return Color(red: 66/255, green: 133/255, blue: 244/255) // Google Blue
        } else if sourceTitle.contains("outlook") || sourceTitle.contains("microsoft") || sourceTitle.contains("exchange") {
            return Color(red: 0/255, green: 120/255, blue: 212/255) // Outlook Blue
        } else {
            return Color(red: 255/255, green: 45/255, blue: 85/255) // iOS Calendar Red
        }
    }
}

// MARK: - Map Location Helper

/// Helper struct for Map annotations
struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Recurrence Picker View

/// View for selecting recurrence rules for calendar events
struct RecurrencePickerView: View {
    @Binding var recurrenceRule: EKRecurrenceRule?
    @ObservedObject var fontManager: FontManager

    @Environment(\.dismiss) var dismiss

    @State private var frequency: EKRecurrenceFrequency = .weekly
    @State private var interval: Int = 1
    @State private var selectedDays: Set<EKRecurrenceDayOfWeek> = []
    @State private var endDate: Date?
    @State private var useEndDate: Bool = false

    var body: some View {
        NavigationView {
            Form {
                Section("Frequency") {
                    Picker("Repeat", selection: $frequency) {
                        Text("Daily").tag(EKRecurrenceFrequency.daily)
                        Text("Weekly").tag(EKRecurrenceFrequency.weekly)
                        Text("Monthly").tag(EKRecurrenceFrequency.monthly)
                        Text("Yearly").tag(EKRecurrenceFrequency.yearly)
                    }
                    .dynamicFont(size: 17, fontManager: fontManager)
                    .pickerStyle(.menu)
                }

                Section("Interval") {
                    Stepper("Every \(interval) \(frequencyLabel)", value: $interval, in: 1...99)
                        .dynamicFont(size: 17, fontManager: fontManager)
                }

                if frequency == .weekly {
                    Section("Repeat On") {
                        ForEach(allWeekdays, id: \.self) { weekday in
                            Button(action: {
                                toggleWeekday(weekday)
                            }) {
                                HStack {
                                    Text(weekdayName(weekday))
                                        .dynamicFont(size: 17, fontManager: fontManager)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if selectedDays.contains(weekday) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("End Repeat") {
                    Toggle("Set End Date", isOn: $useEndDate)
                        .dynamicFont(size: 17, fontManager: fontManager)

                    if useEndDate {
                        DatePicker("End Date", selection: Binding(
                            get: { endDate ?? Date().addingTimeInterval(30*24*60*60) },
                            set: { endDate = $0 }
                        ), displayedComponents: .date)
                        .dynamicFont(size: 17, fontManager: fontManager)
                    }
                }

                Section {
                    Button("Remove Repeat") {
                        recurrenceRule = nil
                        dismiss()
                    }
                    .dynamicFont(size: 17, fontManager: fontManager)
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Repeat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .dynamicFont(size: 17, fontManager: fontManager)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveRecurrenceRule()
                        dismiss()
                    }
                    .dynamicFont(size: 17, fontManager: fontManager)
                }
            }
        }
        .onAppear {
            loadExistingRule()
        }
    }

    private var frequencyLabel: String {
        switch frequency {
        case .daily: return interval == 1 ? "day" : "days"
        case .weekly: return interval == 1 ? "week" : "weeks"
        case .monthly: return interval == 1 ? "month" : "months"
        case .yearly: return interval == 1 ? "year" : "years"
        @unknown default: return "times"
        }
    }

    private var allWeekdays: [EKRecurrenceDayOfWeek] {
        return [
            EKRecurrenceDayOfWeek(.sunday),
            EKRecurrenceDayOfWeek(.monday),
            EKRecurrenceDayOfWeek(.tuesday),
            EKRecurrenceDayOfWeek(.wednesday),
            EKRecurrenceDayOfWeek(.thursday),
            EKRecurrenceDayOfWeek(.friday),
            EKRecurrenceDayOfWeek(.saturday)
        ]
    }

    private func weekdayName(_ weekday: EKRecurrenceDayOfWeek) -> String {
        let dayNumber = weekday.dayOfTheWeek.rawValue
        let formatter = DateFormatter()
        return formatter.weekdaySymbols[dayNumber - 1]
    }

    private func toggleWeekday(_ weekday: EKRecurrenceDayOfWeek) {
        if selectedDays.contains(weekday) {
            selectedDays.remove(weekday)
        } else {
            selectedDays.insert(weekday)
        }
    }

    private func loadExistingRule() {
        guard let rule = recurrenceRule else { return }

        frequency = rule.frequency
        interval = rule.interval

        if frequency == .weekly, let daysOfTheWeek = rule.daysOfTheWeek {
            selectedDays = Set(daysOfTheWeek)
        }

        if let ruleEnd = rule.recurrenceEnd {
            if let date = ruleEnd.endDate {
                useEndDate = true
                endDate = date
            }
        }
    }

    private func saveRecurrenceRule() {
        var end: EKRecurrenceEnd?
        if useEndDate, let date = endDate {
            end = EKRecurrenceEnd(end: date)
        }

        let daysOfWeek = frequency == .weekly && !selectedDays.isEmpty ? Array(selectedDays) : nil

        recurrenceRule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: interval,
            daysOfTheWeek: daysOfWeek,
            daysOfTheMonth: nil,
            monthsOfTheYear: nil,
            weeksOfTheYear: nil,
            daysOfTheYear: nil,
            setPositions: nil,
            end: end
        )
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
struct AISuggestionsSheetView: View {
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

// MARK: - Task Edit View

struct TaskEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var fontManager: FontManager
    @StateObject private var taskManager = EventTaskManager.shared

    @Binding var task: EventTask
    var onSave: (EventTask) -> Void
    var onDelete: (() -> Void)?

    @State private var title: String
    @State private var description: String
    @State private var dueDate: Date
    @State private var hasDueDate: Bool
    @State private var subtasks: [EventSubtask]
    @State private var newSubtaskTitle: String = ""
    @State private var showingDeleteAlert = false

    // Collapsible section states
    @State private var showDetailSection = false
    @State private var showDateSection = false
    @State private var showSubtasksSection = false

    init(task: Binding<EventTask>, fontManager: FontManager, onSave: @escaping (EventTask) -> Void, onDelete: (() -> Void)? = nil) {
        self._task = task
        self.fontManager = fontManager
        self.onSave = onSave
        self.onDelete = onDelete

        _title = State(initialValue: task.wrappedValue.title)
        _description = State(initialValue: task.wrappedValue.description ?? "")
        _dueDate = State(initialValue: task.wrappedValue.dueDate ?? Date())
        _hasDueDate = State(initialValue: task.wrappedValue.dueDate != nil)
        _subtasks = State(initialValue: task.wrappedValue.subtasks)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Task")
                            .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        TextField("Task title", text: $title)
                            .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Add Detail Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button(action: {
                                withAnimation {
                                    showDetailSection.toggle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "text.alignleft")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text("Add Detail")
                                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(action: {
                                withAnimation {
                                    showDetailSection.toggle()
                                }
                            }) {
                                Image(systemName: showDetailSection ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                            }
                        }

                        if showDetailSection {
                            TextEditor(text: $description)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .dynamicFont(size: 15, fontManager: fontManager)
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Add Date/Time Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button(action: {
                                withAnimation {
                                    showDateSection.toggle()
                                    if showDateSection {
                                        hasDueDate = true
                                    }
                                }
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text("Add Date/Time")
                                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(action: {
                                withAnimation {
                                    showDateSection.toggle()
                                    if showDateSection {
                                        hasDueDate = true
                                    }
                                }
                            }) {
                                Image(systemName: showDateSection ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                            }
                        }

                        if showDateSection {
                            DatePicker("Due Date", selection: $dueDate, displayedComponents: [.date, .hourAndMinute])
                                .dynamicFont(size: 15, fontManager: fontManager)
                                .datePickerStyle(GraphicalDatePickerStyle())
                        }
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Add Subtasks Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Button(action: {
                                withAnimation {
                                    showSubtasksSection.toggle()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "list.bullet.indent")
                                        .foregroundColor(.blue)
                                        .frame(width: 24)
                                    Text("Add Subtasks")
                                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button(action: {
                                withAnimation {
                                    showSubtasksSection.toggle()
                                }
                            }) {
                                Image(systemName: showSubtasksSection ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.system(size: 20))
                            }
                        }

                        if showSubtasksSection {
                            // Existing subtasks
                            ForEach($subtasks) { $subtask in
                                HStack {
                                    Button(action: {
                                        subtask.isCompleted.toggle()
                                    }) {
                                        Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(subtask.isCompleted ? .green : .gray)
                                    }

                                    TextField("Subtask", text: $subtask.title)
                                        .dynamicFont(size: 15, fontManager: fontManager)
                                        .strikethrough(subtask.isCompleted)
                                        .foregroundColor(subtask.isCompleted ? .secondary : .primary)

                                    Button(action: {
                                        if let index = subtasks.firstIndex(where: { $0.id == subtask.id }) {
                                            subtasks.remove(at: index)
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 4)
                            }

                            // Add new subtask
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)

                                TextField("Add subtask", text: $newSubtaskTitle)
                                    .dynamicFont(size: 15, fontManager: fontManager)
                                    .onSubmit {
                                        addSubtask()
                                    }

                                if !newSubtaskTitle.isEmpty {
                                    Button(action: addSubtask) {
                                        Text("Add")
                                            .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .padding(.horizontal)

                    Spacer()
                }
                .padding(.top)
            }
            .safeAreaInset(edge: .bottom) {
                // Mark Completed Link at bottom right
                HStack {
                    Spacer()

                    Button(action: markCompleted) {
                        Text(task.isCompleted ? "Mark as Incomplete" : "Mark as Completed")
                            .dynamicFont(size: 17, weight: .regular, fontManager: fontManager)
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(role: .destructive, action: {
                            showingDeleteAlert = true
                        }) {
                            Label("Delete Task", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .alert("Delete Task", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    onDelete?()
                    dismiss()
                }
            } message: {
                Text("Are you sure you want to delete this task?")
            }
        }
    }

    private func addSubtask() {
        guard !newSubtaskTitle.isEmpty else { return }
        let newSubtask = EventSubtask(title: newSubtaskTitle)
        subtasks.append(newSubtask)
        newSubtaskTitle = ""
    }

    private func markCompleted() {
        task.isCompleted.toggle()
        if task.isCompleted {
            task.completedAt = Date()
        } else {
            task.completedAt = nil
        }
        saveTask()
    }

    private func saveTask() {
        task.title = title
        task.description = description.isEmpty ? nil : description
        task.dueDate = hasDueDate ? dueDate : nil
        task.subtasks = subtasks

        onSave(task)
        dismiss()
    }
}
import SwiftUI

// MARK: - Standalone Tasks Tab
// Shows all tasks across all events, not linked to event cards

struct TasksTabView: View {
    @ObservedObject var fontManager: FontManager
    @ObservedObject var calendarManager: CalendarManager

    @StateObject private var taskManager = EventTaskManager.shared
    @State private var showingAddTask = false
    @State private var selectedFilter: TaskFilter = .inbox

    // Task entry fields
    @State private var newTaskTitle: String = ""
    @State private var newTaskDescription: String = ""
    @State private var newTaskDueDate: Date = Date()
    @State private var newTaskPriority: TaskPriority = .medium
    @State private var showTaskDetails: Bool = false
    @State private var showDatePicker: Bool = false
    @FocusState private var isTaskFieldFocused: Bool

    // Task detail sheet
    @State private var showingTaskDetail = false
    @State private var selectedTask: (task: EventTask, eventId: String)?
    @State private var completingTaskId: UUID? = nil // Track task being completed for animation

    // Today view collapsible sections
    @State private var isTodayTodosExpanded: Bool = true
    @State private var isTodayDoneExpanded: Bool = false
    @State private var isTodayCalendarExpanded: Bool = false  // Start collapsed (1 week view)

    enum TaskFilter: String, CaseIterable {
        case inbox = "Inbox"
        case today = "Today"
        case upcoming = "Upcoming"
        case completed = "Completed"

        var icon: String {
            switch self {
            case .inbox: return "tray.fill"
            case .today: return "calendar.badge.clock"
            case .upcoming: return "calendar"
            case .completed: return "checkmark.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Filter Tabs
                    filterTabs

                    // Tasks List
                    ScrollView {
                        VStack(spacing: 12) {
                            // Tasks grouped by event
                            if filteredTasks.isEmpty {
                                emptyStateSection
                            } else {
                                if selectedFilter == .today {
                                    todayTasksSection
                                } else {
                                    allTasksSection
                                }
                            }
                        }
                        .padding()
                        .padding(.bottom, 80) // Space for floating button
                    }

                    // Inline Task Entry (appears when adding)
                    if showingAddTask {
                        taskEntryView
                    }
                }
                .navigationTitle("Tasks")
                .navigationBarTitleDisplayMode(.large)

                // Floating Plus Button
                if !showingAddTask {
                    floatingPlusButton
                }
            }
            .sheet(isPresented: $showingTaskDetail) {
                if var selected = selectedTask {
                    TaskDetailView(
                        task: Binding(
                            get: { selected.task },
                            set: { newTask in
                                selected.task = newTask
                                // Save the updated task
                                taskManager.updateTask(newTask, for: selected.eventId)
                            }
                        ),
                        fontManager: fontManager,
                        eventId: selected.eventId,
                        onSave: {
                            // Task is already saved via binding
                        }
                    )
                }
            }
        }
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TaskFilter.allCases, id: \.self) { filter in
                    TaskFilterChip(
                        title: filter.rawValue,
                        icon: filter.icon,
                        isSelected: selectedFilter == filter,
                        count: taskCount(for: filter),
                        fontManager: fontManager
                    ) {
                        selectedFilter = filter
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }

    // MARK: - Today Tasks Section with Collapsible Groups

    private var todayTasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Today Calendar Header
            VStack(alignment: .leading, spacing: 12) {
                Button(action: {
                    withAnimation {
                        isTodayCalendarExpanded.toggle()
                    }
                }) {
                    HStack {
                        Text("Today")
                            .dynamicFont(size: 24, weight: .bold, fontManager: fontManager)
                            .foregroundColor(.primary)

                        Image(systemName: isTodayCalendarExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
                .buttonStyle(.plain)

                // Calendar is always visible
                miniWeekCalendar
            }
            .padding(.bottom, 8)

            Divider()

            // To-Dos Section (Incomplete tasks)
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    withAnimation {
                        isTodayTodosExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: isTodayTodosExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text("To-Dos")
                            .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)
                            .foregroundColor(.primary)

                        Text("(\(countTasks(in: todayIncompleteTasks)))")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if isTodayTodosExpanded {
                    ForEach(todayIncompleteTasks.keys.sorted(), id: \.self) { eventId in
                        if let tasks = todayIncompleteTasks[eventId],
                           !tasks.isEmpty,
                           let event = findEvent(byId: eventId) {

                            VStack(alignment: .leading, spacing: 8) {
                                // Event Header
                                EventHeaderView(event: event, fontManager: fontManager)

                                // Tasks for this event
                                ForEach(tasks) { task in
                                    simplifiedTaskRow(task: task, eventId: eventId)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }

            // Done Section (Completed tasks)
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    withAnimation {
                        isTodayDoneExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: isTodayDoneExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)

                        Text("Done")
                            .dynamicFont(size: 18, weight: .bold, fontManager: fontManager)
                            .foregroundColor(.primary)

                        Text("(\(countTasks(in: todayCompletedTasks)))")
                            .dynamicFont(size: 16, fontManager: fontManager)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if isTodayDoneExpanded {
                    ForEach(todayCompletedTasks.keys.sorted(), id: \.self) { eventId in
                        if let tasks = todayCompletedTasks[eventId],
                           !tasks.isEmpty,
                           let event = findEvent(byId: eventId) {

                            VStack(alignment: .leading, spacing: 8) {
                                // Event Header
                                EventHeaderView(event: event, fontManager: fontManager)

                                // Tasks for this event
                                ForEach(tasks) { task in
                                    simplifiedTaskRow(task: task, eventId: eventId)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Mini Week Calendar

    private var miniWeekCalendar: some View {
        let calendar = Calendar.current
        let today = Date()

        if isTodayCalendarExpanded {
            // 6 weeks view when expanded
            return AnyView(sixWeeksCalendar(calendar: calendar, today: today))
        } else {
            // Current week view when collapsed
            return AnyView(currentWeekCalendar(calendar: calendar, today: today))
        }
    }

    private func currentWeekCalendar(calendar: Calendar, today: Date) -> some View {
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) ?? today

        return HStack(spacing: 8) {
            ForEach(0..<7) { dayOffset in
                let date = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) ?? today
                let isToday = calendar.isDate(date, inSameDayAs: today)

                VStack(spacing: 4) {
                    // Weekday letter
                    Text(getDayLetter(for: date))
                        .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                        .foregroundColor(.secondary)

                    // Day number - only this gets highlighted
                    Text("\(calendar.component(.day, from: date))")
                        .dynamicFont(size: 16, weight: isToday ? .bold : .regular, fontManager: fontManager)
                        .foregroundColor(isToday ? .white : .primary)
                        .frame(width: 32, height: 32)
                        .background(isToday ? Color.blue : Color.clear)
                        .cornerRadius(16)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 4)
    }

    private func sixWeeksCalendar(calendar: Calendar, today: Date) -> some View {
        // Get the first day of the month
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today

        // Get the first day to display (might be from previous month)
        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let daysFromPrevMonth = (firstWeekday - calendar.firstWeekday + 7) % 7
        let calendarStart = calendar.date(byAdding: .day, value: -daysFromPrevMonth, to: monthStart) ?? monthStart

        return VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 8) {
                ForEach(0..<7) { dayOffset in
                    let date = calendar.date(byAdding: .day, value: dayOffset, to: calendarStart) ?? calendarStart
                    Text(getDayLetter(for: date))
                        .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // 6 weeks of days
            ForEach(0..<6) { weekIndex in
                HStack(spacing: 8) {
                    ForEach(0..<7) { dayIndex in
                        let dayOffset = weekIndex * 7 + dayIndex
                        let date = calendar.date(byAdding: .day, value: dayOffset, to: calendarStart) ?? calendarStart
                        let isToday = calendar.isDate(date, inSameDayAs: today)
                        let isCurrentMonth = calendar.component(.month, from: date) == calendar.component(.month, from: today)

                        // Day number - only this gets highlighted
                        Text("\(calendar.component(.day, from: date))")
                            .dynamicFont(size: 16, weight: isToday ? .bold : .regular, fontManager: fontManager)
                            .foregroundColor(isToday ? .white : (isCurrentMonth ? .primary : .secondary))
                            .frame(width: 32, height: 32)
                            .background(isToday ? Color.blue : Color.clear)
                            .cornerRadius(16)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func getDayLetter(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        let fullDay = formatter.string(from: date)
        return String(fullDay.prefix(1))
    }

    // MARK: - All Tasks Section

    private var allTasksSection: some View {
        ForEach(filteredTasks.keys.sorted(), id: \.self) { eventId in
            if let tasks = filteredTasks[eventId],
               !tasks.isEmpty,
               let event = findEvent(byId: eventId) {

                VStack(alignment: .leading, spacing: 8) {
                    // Event Header
                    EventHeaderView(event: event, fontManager: fontManager)

                    // Tasks for this event
                    ForEach(tasks) { task in
                        simplifiedTaskRow(task: task, eventId: eventId)
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Simplified Task Row

    private func simplifiedTaskRow(task: EventTask, eventId: String) -> some View {
        HStack(alignment: .center, spacing: 12) {
            // Checkbox
            Button(action: {
                handleTaskToggle(task: task, eventId: eventId)
            }) {
                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(task.isCompleted ? .green : .gray)
            }

            // Task Title Only
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

            Spacer()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .opacity(completingTaskId == task.id ? 0 : 1)
        .scaleEffect(completingTaskId == task.id ? 0.8 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedTask = (task, eventId)
            showingTaskDetail = true
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive, action: {
                taskManager.deleteTask(task.id, from: eventId)
            }) {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func handleTaskToggle(task: EventTask, eventId: String) {
        // Mark as completing
        completingTaskId = task.id

        // Animate the task
        withAnimation(.easeInOut(duration: 0.3)) {
            // Just trigger the animation
        }

        // Toggle completion after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            taskManager.toggleTaskCompletion(task.id, in: eventId)

            // Reset the completing state
            completingTaskId = nil
        }
    }

    // MARK: - Empty State

    private var emptyStateSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("No Tasks")
                .dynamicFont(size: 22, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            Text(emptyStateMessage)
                .dynamicFont(size: 15, fontManager: fontManager)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 60)
    }

    private var emptyStateMessage: String {
        switch selectedFilter {
        case .inbox:
            return "Your inbox is empty"
        case .today:
            return "No tasks due today"
        case .upcoming:
            return "No upcoming tasks"
        case .completed:
            return "No completed tasks yet"
        }
    }

    // MARK: - Floating Plus Button

    private var floatingPlusButton: some View {
        Button(action: {
            showingAddTask = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTaskFieldFocused = true
            }
        }) {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Task Entry View

    private var taskEntryView: some View {
        VStack(spacing: 0) {
            // Task Title Field
            HStack(alignment: .top, spacing: 12) {
                Button(action: {
                    // Save task
                    saveNewTask()
                }) {
                    Image(systemName: "circle")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
                .padding(.top, 12)

                TextField("New Task", text: $newTaskTitle)
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .focused($isTaskFieldFocused)
                    .padding(.top, 12)
                    .onSubmit {
                        saveNewTask()
                    }

                Button(action: {
                    showTaskDetails.toggle()
                }) {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
                .padding(.top, 12)
            }
            .padding(.horizontal, 16)

            // Task Details (expandable)
            if showTaskDetails {
                VStack(alignment: .leading, spacing: 12) {
                    Divider()

                    TextEditor(text: $newTaskDescription)
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .frame(minHeight: 60, maxHeight: 120)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)

                    // Priority Picker
                    Picker("Priority", selection: $newTaskPriority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.rawValue).tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Due Date Toggle
                    Toggle("Set Due Date", isOn: $showDatePicker)
                        .dynamicFont(size: 14, fontManager: fontManager)
                }
                .padding(.horizontal, 16)
            }

            // Date Picker
            if showDatePicker {
                VStack(spacing: 0) {
                    Divider()
                    DatePicker("Due Date", selection: $newTaskDueDate, displayedComponents: [.date, .hourAndMinute])
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .padding()
                }
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button("Cancel") {
                    resetTaskEntry()
                }
                .dynamicFont(size: 15, fontManager: fontManager)
                .foregroundColor(.secondary)

                Spacer()

                Button("Save") {
                    saveNewTask()
                }
                .dynamicFont(size: 15, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.blue)
                .disabled(newTaskTitle.isEmpty)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1),
            alignment: .top
        )
    }

    // MARK: - Helpers

    private var todayIncompleteTasks: [String: [EventTask]] {
        var result: [String: [EventTask]] = [:]

        for (eventId, eventTasks) in taskManager.eventTasks {
            let filtered = eventTasks.tasks.filter { task in
                isToday(task.dueDate) && !task.isCompleted
            }

            if !filtered.isEmpty {
                result[eventId] = filtered
            }
        }

        return result
    }

    private var todayCompletedTasks: [String: [EventTask]] {
        var result: [String: [EventTask]] = [:]

        for (eventId, eventTasks) in taskManager.eventTasks {
            let filtered = eventTasks.tasks.filter { task in
                isToday(task.dueDate) && task.isCompleted
            }

            if !filtered.isEmpty {
                result[eventId] = filtered
            }
        }

        return result
    }

    private var filteredTasks: [String: [EventTask]] {
        var result: [String: [EventTask]] = [:]

        for (eventId, eventTasks) in taskManager.eventTasks {
            let filtered = eventTasks.tasks.filter { task in
                switch selectedFilter {
                case .inbox:
                    return !task.isCompleted
                case .today:
                    return isToday(task.dueDate)
                case .upcoming:
                    return !task.isCompleted && (task.dueDate ?? Date()) > Date()
                case .completed:
                    return task.isCompleted
                }
            }

            if !filtered.isEmpty {
                result[eventId] = filtered
            }
        }

        return result
    }

    private func taskCount(for filter: TaskFilter) -> Int {
        var count = 0

        for eventTasks in taskManager.eventTasks.values {
            count += eventTasks.tasks.filter { task in
                switch filter {
                case .inbox:
                    return !task.isCompleted
                case .today:
                    return isToday(task.dueDate)
                case .upcoming:
                    return !task.isCompleted && (task.dueDate ?? Date()) > Date()
                case .completed:
                    return task.isCompleted
                }
            }.count
        }

        return count
    }

    private func isToday(_ date: Date?) -> Bool {
        guard let date = date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private func countTasks(in taskDict: [String: [EventTask]]) -> Int {
        return taskDict.values.reduce(0) { $0 + $1.count }
    }

    private func findEvent(byId id: String) -> UnifiedEvent? {
        return calendarManager.unifiedEvents.first { $0.id == id }
    }

    private func saveNewTask() {
        guard !newTaskTitle.isEmpty else { return }

        // For standalone tasks, we need to associate with an event
        // For now, create as a general task (you can enhance this later)
        // We'll need to pick the nearest upcoming event or create a "General Tasks" category

        // Find the next upcoming event to attach the task to
        let upcomingEvents = calendarManager.unifiedEvents.filter { $0.startDate > Date() }
        guard let targetEvent = upcomingEvents.first else {
            print("⚠️ No upcoming events to attach task to")
            resetTaskEntry()
            return
        }

        let newTask = EventTask(
            title: newTaskTitle,
            description: newTaskDescription.isEmpty ? nil : newTaskDescription,
            priority: newTaskPriority,
            dueDate: showDatePicker ? newTaskDueDate : nil
        )

        taskManager.addTask(newTask, to: targetEvent.id)

        resetTaskEntry()
    }

    private func resetTaskEntry() {
        newTaskTitle = ""
        newTaskDescription = ""
        newTaskDueDate = Date()
        newTaskPriority = .medium
        showTaskDetails = false
        showDatePicker = false
        showingAddTask = false
        isTaskFieldFocused = false
    }
}

// MARK: - Event Header View

struct EventHeaderView: View {
    let event: UnifiedEvent
    @ObservedObject var fontManager: FontManager

    private var eventType: EventType {
        EventType.detect(from: event.title, description: event.description)
    }

    var body: some View {
        HStack {
            Image(systemName: eventType.icon)
                .font(.body)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .dynamicFont(size: 14, weight: .semibold, fontManager: fontManager)
                    .lineLimit(1)

                Text(formatEventTime())
                    .dynamicFont(size: 11, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }

    private func formatEventTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: event.startDate)
    }
}

// MARK: - Task Filter Chip

struct TaskFilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let count: Int
    @ObservedObject var fontManager: FontManager
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))

                Text(title)
                    .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)

                if count > 0 {
                    Text("\(count)")
                        .dynamicFont(size: 12, weight: .semibold, fontManager: fontManager)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color(.systemGray4))
                        .cornerRadius(10)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemBackground))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? Color.clear : Color(.systemGray4), lineWidth: 1)
            )
        }
    }
}

// MARK: - Task Detail View

struct TaskDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var task: EventTask
    @ObservedObject var fontManager: FontManager
    let eventId: String
    let onSave: () -> Void

    @State private var isEditingDescription: Bool = false
    @State private var descriptionText: String = ""
    @State private var showPriorityMenu: Bool = false
    @State private var showDeadlineMenu: Bool = false
    @State private var showPlanningView: Bool = false
    @State private var showTaskInfo: Bool = false
    @State private var showDeleteConfirmation: Bool = false
    @State private var dragOffset: CGFloat = 0

    enum PriorityOption: String, CaseIterable {
        case goal = "Goal"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
        case none = "No priority"

        var icon: String {
            switch self {
            case .goal: return "flag.fill"
            case .high: return "exclamationmark.3"
            case .medium: return "exclamationmark.2"
            case .low: return "exclamationmark"
            case .none: return "minus.circle"
            }
        }

        var color: Color {
            switch self {
            case .goal: return .purple
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            case .none: return .gray
            }
        }
    }

    enum DeadlineOption: String, CaseIterable {
        case today = "Today"
        case tomorrow = "Tomorrow"
        case nextWeek = "Next Week"
        case nextWeekend = "Next Weekend"
        case remove = "Remove"

        var icon: String {
            switch self {
            case .today: return "calendar.badge.clock"
            case .tomorrow: return "calendar"
            case .nextWeek: return "calendar.badge.plus"
            case .nextWeekend: return "calendar.badge.exclamationmark"
            case .remove: return "xmark.circle"
            }
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Drag handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Plan and Duration buttons - small rounded buttons above title
                        HStack(spacing: 12) {
                            Button(action: {
                                showPlanningView = true
                            }) {
                                Text("Plan")
                                    .dynamicFont(size: 15, weight: .medium, fontManager: fontManager)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }

                            Button(action: {
                                // Duration action
                            }) {
                                Text("Duration")
                                    .dynamicFont(size: 15, weight: .medium, fontManager: fontManager)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Task Title with Checkbox
                        HStack(spacing: 12) {
                            Button(action: {
                                task.isCompleted.toggle()
                                onSave()
                            }) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 28))
                                    .foregroundColor(task.isCompleted ? .green : .gray)
                            }

                            Text(task.title)
                                .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)
                                .foregroundColor(task.isCompleted ? .secondary : .primary)

                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        // Description Section - 3x wider
                        VStack(alignment: .leading, spacing: 8) {
                            // Edit/Save buttons
                            HStack {
                                if isEditingDescription {
                                    Button("Cancel") {
                                        isEditingDescription = false
                                        descriptionText = task.description ?? ""
                                    }
                                    .foregroundColor(.red)
                                } else {
                                    Button("Edit") {
                                        descriptionText = task.description ?? ""
                                        isEditingDescription = true
                                    }
                                    .foregroundColor(.blue)
                                }

                                Spacer()

                                if isEditingDescription {
                                    Button("Save") {
                                        task.description = descriptionText.isEmpty ? nil : descriptionText
                                        isEditingDescription = false
                                        onSave()
                                    }
                                    .foregroundColor(.blue)
                                    .fontWeight(.semibold)
                                }
                            }

                            if isEditingDescription {
                                TextEditor(text: $descriptionText)
                                    .frame(minHeight: 133)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            } else {
                                VStack(alignment: .leading) {
                                    Text(task.description ?? "Add description...")
                                        .dynamicFont(size: 18, fontManager: fontManager)
                                        .foregroundColor(task.description == nil ? .secondary : .primary)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, minHeight: 133, alignment: .topLeading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 20)

                        // Project and Tag buttons - sized to fit text with rounded edges
                        HStack(spacing: 12) {
                            Button(action: {
                                // Project action
                            }) {
                                Text("Project")
                                    .dynamicFont(size: 15, fontManager: fontManager)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }

                            Button(action: {
                                // Tag action
                            }) {
                                Text("Tag")
                                    .dynamicFont(size: 15, fontManager: fontManager)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(8)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 20)

                        Spacer(minLength: 60)
                    }
                    .padding(.vertical, 8)
                }

                // Bottom bar with icons and menu
                HStack {
                    // Left side: Priority, Flag, Link icons - small squares, icon only
                    HStack(spacing: 12) {
                        // Priority Icon
                        Menu {
                            ForEach(PriorityOption.allCases, id: \.self) { option in
                                Button(action: {
                                    setPriority(option)
                                }) {
                                    Label(option.rawValue, systemImage: option.icon)
                                }
                            }
                        } label: {
                            Image(systemName: "exclamationmark.circle")
                                .font(.system(size: 22))
                                .foregroundColor(priorityColor())
                                .frame(width: 40, height: 40)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        // Flag Icon (Deadline)
                        Menu {
                            ForEach(DeadlineOption.allCases, id: \.self) { option in
                                Button(action: {
                                    setDeadline(option)
                                }) {
                                    Label(option.rawValue, systemImage: option.icon)
                                }
                            }
                        } label: {
                            Image(systemName: task.dueDate != nil ? "flag.fill" : "flag")
                                .font(.system(size: 22))
                                .foregroundColor(task.dueDate != nil ? .orange : .gray)
                                .frame(width: 40, height: 40)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }

                        // Link Icon
                        Button(action: {
                            // Link action
                        }) {
                            Image(systemName: "link")
                                .font(.system(size: 22))
                                .foregroundColor(.gray)
                                .frame(width: 40, height: 40)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }

                    Spacer()

                    // Right side: Three-dot menu
                    Menu {
                        Button(action: {
                            showTaskInfoAction()
                        }) {
                            Label("Info", systemImage: "info.circle")
                        }

                        Button(action: {
                            duplicateTaskAction()
                        }) {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            deleteTaskAction()
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 22))
                            .foregroundColor(.primary)
                            .frame(width: 40, height: 40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .frame(height: geometry.size.height / 2)
            .background(Color(.systemBackground))
            .cornerRadius(20, corners: [.topLeft, .topRight])
            .shadow(radius: 10)
            .offset(y: geometry.size.height / 2 + dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow downward drag
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        // If dragged down more than 100 points, dismiss
                        if value.translation.height > 100 {
                            dismiss()
                        } else {
                            // Otherwise, snap back
                            withAnimation(.spring()) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .sheet(isPresented: $showPlanningView) {
            TaskPlanningView(
                task: $task,
                fontManager: fontManager,
                eventId: eventId,
                onSave: onSave
            )
        }
        .alert("Task Information", isPresented: $showTaskInfo) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(getTaskInfoMessage())
        }
        .alert("Delete Task", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                EventTaskManager.shared.deleteTask(task.id, from: eventId)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete '\(task.title)'? This action cannot be undone.")
        }
    }

    // MARK: - Helper Methods

    private func getTaskInfoMessage() -> String {
        var info = ""
        info += "Created: \(formatDate(task.createdAt))\n"
        if task.isCompleted, let completedDate = task.completedAt {
            info += "Completed: \(formatDate(completedDate))\n"
        }
        if let dueDate = task.dueDate {
            info += "Due: \(formatDate(dueDate))\n"
        }
        info += "Priority: \(task.priority.rawValue)\n"
        info += "Category: \(task.category.rawValue)\n"
        if let estimatedMinutes = task.estimatedMinutes {
            info += "Estimated time: \(estimatedMinutes) minutes"
        }
        return info
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func showTaskInfoAction() {
        showTaskInfo = true
    }

    private func duplicateTaskAction() {
        let duplicatedTask = EventTask(
            title: "\(task.title) (Copy)",
            description: task.description,
            isCompleted: false,
            priority: task.priority,
            category: task.category,
            timing: task.timing,
            estimatedMinutes: task.estimatedMinutes,
            dueDate: task.dueDate,
            subtasks: task.subtasks
        )
        EventTaskManager.shared.addTask(duplicatedTask, to: eventId)
        dismiss()
    }

    private func deleteTaskAction() {
        showDeleteConfirmation = true
    }

    private func priorityColor() -> Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }

    private func setPriority(_ option: PriorityOption) {
        switch option {
        case .goal, .high:
            task.priority = .high
        case .medium:
            task.priority = .medium
        case .low, .none:
            task.priority = .low
        }
        onSave()
    }

    private func setDeadline(_ option: DeadlineOption) {
        let calendar = Calendar.current

        switch option {
        case .today:
            task.dueDate = Date()
        case .tomorrow:
            task.dueDate = calendar.date(byAdding: .day, value: 1, to: Date())
        case .nextWeek:
            task.dueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: Date())
        case .nextWeekend:
            // Find next Saturday
            var dateComponents = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
            dateComponents.weekday = 7 // Saturday
            if let nextSaturday = calendar.date(from: dateComponents),
               nextSaturday <= Date() {
                task.dueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: nextSaturday)
            } else {
                task.dueDate = calendar.date(from: dateComponents)
            }
        case .remove:
            task.dueDate = nil
        }
        onSave()
    }
}

// MARK: - Task Planning View

struct TaskPlanningView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var task: EventTask
    @ObservedObject var fontManager: FontManager
    let eventId: String
    let onSave: () -> Void

    @State private var searchText: String = ""
    @State private var selectedDate: Date = Date()
    @State private var selectedTime: Date = Date()
    @State private var hasTime: Bool = false
    @State private var duration: TimeInterval = 1800 // 30 minutes default
    @State private var hasDuration: Bool = false
    @State private var showCalendarPicker: Bool = false
    @State private var showTimePicker: Bool = false
    @State private var showDurationPicker: Bool = false

    enum QuickOption: String, CaseIterable {
        case today = "Today"
        case laterToday = "Later today"
        case tomorrow = "Tomorrow"
        case thisWeek = "This week"
        case nextWeek = "Next week"
        case thisMonth = "This month"
        case nextMonth = "Next month"
        case someday = "Someday"

        var icon: String {
            switch self {
            case .today: return "calendar"
            case .laterToday: return "clock"
            case .tomorrow: return "calendar"
            case .thisWeek: return "w.square"
            case .nextWeek: return "arrow.right.square"
            case .thisMonth: return "m.square"
            case .nextMonth: return "arrow.right.square"
            case .someday: return "infinity"
            }
        }

        func displayDate() -> String {
            let calendar = Calendar.current
            let formatter = DateFormatter()

            switch self {
            case .today:
                formatter.dateFormat = "d"
                let day = formatter.string(from: Date())
                formatter.dateFormat = "E"
                let weekday = formatter.string(from: Date())
                return "\(day) • \(weekday)"
            case .laterToday:
                formatter.dateFormat = "E - h:mm a"
                let later = calendar.date(byAdding: .hour, value: 4, to: Date()) ?? Date()
                return formatter.string(from: later)
            case .tomorrow:
                let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date()
                formatter.dateFormat = "d"
                let day = formatter.string(from: tomorrow)
                formatter.dateFormat = "E"
                let weekday = formatter.string(from: tomorrow)
                return "\(day) • \(weekday)"
            case .thisWeek:
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
                let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? Date()
                formatter.dateFormat = "d"
                return "\(formatter.string(from: startOfWeek))-\(formatter.string(from: endOfWeek)) \(calendar.component(.month, from: Date()))"
            case .nextWeek:
                let nextWeekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: Date()) ?? Date()
                let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: nextWeekStart)?.start ?? Date()
                let endOfWeek = calendar.date(byAdding: .day, value: 6, to: startOfWeek) ?? Date()
                formatter.dateFormat = "d"
                return "\(formatter.string(from: startOfWeek))-\(formatter.string(from: endOfWeek))"
            case .thisMonth:
                formatter.dateFormat = "MMMM"
                return formatter.string(from: Date())
            case .nextMonth:
                let nextMonth = calendar.date(byAdding: .month, value: 1, to: Date()) ?? Date()
                formatter.dateFormat = "MMMM"
                return formatter.string(from: nextMonth)
            case .someday:
                return "No date"
            }
        }

        func getDate() -> Date? {
            let calendar = Calendar.current

            switch self {
            case .today:
                return Date()
            case .laterToday:
                return calendar.date(byAdding: .hour, value: 4, to: Date())
            case .tomorrow:
                return calendar.date(byAdding: .day, value: 1, to: Date())
            case .thisWeek:
                let endOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.end ?? Date()
                return endOfWeek
            case .nextWeek:
                return calendar.date(byAdding: .weekOfYear, value: 1, to: Date())
            case .thisMonth:
                let endOfMonth = calendar.dateInterval(of: .month, for: Date())?.end ?? Date()
                return endOfMonth
            case .nextMonth:
                return calendar.date(byAdding: .month, value: 1, to: Date())
            case .someday:
                return nil
            }
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Search/Input Field
                    TextField("Type date and time or Time Slot", text: $searchText)
                        .dynamicFont(size: 16, fontManager: fontManager)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)

                    // Quick Options
                    VStack(spacing: 0) {
                        ForEach(QuickOption.allCases, id: \.self) { option in
                            quickOptionRow(option)
                            if option != QuickOption.allCases.last {
                                Divider()
                                    .padding(.leading, 60)
                            }
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Date and Time Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Date and Time")
                            .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                            .padding(.horizontal)

                        HStack(spacing: 12) {
                            Button(action: {
                                showCalendarPicker.toggle()
                            }) {
                                HStack {
                                    Image(systemName: "calendar")
                                    Text(formatDate(selectedDate))
                                        .dynamicFont(size: 15, fontManager: fontManager)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .foregroundColor(.primary)

                            Button(action: {
                                showTimePicker.toggle()
                                hasTime.toggle()
                            }) {
                                HStack {
                                    Image(systemName: "clock")
                                    Text(hasTime ? formatTime(selectedTime) : "No time")
                                        .dynamicFont(size: 15, fontManager: fontManager)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(10)
                            }
                            .foregroundColor(.primary)
                        }
                        .padding(.horizontal)

                        // Calendar Picker
                        if showCalendarPicker {
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }

                        // Time Picker
                        if showTimePicker {
                            DatePicker("", selection: $selectedTime, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel)
                                .labelsHidden()
                                .frame(height: 200)
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }

                    // Duration Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Duration")
                            .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                            .padding(.horizontal)

                        Button(action: {
                            showDurationPicker.toggle()
                            if !hasDuration {
                                hasDuration = true
                            }
                        }) {
                            HStack {
                                Image(systemName: "timer")
                                Text(hasDuration ? formatDuration(duration) : "None")
                                    .dynamicFont(size: 15, fontManager: fontManager)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal)

                        // Duration Picker
                        if showDurationPicker {
                            durationPicker
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .navigationTitle("Plan Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveTaskPlanning()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Quick Option Row

    private func quickOptionRow(_ option: QuickOption) -> some View {
        Button(action: {
            handleQuickOption(option)
        }) {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(width: 40, height: 40)

                    Group {
                        if option == .today || option == .tomorrow {
                            Text(getDayNumber(for: option))
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        } else {
                            Image(systemName: option.icon)
                                .font(.system(size: 18))
                        }
                    }
                }

                // Title
                Text(option.rawValue)
                    .dynamicFont(size: 16, fontManager: fontManager)
                    .foregroundColor(.primary)

                Spacer()

                // Date/Time Info
                Text(option.displayDate())
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Duration Picker

    private var durationPicker: some View {
        HStack(spacing: 0) {
            // Hours
            Picker("Hours", selection: Binding(
                get: { Int(duration / 3600) },
                set: { hours in
                    let minutes = Int(duration.truncatingRemainder(dividingBy: 3600) / 60)
                    duration = Double(hours * 3600 + minutes * 60)
                }
            )) {
                ForEach(0..<24) { hour in
                    Text("\(hour)")
                        .dynamicFont(size: 20, fontManager: fontManager)
                        .tag(hour)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)

            Text("h")
                .dynamicFont(size: 20, fontManager: fontManager)
                .padding(.horizontal, 8)

            // Minutes
            Picker("Minutes", selection: Binding(
                get: { Int(duration.truncatingRemainder(dividingBy: 3600) / 60) },
                set: { minutes in
                    let hours = Int(duration / 3600)
                    duration = Double(hours * 3600 + minutes * 60)
                }
            )) {
                ForEach(0..<60) { minute in
                    Text("\(minute)")
                        .dynamicFont(size: 20, fontManager: fontManager)
                        .tag(minute)
                }
            }
            .pickerStyle(.wheel)
            .frame(width: 80)

            Text("m")
                .dynamicFont(size: 20, fontManager: fontManager)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helper Methods

    private func getDayNumber(for option: QuickOption) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        let date = option == .today ? Date() : Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        return formatter.string(from: date)
    }

    private func handleQuickOption(_ option: QuickOption) {
        if let date = option.getDate() {
            selectedDate = date
            task.dueDate = date

            // Set time for "Later Today"
            if option == .laterToday {
                hasTime = true
                selectedTime = date
            }
        } else {
            // Someday - no date
            task.dueDate = nil
            hasTime = false
        }
    }

    private func saveTaskPlanning() {
        // Combine date and time if time is set
        if hasTime {
            let calendar = Calendar.current
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
            let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)

            var combined = DateComponents()
            combined.year = dateComponents.year
            combined.month = dateComponents.month
            combined.day = dateComponents.day
            combined.hour = timeComponents.hour
            combined.minute = timeComponents.minute

            if let finalDate = calendar.date(from: combined) {
                task.dueDate = finalDate
            }
        } else {
            task.dueDate = selectedDate
        }

        onSave()
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func formatTime(_ time: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: time)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int(duration.truncatingRemainder(dividingBy: 3600) / 60)

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Preview

#Preview {
    TasksTabView(
        fontManager: FontManager(),
        calendarManager: CalendarManager()
    )
}
