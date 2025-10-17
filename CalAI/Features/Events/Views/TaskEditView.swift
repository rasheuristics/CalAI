import SwiftUI

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

                    // Add Detail Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Add Detail")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        }

                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .dynamicFont(size: 15, fontManager: fontManager)
                    }
                    .padding(.horizontal)

                    Divider()
                        .padding(.horizontal)

                    // Add Date/Time Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Add Date/Time")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)

                            Spacer()

                            Toggle("", isOn: $hasDueDate)
                                .labelsHidden()
                        }

                        if hasDueDate {
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
                            Image(systemName: "list.bullet.indent")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Add Subtasks")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        }

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
                    .padding(.horizontal)

                    Spacer()
                        .frame(height: 20)

                    // Mark Completed Button
                    Button(action: markCompleted) {
                        HStack {
                            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            Text(task.isCompleted ? "Mark as Incomplete" : "Mark as Completed")
                                .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(task.isCompleted ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
                .padding(.top)
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

// MARK: - Preview
struct TaskEditView_Previews: PreviewProvider {
    static var previews: some View {
        TaskEditView(
            task: .constant(EventTask(
                title: "Sample Task",
                description: "This is a sample task",
                dueDate: Date(),
                subtasks: [
                    EventSubtask(title: "Subtask 1"),
                    EventSubtask(title: "Subtask 2", isCompleted: true)
                ]
            )),
            fontManager: FontManager.shared,
            onSave: { _ in }
        )
    }
}
