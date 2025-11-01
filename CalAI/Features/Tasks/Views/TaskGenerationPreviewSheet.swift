import SwiftUI

struct TaskGenerationPreviewSheet: View {
    @ObservedObject var taskManager: EventTaskManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    let generatedTasks: [GeneratedTask]
    let eventId: String
    let eventTitle: String

    @State private var selectedTasks: Set<UUID>
    @State private var isAdding = false

    init(
        taskManager: EventTaskManager,
        fontManager: FontManager,
        generatedTasks: [GeneratedTask],
        eventId: String,
        eventTitle: String
    ) {
        self.taskManager = taskManager
        self.fontManager = fontManager
        self.generatedTasks = generatedTasks
        self.eventId = eventId
        self.eventTitle = eventTitle

        // Pre-select all tasks
        _selectedTasks = State(initialValue: Set(generatedTasks.map { $0.id }))
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)

                        Text("AI-Generated Tasks")
                            .dynamicFont(size: 20, weight: .bold, fontManager: fontManager)

                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    HStack {
                        Text("For: \(eventTitle)")
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemGroupedBackground))

                // Task selection list
                if generatedTasks.isEmpty {
                    emptyStateView
                } else {
                    List {
                        Section(header: Text("Select tasks to add (\(selectedTasks.count) of \(generatedTasks.count) selected)")) {
                            ForEach(generatedTasks) { task in
                                TaskPreviewRow(
                                    task: task,
                                    isSelected: selectedTasks.contains(task.id),
                                    fontManager: fontManager,
                                    onToggle: {
                                        toggleTaskSelection(task.id)
                                    }
                                )
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                }

                // Bottom actions
                VStack(spacing: 12) {
                    Button(action: {
                        toggleSelectAll()
                    }) {
                        HStack {
                            Image(systemName: selectedTasks.count == generatedTasks.count ? "checkmark.circle.fill" : "circle")
                            Text(selectedTasks.count == generatedTasks.count ? "Deselect All" : "Select All")
                                .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.top, 8)

                    Button(action: {
                        addSelectedTasks()
                    }) {
                        HStack {
                            if isAdding {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "plus.circle.fill")
                                Text("Add \(selectedTasks.count) \(selectedTasks.count == 1 ? "Task" : "Tasks")")
                                    .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedTasks.isEmpty ? Color.gray : Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(selectedTasks.isEmpty || isAdding)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
                .background(Color(.systemGroupedBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.orange)

            Text("No Tasks Generated")
                .dynamicFont(size: 20, weight: .semibold, fontManager: fontManager)

            Text("The AI couldn't generate tasks for this event. Try adding some manually.")
                .dynamicFont(size: 14, fontManager: fontManager)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func toggleTaskSelection(_ taskId: UUID) {
        if selectedTasks.contains(taskId) {
            selectedTasks.remove(taskId)
        } else {
            selectedTasks.insert(taskId)
        }
    }

    private func toggleSelectAll() {
        if selectedTasks.count == generatedTasks.count {
            selectedTasks.removeAll()
        } else {
            selectedTasks = Set(generatedTasks.map { $0.id })
        }
    }

    private func addSelectedTasks() {
        isAdding = true

        let tasksToAdd = generatedTasks.filter { selectedTasks.contains($0.id) }

        for generatedTask in tasksToAdd {
            let eventTask = generatedTask.toEventTask(linkedEventId: eventId)
            taskManager.addTask(eventTask, to: eventId)
            print("✅ Added task: \(eventTask.title)")
        }

        print("🎉 Added \(tasksToAdd.count) AI-generated tasks")

        // Small delay for visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isAdding = false
            dismiss()
        }
    }
}

// MARK: - Task Preview Row

struct TaskPreviewRow: View {
    let task: GeneratedTask
    let isSelected: Bool
    let fontManager: FontManager
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 12) {
                // Selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .gray)

                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(task.title)
                        .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                        .foregroundColor(.primary)

                    // Metadata row
                    HStack(spacing: 8) {
                        // Priority
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

                        // Category
                        HStack(spacing: 2) {
                            Image(systemName: task.category.icon)
                                .font(.system(size: 10))
                            Text(task.category.rawValue)
                                .font(.system(size: 11))
                        }
                        .foregroundColor(.secondary)

                        // Timing
                        if case .before(let hours) = task.timing {
                            HStack(spacing: 2) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text("\(hours)h before")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }

                        Spacer()
                    }

                    // Description
                    if let description = task.description, !description.isEmpty {
                        Text(description)
                            .dynamicFont(size: 13, fontManager: fontManager)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
