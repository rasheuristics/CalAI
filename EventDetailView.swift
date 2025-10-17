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
                            HStack(spacing: 12) {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.blue)
                                    .frame(width: 24)

                                Text(location)
                                    .dynamicFont(size: 17, fontManager: fontManager)
                            }
                        }
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
                                    Text(notes)
                                        .dynamicFont(size: 17, fontManager: fontManager)
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

                    // Delete Button Section
                    Button(action: {
                        showingDeleteConfirmation = true
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
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .disabled(isDeleting)

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
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEvent()
                }
            } message: {
                Text("Are you sure you want to delete '\(event.title)'? This action cannot be undone.")
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
        isDeleting = true

        switch event.source {
        case .ios:
            deleteIOSEvent()
        case .google:
            deleteGoogleEvent()
        case .outlook:
            deleteOutlookEvent()
        }
    }

    private func deleteIOSEvent() {
        guard let ekEvent = event.originalEvent as? EKEvent else {
            // Try to find by ID
            if let ekEvent = calendarManager.eventStore.event(withIdentifier: event.id) {
                performIOSDeletion(ekEvent)
            } else {
                print("❌ Could not find iOS event")
                isDeleting = false
            }
            return
        }
        performIOSDeletion(ekEvent)
    }

    private func performIOSDeletion(_ ekEvent: EKEvent) {
        do {
            try calendarManager.eventStore.remove(ekEvent, span: .thisEvent, commit: true)
            print("✅ iOS event deleted successfully")

            // Delete from Core Data
            CoreDataManager.shared.permanentlyDeleteEvent(eventId: event.id, source: .ios)

            // Remove from unified events
            calendarManager.unifiedEvents.removeAll { $0.id == event.id && $0.source == .ios }

            // Refresh
            calendarManager.loadEvents()

            HapticManager.shared.success()
            dismiss()
        } catch {
            print("❌ Failed to delete iOS event: \(error)")
            isDeleting = false
        }
    }

    private func deleteGoogleEvent() {
        guard let googleManager = calendarManager.googleCalendarManager else {
            print("❌ Google Calendar not connected")
            isDeleting = false
            return
        }

        Task {
            let success = await googleManager.deleteEvent(eventId: event.id)

            await MainActor.run {
                if success {
                    print("✅ Google event deleted successfully")
                    CoreDataManager.shared.permanentlyDeleteEvent(eventId: event.id, source: .google)
                    calendarManager.unifiedEvents.removeAll { $0.id == event.id && $0.source == .google }
                    googleManager.fetchEvents()
                    HapticManager.shared.success()
                    dismiss()
                } else {
                    print("❌ Failed to delete Google event")
                    isDeleting = false
                }
            }
        }
    }

    private func deleteOutlookEvent() {
        guard let outlookManager = calendarManager.outlookCalendarManager else {
            print("❌ Outlook Calendar not connected")
            isDeleting = false
            return
        }

        Task {
            let success = await outlookManager.deleteEvent(eventId: event.id)

            await MainActor.run {
                if success {
                    print("✅ Outlook event deleted successfully")
                    CoreDataManager.shared.permanentlyDeleteEvent(eventId: event.id, source: .outlook)
                    calendarManager.unifiedEvents.removeAll { $0.id == event.id && $0.source == .outlook }
                    outlookManager.fetchEvents()
                    HapticManager.shared.success()
                    dismiss()
                } else {
                    print("❌ Failed to delete Outlook event")
                    isDeleting = false
                }
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
