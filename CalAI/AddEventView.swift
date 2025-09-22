import SwiftUI
import EventKit
import UniformTypeIdentifiers

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

struct AddEventView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

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

    var body: some View {
        NavigationView {
            Form {
                Section("Event Details") {
                    TextField("Title", text: $title)
                        .dynamicFont(size: 17, fontManager: fontManager)

                    TextField("Location", text: $location)
                        .dynamicFont(size: 17, fontManager: fontManager)
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
            .navigationTitle("Add Event")
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
                        createEvent()
                    }
                    .disabled(title.isEmpty)
                    .dynamicFont(size: 17, weight: .semibold, fontManager: fontManager)
                }
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