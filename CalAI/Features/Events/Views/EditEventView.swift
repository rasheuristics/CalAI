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
                    // Refresh calendar data to reflect changes
                    calendarManager.refreshAllCalendars()
                    dismiss()
                } else {
                    errorMessage = error ?? "Failed to update event"
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