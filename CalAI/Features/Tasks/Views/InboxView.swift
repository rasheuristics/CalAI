import SwiftUI

struct InboxView: View {
    @ObservedObject var taskManager = EventTaskManager.shared
    @ObservedObject var fontManager: FontManager
    @ObservedObject var appearanceManager: AppearanceManager

    @State private var selectedList: TaskList = .today
    @State private var showingAddTask = false
    @State private var selectedTask: EventTask?
    @State private var showingTaskDetail = false
    @State private var selectedEventId: String?
    @State private var showingScheduleSheet = false
    @State private var taskToSchedule: EventTask?
    @State private var eventIdForScheduling: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // List selector
                listSelectorView

                // Task list
                taskListView
            }
            .navigationTitle("Tasks")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button("Add Sample Tasks") {
                            TaskInboxTestHelper.createSampleTasks()
                        }
                        Button("Print Summary") {
                            TaskInboxTestHelper.printTaskSummary()
                        }
                        Button("Clear Standalone Tasks", role: .destructive) {
                            TaskInboxTestHelper.clearStandaloneTasks()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddTask = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                StandaloneTaskSheet(
                    taskManager: taskManager,
                    fontManager: fontManager,
                    initialList: selectedList
                )
            }
            .sheet(isPresented: $showingTaskDetail) {
                if let task = selectedTask, let eventId = selectedEventId {
                    // Use existing TaskDetailView from EventTasksSystem
                    TaskDetailView(
                        task: .constant(task),
                        fontManager: fontManager,
                        eventId: eventId,
                        onSave: {}
                    )
                }
            }
            .sheet(isPresented: $showingScheduleSheet) {
                if let task = taskToSchedule, let eventId = eventIdForScheduling {
                    ScheduleTaskSheet(
                        taskManager: taskManager,
                        fontManager: fontManager,
                        task: task,
                        eventId: eventId
                    )
                }
            }
        }
    }

    private var listSelectorView: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(Array(TaskList.allCases.enumerated()), id: \.element) { index, list in
                    InboxListButton(
                        list: list,
                        count: taskManager.getTaskCountForList(list),
                        isSelected: selectedList == list,
                        titleIndex: index,
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedList = list
                            }
                        }
                    )
                    .frame(width: geometry.size.width / CGFloat(TaskList.allCases.count))
                }
            }
            .padding(.vertical, 12)
        }
        .frame(height: 80)
        .background(Color(.systemGroupedBackground))
    }

    private var taskListView: some View {
        let tasks = taskManager.getTasksForList(selectedList)

        return Group {
            if tasks.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(tasks) { task in
                        InboxTaskRow(
                            task: task,
                            taskManager: taskManager,
                            fontManager: fontManager,
                            onTap: {
                                selectedTask = task
                                selectedEventId = task.linkedEventId
                                showingTaskDetail = true
                            },
                            onSchedule: { task, eventId in
                                taskToSchedule = task
                                eventIdForScheduling = eventId
                                showingScheduleSheet = true
                            }
                        )
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { indexSet in
                        deleteTask(at: indexSet, from: tasks)
                    }
                }
                .listStyle(PlainListStyle())
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedList.icon)
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))

            Text(emptyStateTitle)
                .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            Text(emptyStateMessage)
                .dynamicFont(size: 14, fontManager: fontManager)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: {
                showingAddTask = true
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Task")
                }
                .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var emptyStateTitle: String {
        switch selectedList {
        case .inbox: return "Inbox is empty"
        case .today: return "Nothing due today"
        case .upcoming: return "No upcoming tasks"
        case .someday: return "No future tasks"
        }
    }

    private var emptyStateMessage: String {
        switch selectedList {
        case .inbox: return "Add tasks here to organize them later"
        case .today: return "You're all caught up for today!"
        case .upcoming: return "No tasks scheduled for this week"
        case .someday: return "Add tasks you'll get to eventually"
        }
    }

    private func deleteTask(at indexSet: IndexSet, from tasks: [EventTask]) {
        for index in indexSet {
            let task = tasks[index]
            if let linkedEventId = task.linkedEventId {
                taskManager.deleteTask(task.id, from: linkedEventId)
            }
        }
    }
}

// MARK: - List Selector Button

struct InboxListButton: View {
    let list: TaskList
    let count: Int
    let isSelected: Bool
    let titleIndex: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // Icon with today's date for calendar
                    if list == .today {
                        CalendarIconWithDate(isSelected: isSelected)
                    } else {
                        Image(systemName: list.icon)
                            .font(.system(size: 28))
                            .foregroundColor(isSelected ? .blue : Color(.label).opacity(0.55))
                    }

                    // Badge in top-right corner of icon
                    if count > 0 {
                        Text("\(count)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .frame(minWidth: 16, minHeight: 16)
                            .background(
                                Circle()
                                    .fill(Color.red)
                            )
                            .offset(x: 8, y: -4)
                    }
                }
                .frame(width: 44, height: 44)

                // Label below icon with consistent 14pt sizing
                Text(list.rawValue)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .blue : Color(.label).opacity(0.55))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Calendar Icon with Today's Date

struct CalendarIconWithDate: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            // Calendar background
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue : Color(.label).opacity(0.55))
                .frame(width: 28, height: 28)

            // Top bar of calendar
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.white)
                .frame(width: 28, height: 6)
                .offset(y: -11)

            // Today's date
            Text("\(Calendar.current.component(.day, from: Date()))")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .offset(y: 2)
        }
    }
}

// MARK: - Inbox Task Row

struct InboxTaskRow: View {
    let task: EventTask
    let taskManager: EventTaskManager
    let fontManager: FontManager
    let onTap: () -> Void
    let onSchedule: (EventTask, String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Main task row
            Button(action: onTap) {
                HStack(spacing: 12) {
                    // Completion checkbox
                    Button(action: {
                        toggleCompletion()
                    }) {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24))
                            .foregroundColor(task.isCompleted ? .green : .gray)
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Task content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted)

                        HStack(spacing: 8) {
                            // Priority
                            if task.priority != .none {
                                HStack(spacing: 2) {
                                    Image(systemName: task.priority.icon)
                                        .font(.system(size: 10))
                                    Text(task.priority.rawValue)
                                        .font(.system(size: 11, weight: .medium))
                                }
                                .foregroundColor(Color(task.priority.color))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(task.priority.color).opacity(0.15))
                                .cornerRadius(4)
                            }

                            // Category
                            HStack(spacing: 2) {
                                Image(systemName: task.category.icon)
                                    .font(.system(size: 10))
                                Text(task.category.rawValue)
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)

                            // Due date
                            if let dueDate = task.dueDate {
                                HStack(spacing: 2) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 10))
                                    Text(formatDate(dueDate))
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                            }

                            // Duration
                            if let duration = task.duration {
                                HStack(spacing: 2) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 10))
                                    Text(formatDuration(duration))
                                        .font(.system(size: 11))
                                }
                                .foregroundColor(.secondary)
                            }

                            Spacer()
                        }

                        // Subtasks progress
                        if !task.subtasks.isEmpty {
                            let completed = task.subtasks.filter { $0.isCompleted }.count
                            HStack(spacing: 4) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 10))
                                Text("\(completed)/\(task.subtasks.count) subtasks")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.5))
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(PlainButtonStyle())

            // Schedule button (shown only for tasks with duration but no scheduled time)
            if task.duration != nil && task.scheduledTime == nil, let eventId = task.linkedEventId {
                Button(action: {
                    onSchedule(task, eventId)
                }) {
                    HStack {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 14))
                        Text("Schedule Time")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.top, 8)
            }

            // Scheduled indicator (shown for tasks with scheduled time)
            if let scheduledTime = task.scheduledTime {
                HStack(spacing: 6) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Text("Scheduled: \(formatScheduledTime(scheduledTime))")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    Spacer()
                    if let eventId = task.linkedEventId {
                        Button(action: {
                            onSchedule(task, eventId)
                        }) {
                            Text("Edit")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
                .padding(.top, 8)
            }
        }
    }

    private func toggleCompletion() {
        if let linkedEventId = task.linkedEventId {
            taskManager.toggleTaskCompletion(task.id, in: linkedEventId)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInTomorrow(date) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }

    private func isOverdue(_ date: Date) -> Bool {
        return date < Date() && !Calendar.current.isDateInToday(date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }

    private func formatScheduledTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()

        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
            return "Today at \(formatter.string(from: date))"
        } else if calendar.isDateInTomorrow(date) {
            formatter.dateFormat = "h:mm a"
            return "Tomorrow at \(formatter.string(from: date))"
        } else {
            formatter.dateFormat = "MMM d 'at' h:mm a"
            return formatter.string(from: date)
        }
    }
}
