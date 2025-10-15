import Foundation
import EventKit
import SwiftUI
import Combine

class PostMeetingService: ObservableObject {
    static let shared = PostMeetingService()

    @Published var recentlyCompletedMeetings: [MeetingFollowUp] = []
    @Published var pendingActionItems: [ActionItem] = []
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
                self.pendingActionItems.append(contentsOf: followUp.actionItems.filter { !$0.isCompleted })
                self.currentMeetingSummary = followUp
                self.showPostMeetingSummary = true
                self.persistData()
            }
        }
    }

    private func extractFollowUpWithAI(for event: UnifiedEvent, notes: String?) async -> MeetingFollowUp {
        let meetingNotes = notes ?? event.description ?? "No notes provided."

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
        if let index = pendingActionItems.firstIndex(where: { $0.id == itemId }) {
            pendingActionItems[index].isCompleted = true
            pendingActionItems[index].completedDate = Date()
        }
        for i in 0..<recentlyCompletedMeetings.count {
            if let itemIndex = recentlyCompletedMeetings[i].actionItems.firstIndex(where: { $0.id == itemId }) {
                recentlyCompletedMeetings[i].actionItems[itemIndex].isCompleted = true
                recentlyCompletedMeetings[i].actionItems[itemIndex].completedDate = Date()
            }
        }
        persistData()
    }

    func deleteActionItem(_ itemId: UUID) {
        pendingActionItems.removeAll { $0.id == itemId }
        for i in 0..<recentlyCompletedMeetings.count {
            recentlyCompletedMeetings[i].actionItems.removeAll { $0.id == itemId }
        }
        persistData()
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
        if let encodedItems = try? encoder.encode(pendingActionItems) {
            UserDefaults.standard.set(encodedItems, forKey: "pendingActionItems")
        }
        UserDefaults.standard.set(Array(processedEventIds), forKey: "processedEventIds")
    }

    private func loadPersistedData() {
        let decoder = JSONDecoder()
        if let meetingsData = UserDefaults.standard.data(forKey: "recentlyCompletedMeetings"), let meetings = try? decoder.decode([MeetingFollowUp].self, from: meetingsData) {
            recentlyCompletedMeetings = meetings
        }
        if let itemsData = UserDefaults.standard.data(forKey: "pendingActionItems"), let items = try? decoder.decode([ActionItem].self, from: itemsData) {
            pendingActionItems = items
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
}