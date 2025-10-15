import SwiftUI
import EventKit

/// A streamlined view for creating events using natural language input
struct NaturalLanguageEventView: View {
    @ObservedObject var calendarManager: CalendarManager
    @Environment(\.dismiss) private var dismiss

    @State private var inputText = ""
    @State private var isProcessing = false
    @State private var parsedEvent: ParsedEvent?
    @State private var showingConfirmation = false
    @State private var errorMessage: String?

    // Location suggestions
    @State private var locationSuggestions: [String] = []
    @State private var showingLocationSuggestions = false

    // Contact suggestions
    @State private var contactSuggestions: [ContactSuggestion] = []
    @State private var showingContactSuggestions = false
    @State private var contactSearchQuery = ""

    private let parser = NaturalLanguageParser()

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundColor(.blue)

                        Text("Natural Language Event")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Describe your event in plain English")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)

                    // Quick Templates
                    QuickTemplatesView(onSelect: { template in
                        inputText = template.title
                        parseInput()
                    })

                    // Main Input
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Event Description")
                            .font(.headline)

                        ZStack(alignment: .topLeading) {
                            if inputText.isEmpty {
                                Text("e.g., \"Lunch with Sarah tomorrow at noon\" or \"Weekly team meeting every Monday at 2pm\"")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 12)
                            }

                            TextEditor(text: $inputText)
                                .frame(minHeight: 100)
                                .padding(4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        }

                        Button(action: parseInput) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "wand.and.stars")
                                }
                                Text(isProcessing ? "Parsing..." : "Parse Event")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(inputText.isEmpty ? Color.gray.opacity(0.3) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(inputText.isEmpty || isProcessing)
                    }

                    // Parsed Event Preview
                    if let event = parsedEvent {
                        ParsedEventPreview(
                            event: event,
                            onLocationEdit: { showingLocationSuggestions = true },
                            onAttendeeAdd: { contactSearchQuery = ""; showingContactSuggestions = true },
                            locationSuggestions: locationSuggestions,
                            parser: parser
                        )
                    }

                    // Error Message
                    if let error = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Quick Add Event")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createEvent()
                    }
                    .disabled(parsedEvent == nil || isProcessing)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingLocationSuggestions) {
                LocationSuggestionsSheet(
                    suggestions: locationSuggestions,
                    onSelect: { location in
                        if parsedEvent != nil {
                            parsedEvent?.location = location
                            parser.recordLocationUsage(location)
                        }
                        showingLocationSuggestions = false
                    }
                )
            }
            .sheet(isPresented: $showingContactSuggestions) {
                ContactSearchSheet(
                    query: $contactSearchQuery,
                    suggestions: contactSuggestions,
                    parser: parser,
                    onSelect: { contact in
                        if parsedEvent != nil, let email = contact.email {
                            parsedEvent?.attendees.append(email)
                        }
                        showingContactSuggestions = false
                    }
                )
            }
        }
    }

    // MARK: - Actions

    private func parseInput() {
        guard !inputText.isEmpty else { return }

        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let event = try await parser.parseEvent(from: inputText)

                DispatchQueue.main.async {
                    self.parsedEvent = event
                    self.isProcessing = false

                    // Get location suggestions
                    if event.location == nil || event.location?.isEmpty == true {
                        let eventCategory = ParsedEventCategory.classify(from: event.title)
                        self.locationSuggestions = parser.getLocationSuggestions(for: eventCategory)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to parse event: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }

    private func createEvent() {
        guard let event = parsedEvent else { return }

        isProcessing = true

        // Create the event using CalendarManager
        Task {
            do {
                // Convert ParsedEvent to the format CalendarManager expects
                // Using iOS calendar as default
                try await calendarManager.iosCalendarManager.createEvent(
                    title: event.title,
                    startDate: event.startDate,
                    endDate: event.endDate,
                    location: event.location,
                    notes: nil,
                    isAllDay: event.isAllDay,
                    recurrenceRule: convertRecurrenceRule(event.recurrence),
                    attendees: event.attendees
                )

                // Record location if used
                if let location = event.location, !location.isEmpty {
                    parser.recordLocationUsage(location)
                }

                DispatchQueue.main.async {
                    // Reload events
                    calendarManager.loadAllUnifiedEvents()
                    dismiss()
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to create event: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }

    private func convertRecurrenceRule(_ pattern: RecurrencePattern) -> EKRecurrenceRule? {
        switch pattern {
        case .none:
            return nil
        case .daily:
            return EKRecurrenceRule(recurrenceWith: .daily, interval: 1, end: nil)
        case .weekly:
            return EKRecurrenceRule(recurrenceWith: .weekly, interval: 1, end: nil)
        case .monthly:
            return EKRecurrenceRule(recurrenceWith: .monthly, interval: 1, end: nil)
        case .yearly:
            return EKRecurrenceRule(recurrenceWith: .yearly, interval: 1, end: nil)
        }
    }
}

// MARK: - Quick Templates View

struct QuickTemplatesView: View {
    let onSelect: (EventTemplate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Templates")
                .font(.headline)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(NaturalLanguageParser.quickTemplates) { template in
                        Button(action: { onSelect(template) }) {
                            VStack(spacing: 8) {
                                Image(systemName: template.icon)
                                    .font(.title2)
                                Text(template.title)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(width: 80, height: 80)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Parsed Event Preview

struct ParsedEventPreview: View {
    var event: ParsedEvent
    let onLocationEdit: () -> Void
    let onAttendeeAdd: () -> Void
    let locationSuggestions: [String]
    let parser: NaturalLanguageParser

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Event Preview")
                .font(.headline)

            VStack(spacing: 12) {
                // Title
                InfoRow(icon: "text.quote", title: "Title", value: event.title)

                // Date & Time
                InfoRow(
                    icon: "calendar",
                    title: "Start",
                    value: formatDate(event.startDate)
                )

                InfoRow(
                    icon: "clock",
                    title: "Duration",
                    value: formatDuration(event.duration)
                )

                // Location
                HStack {
                    Label("Location", systemImage: "location.fill")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 120, alignment: .leading)

                    if let location = event.location, !location.isEmpty {
                        Text(location)
                    } else {
                        Button("Add Location") {
                            onLocationEdit()
                        }
                        .font(.subheadline)
                        .foregroundColor(.blue)
                    }

                    Spacer()

                    if event.location != nil {
                        Button(action: onLocationEdit) {
                            Image(systemName: "pencil")
                                .font(.caption)
                        }
                    }
                }

                // Attendees
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Attendees", systemImage: "person.2.fill")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: onAttendeeAdd) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }

                    if !event.attendees.isEmpty {
                        ForEach(event.attendees, id: \.self) { attendee in
                            Text(attendee)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(6)
                        }
                    }
                }

                // Recurrence
                if event.recurrence != .none {
                    InfoRow(
                        icon: "repeat",
                        title: "Repeats",
                        value: event.recurrence.rawValue.capitalized
                    )
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

struct InfoRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)

            Text(value)
                .font(.subheadline)

            Spacer()
        }
    }
}

// MARK: - Location Suggestions Sheet

struct LocationSuggestionsSheet: View {
    let suggestions: [String]
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List(suggestions, id: \.self) { location in
                Button(action: {
                    onSelect(location)
                }) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.blue)
                        Text(location)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Select Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Contact Search Sheet

struct ContactSearchSheet: View {
    @Binding var query: String
    @State var suggestions: [ContactSuggestion]
    let parser: NaturalLanguageParser
    let onSelect: (ContactSuggestion) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var searchResults: [ContactSuggestion] = []
    @State private var isSearching = false

    var body: some View {
        NavigationView {
            VStack {
                // Search Field
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)

                    TextField("Search contacts", text: $query)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: query) { newValue in
                            searchContacts(newValue)
                        }

                    if isSearching {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .padding()

                // Results
                List(searchResults.isEmpty ? suggestions : searchResults) { contact in
                    Button(action: {
                        onSelect(contact)
                    }) {
                        HStack {
                            Image(systemName: "person.circle.fill")
                                .foregroundColor(.blue)
                                .font(.title2)

                            VStack(alignment: .leading) {
                                Text(contact.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                if let email = contact.email {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }

                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Add Attendee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func searchContacts(_ query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true

        Task {
            let results = await parser.searchContacts(query: query)

            DispatchQueue.main.async {
                self.searchResults = results
                self.isSearching = false
            }
        }
    }
}

// MARK: - Preview

struct NaturalLanguageEventView_Previews: PreviewProvider {
    static var previews: some View {
        NaturalLanguageEventView(
            calendarManager: CalendarManager()
        )
    }
}
