import Foundation
import EventKit
import SwiftUI
import Combine

/// Service that detects meeting completion and triggers post-meeting workflows
class PostMeetingService: ObservableObject {
    static let shared = PostMeetingService()

    @Published var recentlyCompletedMeetings: [MeetingFollowUp] = []
    @Published var pendingActionItems: [ActionItem] = []
    @Published var showPostMeetingSummary: Bool = false
    @Published var currentMeetingSummary: MeetingFollowUp?

    private var cancellables = Set<AnyCancellable>()
    private var monitoringTimer: Timer?
    private var processedEventIds: Set<String> = []

    // Dependencies
    private var calendarManager: CalendarManager?
    private var aiManager: AIManager?

    private init() {
        loadPersistedData()
        startMonitoring()
    }

    // MARK: - Dependency Injection

    func configure(calendarManager: CalendarManager, aiManager: AIManager) {
        self.calendarManager = calendarManager
        self.aiManager = aiManager
    }

    // MARK: - Meeting Completion Monitoring

    func startMonitoring() {
        // Check for completed meetings every 5 minutes
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.checkForCompletedMeetings()
        }

        // Initial check
        checkForCompletedMeetings()
    }

    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }

    private func checkForCompletedMeetings() {
        guard let calendarManager = calendarManager else { return }

        let now = Date()
        let oneHourAgo = now.addingTimeInterval(-3600) // Check last hour

        // Get events that ended in the last hour
        let recentlyCompleted = calendarManager.unifiedEvents.filter { event in
            event.endDate > oneHourAgo &&
            event.endDate <= now &&
            !processedEventIds.contains(event.id) &&
            !event.isAllDay &&
            event.endDate.timeIntervalSince(event.startDate) >= 900 // At least 15 min meeting
        }

        for event in recentlyCompleted {
            processCompletedMeeting(event)
        }
    }

    /// Manually trigger post-meeting processing for a specific event
    func processCompletedMeeting(_ event: UnifiedEvent, notes: String? = nil) {
        guard !processedEventIds.contains(event.id) else { return }

        processedEventIds.insert(event.id)

        // Check if we should use AI for enhanced extraction
        if let aiManager = aiManager {
            // Use AI to extract action items
            extractActionItemsWithAI(for: event, notes: notes) { [weak self] followUp in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.recentlyCompletedMeetings.insert(followUp, at: 0)
                    self.pendingActionItems.append(contentsOf: followUp.actionItems.filter { !$0.isCompleted })
                    self.currentMeetingSummary = followUp
                    self.showPostMeetingSummary = true
                    self.persistData()

                    // Schedule notification
                    self.schedulePostMeetingNotification(for: followUp)
                }
            }
        } else {
            // Fallback to basic extraction
            let followUp = MeetingFollowUpGenerator.generate(
                for: event,
                notes: notes,
                allEvents: calendarManager?.unifiedEvents ?? []
            )

            DispatchQueue.main.async {
                self.recentlyCompletedMeetings.insert(followUp, at: 0)
                self.pendingActionItems.append(contentsOf: followUp.actionItems.filter { !$0.isCompleted })
                self.currentMeetingSummary = followUp
                self.showPostMeetingSummary = true
                self.persistData()

                // Schedule notification
                self.schedulePostMeetingNotification(for: followUp)
            }
        }
    }

    // MARK: - AI-Powered Action Item Extraction

    private func extractActionItemsWithAI(for event: UnifiedEvent, notes: String?, completion: @escaping (MeetingFollowUp) -> Void) {
        guard let aiManager = aiManager else {
            // Fallback
            let followUp = MeetingFollowUpGenerator.generate(for: event, notes: notes, allEvents: calendarManager?.unifiedEvents ?? [])
            completion(followUp)
            return
        }

        let meetingContext = """
        Meeting: \(event.title)
        Date: \(formatDate(event.startDate))
        Duration: \(Int(event.endDate.timeIntervalSince(event.startDate) / 60)) minutes
        Location: \(event.location ?? "Not specified")
        Notes: \(notes ?? event.description ?? "No notes provided")
        """

        aiManager.extractMeetingActionItems(context: meetingContext) { [weak self] actionItems, summary, decisions in
            guard let self = self else { return }

            // Combine AI-extracted items with basic extraction
            var allActionItems = actionItems

            // Add basic extraction as backup
            let basicFollowUp = MeetingFollowUpGenerator.generate(
                for: event,
                notes: notes,
                allEvents: self.calendarManager?.unifiedEvents ?? []
            )

            // Merge action items (avoid duplicates)
            for basicItem in basicFollowUp.actionItems {
                if !allActionItems.contains(where: { $0.title.lowercased() == basicItem.title.lowercased() }) {
                    allActionItems.append(basicItem)
                }
            }

            // Create enhanced follow-up
            let enhancedSummary = MeetingSummary(
                highlights: summary ?? basicFollowUp.summary.highlights,
                outcomes: basicFollowUp.summary.outcomes,
                topics: basicFollowUp.summary.topics,
                duration: basicFollowUp.summary.duration,
                attendance: basicFollowUp.summary.attendance
            )

            let followUp = MeetingFollowUp(
                id: UUID().uuidString,
                eventId: event.id,
                eventTitle: event.title,
                meetingDate: event.startDate,
                summary: enhancedSummary,
                actionItems: allActionItems,
                decisions: decisions.isEmpty ? basicFollowUp.decisions : decisions,
                followUpMeetings: basicFollowUp.followUpMeetings,
                participants: basicFollowUp.participants,
                createdAt: Date()
            )

            completion(followUp)
        }
    }

    // MARK: - Action Item Management

    func completeActionItem(_ itemId: UUID) {
        // Update in pending action items
        if let index = pendingActionItems.firstIndex(where: { $0.id == itemId }) {
            var updatedItem = pendingActionItems[index]
            updatedItem.isCompleted = true
            updatedItem.completedDate = Date()
            pendingActionItems[index] = updatedItem
        }

        // Update in meeting follow-ups
        for (meetingIndex, meeting) in recentlyCompletedMeetings.enumerated() {
            if let itemIndex = meeting.actionItems.firstIndex(where: { $0.id == itemId }) {
                var updatedMeeting = meeting
                var updatedItem = updatedMeeting.actionItems[itemIndex]
                updatedItem.isCompleted = true
                updatedItem.completedDate = Date()
                var updatedItems = updatedMeeting.actionItems
                updatedItems[itemIndex] = updatedItem

                let newFollowUp = MeetingFollowUp(
                    id: updatedMeeting.id,
                    eventId: updatedMeeting.eventId,
                    eventTitle: updatedMeeting.eventTitle,
                    meetingDate: updatedMeeting.meetingDate,
                    summary: updatedMeeting.summary,
                    actionItems: updatedItems,
                    decisions: updatedMeeting.decisions,
                    followUpMeetings: updatedMeeting.followUpMeetings,
                    participants: updatedMeeting.participants,
                    createdAt: updatedMeeting.createdAt
                )

                recentlyCompletedMeetings[meetingIndex] = newFollowUp
            }
        }

        persistData()
    }

    func deleteActionItem(_ itemId: UUID) {
        pendingActionItems.removeAll { $0.id == itemId }

        for (meetingIndex, meeting) in recentlyCompletedMeetings.enumerated() {
            let filteredItems = meeting.actionItems.filter { $0.id != itemId }
            if filteredItems.count != meeting.actionItems.count {
                let newFollowUp = MeetingFollowUp(
                    id: meeting.id,
                    eventId: meeting.eventId,
                    eventTitle: meeting.eventTitle,
                    meetingDate: meeting.meetingDate,
                    summary: meeting.summary,
                    actionItems: filteredItems,
                    decisions: meeting.decisions,
                    followUpMeetings: meeting.followUpMeetings,
                    participants: meeting.participants,
                    createdAt: meeting.createdAt
                )
                recentlyCompletedMeetings[meetingIndex] = newFollowUp
            }
        }

        persistData()
    }

    // MARK: - Follow-Up Scheduling

    func scheduleFollowUpMeeting(_ followUpMeeting: FollowUpMeeting, for meetingFollowUp: MeetingFollowUp) {
        guard let calendarManager = calendarManager,
              let suggestedDate = followUpMeeting.suggestedDate else { return }

        // Create the follow-up event
        let endDate = suggestedDate.addingTimeInterval(3600) // 1 hour default

        calendarManager.createEvent(
            title: followUpMeeting.title,
            startDate: suggestedDate,
            endDate: endDate,
            location: nil,
            notes: followUpMeeting.purpose
        )

        // Mark as scheduled
        for (meetingIndex, meeting) in recentlyCompletedMeetings.enumerated() {
            if meeting.id == meetingFollowUp.id {
                var updatedMeetings = meeting.followUpMeetings
                if let followUpIndex = updatedMeetings.firstIndex(where: { $0.id == followUpMeeting.id }) {
                    var updated = updatedMeetings[followUpIndex]
                    updated.isScheduled = true
                    updatedMeetings[followUpIndex] = updated

                    let newFollowUp = MeetingFollowUp(
                        id: meeting.id,
                        eventId: meeting.eventId,
                        eventTitle: meeting.eventTitle,
                        meetingDate: meeting.meetingDate,
                        summary: meeting.summary,
                        actionItems: meeting.actionItems,
                        decisions: meeting.decisions,
                        followUpMeetings: updatedMeetings,
                        participants: meeting.participants,
                        createdAt: meeting.createdAt
                    )

                    recentlyCompletedMeetings[meetingIndex] = newFollowUp
                }
            }
        }

        persistData()
    }

    // MARK: - Notifications

    private func schedulePostMeetingNotification(for followUp: MeetingFollowUp) {
        // TODO: Schedule local notification with action items summary
        // This would integrate with UNUserNotificationCenter
    }

    // MARK: - Persistence

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

        if let meetingsData = UserDefaults.standard.data(forKey: "recentlyCompletedMeetings"),
           let meetings = try? decoder.decode([MeetingFollowUp].self, from: meetingsData) {
            recentlyCompletedMeetings = meetings
        }

        if let itemsData = UserDefaults.standard.data(forKey: "pendingActionItems"),
           let items = try? decoder.decode([ActionItem].self, from: itemsData) {
            pendingActionItems = items
        }

        if let processedIds = UserDefaults.standard.array(forKey: "processedEventIds") as? [String] {
            processedEventIds = Set(processedIds)
        }
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

