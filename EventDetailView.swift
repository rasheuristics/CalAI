import SwiftUI
import EventKit

struct EventDetailView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) private var dismiss

    let event: UnifiedEvent
    @State private var showEditView = false
    @State private var showShareView = false

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

                    // Notes Section
                    if let notes = event.description, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 12) {
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
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
            originalEvent: NSObject()
        )
    )
}
