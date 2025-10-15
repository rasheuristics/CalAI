import SwiftUI
import EventKit

struct EditEventView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    let event: UnifiedEvent

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingDeleteConfirmation = false

    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                        .dynamicFont(size: 17, fontManager: fontManager)

                    TextField("Location", text: $location)
                        .dynamicFont(size: 17, fontManager: fontManager)
                }

                Section("Date & Time") {
                    Toggle("All Day", isOn: $isAllDay)
                        .dynamicFont(size: 17, fontManager: fontManager)

                    if !isAllDay {
                        DatePicker("Starts", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                            .dynamicFont(size: 17, fontManager: fontManager)

                        DatePicker("Ends", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                            .dynamicFont(size: 17, fontManager: fontManager)
                    } else {
                        DatePicker("Starts", selection: $startDate, displayedComponents: .date)
                            .dynamicFont(size: 17, fontManager: fontManager)

                        DatePicker("Ends", selection: $endDate, displayedComponents: .date)
                            .dynamicFont(size: 17, fontManager: fontManager)
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .dynamicFont(size: 17, fontManager: fontManager)
                        .frame(minHeight: 100)
                }

                Section("Calendar Source") {
                    HStack {
                        Text("Source:")
                            .dynamicFont(size: 17, fontManager: fontManager)

                        Spacer()

                        Text(event.sourceLabel)
                            .dynamicFont(size: 17, weight: .medium, fontManager: fontManager)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .cornerRadius(6)
                    }
                }

                if let errorMessage = errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .dynamicFont(size: 14, fontManager: fontManager)
                    }
                }

                Section {
                    Button(action: { showingDeleteConfirmation = true }) {
                        HStack {
                            Spacer()
                            Text("Delete Event")
                                .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                                .foregroundColor(.red)
                            Spacer()
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .navigationTitle("Edit Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .dynamicFont(size: 17, fontManager: fontManager)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveEvent()
                    }
                    .disabled(title.isEmpty || isLoading)
                    .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                }
            }
            .overlay(
                Group {
                    if isLoading {
                        ZStack {
                            Color.black.opacity(0.3)
                                .ignoresSafeArea()

                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.2)

                                Text("Updating Event...")
                                    .dynamicFont(size: 14, fontManager: fontManager)
                                    .foregroundColor(.white)
                                    .padding(.top, 8)
                            }
                            .padding()
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(10)
                        }
                    }
                }
            )
        }
        .onAppear {
            loadEventData()
        }
        .onChange(of: startDate) { newValue in
            if endDate <= newValue {
                endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
            }
        }
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Are you sure you want to delete '\(title)'? This action cannot be undone.")
        }
        .overlay(
            Group {
                if let successMessage = successMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.white)
                            Text(successMessage)
                                .dynamicFont(size: 15, fontManager: fontManager)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.green)
                        .cornerRadius(10)
                        .padding(.bottom, 50)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        )
    }

    private func loadEventData() {
        title = event.title
        location = event.location ?? ""
        notes = event.description ?? ""
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
    }

    private func saveEvent() {
        guard !title.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        let updatedEvent = UnifiedEvent(
            id: event.id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location.isEmpty ? nil : location,
            description: notes.isEmpty ? nil : notes,
            isAllDay: isAllDay,
            source: event.source,
            organizer: event.organizer,
            originalEvent: event.originalEvent
        )

        updateEventInCalendar(updatedEvent) { success, error in
            DispatchQueue.main.async {
                isLoading = false

                if success {
                    print("✅ Event updated successfully, refreshing calendar and conflicts...")
                    print("📊 Current conflict count BEFORE refresh: \(calendarManager.detectedConflicts.count)")

                    // Show success message
                    withAnimation {
                        successMessage = "Event updated successfully"
                    }

                    // Haptic feedback
                    HapticManager.shared.success()

                    // Dismiss after showing message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        dismiss()
                    }

                    // Then refresh calendar data
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        print("🔄 Step 1: Refreshing all calendars...")
                        calendarManager.refreshAllCalendars()

                        // Wait for calendar to refresh, then reload unified events and re-detect conflicts
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            print("🔄 Step 2: Reloading unified events...")
                            print("📊 Unified events count BEFORE reload: \(calendarManager.unifiedEvents.count)")
                            calendarManager.loadAllUnifiedEvents()

                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                print("📊 Unified events count AFTER reload: \(calendarManager.unifiedEvents.count)")
                                print("🔄 Step 3: Re-detecting conflicts...")
                                calendarManager.detectAllConflicts()
                                print("📊 Current conflict count AFTER detect: \(calendarManager.detectedConflicts.count)")
                            }
                        }
                    }
                } else {
                    errorMessage = error ?? "Failed to update event"
                }
            }
        }
    }

    private func deleteEvent() {
        isLoading = true
        errorMessage = nil

        deleteEventFromCalendar(event) { success, error in
            DispatchQueue.main.async {
                isLoading = false

                if success {
                    print("🗑️ ========== EVENT DELETION SUCCESSFUL ==========")
                    print("🗑️ Event ID: \(event.id)")
                    print("🗑️ Event Title: \(event.title)")
                    print("📊 Current conflict count BEFORE: \(calendarManager.detectedConflicts.count)")
                    print("📊 Unified events count BEFORE: \(calendarManager.unifiedEvents.count)")

                    // Show success message
                    withAnimation {
                        successMessage = "Event '\(event.title)' deleted successfully"
                    }

                    // Haptic feedback
                    HapticManager.shared.success()

                    // Immediately remove the event from unified events
                    calendarManager.unifiedEvents.removeAll { $0.id == event.id }
                    print("📊 Unified events count AFTER removal: \(calendarManager.unifiedEvents.count)")

                    // Re-detect conflicts with updated list
                    calendarManager.detectAllConflicts()
                    print("📊 Current conflict count AFTER: \(calendarManager.detectedConflicts.count)")
                    print("🗑️ ========== CONFLICT UPDATE COMPLETE ==========")

                    // Dismiss after showing message
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }

                    // Also refresh calendar data in background
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        calendarManager.refreshAllCalendars()
                    }
                } else {
                    errorMessage = error ?? "Failed to delete event"
                }
            }
        }
    }

    private func deleteEventFromCalendar(_ eventToDelete: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        switch eventToDelete.source {
        case .ios:
            deleteIOSEvent(eventToDelete, completion: completion)
        case .google:
            deleteGoogleEvent(eventToDelete, completion: completion)
        case .outlook:
            deleteOutlookEvent(eventToDelete, completion: completion)
        }
    }

    private func deleteIOSEvent(_ eventToDelete: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        print("🗑️ Attempting to delete iOS event: \(eventToDelete.id)")
        print("🗑️ Original event type: \(type(of: eventToDelete.originalEvent))")

        // Try to get the EKEvent from originalEvent
        if let ekEvent = eventToDelete.originalEvent as? EKEvent {
            do {
                try calendarManager.eventStore.remove(ekEvent, span: .thisEvent)
                print("✅ Successfully deleted iOS event")
                completion(true, nil)
            } catch {
                print("❌ Failed to delete iOS event: \(error.localizedDescription)")
                completion(false, "Failed to delete event: \(error.localizedDescription)")
            }
            return
        }

        // Fallback: Try to find the event by ID in the event store
        print("⚠️ Original EKEvent not found, searching by ID...")
        if let ekEvent = calendarManager.eventStore.event(withIdentifier: eventToDelete.id) {
            do {
                try calendarManager.eventStore.remove(ekEvent, span: .thisEvent)
                print("✅ Successfully deleted iOS event via ID lookup")
                completion(true, nil)
            } catch {
                print("❌ Failed to delete iOS event via ID: \(error.localizedDescription)")
                completion(false, "Failed to delete event: \(error.localizedDescription)")
            }
        } else {
            print("❌ Could not find iOS event with ID: \(eventToDelete.id)")
            completion(false, "Could not find original iOS event. It may have already been deleted.")
        }
    }

    private func deleteGoogleEvent(_ eventToDelete: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        // Use CalendarManager's delete method
        calendarManager.deleteEvent(eventToDelete)
        completion(true, nil)
    }

    private func deleteOutlookEvent(_ eventToDelete: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        // Use CalendarManager's delete method
        calendarManager.deleteEvent(eventToDelete)
        completion(true, nil)
    }

    private func updateEventInCalendar(_ updatedEvent: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        switch updatedEvent.source {
        case .ios:
            updateIOSEvent(updatedEvent, completion: completion)
        case .google:
            updateGoogleEvent(updatedEvent, completion: completion)
        case .outlook:
            updateOutlookEvent(updatedEvent, completion: completion)
        }
    }

    private func updateIOSEvent(_ updatedEvent: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        guard let ekEvent = updatedEvent.originalEvent as? EKEvent else {
            completion(false, "Could not find original iOS event")
            return
        }

        // Update the EKEvent with new data
        ekEvent.title = updatedEvent.title
        ekEvent.location = updatedEvent.location
        ekEvent.notes = updatedEvent.description
        ekEvent.startDate = updatedEvent.startDate
        ekEvent.endDate = updatedEvent.endDate
        ekEvent.isAllDay = updatedEvent.isAllDay

        do {
            try calendarManager.eventStore.save(ekEvent, span: .thisEvent)
            print("✅ Successfully updated iOS event: \(updatedEvent.title)")
            completion(true, nil)
        } catch {
            print("❌ Failed to update iOS event: \(error)")
            completion(false, error.localizedDescription)
        }
    }

    private func updateGoogleEvent(_ updatedEvent: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        // Convert UnifiedEvent to GoogleEvent for updating
        let googleEvent = GoogleEvent(
            id: updatedEvent.id,
            title: updatedEvent.title,
            startDate: updatedEvent.startDate,
            endDate: updatedEvent.endDate,
            location: updatedEvent.location,
            description: updatedEvent.description,
            calendarId: "primary", // Default calendar ID
            organizer: nil
        )

        calendarManager.googleCalendarManager?.updateEvent(googleEvent) { success, error in
            completion(success, error)
        }
    }

    private func updateOutlookEvent(_ updatedEvent: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        // Convert UnifiedEvent to OutlookEvent for updating
        let outlookEvent = OutlookEvent(
            id: updatedEvent.id,
            title: updatedEvent.title,
            startDate: updatedEvent.startDate,
            endDate: updatedEvent.endDate,
            location: updatedEvent.location,
            description: updatedEvent.description,
            calendarId: "primary-calendar", // Default calendar ID
            organizer: nil
        )

        calendarManager.outlookCalendarManager?.updateEvent(outlookEvent) { success, error in
            completion(success, error)
        }
    }
}

#Preview {
    EditEventView(
        calendarManager: CalendarManager(),
        fontManager: FontManager(),
        event: UnifiedEvent(
            id: "preview-event",
            title: "Sample Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            location: "Sample Location",
            description: "Sample notes",
            isAllDay: false,
            source: .ios,
            organizer: nil,
            originalEvent: Optional<Any>.none as Any
        )
    )
}