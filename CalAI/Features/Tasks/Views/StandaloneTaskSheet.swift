import SwiftUI

struct StandaloneTaskSheet: View {
    @ObservedObject var taskManager: EventTaskManager
    @ObservedObject var fontManager: FontManager

    let initialList: TaskList
    let linkedEventId: String?
    let editingTask: EventTask?  // Task to edit (nil for new task)
    let eventIdForEditing: String?  // Event ID for the task being edited

    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var description: String = ""
    @State private var priority: TaskPriority = .none
    @State private var category: TaskCategory = .preparation
    @State private var selectedList: TaskList
    @State private var hasDueDate: Bool = false
    @State private var dueDate: Date = Date()
    @State private var hasDuration: Bool = false
    @State private var durationHours: Int = 1
    @State private var durationMinutes: Int = 0
    @State private var tags: String = ""
    @State private var showPriorityOptions: Bool = false

    init(
        taskManager: EventTaskManager,
        fontManager: FontManager,
        initialList: TaskList = .inbox,
        linkedEventId: String? = nil,
        editingTask: EventTask? = nil,
        eventIdForEditing: String? = nil
    ) {
        self.taskManager = taskManager
        self.fontManager = fontManager
        self.initialList = initialList
        self.linkedEventId = linkedEventId
        self.editingTask = editingTask
        self.eventIdForEditing = eventIdForEditing
        _selectedList = State(initialValue: editingTask?.taskList ?? initialList)

        // Pre-fill fields if editing
        if let task = editingTask {
            _title = State(initialValue: task.title)
            _description = State(initialValue: task.description ?? "")
            _priority = State(initialValue: task.priority)
            _category = State(initialValue: task.category)
            _hasDueDate = State(initialValue: task.dueDate != nil)
            _dueDate = State(initialValue: task.dueDate ?? Date())
            _hasDuration = State(initialValue: task.duration != nil)

            if let duration = task.duration {
                let hours = Int(duration) / 3600
                let minutes = (Int(duration) % 3600) / 60
                _durationHours = State(initialValue: hours)
                _durationMinutes = State(initialValue: minutes)
            }

            _tags = State(initialValue: task.tags.joined(separator: ", "))
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // Title section
                Section(header: Text("Task Details")) {
                    TextField("Task title", text: $title)
                        .dynamicFont(size: 16, fontManager: fontManager)

                    ZStack(alignment: .topLeading) {
                        if description.isEmpty {
                            Text("Description (optional)")
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 4)
                        }
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .dynamicFont(size: 14, fontManager: fontManager)
                    }
                }

                // Priority & Category
                Section(header: Text("Organization")) {
                    // Priority selector with expandable options showing custom icons
                    VStack(alignment: .leading, spacing: 0) {
                        // Selected priority display (tap to expand/collapse)
                        Button(action: {
                            withAnimation {
                                showPriorityOptions.toggle()
                            }
                        }) {
                            HStack {
                                Text("Priority")
                                    .foregroundColor(.primary)
                                    .dynamicFont(size: 16, fontManager: fontManager)
                                Spacer()
                                HStack(spacing: 8) {
                                    priorityIconView(for: priority)
                                        .frame(width: 20, height: 20)
                                    Text(priority.rawValue)
                                        .foregroundColor(.secondary)
                                        .dynamicFont(size: 16, fontManager: fontManager)
                                    Image(systemName: showPriorityOptions ? "chevron.up" : "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())

                        // Expandable options with custom icons
                        if showPriorityOptions {
                            VStack(spacing: 0) {
                                ForEach(TaskPriority.allCases, id: \.self) { priorityOption in
                                    Button(action: {
                                        withAnimation {
                                            priority = priorityOption
                                            showPriorityOptions = false
                                        }
                                    }) {
                                        HStack(spacing: 12) {
                                            priorityIconView(for: priorityOption)
                                                .frame(width: 22, height: 22)
                                            Text(priorityOption.rawValue)
                                                .foregroundColor(.primary)
                                                .dynamicFont(size: 16, fontManager: fontManager)
                                            Spacer()
                                            if priority == priorityOption {
                                                Image(systemName: "checkmark")
                                                    .foregroundColor(.blue)
                                                    .font(.system(size: 14, weight: .semibold))
                                            }
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(priority == priorityOption ? Color.blue.opacity(0.1) : Color.clear)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    if priorityOption != TaskPriority.allCases.last {
                                        Divider()
                                            .padding(.leading, 50)
                                    }
                                }
                            }
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.vertical, 4)

                    Picker("Category", selection: $category) {
                        ForEach(TaskCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }

                    Picker("List", selection: $selectedList) {
                        ForEach(TaskList.allCases, id: \.self) { list in
                            HStack {
                                Image(systemName: list.icon)
                                Text(list.rawValue)
                            }
                            .tag(list)
                        }
                    }
                }

                // Due Date
                Section(header: Text("Scheduling")) {
                    Toggle("Set Due Date", isOn: $hasDueDate)
                        .dynamicFont(size: 16, fontManager: fontManager)

                    if hasDueDate {
                        DatePicker(
                            "Due Date",
                            selection: $dueDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .dynamicFont(size: 16, fontManager: fontManager)
                    }

                    Toggle("Estimate Duration", isOn: $hasDuration)
                        .dynamicFont(size: 16, fontManager: fontManager)

                    if hasDuration {
                        HStack {
                            Text("Duration:")
                                .dynamicFont(size: 16, fontManager: fontManager)

                            Spacer()

                            Picker("Hours", selection: $durationHours) {
                                ForEach(0..<24) { hour in
                                    Text("\(hour)h").tag(hour)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 80)

                            Picker("Minutes", selection: $durationMinutes) {
                                ForEach([0, 15, 30, 45], id: \.self) { minute in
                                    Text("\(minute)m").tag(minute)
                                }
                            }
                            .pickerStyle(WheelPickerStyle())
                            .frame(width: 80)
                        }
                    }
                }

                // Tags
                Section(header: Text("Tags (Optional)")) {
                    TextField("Comma-separated tags", text: $tags)
                        .dynamicFont(size: 14, fontManager: fontManager)

                    if !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(parsedTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 12))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }

                // Type indicator
                Section {
                    HStack {
                        Image(systemName: linkedEventId != nil ? "link.circle.fill" : "tray.fill")
                            .foregroundColor(linkedEventId != nil ? .blue : .orange)
                        Text(linkedEventId != nil ? "Event-Linked Task" : "Standalone Task")
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(editingTask == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editingTask == nil ? "Add" : "Save") {
                        saveTask()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }

    private var parsedTags: [String] {
        tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    // Old priority colors from TaskDetailView
    private func priorityColor(for priority: TaskPriority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .yellow
        case .low: return .green
        case .none: return .black
        case .urgent: return .red
        }
    }

    // Old priority icon view from TaskDetailView
    @ViewBuilder
    private func priorityIconView(for priority: TaskPriority) -> some View {
        let color = priorityColor(for: priority)
        let size: CGFloat = 22

        switch priority {
        case .high:
            // Rounded square with 3 exclamation marks
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: size, height: size)
                HStack(spacing: 1) {
                    Text("!")
                        .font(.system(size: size * 0.5, weight: .bold))
                    Text("!")
                        .font(.system(size: size * 0.5, weight: .bold))
                    Text("!")
                        .font(.system(size: size * 0.5, weight: .bold))
                }
            }
            .foregroundColor(color)
        case .medium:
            // Rounded square with 2 exclamation marks
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: size, height: size)
                HStack(spacing: 2) {
                    Text("!")
                        .font(.system(size: size * 0.55, weight: .bold))
                    Text("!")
                        .font(.system(size: size * 0.55, weight: .bold))
                }
            }
            .foregroundColor(color)
        case .low:
            // Rounded square with 1 exclamation mark
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: size, height: size)
                Text("!")
                    .font(.system(size: size * 0.6, weight: .bold))
            }
            .foregroundColor(color)
        case .none:
            // Circle with diagonal line (3/4 diameter)
            ZStack {
                Circle()
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: size, height: size)
                Path { path in
                    let lineLength = size * 0.75 / sqrt(2)
                    let centerX = size / 2
                    let centerY = size / 2
                    let offset = lineLength / 2
                    path.move(to: CGPoint(x: centerX - offset, y: centerY + offset))
                    path.addLine(to: CGPoint(x: centerX + offset, y: centerY - offset))
                }
                .stroke(color, lineWidth: 2)
                .frame(width: size, height: size)
            }
            .foregroundColor(color)
        case .urgent:
            // Same as high priority but with triangle
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(color, lineWidth: 2)
                    .frame(width: size, height: size)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: size * 0.6, weight: .bold))
            }
            .foregroundColor(color)
        }
    }

    private func saveTask() {
        let duration: TimeInterval? = hasDuration ? TimeInterval(durationHours * 3600 + durationMinutes * 60) : nil

        if let existingTask = editingTask, let eventId = eventIdForEditing {
            // Edit mode - update existing task
            var updatedTask = existingTask
            updatedTask.title = title
            updatedTask.description = description.isEmpty ? nil : description
            updatedTask.priority = priority
            updatedTask.category = category
            updatedTask.dueDate = hasDueDate ? dueDate : nil
            updatedTask.tags = parsedTags
            updatedTask.duration = duration
            updatedTask.taskList = selectedList

            taskManager.updateTask(updatedTask, for: eventId)
        } else {
            // Add mode - create new task
            let newTask = EventTask(
                title: title,
                description: description.isEmpty ? nil : description,
                isCompleted: false,
                priority: priority,
                category: category,
                timing: .before(hours: 24), // Default timing
                dueDate: hasDueDate ? dueDate : nil,
                tags: parsedTags,
                linkedEventId: linkedEventId,
                duration: duration,
                taskList: selectedList
            )

            // If standalone task (no linked event), we need to create a placeholder entry
            if let eventId = linkedEventId {
                // Event-linked task
                taskManager.addTask(newTask, to: eventId)
            } else {
                // Standalone task - use a special "standalone" key
                let standaloneEventId = "standalone-\(newTask.id.uuidString)"
                taskManager.addTask(newTask, to: standaloneEventId)
            }
        }

        dismiss()
    }
}
