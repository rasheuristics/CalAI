import SwiftUI
import EventKit

struct AddEventView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var location = ""
    @State private var notes = ""
    @State private var startDate = Date()
    @State private var endDate = Date().addingTimeInterval(3600)
    @State private var isAllDay = false

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
    }

    private func createEvent() {
        guard !title.isEmpty else { return }

        calendarManager.createEvent(
            title: title,
            startDate: startDate,
            endDate: endDate
        )

        dismiss()
    }
}