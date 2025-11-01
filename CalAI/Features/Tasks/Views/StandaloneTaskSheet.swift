import SwiftUI

struct StandaloneTaskSheet: View {
    @ObservedObject var taskManager: EventTaskManager
    @ObservedObject var fontManager: FontManager

    let initialList: TaskList
    let linkedEventId: String?

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

    init(
        taskManager: EventTaskManager,
        fontManager: FontManager,
        initialList: TaskList = .inbox,
        linkedEventId: String? = nil
    ) {
        self.taskManager = taskManager
        self.fontManager = fontManager
        self.initialList = initialList
        self.linkedEventId = linkedEventId
        _selectedList = State(initialValue: initialList)
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
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            HStack {
                                Image(systemName: priority.icon)
                                Text(priority.rawValue)
                            }
                            .tag(priority)
                        }
                    }

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
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addTask()
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

    private func addTask() {
        let duration: TimeInterval? = hasDuration ? TimeInterval(durationHours * 3600 + durationMinutes * 60) : nil

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

        dismiss()
    }
}
