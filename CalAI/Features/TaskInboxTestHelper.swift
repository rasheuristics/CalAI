import Foundation

/// Helper for testing task list filtering
struct TaskInboxTestHelper {

    /// Create sample tasks for testing
    static func createSampleTasks() {
        let taskManager = EventTaskManager.shared

        // Inbox task (no due date)
        let inboxTask = EventTask(
            title: "Review project proposal",
            description: "Check the new project proposal document",
            priority: .medium,
            category: .research,
            linkedEventId: nil,
            taskList: .inbox
        )
        taskManager.addTask(inboxTask, to: "standalone-inbox-1")

        // Today task
        let todayTask = EventTask(
            title: "Team standup meeting prep",
            description: "Prepare updates for team standup",
            priority: .high,
            category: .preparation,
            dueDate: Date(), // Today
            linkedEventId: nil,
            duration: 1800, // 30 minutes
            taskList: .today
        )
        taskManager.addTask(todayTask, to: "standalone-today-1")

        // Upcoming task (3 days from now)
        let upcomingTask = EventTask(
            title: "Prepare Q4 presentation",
            description: "Create slides for Q4 review meeting",
            priority: .medium,
            category: .preparation,
            dueDate: Calendar.current.date(byAdding: .day, value: 3, to: Date())!,
            linkedEventId: nil,
            duration: 7200, // 2 hours
            taskList: .upcoming
        )
        taskManager.addTask(upcomingTask, to: "standalone-upcoming-1")

        // Someday task (30 days from now)
        let somedayTask = EventTask(
            title: "Research new productivity tools",
            description: "Explore alternatives for task management",
            priority: .low,
            category: .research,
            dueDate: Calendar.current.date(byAdding: .day, value: 30, to: Date())!,
            linkedEventId: nil,
            taskList: .someday
        )
        taskManager.addTask(somedayTask, to: "standalone-someday-1")

        print("✅ Created 4 sample tasks for testing Task Inbox")
        print("📥 Inbox: \(taskManager.getTaskCountForList(.inbox)) tasks")
        print("📅 Today: \(taskManager.getTaskCountForList(.today)) tasks")
        print("📆 Upcoming: \(taskManager.getTaskCountForList(.upcoming)) tasks")
        print("💭 Someday: \(taskManager.getTaskCountForList(.someday)) tasks")
    }

    /// Clear all standalone tasks
    static func clearStandaloneTasks() {
        let taskManager = EventTaskManager.shared
        let standaloneTasks = taskManager.getStandaloneTasks()

        for task in standaloneTasks {
            if let linkedEventId = task.linkedEventId {
                taskManager.deleteTask(task.id, from: linkedEventId)
            }
        }

        print("🗑️ Cleared all standalone tasks")
    }

    /// Print task list summary
    static func printTaskSummary() {
        let taskManager = EventTaskManager.shared

        print("\n📊 Task List Summary:")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        for list in TaskList.allCases {
            let tasks = taskManager.getTasksForList(list)
            print("\(list.icon) \(list.rawValue): \(tasks.count) tasks")

            for (index, task) in tasks.enumerated() {
                let checkbox = task.isCompleted ? "✅" : "⬜️"
                print("  \(index + 1). \(checkbox) \(task.title)")
                if let dueDate = task.dueDate {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .short
                    print("     Due: \(formatter.string(from: dueDate))")
                }
            }
        }

        print("\n🎯 Standalone tasks: \(taskManager.getStandaloneTasks().count)")
        print("🔗 Event-linked tasks: \(taskManager.getEventLinkedTasks().count)")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
}
