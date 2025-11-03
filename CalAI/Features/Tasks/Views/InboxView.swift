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
                if let task = selectedTask {
                    // Get the event ID (either from selection or by finding it)
                    let eventId = selectedEventId ?? taskManager.findEventId(for: task) ?? "standalone_tasks"

                    // Use unified StandaloneTaskSheet for editing
                    StandaloneTaskSheet(
                        taskManager: taskManager,
                        fontManager: fontManager,
                        initialList: selectedList,
                        linkedEventId: nil,  // Keep nil since we're editing an existing task
                        editingTask: task,
                        eventIdForEditing: eventId
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

        return VStack(spacing: 0) {
            // Collapsible calendar for Today view only
            if selectedList == .today {
                CollapsibleTodayCalendar(
                    fontManager: fontManager,
                    taskManager: taskManager
                )
            }

            // Task list
            Group {
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
                                    // Find the event ID for this task
                                    // First try linkedEventId, then search for it
                                    if let linkedId = task.linkedEventId {
                                        selectedEventId = linkedId
                                    } else {
                                        // Search through all event tasks to find which event contains this task
                                        selectedEventId = taskManager.findEventId(for: task) ?? "standalone_tasks"
                                    }
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

// MARK: - Collapsible Today Calendar

struct CollapsibleTodayCalendar: View {
    @ObservedObject var fontManager: FontManager
    @ObservedObject var taskManager: EventTaskManager

    @State private var isExpanded = false
    @State private var selectedDate = Date()

    private let collapsedHeight: CGFloat = 50
    private let expandedHeight: CGFloat = 400

    // Get tasks that should appear on calendar (Today + Upcoming with scheduled times)
    private var calendarTasks: [TaskTimelineItem] {
        var timelineEvents: [TaskTimelineItem] = []

        // Get today and upcoming tasks
        let todayTasks = taskManager.getTasksForList(.today)
        let upcomingTasks = taskManager.getTasksForList(.upcoming)

        // Combine and filter for scheduled tasks
        let scheduledTasks = (todayTasks + upcomingTasks).filter { task in
            task.scheduledTime != nil && task.duration != nil
        }

        // Convert to TaskTimelineItem
        for task in scheduledTasks {
            guard let startTime = task.scheduledTime,
                  let duration = task.duration else { continue }

            // Convert color string to UIColor
            let colorName = task.priority.color
            let uiColor: UIColor = {
                switch colorName {
                case "red": return .systemRed
                case "orange": return .systemOrange
                case "green": return .systemGreen
                case "black": return .label
                default: return .systemBlue
                }
            }()

            timelineEvents.append(TaskTimelineItem(
                id: task.id.uuidString,
                title: task.title,
                startTime: startTime,
                endTime: startTime.addingTimeInterval(duration),
                color: uiColor
            ))
        }

        return timelineEvents
    }

    var body: some View {
        VStack(spacing: 0) {
            // Collapse/Expand header
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.blue)

                    Text("Today's Schedule")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(.systemGray6))
            }
            .buttonStyle(PlainButtonStyle())

            // Calendar week view (expanded)
            if isExpanded {
                MiniWeekTimeline(
                    selectedDate: $selectedDate,
                    tasks: calendarTasks,
                    fontManager: fontManager
                )
                .frame(height: expandedHeight)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Mini Week Timeline

struct MiniWeekTimeline: View {
    @Binding var selectedDate: Date
    let tasks: [TaskTimelineItem]
    @ObservedObject var fontManager: FontManager

    @State private var showMonthCalendar = false
    @State private var dragOffset: CGFloat = 0

    private let calendar = Calendar.current
    private let hourHeight: CGFloat = 60
    private let monthCalendarHeight: CGFloat = 320

    private var currentWeekDays: [Date] {
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private var todayIndex: Int? {
        currentWeekDays.firstIndex { calendar.isDate($0, inSameDayAs: Date()) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Fixed day header - THIS IS THE FIRST WEEK OF THE 6-WEEK CALENDAR
            HStack(spacing: 0) {
                // Spacer for time labels
                Color.clear.frame(width: 45)

                // Day columns headers
                ForEach(Array(currentWeekDays.enumerated()), id: \.offset) { index, day in
                    let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
                    let isToday = todayIndex == index

                    Button(action: {
                        selectedDate = day
                    }) {
                        VStack(spacing: 2) {
                            Text(dayName(for: day))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.gray)

                            Text("\(calendar.component(.day, from: day))")
                                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                                .foregroundColor(isToday ? .white : .black)
                                .frame(width: 28, height: 28)
                                .background(isToday ? Color.blue : Color.clear)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .strokeBorder(isSelected && !isToday ? Color.blue : Color.clear, lineWidth: 2)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .frame(height: 50)
            .background(Color(.systemBackground))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow pulling down
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        // If pulled down more than 50 points, show additional 5 weeks
                        if value.translation.height > 50 {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                showMonthCalendar = true
                            }
                        }
                        dragOffset = 0
                    }
            )

            // Additional 5 weeks below (revealed by pull-down)
            if showMonthCalendar {
                AdditionalWeeksView(selectedDate: $selectedDate, currentWeekDays: currentWeekDays)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                // If user swipes up on the additional weeks, collapse it
                                if value.translation.height < -50 {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                        showMonthCalendar = false
                                    }
                                }
                            }
                    )
            }

            // Scrollable timeline
            GeometryReader { geometry in
                ScrollView {
                    ScrollViewReader { proxy in
                        ZStack(alignment: .topLeading) {
                            // Time labels
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(0..<24, id: \.self) { hour in
                                    Text("\(hour):00")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                        .frame(width: 40, height: hourHeight, alignment: .top)
                                        .id("hour_\(hour)")
                                }
                            }

                            // Timeline grid
                            HStack(spacing: 0) {
                                // Spacer for time labels
                                Color.clear.frame(width: 45)

                                // Day columns
                                ForEach(Array(currentWeekDays.enumerated()), id: \.offset) { index, day in
                                    ZStack(alignment: .topLeading) {
                                        // Hour lines
                                        VStack(spacing: 0) {
                                            ForEach(0..<24, id: \.self) { hour in
                                                Divider()
                                                    .frame(height: hourHeight)
                                            }
                                        }

                                        // Tasks for this day
                                        ForEach(tasksForDay(day), id: \.id) { task in
                                            taskBlock(for: task, in: day)
                                        }
                                    }
                                    .frame(width: (geometry.size.width - 45) / 7)
                                }
                            }
                        }
                        .onAppear {
                            // Scroll to 8 AM
                            proxy.scrollTo("hour_8", anchor: .top)
                        }
                    }
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func tasksForDay(_ day: Date) -> [TaskTimelineItem] {
        tasks.filter { calendar.isDate($0.startTime, inSameDayAs: day) }
    }

    private func taskBlock(for task: TaskTimelineItem, in day: Date) -> some View {
        let startHour = calendar.component(.hour, from: task.startTime)
        let startMinute = calendar.component(.minute, from: task.startTime)
        let duration = task.endTime.timeIntervalSince(task.startTime)

        let topOffset = CGFloat(startHour) * hourHeight + (CGFloat(startMinute) / 60.0) * hourHeight
        let height = (duration / 3600.0) * hourHeight

        return VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 7))
                Text(task.title)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.white)
            .lineLimit(2)
        }
        .padding(4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: max(height, 20))
        .background(Color(task.color).opacity(0.7))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(Color(task.color), lineWidth: 1, antialiased: true)
        )
        .offset(y: topOffset)
        .padding(.horizontal, 2)
    }
}

// MARK: - Additional Weeks View (5 weeks above current week)

struct AdditionalWeeksView: View {
    @Binding var selectedDate: Date
    let currentWeekDays: [Date]

    private let calendar = Calendar.current

    // Get 5 weeks after the current visible week
    private var additionalWeeks: [[Date]] {
        guard let currentWeekStart = currentWeekDays.first else {
            return []
        }

        var weeks: [[Date]] = []

        // Start from week 1 (next week after current)
        for weekOffset in 1...5 {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: weekOffset, to: currentWeekStart) else {
                continue
            }

            let weekDays = (0..<7).compactMap { dayOffset in
                calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
            }

            weeks.append(weekDays)
        }

        return weeks
    }

    var body: some View {
        VStack(spacing: 0) {
            // 5 weeks grid (no header needed, weekdays already shown above)
            ForEach(Array(additionalWeeks.enumerated()), id: \.offset) { weekIndex, week in
                HStack(spacing: 0) {
                    // Spacer for time labels alignment
                    Color.clear.frame(width: 45)

                    // Days in this week
                    ForEach(Array(week.enumerated()), id: \.offset) { dayIndex, day in
                        Button(action: {
                            selectedDate = day
                        }) {
                            Text("\(calendar.component(.day, from: day))")
                                .font(.system(size: 14, weight: calendar.isDate(day, inSameDayAs: selectedDate) ? .bold : .regular))
                                .foregroundColor(getDateColor(day))
                                .frame(width: 28, height: 28)
                                .background(calendar.isDate(day, inSameDayAs: selectedDate) ? Color.blue : Color.clear)
                                .clipShape(Circle())
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(height: 40)
                .background(Color(.systemBackground))

                if weekIndex < additionalWeeks.count - 1 {
                    Divider()
                }
            }
        }
        .background(Color(.systemGray6))
    }

    private func dayName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }

    private func getDateColor(_ date: Date) -> Color {
        if calendar.isDate(date, inSameDayAs: selectedDate) {
            return .white
        } else if calendar.isDate(date, inSameDayAs: Date()) {
            return .blue
        } else {
            return .primary
        }
    }
}

// MARK: - Task Timeline Item Model

struct TaskTimelineItem: Identifiable {
    let id: String
    let title: String
    let startTime: Date
    let endTime: Date
    let color: UIColor
}
