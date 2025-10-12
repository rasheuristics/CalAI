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
        // This would be determined by checking if the respective managers are signed in
        return true // For now, always show all options
    }
}

struct AttachmentItem: Identifiable {
    let id = UUID()
    let name: String
    let url: URL?
    let data: Data?
}

enum RepeatOption: String, CaseIterable, Identifiable {
    case none = "None"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"

    var id: String { rawValue }

    var displayName: String { rawValue }
}

struct EventAttendee: Identifiable {
    let id = UUID()
    let email: String
    let name: String?

    var displayName: String {
        return name ?? email
    }
}

struct LocationSuggestion: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String?
    let coordinate: CLLocationCoordinate2D?

    init(name: String, subtitle: String? = nil, coordinate: CLLocationCoordinate2D? = nil) {
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
    }

    init(mapItem: MKMapItem) {
        self.name = mapItem.name ?? "Unknown Location"
        self.subtitle = mapItem.placemark.title
        self.coordinate = mapItem.placemark.coordinate
    }
}

struct AddEventView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    // Optional event for editing mode
    let eventToEdit: UnifiedEvent?

    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var eventURL = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var isAllDay = false
    @State private var selectedCalendar: CalendarOption = .ios
    @State private var attachments: [AttachmentItem] = []
    @State private var showingDocumentPicker = false
    @State private var selectedRepeat: RepeatOption = .none
    @State private var attendees: [EventAttendee] = []
    @State private var newAttendeeEmail = ""
    @State private var showingAttendeeInput = false
    @State private var sendInvitations = true
    @State private var isLoading = false
    @State private var errorMessage: String?

    // Location selection states
    @State private var showingLocationPicker = false
    @State private var locationSearchText = ""
    @State private var locationSuggestions: [LocationSuggestion] = []
    @State private var recentLocations: [LocationSuggestion] = []
    @State private var isSearchingLocation = false

    // Computed properties for edit mode
    private var isEditMode: Bool { eventToEdit != nil }
    private var navigationTitle: String { isEditMode ? "Edit Event" : "Add Event" }
    private var saveButtonTitle: String { isEditMode ? "Update" : "Save" }

    // Initialize with optional event
    init(calendarManager: CalendarManager, fontManager: FontManager, eventToEdit: UnifiedEvent? = nil) {
        self.calendarManager = calendarManager
        self.fontManager = fontManager
        self.eventToEdit = eventToEdit
    }

    var body: some View {
        NavigationView {
            ZStack {
                // Transparent background to show main gradient
                Color.clear
                    .ignoresSafeArea()

                Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                        .dynamicFont(size: 17, fontManager: fontManager)

                    Button(action: {
                        showingLocationPicker = true
                    }) {
                        HStack {
                            Image(systemName: "location")
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Location")
                                    .dynamicFont(size: 17, fontManager: fontManager)
                                    .foregroundColor(.primary)

                                if location.isEmpty {
                                    Text("Add location")
                                        .dynamicFont(size: 15, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(location)
                                        .dynamicFont(size: 15, fontManager: fontManager)
                                        .foregroundColor(.blue)
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }

                Section("Calendar") {
                    Picker("Add to Calendar", selection: $selectedCalendar) {
                        ForEach(CalendarOption.allCases.filter(\.isAvailable)) { option in
                            Text(option.name)
                                .dynamicFont(size: 17, fontManager: fontManager)
                                .tag(option)
                        }
                    }
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

                Section("Invites & Attendees") {
                    if attendees.isEmpty {
                        Button(action: {
                            showingAttendeeInput = true
                        }) {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                    .foregroundColor(.blue)
                                Text("Add Attendees")
                                    .dynamicFont(size: 17, fontManager: fontManager)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                    } else {
                        ForEach(attendees) { attendee in
                            HStack {
                                Image(systemName: "person.circle")
                                    .foregroundColor(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(attendee.displayName)
                                        .dynamicFont(size: 17, fontManager: fontManager)
                                    Text(attendee.email)
                                        .dynamicFont(size: 12, fontManager: fontManager)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    removeAttendee(attendee)
                                }) {
                                    Image(systemName: "minus.circle")
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        Button(action: {
                            showingAttendeeInput = true
                        }) {
                            HStack {
                                Image(systemName: "plus")
                                    .foregroundColor(.blue)
                                Text("Add More")
                                    .dynamicFont(size: 17, fontManager: fontManager)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }

                        Toggle("Send Invitations", isOn: $sendInvitations)
                            .dynamicFont(size: 17, fontManager: fontManager)
                    }
                }

                Section("URL") {
                    TextField("Event URL", text: $eventURL)
                        .dynamicFont(size: 17, fontManager: fontManager)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }

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
                                Spacer()
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
                                Image(systemName: "plus")
                                    .foregroundColor(.blue)
                                Text("Add More")
                                    .dynamicFont(size: 17, fontManager: fontManager)
                                    .foregroundColor(.blue)
                                Spacer()
                            }
                        }
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .dynamicFont(size: 17, fontManager: fontManager)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .dynamicFont(size: 17, fontManager: fontManager)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(saveButtonTitle) {
                        if isEditMode {
                            updateEvent()
                        } else {
                            createEvent()
                        }
                    }
                    .disabled(title.isEmpty || isLoading)
                    .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                }
                }
                .background(Color.clear)
            }
        }
        .onAppear {
            loadEventDataIfNeeded()
            loadRecentLocations()
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
        .sheet(isPresented: $showingAttendeeInput) {
            AttendeeInputView(
                newAttendeeEmail: $newAttendeeEmail,
                onAdd: { email in
                    addAttendee(email: email)
                    showingAttendeeInput = false
                },
                onCancel: {
                    newAttendeeEmail = ""
                    showingAttendeeInput = false
                }
            )
        }
        .sheet(isPresented: $showingLocationPicker) {
            LocationPickerView(
                selectedLocation: $location,
                fontManager: fontManager,
                onLocationSelected: { selectedLocation in
                    location = selectedLocation
                    saveToRecentLocations(selectedLocation)
                    showingLocationPicker = false
                },
                onCancel: {
                    showingLocationPicker = false
                }
            )
        }
    }

    private func createEvent() {
        guard !title.isEmpty else { return }

        // For now, only create events in iOS calendar
        // TODO: Implement creation for Google and Outlook calendars based on selectedCalendar
        switch selectedCalendar {
        case .ios:
            calendarManager.createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate
            )
        case .google:
            // TODO: Implement Google Calendar event creation
            print("📅 Google Calendar event creation not yet implemented")
        case .outlook:
            // TODO: Implement Outlook Calendar event creation
            print("📅 Outlook Calendar event creation not yet implemented")
        }

        dismiss()
    }

    private func loadEventDataIfNeeded() {
        guard let event = eventToEdit else { return }

        // Load event data into form fields
        title = event.title
        location = event.location ?? ""
        notes = event.description ?? ""
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay

        // Set the appropriate calendar option based on source
        switch event.source {
        case .ios:
            selectedCalendar = .ios
        case .google:
            selectedCalendar = .google
        case .outlook:
            selectedCalendar = .outlook
        }
    }

    private func updateEvent() {
        guard !title.isEmpty, let eventToEdit = eventToEdit else { return }

        isLoading = true
        errorMessage = nil

        let updatedEvent = UnifiedEvent(
            id: eventToEdit.id,
            title: title,
            startDate: startDate,
            endDate: endDate,
            location: location.isEmpty ? nil : location,
            description: notes.isEmpty ? nil : notes,
            isAllDay: isAllDay,
            source: eventToEdit.source,
            organizer: eventToEdit.organizer,
            originalEvent: eventToEdit.originalEvent
        )

        updateEventInCalendar(updatedEvent) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    // Refresh calendar data
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
            calendarId: "primary",
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
            calendarId: "primary-calendar",
            organizer: nil
        )

        calendarManager.outlookCalendarManager?.updateEvent(outlookEvent) { success, error in
            completion(success, error)
        }
    }

    private func loadRecentLocations() {
        // Load recent locations from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "RecentLocations"),
           let locations = try? JSONDecoder().decode([String].self, from: data) {
            recentLocations = locations.prefix(5).map { LocationSuggestion(name: $0) }
        }
    }

    private func saveToRecentLocations(_ location: String) {
        guard !location.isEmpty else { return }

        var locations = UserDefaults.standard.stringArray(forKey: "RecentLocations") ?? []

        // Remove if already exists
        locations.removeAll { $0 == location }

        // Add to beginning
        locations.insert(location, at: 0)

        // Keep only 10 most recent
        locations = Array(locations.prefix(10))

        UserDefaults.standard.set(locations, forKey: "RecentLocations")

        // Update the state
        recentLocations = locations.prefix(5).map { LocationSuggestion(name: $0) }
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

    private func addAttendee(email: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty,
              trimmedEmail.contains("@"),
              !attendees.contains(where: { $0.email == trimmedEmail }) else {
            return
        }

        let name = extractDisplayName(from: trimmedEmail)
        let attendee = EventAttendee(email: trimmedEmail, name: name.isEmpty ? nil : name)
        attendees.append(attendee)
        newAttendeeEmail = ""
    }

    private func removeAttendee(_ attendee: EventAttendee) {
        attendees.removeAll { $0.id == attendee.id }
    }

    private func extractDisplayName(from email: String) -> String {
        let localPart = email.components(separatedBy: "@").first ?? ""
        let nameParts = localPart.components(separatedBy: ".")

        if nameParts.count >= 2 {
            let firstName = nameParts[0].capitalized
            let lastName = nameParts[1].capitalized
            return "\(firstName) \(lastName)"
        } else {
            return localPart.capitalized
        }
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    let onDocumentsPicked: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [
            .item,
            .content,
            .data,
            .image,
            .pdf,
            .text,
            .audio,
            .movie
        ], asCopy: true)
        documentPicker.allowsMultipleSelection = true
        documentPicker.delegate = context.coordinator
        return documentPicker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker

        init(_ parent: DocumentPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.onDocumentsPicked(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // Handle cancellation if needed
        }
    }
}

struct AttendeeInputView: View {
    @Binding var newAttendeeEmail: String
    let onAdd: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationView {
            Form {
                Section("Add Attendee") {
                    TextField("Email address", text: $newAttendeeEmail)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .textInputAutocapitalization(.never)
                }

                Section {
                    Text("Enter the email address of the person you want to invite to this event.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Add Attendee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd(newAttendeeEmail)
                    }
                    .disabled(newAttendeeEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !newAttendeeEmail.contains("@"))
                }
            }
        }
    }
}

struct LocationPickerView: View {
    @Binding var selectedLocation: String
    @ObservedObject var fontManager: FontManager
    let onLocationSelected: (String) -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @State private var searchResults: [LocationSuggestion] = []
    @State private var recentLocations: [LocationSuggestion] = []
    @State private var isSearching = false
    @StateObject private var locationSearchDelegate = LocationSearchDelegate()

    private let commonSuggestions = [
        LocationSuggestion(name: "Home"),
        LocationSuggestion(name: "Work"),
        LocationSuggestion(name: "Office"),
        LocationSuggestion(name: "Conference Room"),
        LocationSuggestion(name: "Meeting Room"),
        LocationSuggestion(name: "Coffee Shop"),
        LocationSuggestion(name: "Restaurant"),
        LocationSuggestion(name: "Library"),
        LocationSuggestion(name: "Gym"),
        LocationSuggestion(name: "Airport")
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search for a location", text: $searchText)
                        .dynamicFont(size: 17, fontManager: fontManager)
                        .textFieldStyle(PlainTextFieldStyle())
                        .onSubmit {
                            performSearch()
                        }

                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                List {
                    // No location option
                    Button(action: {
                        onLocationSelected("")
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.red)
                            Text("No Location")
                                .dynamicFont(size: 17, fontManager: fontManager)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                    }
                    .buttonStyle(PlainButtonStyle())

                    // Custom location entry
                    if !searchText.isEmpty && !searchResults.contains(where: { $0.name.lowercased() == searchText.lowercased() }) {
                        Button(action: {
                            onLocationSelected(searchText)
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                    .foregroundColor(.blue)
                                Text("Use \"\(searchText)\"")
                                    .dynamicFont(size: 17, fontManager: fontManager)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    // Search results
                    if !searchResults.isEmpty {
                        Section("Search Results") {
                            ForEach(searchResults) { location in
                                LocationRow(
                                    location: location,
                                    fontManager: fontManager,
                                    onTap: {
                                        onLocationSelected(location.name)
                                    }
                                )
                            }
                        }
                    }

                    // Recent locations
                    if !recentLocations.isEmpty && searchText.isEmpty {
                        Section("Recent") {
                            ForEach(recentLocations) { location in
                                LocationRow(
                                    location: location,
                                    fontManager: fontManager,
                                    onTap: {
                                        onLocationSelected(location.name)
                                    }
                                )
                            }
                        }
                    }

                    // Common suggestions
                    if searchText.isEmpty {
                        Section("Suggestions") {
                            ForEach(commonSuggestions) { location in
                                LocationRow(
                                    location: location,
                                    fontManager: fontManager,
                                    onTap: {
                                        onLocationSelected(location.name)
                                    }
                                )
                            }
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        onCancel()
                    }
                    .dynamicFont(size: 17, fontManager: fontManager)
                }
            }
        }
        .onAppear {
            loadRecentLocations()
            locationSearchDelegate.onSearchResultsUpdated = { results in
                self.searchResults = results
            }
        }
        .onChange(of: searchText) { newValue in
            if newValue.isEmpty {
                searchResults = []
                locationSearchDelegate.searchCompleter.cancel()
            } else {
                locationSearchDelegate.searchCompleter.queryFragment = newValue
            }
        }
    }

    private func performSearch() {
        guard !searchText.isEmpty else { return }
        locationSearchDelegate.searchCompleter.queryFragment = searchText
    }

    private func loadRecentLocations() {
        if let data = UserDefaults.standard.data(forKey: "RecentLocations"),
           let locations = try? JSONDecoder().decode([String].self, from: data) {
            recentLocations = locations.prefix(5).map { LocationSuggestion(name: $0) }
        }
    }
}

struct LocationRow: View {
    let location: LocationSuggestion
    @ObservedObject var fontManager: FontManager
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "location")
                    .foregroundColor(.blue)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .dynamicFont(size: 17, fontManager: fontManager)
                        .foregroundColor(.primary)

                    if let subtitle = location.subtitle {
                        Text(subtitle)
                            .dynamicFont(size: 14, fontManager: fontManager)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

class LocationSearchDelegate: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchResults: [LocationSuggestion] = []
    var onSearchResultsUpdated: (([LocationSuggestion]) -> Void)?

    let searchCompleter = MKLocalSearchCompleter()

    override init() {
        super.init()
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results.map { completion in
            LocationSuggestion(
                name: completion.title,
                subtitle: completion.subtitle.isEmpty ? nil : completion.subtitle
            )
        }

        DispatchQueue.main.async {
            self.searchResults = results
            self.onSearchResultsUpdated?(results)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Location search failed: \(error.localizedDescription)")
        DispatchQueue.main.async {
            self.searchResults = []
            self.onSearchResultsUpdated?([])
        }
    }
}