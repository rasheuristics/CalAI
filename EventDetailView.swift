import SwiftUI
import EventKit

struct EventDetailView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    let event: UnifiedEvent
    @State private var showEditView = false
    @State private var showShareView = false
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deletionError: String?
    @State private var showingDeletionError = false

    // Phase 4: AI Task Generation
    @StateObject private var aiManager = AIManager()
    @StateObject private var taskManager = EventTaskManager.shared
    @State private var showTaskPreview = false
    @State private var generatedTasks: [GeneratedTask] = []
    @State private var isGeneratingTasks = false
    @State private var taskGenerationError: String?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Title Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text(event.title)
                            .dynamicFont(size: 28, weight: .bold, fontManager: fontManager)
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)

                    // Date & Time Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatDate(event.startDate))
                                    .dynamicFont(size: 17, weight: .medium, fontManager: fontManager)

                                if !event.isAllDay {
                                    Text("\(formatTime(event.startDate)) - \(formatTime(event.endDate))")
                                        .dynamicFont(size: 15, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("All Day")
                                        .dynamicFont(size: 15, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Location Section
                    if let location = event.location, !location.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                ClickableTextView(location, fontSize: 17, fontManager: fontManager)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Video Meeting Join Button
                    if let videoMeeting = detectVideoMeeting() {
                        Button(action: {
                            openVideoMeeting(videoMeeting.url)
                        }) {
                            HStack {
                                Image(systemName: videoMeeting.platform.icon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.white)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Join \(videoMeeting.platform.rawValue)")
                                        .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)

                                    if let meetingID = videoMeeting.meetingID {
                                        Text("ID: \(meetingID)")
                                            .dynamicFont(size: 13, fontManager: fontManager)
                                            .opacity(0.9)
                                    }
                                }

                                Spacer()

                                Image(systemName: "arrow.up.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            .foregroundColor(.white)
                            .padding()
                            .background(platformColor(for: videoMeeting.platform))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)
                    }

                    // Organizer Section
                    if let organizer = event.organizer, !organizer.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Organizer")
                                        .dynamicFont(size: 13, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                    Text(organizer)
                                        .dynamicFont(size: 17, fontManager: fontManager)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // URL Section
                    if let urlString = eventURL, !urlString.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "link")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("URL")
                                        .dynamicFont(size: 13, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                    Link(urlString, destination: URL(string: urlString) ?? URL(string: "https://")!)
                                        .dynamicFont(size: 17, fontManager: fontManager)
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Repeat Section
                    if let recurrenceRules = eventRecurrence, !recurrenceRules.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
                                Image(systemName: "repeat")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Repeat")
                                        .dynamicFont(size: 13, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                    Text(recurrenceRules)
                                        .dynamicFont(size: 17, fontManager: fontManager)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Attendees Section
                    if let attendees = eventAttendees, !attendees.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Attendees")
                                        .dynamicFont(size: 13, fontManager: fontManager)
                                        .foregroundColor(.secondary)

                                    ForEach(attendees, id: \.self) { attendee in
                                        Text(attendee)
                                            .dynamicFont(size: 17, fontManager: fontManager)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Notes Section
                    if let notes = event.description, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "note.text")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Notes")
                                        .dynamicFont(size: 13, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                    ClickableTextView(notes, fontSize: 17, fontManager: fontManager)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Attachments Section
                    if let attachments = eventAttachments, !attachments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "paperclip")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Attachments")
                                        .dynamicFont(size: 13, fontManager: fontManager)
                                        .foregroundColor(.secondary)

                                    ForEach(attachments, id: \.self) { attachment in
                                        Text(attachment)
                                            .dynamicFont(size: 17, fontManager: fontManager)
                                            .foregroundColor(.blue)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Calendar Source Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "cloud.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Calendar Source")
                                    .dynamicFont(size: 13, fontManager: fontManager)
                                    .foregroundColor(.secondary)
                                Text(event.sourceLabel)
                                    .dynamicFont(size: 17, weight: .medium, fontManager: fontManager)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // AI Task Generation Button (Phase 4)
                    Button(action: {
                        generateAITasks()
                    }) {
                        HStack {
                            Spacer()
                            if isGeneratingTasks {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.9)
                                Text("Generating...")
                                    .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 16))
                                Text("Generate AI Tasks")
                                    .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                            }
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(isGeneratingTasks ? Color.blue.opacity(0.7) : Color.blue)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .disabled(isGeneratingTasks)

                    // Delete Button Section
                    Button(action: {
                        print("🔴🔴🔴 DELETE BUTTON TAPPED IN EVENTDETAILVIEW 🔴🔴🔴")
                        print("🗑️ Delete button tapped - showing confirmation alert")
                        print("🗑️ Current isDeleting state: \(isDeleting)")
                        print("🗑️ Current showingDeleteConfirmation: \(showingDeleteConfirmation)")
                        showingDeleteConfirmation = true
                        print("🗑️ Set showingDeleteConfirmation to: \(showingDeleteConfirmation)")
                    }) {
                        HStack {
                            Spacer()
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16))
                            Text("Delete Event")
                                .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .disabled(isDeleting)
                    .allowsHitTesting(!isDeleting)

                    Spacer(minLength: 40)
                }
                .padding(.vertical)
            }
            .navigationTitle("Event Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                                .dynamicFont(size: 17, fontManager: fontManager)
                        }
                    }
                }

                // Join Meeting button (appears first if video meeting detected)
                if let videoMeeting = detectVideoMeeting() {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            openVideoMeeting(videoMeeting.url)
                        }) {
                            Image(systemName: videoMeeting.platform.icon)
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(platformColor(for: videoMeeting.platform))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showShareView = true
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .medium))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showEditView = true
                    }
                    .dynamicFont(size: 17, fontManager: fontManager)
                }
            }
            .sheet(isPresented: $showEditView) {
                EditEventView(
                    calendarManager: calendarManager,
                    fontManager: fontManager,
                    event: event
                )
            }
            .sheet(isPresented: $showShareView) {
                EventShareView(
                    event: event,
                    calendarManager: calendarManager,
                    fontManager: fontManager
                )
            }
            .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    print("🔴 ALERT: Delete cancelled by user")
                }
                Button("Delete", role: .destructive) {
                    print("🔴🔴🔴 ALERT: User confirmed deletion - calling deleteEvent() 🔴🔴🔴")
                    deleteEvent()
                }
            } message: {
                Text("Are you sure you want to delete '\(event.title)'? This action cannot be undone.")
            }
            .onChange(of: showingDeleteConfirmation) { newValue in
                print("🔴 showingDeleteConfirmation changed to: \(newValue)")
            }
            .alert("Deletion Failed", isPresented: $showingDeletionError) {
                Button("OK", role: .cancel) {
                    deletionError = nil
                }
            } message: {
                Text(deletionError ?? "An unknown error occurred while deleting the event.")
            }
            .sheet(isPresented: $showTaskPreview) {
                TaskGenerationPreviewSheet(
                    taskManager: taskManager,
                    fontManager: fontManager,
                    generatedTasks: generatedTasks,
                    eventId: event.id,
                    eventTitle: event.title
                )
            }
            .alert("Task Generation Error", isPresented: .constant(taskGenerationError != nil)) {
                Button("OK", role: .cancel) {
                    taskGenerationError = nil
                }
            } message: {
                Text(taskGenerationError ?? "An error occurred while generating tasks.")
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

    // MARK: - Computed Properties for Additional Event Data

    private var eventURL: String? {
        // Try to extract URL from the event
        if let ekEvent = event.originalEvent as? EKEvent {
            return ekEvent.url?.absoluteString
        }
        // For Google/Outlook events, URL might be in description or custom field
        return nil
    }

    private var eventRecurrence: String? {
        // Try to get recurrence rules from EKEvent
        if let ekEvent = event.originalEvent as? EKEvent,
           let recurrenceRules = ekEvent.recurrenceRules,
           !recurrenceRules.isEmpty {
            // Format the recurrence rule into human-readable text
            let rule = recurrenceRules[0]
            return formatRecurrenceRule(rule)
        }
        return nil
    }

    private var eventAttendees: [String]? {
        // Try to get attendees from EKEvent
        if let ekEvent = event.originalEvent as? EKEvent,
           let attendees = ekEvent.attendees,
           !attendees.isEmpty {
            return attendees.compactMap { participant in
                if let name = participant.name, !name.isEmpty {
                    return name
                } else {
                    // Extract email from URL (usually in format "mailto:email@example.com")
                    let urlString = participant.url.absoluteString
                    return urlString.replacingOccurrences(of: "mailto:", with: "")
                }
            }
        }
        return nil
    }

    private var eventAttachments: [String]? {
        // Try to get attachments from EKEvent
        // Note: EKEvent doesn't directly expose attachments in EventKit
        // Attachments are typically handled through the calendar app
        // For now, we'll return nil since there's no direct API access
        return nil
    }

    private func formatRecurrenceRule(_ rule: EKRecurrenceRule) -> String {
        switch rule.frequency {
        case .daily:
            return rule.interval == 1 ? "Daily" : "Every \(rule.interval) days"
        case .weekly:
            return rule.interval == 1 ? "Weekly" : "Every \(rule.interval) weeks"
        case .monthly:
            return rule.interval == 1 ? "Monthly" : "Every \(rule.interval) months"
        case .yearly:
            return rule.interval == 1 ? "Yearly" : "Every \(rule.interval) years"
        @unknown default:
            return "Custom"
        }
    }

    private func deleteEvent() {
        print("🗑️ DELETE EVENT TRIGGERED - Source: \(event.source), ID: \(event.id), Title: \(event.title)")
        isDeleting = true

        switch event.source {
        case .ios:
            print("🗑️ Routing to deleteIOSEvent()")
            deleteIOSEvent()
        case .google:
            print("🗑️ Routing to deleteGoogleEvent()")
            deleteGoogleEvent()
        case .outlook:
            print("🗑️ Routing to deleteOutlookEvent()")
            deleteOutlookEvent()
        }
    }

    private func deleteIOSEvent() {
        print("🗑️ deleteIOSEvent() - Looking for event in originalEvent...")
        guard let ekEvent = event.originalEvent as? EKEvent else {
            print("⚠️ originalEvent is not EKEvent, trying to find by ID: \(event.id)")
            // Try to find by ID
            if let ekEvent = calendarManager.eventStore.event(withIdentifier: event.id) {
                print("✅ Found event by ID lookup")
                performIOSDeletion(ekEvent)
            } else {
                print("❌ Could not find iOS event with ID: \(event.id)")
                deletionError = "Could not find the iOS event. It may have already been deleted."
                showingDeletionError = true
                isDeleting = false
            }
            return
        }
        print("✅ Found event in originalEvent, proceeding with deletion")
        performIOSDeletion(ekEvent)
    }

    private func performIOSDeletion(_ ekEvent: EKEvent) {
        let eventIdToDelete = event.id

        // Set flag to prevent reload triggered by EventKit change notification
        calendarManager.isPerformingInternalDeletion = true
        print("🚫 Set isPerformingInternalDeletion = true")

        do {
            // Step 1: Remove from EventKit (the actual calendar)
            try calendarManager.eventStore.remove(ekEvent, span: .thisEvent, commit: true)
            print("✅ iOS event deleted from EventKit successfully")

            // Step 2: Track deletion to prevent reappearance (do this BEFORE cleanup)
            calendarManager.trackDeletedEvent(eventIdToDelete, source: .ios)
            print("✅ Event tracked as deleted: \(eventIdToDelete)")

            // Step 3: Delete from Core Data cache
            CoreDataManager.shared.permanentlyDeleteEvent(eventId: eventIdToDelete, source: .ios)
            print("✅ Event deleted from Core Data cache")

            // Step 4: Remove from iOS events array immediately
            DispatchQueue.main.async {
                let beforeCount = self.calendarManager.events.count
                self.calendarManager.events.removeAll { $0.eventIdentifier == eventIdToDelete }
                let afterCount = self.calendarManager.events.count
                print("✅ Removed from iOS events array: \(beforeCount) -> \(afterCount)")

                // Step 5: Remove from unified events array immediately
                let beforeUnifiedCount = self.calendarManager.unifiedEvents.count
                self.calendarManager.unifiedEvents.removeAll {
                    $0.id == eventIdToDelete && $0.source == .ios
                }
                let afterUnifiedCount = self.calendarManager.unifiedEvents.count
                print("✅ Removed from unified events: \(beforeUnifiedCount) -> \(afterUnifiedCount)")

                // Step 6: Verify event is gone
                let stillExists = self.calendarManager.unifiedEvents.contains {
                    $0.id == eventIdToDelete && $0.source == .ios
                }

                if stillExists {
                    print("⚠️ WARNING: Event still exists in unified events after deletion!")
                } else {
                    print("✅ VERIFIED: Event completely removed from all arrays")
                }

                // Provide success feedback
                HapticManager.shared.success()
                self.isDeleting = false

                // Force UI refresh by triggering objectWillChange
                self.calendarManager.objectWillChange.send()
                print("🔄 Triggered UI refresh via objectWillChange")

                // Clear the deletion flag after a delay to allow EventKit notification to fire
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.calendarManager.isPerformingInternalDeletion = false
                    print("✅ Cleared isPerformingInternalDeletion flag")
                }

                // Dismiss the detail view
                self.dismiss()
            }
        } catch {
            print("❌ Failed to delete iOS event from EventKit: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.deletionError = "Failed to delete iOS event: \(error.localizedDescription)"
                self.showingDeletionError = true
                self.isDeleting = false

                // Clear the deletion flag even on error
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.calendarManager.isPerformingInternalDeletion = false
                    print("✅ Cleared isPerformingInternalDeletion flag (after error)")
                }
            }
        }
    }

    private func deleteGoogleEvent() {
        let eventIdToDelete = event.id

        print("🗑️ deleteGoogleEvent() - Checking Google Calendar connection...")
        guard let googleManager = calendarManager.googleCalendarManager else {
            print("❌ Google Calendar not connected")
            deletionError = "Google Calendar is not connected. Please sign in first."
            showingDeletionError = true
            isDeleting = false
            return
        }
        print("✅ Google Calendar connected, proceeding with deletion")

        // Step 1: Track deletion to prevent reappearance (do this FIRST)
        calendarManager.trackDeletedEvent(eventIdToDelete, source: .google)
        print("✅ Event tracked as deleted: \(eventIdToDelete)")

        Task {
            // Step 2: Delete from Google Calendar server
            let success = await googleManager.deleteEvent(eventId: eventIdToDelete)
            print(success ? "✅ Google event deleted from server" : "⚠️ Failed to delete from Google server")

            await MainActor.run {
                // Step 3: Delete from Core Data cache (regardless of server success)
                CoreDataManager.shared.permanentlyDeleteEvent(eventId: eventIdToDelete, source: .google)
                print("✅ Event deleted from Core Data cache")

                // Step 4: Remove from unified events array immediately
                let beforeCount = self.calendarManager.unifiedEvents.count
                self.calendarManager.unifiedEvents.removeAll {
                    $0.id == eventIdToDelete && $0.source == .google
                }
                let afterCount = self.calendarManager.unifiedEvents.count
                print("✅ Removed from unified events: \(beforeCount) -> \(afterCount)")

                // Step 5: Verify event is gone
                let stillExists = self.calendarManager.unifiedEvents.contains {
                    $0.id == eventIdToDelete && $0.source == .google
                }

                if stillExists {
                    print("⚠️ WARNING: Event still exists in unified events after deletion!")
                } else {
                    print("✅ VERIFIED: Event completely removed from all arrays")
                }

                // Provide appropriate feedback
                if success {
                    HapticManager.shared.success()
                } else {
                    HapticManager.shared.warning()
                }

                // Force UI refresh by triggering objectWillChange
                self.calendarManager.objectWillChange.send()
                print("🔄 Triggered UI refresh via objectWillChange")

                self.isDeleting = false
                self.dismiss()
            }
        }
    }

    private func deleteOutlookEvent() {
        let eventIdToDelete = event.id

        print("🗑️ deleteOutlookEvent() - Checking Outlook Calendar connection...")
        guard let outlookManager = calendarManager.outlookCalendarManager else {
            print("❌ Outlook Calendar not connected")
            deletionError = "Outlook Calendar is not connected. Please sign in first."
            showingDeletionError = true
            isDeleting = false
            return
        }
        print("✅ Outlook Calendar connected, proceeding with deletion")

        // Step 1: Track deletion to prevent reappearance (do this FIRST)
        calendarManager.trackDeletedEvent(eventIdToDelete, source: .outlook)
        print("✅ Event tracked as deleted: \(eventIdToDelete)")

        Task {
            // Step 2: Delete from Outlook Calendar server
            let success = await outlookManager.deleteEvent(eventId: eventIdToDelete)
            print(success ? "✅ Outlook event deleted from server" : "⚠️ Failed to delete from Outlook server")

            await MainActor.run {
                // Step 3: Delete from Core Data cache (regardless of server success)
                CoreDataManager.shared.permanentlyDeleteEvent(eventId: eventIdToDelete, source: .outlook)
                print("✅ Event deleted from Core Data cache")

                // Step 4: Remove from unified events array immediately
                let beforeCount = self.calendarManager.unifiedEvents.count
                self.calendarManager.unifiedEvents.removeAll {
                    $0.id == eventIdToDelete && $0.source == .outlook
                }
                let afterCount = self.calendarManager.unifiedEvents.count
                print("✅ Removed from unified events: \(beforeCount) -> \(afterCount)")

                // Step 5: Verify event is gone
                let stillExists = self.calendarManager.unifiedEvents.contains {
                    $0.id == eventIdToDelete && $0.source == .outlook
                }

                if stillExists {
                    print("⚠️ WARNING: Event still exists in unified events after deletion!")
                } else {
                    print("✅ VERIFIED: Event completely removed from all arrays")
                }

                // Provide appropriate feedback
                if success {
                    HapticManager.shared.success()
                } else {
                    HapticManager.shared.warning()
                }

                // Force UI refresh by triggering objectWillChange
                self.calendarManager.objectWillChange.send()
                print("🔄 Triggered UI refresh via objectWillChange")

                self.isDeleting = false
                self.dismiss()
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    // MARK: - Video Meeting Detection

    private func detectVideoMeeting() -> VideoMeetingDetector.VideoMeeting? {
        let detector = VideoMeetingDetector()
        return detector.detectMeeting(from: event)
    }

    private func openVideoMeeting(_ url: URL) {
        UIApplication.shared.open(url)
    }

    private func platformColor(for platform: VideoMeetingDetector.MeetingPlatform) -> Color {
        switch platform {
        case .zoom:
            return Color.blue
        case .googleMeet:
            return Color.green
        case .webex:
            return Color.blue
        case .microsoftTeams:
            return Color.purple
        case .unknown:
            return Color.blue
        }
    }

    // MARK: - Phase 4: AI Task Generation

    private func generateAITasks() {
        print("🤖 Generating AI tasks for event: \(event.title)")
        isGeneratingTasks = true
        taskGenerationError = nil

        Task {
            do {
                let result = try await aiManager.generateTasksForEvent(event)
                print("✅ Generated \(result.tasks.count) tasks")

                await MainActor.run {
                    self.generatedTasks = result.tasks
                    self.isGeneratingTasks = false

                    if !result.tasks.isEmpty {
                        self.showTaskPreview = true
                    } else {
                        self.taskGenerationError = result.message
                    }
                }
            } catch {
                print("❌ Task generation failed: \(error)")
                await MainActor.run {
                    self.isGeneratingTasks = false
                    self.taskGenerationError = "Failed to generate tasks. Please check your API key in Settings and try again."
                }
            }
        }
    }
}

#Preview {
    EventDetailView(
        calendarManager: CalendarManager(),
        fontManager: FontManager(),
        event: UnifiedEvent(
            id: "preview-event",
            title: "Team Meeting",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: "Conference Room A",
            description: "Discuss Q4 planning and goals",
            isAllDay: false,
            source: .ios,
            organizer: "john@example.com",
            originalEvent: NSObject(),
            calendarId: "preview-calendar",
            calendarName: "Personal",
            calendarColor: .blue
        )
    )
}
