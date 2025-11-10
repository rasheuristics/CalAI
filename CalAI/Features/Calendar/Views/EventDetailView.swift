//
//  EventDetailView.swift
//  CalAI
//
//  Detailed event view matching iOS Calendar app design
//  Created by Claude Code on 11/9/25.
//

import SwiftUI
import MapKit
import EventKit

struct EventDetailView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var calendarManager: CalendarManager

    let event: UnifiedEvent
    @State private var showingOptions = false
    @State private var showingDeleteConfirmation = false
    @State private var region: MKCoordinateRegion?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // Event header with color bar
                    eventHeader

                    // Event details cards
                    VStack(spacing: 16) {
                        // Time card
                        timeCard

                        // Calendar badge
                        calendarCard

                        // Location with map
                        if let location = event.location, !location.isEmpty {
                            locationCard(location: location)
                        }

                        // Alerts
                        alertsCard

                        // Notes
                        if let notes = event.notes, !notes.isEmpty {
                            notesCard(notes: notes)
                        }

                        // Attendees
                        if let attendees = event.attendees, !attendees.isEmpty {
                            attendeesCard(attendees: attendees)
                        }
                    }
                    .padding()

                    Spacer(minLength: 80)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Back")
                        }
                        .foregroundColor(.blue)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingOptions = true }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.blue)
                    }
                }
            }
            .overlay(alignment: .bottom) {
                deleteButton
            }
            .confirmationDialog("Delete Event", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete Event", role: .destructive) {
                    deleteEvent()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete '\(event.title)'?")
            }
            .sheet(isPresented: $showingOptions) {
                optionsSheet
            }
        }
    }

    // MARK: - Event Header

    private var eventHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Color bar
            Rectangle()
                .fill(Color(event.color ?? .systemBlue))
                .frame(height: 4)

            // Title
            Text(event.title)
                .font(.system(size: 28, weight: .bold))
                .padding(.horizontal)
                .padding(.top, 12)

            // Date range
            Text(formatDateRange())
                .font(.system(size: 17))
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Time Card

    private var timeCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text(formatTime(event.startDate))
                        .font(.system(size: 17))

                    if !event.isAllDay {
                        Text(formatDuration())
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding()

            Divider()
                .padding(.leading, 50)

            // Visual timeline
            timelineView
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    private var timelineView: some View {
        HStack(alignment: .top, spacing: 12) {
            // Time labels
            VStack(alignment: .trailing, spacing: 0) {
                Text(formatTimeOnly(event.startDate))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()

                Text(formatTimeOnly(event.endDate))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(width: 60)

            // Timeline bar
            VStack(spacing: 0) {
                Circle()
                    .fill(Color(event.color ?? .systemBlue))
                    .frame(width: 8, height: 8)

                Rectangle()
                    .fill(Color(event.color ?? .systemBlue))
                    .frame(width: 2)

                Circle()
                    .fill(Color(event.color ?? .systemBlue))
                    .frame(width: 8, height: 8)
            }
            .frame(height: 60)

            // Event card preview
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(2)

                if let location = event.location {
                    Text(location)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(event.color ?? .systemBlue).opacity(0.15))
            .cornerRadius(6)

            Spacer()
        }
        .padding()
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(event.color ?? .systemBlue))
                        .frame(width: 10, height: 10)

                    Text(event.source.displayName)
                        .font(.system(size: 17))
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: - Location Card with Map

    private func locationCard(location: String) -> some View {
        VStack(spacing: 0) {
            // Location info
            HStack {
                Image(systemName: "location")
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Location")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)

                    Text(location)
                        .font(.system(size: 17))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding()

            // Map preview
            if region != nil {
                Map(coordinateRegion: .constant(region!))
                    .frame(height: 180)
                    .cornerRadius(10)
                    .padding(.horizontal)
                    .padding(.bottom)
                    .onTapGesture {
                        openInMaps(location: location)
                    }
            } else {
                // Placeholder map
                ZStack {
                    Color(.systemGray5)

                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)

                        Text("Tap to open in Maps")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 180)
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.bottom)
                .onTapGesture {
                    openInMaps(location: location)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
        .onAppear {
            geocodeLocation(location)
        }
    }

    // MARK: - Alerts Card

    private var alertsCard: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "bell")
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Alert")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)

                    Text("At time of event")
                        .font(.system(size: 17))
                }

                Spacer()
            }
            .padding()

            Divider()
                .padding(.leading, 50)

            HStack {
                Image(systemName: "bell")
                    .foregroundColor(.blue)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Second Alert")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)

                    Text("15 minutes before")
                        .font(.system(size: 17))
                }

                Spacer()
            }
            .padding()
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: - Notes Card

    private func notesCard(notes: String) -> some View {
        HStack(alignment: .top) {
            Image(systemName: "note.text")
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text("Notes")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                Text(notes)
                    .font(.system(size: 17))
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: - Attendees Card

    private func attendeesCard(attendees: [UnifiedAttendee]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.2")
                    .foregroundColor(.blue)
                    .frame(width: 30)

                Text("Invitees")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                Spacer()
            }

            ForEach(attendees, id: \.emailAddress) { attendee in
                HStack(spacing: 12) {
                    // Avatar placeholder
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Text(String(attendee.name?.prefix(1) ?? "?"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.blue)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(attendee.name ?? attendee.emailAddress ?? "Unknown")
                            .font(.system(size: 17))

                        if let email = attendee.emailAddress {
                            Text(email)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.leading, 42)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: - Delete Button

    private var deleteButton: some View {
        Button(action: { showingDeleteConfirmation = true }) {
            Text("Delete Event")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Options Sheet

    private var optionsSheet: some View {
        NavigationView {
            List {
                Button(action: {
                    showingOptions = false
                    // TODO: Implement edit
                }) {
                    Label("Edit", systemImage: "pencil")
                }

                Button(action: {
                    showingOptions = false
                    shareEvent()
                }) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }

                Button(action: {
                    showingOptions = false
                    // TODO: Implement convert to task
                }) {
                    Label("Convert to Task", systemImage: "checkmark.circle")
                }
            }
            .navigationTitle("Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingOptions = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Helper Functions

    private func formatDateRange() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"

        let calendar = Calendar.current
        if calendar.isDate(event.startDate, inSameDayAs: event.endDate) {
            return formatter.string(from: event.startDate)
        } else {
            let endFormatter = DateFormatter()
            endFormatter.dateFormat = "EEEE, MMMM d, yyyy"
            return "\(formatter.string(from: event.startDate)) - \(endFormatter.string(from: event.endDate))"
        }
    }

    private func formatTime(_ date: Date) -> String {
        if event.isAllDay {
            return "All day"
        }

        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatTimeOnly(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func formatDuration() -> String {
        let duration = event.endDate.timeIntervalSince(event.startDate)
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60

        if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")\(minutes > 0 ? " \(minutes) min" : "")"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }

    private func geocodeLocation(_ location: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            if let placemark = placemarks?.first,
               let location = placemark.location {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }

    private func openInMaps(location: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            if let placemark = placemarks?.first,
               let location = placemark.location {
                let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                mapItem.name = event.title
                mapItem.openInMaps(launchOptions: nil)
            } else {
                // Fallback: search by name
                let searchRequest = MKLocalSearch.Request()
                searchRequest.naturalLanguageQuery = location
                let search = MKLocalSearch(request: searchRequest)
                search.start { response, error in
                    response?.mapItems.first?.openInMaps(launchOptions: nil)
                }
            }
        }
    }

    private func shareEvent() {
        // Create share content
        var shareText = "📅 \(event.title)\n"
        shareText += "🕐 \(formatDateRange())\n"
        if !event.isAllDay {
            shareText += "\(formatTime(event.startDate)) - \(formatTime(event.endDate))\n"
        }
        if let location = event.location {
            shareText += "📍 \(location)\n"
        }

        // Present share sheet
        let activityVC = UIActivityViewController(
            activityItems: [shareText],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    private func deleteEvent() {
        calendarManager.deleteEvent(eventId: event.id, source: event.source)
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    EventDetailView(
        calendarManager: CalendarManager(),
        event: UnifiedEvent(
            id: "preview",
            title: "Team Standup",
            startDate: Date(),
            endDate: Date().addingTimeInterval(1800),
            location: "Conference Room A",
            notes: "Discuss project progress and blockers",
            source: .iOS,
            color: .systemBlue,
            attendees: [
                UnifiedAttendee(name: "John Doe", emailAddress: "john@example.com", status: .accepted),
                UnifiedAttendee(name: "Jane Smith", emailAddress: "jane@example.com", status: .tentative)
            ],
            isAllDay: false
        )
    )
}
