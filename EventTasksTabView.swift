import SwiftUI

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
                    .foregroundColor(.primary)
                    .strikethrough(task.isCompleted)

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
