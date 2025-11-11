import Foundation
import EventKit
import SwiftUI
import Combine

class PostMeetingService: ObservableObject {
    static let shared = PostMeetingService()

    @Published var recentlyCompletedMeetings: [MeetingFollowUp] = []
    @Published var showPostMeetingSummary: Bool = false
    @Published var currentMeetingSummary: MeetingFollowUp?

    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private var processedEventIds: Set<String> = []

    private var calendarManager: CalendarManager?
    private let parser = NaturalLanguageParser()

    private init() {
        loadPersistedData()
        startMonitoring()
    }

    func configure(calendarManager: CalendarManager) {
        self.calendarManager = calendarManager
    }

    func startMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkForCompletedMeetings()
        }
        checkForCompletedMeetings()
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func checkForCompletedMeetings() {
        guard let calendarManager = calendarManager else { return }
        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600)
        let recentlyCompleted = calendarManager.unifiedEvents.filter {
            $0.endDate > oneHourAgo && $0.endDate <= now && !processedEventIds.contains($0.id) && !$0.isAllDay && $0.endDate.timeIntervalSince($0.startDate) >= 900
        }
        for event in recentlyCompleted {
            processCompletedMeeting(event)
        }
    }

    func processCompletedMeeting(_ event: UnifiedEvent, notes: String? = nil) {
        guard !processedEventIds.contains(event.id) else { return }
        processedEventIds.insert(event.id)

        Task {
            let followUp = await extractFollowUpWithAI(for: event, notes: notes)

            await MainActor.run {
                self.recentlyCompletedMeetings.insert(followUp, at: 0)

                // Directly create EventTasks for each action item
                self.createEventTasksFromActionItems(followUp.actionItems, for: event)

                self.currentMeetingSummary = followUp
                self.showPostMeetingSummary = true
                self.persistData()
            }
        }
    }

    private func extractFollowUpWithAI(for event: UnifiedEvent, notes: String?) async -> MeetingFollowUp {
        let meetingNotes = notes ?? event.description ?? "No notes provided."

        // Try on-device AI first if available
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), Config.aiProvider == .onDevice {
            if let enhancedFollowUp = try? await extractFollowUpWithOnDeviceAI(for: event, notes: meetingNotes) {
                return enhancedFollowUp
            }
            // Fall through to cloud AI if on-device fails
        }
        #endif

        // Cloud AI fallback
        let summaryPrompt = "Generate a concise 2-3 sentence meeting summary for an event titled '\(event.title)' with these notes: \(meetingNotes)"
        let actionItemsPrompt = "Analyze the following text and extract a list of action items, each on a new line. If none, respond with an empty string. Text: \(meetingNotes)"
        let decisionsPrompt = "Analyze the following text and extract a list of key decisions, each on a new line. If none, respond with an empty string. Text: \(meetingNotes)"

        async let summaryResult = try? await parser.generateText(prompt: summaryPrompt, maxTokens: 200)
        async let actionItemsResult = try? await parser.generateText(prompt: actionItemsPrompt, maxTokens: 300)
        async let decisionsResult = try? await parser.generateText(prompt: decisionsPrompt, maxTokens: 200)

        let (summary, actionItemsText, decisionsText) = await (summaryResult, actionItemsResult, decisionsResult)

        let aiActionItems = (actionItemsText ?? "").split(separator: "\n").map { 
            ActionItem(id: UUID(), title: String($0), description: nil, assignee: nil, dueDate: nil, priority: .medium, category: .task, isCompleted: false, completedDate: nil, sourceText: String($0))
        }
        let aiDecisions = (decisionsText ?? "").split(separator: "\n").map { 
            Decision(id: UUID(), decision: String($0), context: nil, madeBy: nil, timestamp: nil)
        }

        let basicFollowUp = MeetingFollowUpGenerator.generate(for: event, notes: notes, allEvents: self.calendarManager?.unifiedEvents ?? [])
        
        var allActionItems = aiActionItems
        for basicItem in basicFollowUp.actionItems {
            if !allActionItems.contains(where: { $0.title.lowercased() == basicItem.title.lowercased() }) {
                allActionItems.append(basicItem)
            }
        }

        let enhancedSummary = MeetingSummary(
            highlights: summary ?? basicFollowUp.summary.highlights,
            outcomes: basicFollowUp.summary.outcomes,
            topics: basicFollowUp.summary.topics,
            duration: basicFollowUp.summary.duration,
            attendance: basicFollowUp.summary.attendance
        )

        return MeetingFollowUp(
            id: UUID().uuidString,
            eventId: event.id,
            eventTitle: event.title,
            meetingDate: event.startDate,
            summary: enhancedSummary,
            actionItems: allActionItems,
            decisions: aiDecisions.isEmpty ? basicFollowUp.decisions : aiDecisions,
            followUpMeetings: basicFollowUp.followUpMeetings,
            participants: basicFollowUp.participants,
            createdAt: Date()
        )
    }

    func completeActionItem(_ itemId: UUID) {
        // Update in meeting follow-up data
        for i in 0..<recentlyCompletedMeetings.count {
            if let itemIndex = recentlyCompletedMeetings[i].actionItems.firstIndex(where: { $0.id == itemId }) {
                recentlyCompletedMeetings[i].actionItems[itemIndex].isCompleted = true
                recentlyCompletedMeetings[i].actionItems[itemIndex].completedDate = Date()
            }
        }

        // Update the corresponding EventTask
        EventTaskManager.shared.markTaskCompleted(itemId)
        persistData()
    }

    func deleteActionItem(_ itemId: UUID) {
        // Remove from meeting follow-up data
        for i in 0..<recentlyCompletedMeetings.count {
            recentlyCompletedMeetings[i].actionItems.removeAll { $0.id == itemId }
        }

        // Remove the corresponding EventTask
        EventTaskManager.shared.deleteTaskById(itemId)
        persistData()
    }

    /// Create EventTasks directly from ActionItems when meeting is processed
    private func createEventTasksFromActionItems(_ actionItems: [ActionItem], for event: UnifiedEvent) {
        for actionItem in actionItems {
            let eventTask = EventTask(
                id: actionItem.id,
                title: actionItem.title,
                description: actionItem.description,
                isCompleted: actionItem.isCompleted,
                priority: mapActionPriorityToTaskPriority(actionItem.priority),
                category: mapActionCategoryToTaskCategory(actionItem.category),
                timing: .before(hours: 24), // Default timing for meeting tasks
                estimatedMinutes: nil,
                createdAt: Date(),
                completedAt: actionItem.completedDate,
                dueDate: actionItem.dueDate,
                subtasks: [],
                project: nil,
                tags: [],
                linkedEventId: event.id, // Link to the original calendar event
                duration: nil,
                taskList: .inbox, // Default to inbox for meeting tasks
                scheduledTime: nil,
                recurrence: nil,
                templateId: nil,
                autoSchedule: false,
                sourceType: .meeting,
                sourceMeetingId: recentlyCompletedMeetings.first { $0.eventId == event.id }?.id,
                assignee: actionItem.assignee,
                sourceText: actionItem.sourceText
            )

            // Add to EventTaskManager with the event ID as the key
            EventTaskManager.shared.addTask(eventTask, to: event.id)
        }
    }

    private func mapActionPriorityToTaskPriority(_ priority: ActionItem.ActionPriority) -> TaskPriority {
        switch priority {
        case .urgent: return .urgent
        case .high: return .high
        case .medium: return .medium
        case .low: return .low
        }
    }

    private func mapActionCategoryToTaskCategory(_ category: ActionItem.ActionCategory) -> TaskCategory {
        switch category {
        case .task: return .preparation
        case .followUp: return .followUp
        case .research: return .materials
        case .decision: return .preparation
        case .communication: return .logistics
        case .other: return .preparation
        }
    }

    func scheduleFollowUpMeeting(_ followUpMeeting: FollowUpMeeting, for meetingFollowUp: MeetingFollowUp) {
        guard let calendarManager = calendarManager, let suggestedDate = followUpMeeting.suggestedDate else { return }
        let endDate = suggestedDate.addingTimeInterval(3600)
        calendarManager.createEvent(title: followUpMeeting.title, startDate: suggestedDate, endDate: endDate, notes: followUpMeeting.purpose)
        persistData()
    }

    private func schedulePostMeetingNotification(for followUp: MeetingFollowUp) { }

    private func persistData() {
        let encoder = JSONEncoder()
        if let encodedMeetings = try? encoder.encode(recentlyCompletedMeetings) {
            UserDefaults.standard.set(encodedMeetings, forKey: "recentlyCompletedMeetings")
        }
        UserDefaults.standard.set(Array(processedEventIds), forKey: "processedEventIds")
    }

    private func loadPersistedData() {
        let decoder = JSONDecoder()
        if let meetingsData = UserDefaults.standard.data(forKey: "recentlyCompletedMeetings"), let meetings = try? decoder.decode([MeetingFollowUp].self, from: meetingsData) {
            recentlyCompletedMeetings = meetings
        }
        if let processedIds = UserDefaults.standard.array(forKey: "processedEventIds") as? [String] {
            processedEventIds = Set(processedIds)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - On-Device AI Integration

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func extractFollowUpWithOnDeviceAI(for event: UnifiedEvent, notes: String) async throws -> MeetingFollowUp {
        print("🤖 Using on-device AI for meeting insights...")

        // Extract attendees from event
        let attendees: [String] = [] // TODO: Extract from event if available

        // Use on-device AI to analyze meeting notes
        let insights = try await OnDeviceAIService.shared.analyzeMeetingNotes(
            eventTitle: event.title,
            notes: notes,
            attendees: attendees
        )

        print("✅ On-device AI extracted \(insights.actionItems.count) action items")

        // Convert AI action items to our ActionItem model
        let actionItems = insights.actionItems.map { aiItem in
            // Parse due date if provided
            var dueDate: Date? = nil
            if let dueDateStr = aiItem.dueDate, dueDateStr.lowercased() != "unknown" {
                dueDate = parseDateString(dueDateStr)
            }

            // Map priority
            let priority: ActionItem.ActionPriority
            switch aiItem.priority.lowercased() {
            case "urgent": priority = .urgent
            case "high": priority = .high
            case "low": priority = .low
            default: priority = .medium
            }

            return ActionItem(
                id: UUID(),
                title: aiItem.title,
                description: aiItem.context,
                assignee: aiItem.assignee != "Unknown" ? aiItem.assignee : nil,
                dueDate: dueDate,
                priority: priority,
                category: .task,
                isCompleted: false,
                completedDate: nil,
                sourceText: notes
            )
        }

        // Convert decisions
        let decisions = insights.decisions.map { decisionText in
            Decision(
                id: UUID(),
                decision: decisionText,
                context: insights.summary,
                madeBy: nil,
                timestamp: event.startDate
            )
        }

        // Create enhanced summary
        let summary = MeetingSummary(
            highlights: insights.summary,
            outcomes: insights.decisions,
            topics: insights.topics,
            duration: event.endDate.timeIntervalSince(event.startDate), // in seconds
            attendance: attendees.isEmpty ? nil : attendees.joined(separator: ", ")
        )

        // Create follow-up meetings if needed
        var followUpMeetings: [FollowUpMeeting] = []
        if insights.followUpNeeded, let suggestedDate = insights.suggestedFollowUpDate {
            // Parse suggested follow-up date
            if let followUpDate = parseDateString(suggestedDate) {
                followUpMeetings.append(FollowUpMeeting(
                    id: UUID(),
                    title: "Follow-up: \(event.title)",
                    suggestedDate: followUpDate,
                    purpose: "Continue discussion from \(event.title)",
                    attendees: attendees,
                    isScheduled: false
                ))
            }
        }

        return MeetingFollowUp(
            id: UUID().uuidString,
            eventId: event.id,
            eventTitle: event.title,
            meetingDate: event.startDate,
            summary: summary,
            actionItems: actionItems,
            decisions: decisions,
            followUpMeetings: followUpMeetings,
            participants: attendees,
            createdAt: Date()
        )
    }

    private func parseDateString(_ dateStr: String) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        let lowercased = dateStr.lowercased()

        if lowercased.contains("today") {
            return now
        } else if lowercased.contains("tomorrow") {
            return calendar.date(byAdding: .day, value: 1, to: now)
        } else if lowercased.contains("next week") || lowercased.contains("week") {
            return calendar.date(byAdding: .weekOfYear, value: 1, to: now)
        } else if lowercased.contains("monday") {
            return nextWeekday(1, from: now)
        } else if lowercased.contains("tuesday") {
            return nextWeekday(2, from: now)
        } else if lowercased.contains("wednesday") {
            return nextWeekday(3, from: now)
        } else if lowercased.contains("thursday") {
            return nextWeekday(4, from: now)
        } else if lowercased.contains("friday") {
            return nextWeekday(5, from: now)
        }

        return nil
    }

    private func nextWeekday(_ weekday: Int, from date: Date) -> Date? {
        let calendar = Calendar.current
        var components = DateComponents()
        components.weekday = weekday

        return calendar.nextDate(after: date, matching: components, matchingPolicy: .nextTime)
    }
    #endif

}