import SwiftUI

struct ScheduleTaskSheet: View {
    @ObservedObject var taskManager: EventTaskManager
    @ObservedObject var fontManager: FontManager

    let task: EventTask
    let eventId: String

    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date
    @State private var selectedTime: Date

    init(taskManager: EventTaskManager, fontManager: FontManager, task: EventTask, eventId: String) {
        self.taskManager = taskManager
        self.fontManager = fontManager
        self.task = task
        self.eventId = eventId

        // Initialize with current scheduled time or default to now
        let initialDateTime = task.scheduledTime ?? Date()
        _selectedDate = State(initialValue: initialDateTime)
        _selectedTime = State(initialValue: initialDateTime)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Task")) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                            .foregroundColor(.blue)
                        Text(task.title)
                            .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                    }

                    if let duration = task.duration {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundColor(.secondary)
                            Text("Duration: \(formatDuration(duration))")
                                .dynamicFont(size: 14, fontManager: fontManager)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Section(header: Text("Schedule")) {
                    DatePicker(
                        "Date",
                        selection: $selectedDate,
                        displayedComponents: [.date]
                    )
                    .dynamicFont(size: 16, fontManager: fontManager)

                    DatePicker(
                        "Time",
                        selection: $selectedTime,
                        displayedComponents: [.hourAndMinute]
                    )
                    .dynamicFont(size: 16, fontManager: fontManager)
                }

                Section {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scheduled For")
                                .dynamicFont(size: 12, fontManager: fontManager)
                                .foregroundColor(.secondary)
                            Text(formatScheduledTime())
                                .dynamicFont(size: 16, weight: .medium, fontManager: fontManager)
                        }
                    }
                }

                if task.scheduledTime != nil {
                    Section {
                        Button(role: .destructive, action: {
                            unscheduleTask()
                        }) {
                            HStack {
                                Image(systemName: "calendar.badge.minus")
                                Text("Remove from Calendar")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Schedule Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        scheduleTask()
                    }
                }
            }
        }
    }

    private func combineDateAndTime() -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: selectedTime)

        var combined = DateComponents()
        combined.year = dateComponents.year
        combined.month = dateComponents.month
        combined.day = dateComponents.day
        combined.hour = timeComponents.hour
        combined.minute = timeComponents.minute

        return calendar.date(from: combined) ?? Date()
    }

    private func scheduleTask() {
        let scheduledDateTime = combineDateAndTime()
        taskManager.scheduleTask(task.id, at: scheduledDateTime, in: eventId)
        print("📅 Scheduled task '\(task.title)' for \(scheduledDateTime)")
        dismiss()
    }

    private func unscheduleTask() {
        taskManager.unscheduleTask(task.id, in: eventId)
        print("📅 Unscheduled task '\(task.title)'")
        dismiss()
    }

    private func formatScheduledTime() -> String {
        let scheduledDateTime = combineDateAndTime()
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d 'at' h:mm a"
        return formatter.string(from: scheduledDateTime)
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
}
