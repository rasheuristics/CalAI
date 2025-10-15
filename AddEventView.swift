import SwiftUI
import EventKit
import UniformTypeIdentifiers
import MapKit

enum CalendarOption: CaseIterable, Identifiable {
    case ios
    case google
    case outlook

    var id: String { name }

    var name: String {
        switch self {
        case .ios: return "📱 iOS Calendar"
        case .google: return "🟢 Google Calendar"
        case .outlook: return "🔵 Outlook Calendar"
        }
    }

    var isAvailable: Bool {
        return true
    }
}

struct AddEventView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    let eventToEdit: UnifiedEvent?

    @State private var title = ""
    @State private var location = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var isAllDay = false
    @State private var selectedCalendar: CalendarOption = .ios
    @State private var notes = ""
    
    // Personalization State
    @State private var showBreakSuggestion = false
    @State private var lastSavedEvent: UnifiedEvent?

    private var isEditMode: Bool { eventToEdit != nil }
    private var navigationTitle: String { isEditMode ? "Edit Event" : "Add Event" }

    init(calendarManager: CalendarManager, fontManager: FontManager, eventToEdit: UnifiedEvent? = nil) {
        self.calendarManager = calendarManager
        self.fontManager = fontManager
        self.eventToEdit = eventToEdit
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                }

                Section("Date & Time") {
                    Toggle("All Day", isOn: $isAllDay)
                    DatePicker("Starts", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                    DatePicker("Ends", selection: $endDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                }
                
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditMode ? "Update" : "Save") { saveChanges() }
                        .disabled(title.isEmpty)
                }
            }
            .onAppear(perform: loadEventDataIfNeeded)
            .onChange(of: startDate) { newValue in
                if endDate <= newValue {
                    endDate = Calendar.current.date(byAdding: .hour, value: 1, to: newValue) ?? newValue
                }
            }
            .alert("Smart Suggestion", isPresented: $showBreakSuggestion, presenting: lastSavedEvent) { event in
                Button("Yes, please") {
                    scheduleBreak(after: event)
                    dismiss()
                }
                Button("No, thanks", role: .cancel) { dismiss() }
            } message: { event in
                Text("You often schedule a break after long meetings. Would you like to add a 15-minute coffee break after this one?")
            }
        }
    }

    private func saveChanges() {
        guard !title.isEmpty else { return }

        let event = UnifiedEvent(
            id: eventToEdit?.id ?? UUID().uuidString,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location,
            description: notes,
            isAllDay: isAllDay,
            source: eventToEdit?.source ?? .ios, // Default to iOS calendar for new events
            organizer: eventToEdit?.organizer,
            originalEvent: eventToEdit?.originalEvent
        )

        // Save the event (create or update)
        calendarManager.saveEvent(event)
        
        // Check for personalization suggestion
        if PersonalizationService.shared.checkForBreakSuggestion(after: event) {
            self.lastSavedEvent = event
            self.showBreakSuggestion = true
        } else {
            // If no suggestion, just dismiss
            dismiss()
        }
    }

    private func scheduleBreak(after event: UnifiedEvent) {
        let breakEvent = UnifiedEvent(
            id: UUID().uuidString,
            title: "☕️ Coffee Break",
            startDate: event.endDate,
            endDate: event.endDate.addingTimeInterval(15 * 60), // 15 minutes
            location: nil,
            description: "A short break after your long meeting.",
            isAllDay: false,
            source: event.source,
            organizer: nil,
            originalEvent: nil
        )
        calendarManager.saveEvent(breakEvent)
    }

    private func loadEventDataIfNeeded() {
        guard let event = eventToEdit else { return }
        title = event.title
        location = event.location ?? ""
        notes = event.description ?? ""
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        selectedCalendar = .ios // Simplified for this example
    }
}
