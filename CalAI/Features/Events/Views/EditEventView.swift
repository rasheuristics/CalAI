import SwiftUI
import EventKit
import MapKit

struct EditEventView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    let event: UnifiedEvent
    var triggerSave: Binding<Bool>?

    @State private var title: String = ""
    @State private var location: String = ""
    @State private var notes: String = ""
    @State private var eventURL: String = ""
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Date().addingTimeInterval(3600)
    @State private var isAllDay: Bool = false
    @State private var selectedRepeat: RepeatOption = .none
    @State private var selectedColor: Color = .blue
    @State private var attachments: [AttachmentItem] = []
    @State private var showingDocumentPicker = false
    @State private var showingLocationPicker = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?
    @State private var successMessage: String?
    @State private var showingDeleteConfirmation = false
    @StateObject private var colorManager = EventColorManager.shared

    var body: some View {
        Form {
            eventDetailsSection
            calendarSection
            dateTimeSection
            repeatSection
            colorSection
            urlSection
            attachmentsSection
            notesSection
            errorSection
            actionButtons
        }
        .onAppear {
            loadEventData()
        }
        .onChange(of: triggerSave?.wrappedValue) { _ in
            // Save when parent triggers it
            if triggerSave != nil {
                saveEvent()
            }
        }
        .onChange(of: startDate) { newValue in
            if endDate <= newValue {
                endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { urls in
                for url in urls {
                    addAttachment(from: url)
                }
            }
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(
                selectedLocation: $location,
                fontManager: fontManager,
                onLocationSelected: { selectedLocation in
                    location = selectedLocation
                    showingLocationPicker = false
                },
                onCancel: {
                    showingLocationPicker = false
                }
            )
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

    // MARK: - Form Sections

    private var eventDetailsSection: some View {
        Section("Event Details") {
            TextField("Title", text: $title)
                .dynamicFont(size: 17, fontManager: fontManager)

            // Location field with search
            Button(action: {
                showingLocationPicker = true
            }) {
                HStack {
                    Text("Location")
                        .dynamicFont(size: 17, fontManager: fontManager)
                        .foregroundColor(.primary)

                    Spacer()

                    if location.isEmpty {
                        Text("Add location")
                            .dynamicFont(size: 17, fontManager: fontManager)
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                            Text(location)
                                .dynamicFont(size: 17, fontManager: fontManager)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var calendarSection: some View {
        Section("Calendar") {
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

            if let calendarName = event.calendarName {
                HStack {
                    Text("Calendar:")
                        .dynamicFont(size: 17, fontManager: fontManager)

                    Spacer()

                    HStack(spacing: 8) {
                        if let color = event.calendarColor {
                            Circle()
                                .fill(color)
                                .frame(width: 12, height: 12)
                        }
                        Text(calendarName)
                            .dynamicFont(size: 17, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var dateTimeSection: some View {
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
    }

    private var repeatSection: some View {
        Section("Repeat") {
            Picker("Repeat", selection: $selectedRepeat) {
                ForEach(RepeatOption.allCases) { option in
                    Text(option.displayName)
                        .dynamicFont(size: 17, fontManager: fontManager)
                        .tag(option)
                }
            }
            .dynamicFont(size: 17, fontManager: fontManager)
        }
    }

    private var colorSection: some View {
        Section {
            ColorPicker("Card Color", selection: $selectedColor, supportsOpacity: false)
                .dynamicFont(size: 17, fontManager: fontManager)

            HStack {
                Text("Preview:")
                    .dynamicFont(size: 15, fontManager: fontManager)
                    .foregroundColor(.secondary)

                Spacer()

                RoundedRectangle(cornerRadius: 8)
                    .fill(selectedColor)
                    .frame(width: 60, height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
        } header: {
            Text("Event Card Color")
        } footer: {
            Text("This color affects how the event appears in CalAI. For iOS Calendar events, the actual calendar color is managed in the iOS Calendar settings.")
                .dynamicFont(size: 13, fontManager: fontManager)
        }
    }

    private var urlSection: some View {
        Section("URL") {
            TextField("Event URL", text: $eventURL)
                .dynamicFont(size: 17, fontManager: fontManager)
                .keyboardType(.URL)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
    }

    private var attachmentsSection: some View {
        Section("Attachments") {
            if attachments.isEmpty {
                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "paperclip")
                            .foregroundColor(.blue)
                        Text("Add Attachment")
                            .dynamicFont(size: 17, fontManager: fontManager)
                            .foregroundColor(.blue)
                    }
                }
            } else {
                ForEach(attachments) { attachment in
                    HStack {
                        Image(systemName: "doc")
                            .foregroundColor(.secondary)
                        Text(attachment.name)
                            .dynamicFont(size: 17, fontManager: fontManager)
                        Spacer()
                        Button(action: {
                            removeAttachment(attachment)
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }

                Button(action: {
                    showingDocumentPicker = true
                }) {
                    HStack {
                        Image(systemName: "paperclip")
                            .foregroundColor(.blue)
                        Text("Add Another Attachment")
                            .dynamicFont(size: 17, fontManager: fontManager)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
    }

    private var notesSection: some View {
        Section("Notes") {
            TextEditor(text: $notes)
                .dynamicFont(size: 17, fontManager: fontManager)
                .frame(minHeight: 100)
        }
    }

    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = errorMessage {
            Section {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .dynamicFont(size: 14, fontManager: fontManager)
            }
        }
    }

    private var actionButtons: some View {
        Group {
            Section {
                Button(action: { saveEvent() }) {
                    HStack {
                        Spacer()
                        Text("Save Changes")
                            .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                }
                .disabled(title.isEmpty || isLoading)
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
    }


    // MARK: - Helper Methods

    private func loadEventData() {
        title = event.title
        location = event.location ?? ""
        notes = event.description ?? ""
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay

        // Load color from EventColorManager if custom color is set
        if colorManager.shouldUseCustomColor(for: event.id),
           let customColor = colorManager.getCustomColor(for: event.id) {
            selectedColor = customColor
        } else if let calendarColor = event.calendarColor {
            selectedColor = calendarColor
        } else {
            selectedColor = .blue
        }

        // Load URL and recurrence from EKEvent if available
        if let ekEvent = event.originalEvent as? EKEvent {
            eventURL = ekEvent.url?.absoluteString ?? ""

            // Load recurrence rule
            if let recurrenceRules = ekEvent.recurrenceRules, let rule = recurrenceRules.first {
                selectedRepeat = mapEKRecurrenceRuleToRepeatOption(rule)
            }

            // Note: EKEvent doesn't expose attachments through the EventKit API
            // Attachments are managed by the system and cannot be accessed programmatically
        }
    }

    private func mapEKRecurrenceRuleToRepeatOption(_ rule: EKRecurrenceRule) -> RepeatOption {
        switch rule.frequency {
        case .daily:
            return .daily
        case .weekly:
            return rule.interval == 2 ? .biweekly : .weekly
        case .monthly:
            return .monthly
        case .yearly:
            return .yearly
        @unknown default:
            return .none
        }
    }

    private func addAttachment(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            print("❌ Failed to access security scoped resource")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let attachment = AttachmentItem(
                name: url.lastPathComponent,
                url: url,
                data: data
            )
            attachments.append(attachment)
        } catch {
            print("❌ Failed to read attachment: \(error)")
        }
    }

    private func removeAttachment(_ attachment: AttachmentItem) {
        attachments.removeAll { $0.id == attachment.id }
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
            originalEvent: event.originalEvent,
            calendarId: event.calendarId,
            calendarName: event.calendarName,
            calendarColor: event.calendarColor
        )

        updateEventInCalendar(updatedEvent) { success, error in
            DispatchQueue.main.async {
                isLoading = false

                if success {
                    print("✅ Event updated successfully, refreshing calendar and conflicts...")
                    print("📊 Current conflict count BEFORE refresh: \(calendarManager.detectedConflicts.count)")

                    // Save custom color to EventColorManager
                    colorManager.setUseCustomColor(true, for: event.id)
                    colorManager.setCustomColor(selectedColor, for: event.id)

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

                        // Note: We don't call refreshAllCalendars() here because it would
                        // call loadAllUnifiedEvents() which would restore the deleted event!
                        // The event is already removed from unifiedEvents and conflicts re-detected.
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

        // Set flag to prevent reload triggered by EventKit change notification
        calendarManager.isPerformingInternalDeletion = true
        print("🚫 Set isPerformingInternalDeletion = true")

        // Try to get the EKEvent from originalEvent
        if let ekEvent = eventToDelete.originalEvent as? EKEvent {
            do {
                try calendarManager.eventStore.remove(ekEvent, span: .thisEvent, commit: true)
                print("✅ Successfully deleted iOS event from EventKit")

                // Track deletion to prevent reappearance
                calendarManager.trackDeletedEvent(eventToDelete.id, source: .ios)
                print("✅ Event tracked as deleted")

                // Delete from Core Data cache
                CoreDataManager.shared.permanentlyDeleteEvent(eventId: eventToDelete.id, source: .ios)
                print("✅ Event deleted from Core Data cache")

                // Remove from iOS events array
                calendarManager.events.removeAll { $0.eventIdentifier == eventToDelete.id }

                // Force UI refresh
                calendarManager.objectWillChange.send()
                print("🔄 Triggered UI refresh")

                // Clear flag after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.calendarManager.isPerformingInternalDeletion = false
                    print("✅ Cleared isPerformingInternalDeletion flag")
                }

                completion(true, nil)
            } catch {
                print("❌ Failed to delete iOS event: \(error.localizedDescription)")
                // Clear flag even on error
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.calendarManager.isPerformingInternalDeletion = false
                }
                completion(false, "Failed to delete event: \(error.localizedDescription)")
            }
            return
        }

        // Fallback: Try to find the event by ID in the event store
        print("⚠️ Original EKEvent not found, searching by ID...")
        if let ekEvent = calendarManager.eventStore.event(withIdentifier: eventToDelete.id) {
            do {
                try calendarManager.eventStore.remove(ekEvent, span: .thisEvent, commit: true)
                print("✅ Successfully deleted iOS event via ID lookup")

                // Track deletion and cleanup
                calendarManager.trackDeletedEvent(eventToDelete.id, source: .ios)
                CoreDataManager.shared.permanentlyDeleteEvent(eventId: eventToDelete.id, source: .ios)
                calendarManager.events.removeAll { $0.eventIdentifier == eventToDelete.id }
                calendarManager.objectWillChange.send()

                // Clear flag after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.calendarManager.isPerformingInternalDeletion = false
                }

                completion(true, nil)
            } catch {
                print("❌ Failed to delete iOS event via ID: \(error.localizedDescription)")
                // Clear flag even on error
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.calendarManager.isPerformingInternalDeletion = false
                }
                completion(false, "Failed to delete event: \(error.localizedDescription)")
            }
        } else {
            print("❌ Could not find iOS event with ID: \(eventToDelete.id)")
            // Clear flag
            calendarManager.isPerformingInternalDeletion = false
            completion(false, "Could not find original iOS event. It may have already been deleted.")
        }
    }

    private func deleteGoogleEvent(_ eventToDelete: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        print("🗑️ Deleting Google event: \(eventToDelete.id)")

        guard let googleManager = calendarManager.googleCalendarManager else {
            print("❌ Google Calendar not connected")
            completion(false, "Google Calendar not connected")
            return
        }

        // Track deletion to prevent reappearance
        calendarManager.trackDeletedEvent(eventToDelete.id, source: .google)
        print("✅ Event tracked as deleted")

        Task {
            let success = await googleManager.deleteEvent(eventId: eventToDelete.id)

            await MainActor.run {
                // Delete from Core Data cache regardless of server success
                CoreDataManager.shared.permanentlyDeleteEvent(eventId: eventToDelete.id, source: .google)
                print("✅ Event deleted from Core Data cache")

                // Force UI refresh
                self.calendarManager.objectWillChange.send()
                print("🔄 Triggered UI refresh")

                if success {
                    print("✅ Google event deleted successfully from server and cache")
                    completion(true, nil)
                } else {
                    print("⚠️ Failed to delete from Google server, but removed from local cache")
                    completion(true, nil) // Return success since we deleted locally
                }
            }
        }
    }

    private func deleteOutlookEvent(_ eventToDelete: UnifiedEvent, completion: @escaping (Bool, String?) -> Void) {
        print("🗑️ Deleting Outlook event: \(eventToDelete.id)")

        guard let outlookManager = calendarManager.outlookCalendarManager else {
            print("❌ Outlook Calendar not connected")
            completion(false, "Outlook Calendar not connected")
            return
        }

        // Track deletion to prevent reappearance
        calendarManager.trackDeletedEvent(eventToDelete.id, source: .outlook)
        print("✅ Event tracked as deleted")

        Task {
            let success = await outlookManager.deleteEvent(eventId: eventToDelete.id)

            await MainActor.run {
                // Delete from Core Data cache regardless of server success
                CoreDataManager.shared.permanentlyDeleteEvent(eventId: eventToDelete.id, source: .outlook)
                print("✅ Event deleted from Core Data cache")

                // Force UI refresh
                self.calendarManager.objectWillChange.send()
                print("🔄 Triggered UI refresh")

                if success {
                    print("✅ Outlook event deleted successfully from server and cache")
                    completion(true, nil)
                } else {
                    print("⚠️ Failed to delete from Outlook server, but removed from local cache")
                    completion(true, nil) // Return success since we deleted locally
                }
            }
        }
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

        // Update URL
        if !eventURL.isEmpty, let url = URL(string: eventURL) {
            ekEvent.url = url
        } else {
            ekEvent.url = nil
        }

        // Update recurrence rule
        if selectedRepeat != .none, let frequency = selectedRepeat.ekRecurrenceFrequency {
            let recurrenceRule = EKRecurrenceRule(
                recurrenceWith: frequency,
                interval: selectedRepeat.interval,
                end: nil
            )
            ekEvent.recurrenceRules = [recurrenceRule]
        } else {
            ekEvent.recurrenceRules = nil
        }

        // Note: EKEvent doesn't support directly adding custom attachments
        // Attachments are typically added via the system calendar UI
        // We'll store attachment data separately if needed

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
            originalEvent: Optional<Any>.none as Any,
            calendarId: "preview-calendar",
            calendarName: "Personal",
            calendarColor: .blue
        )
    )
}