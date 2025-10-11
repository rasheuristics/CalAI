import SwiftUI
import UIKit

/// View for sharing an event with QR code, tasks, and details
struct EventShareView: View {
    let event: UnifiedEvent
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: EventTab = .share
    @State private var organizerEmail: String = ""
    @State private var attendeeEmails: String = ""
    @State private var qrCodeImage: UIImage?
    @State private var showShareSheet = false

    enum EventTab: String, CaseIterable {
        case share = "Share"
        case tasks = "Tasks"
        case details = "Details"
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    ForEach(EventTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab Content
                TabView(selection: $selectedTab) {
                    // Share Tab
                    shareTabContent
                        .tag(EventTab.share)

                    // Tasks Tab
                    tasksTabContent
                        .tag(EventTab.tasks)

                    // Details Tab
                    detailsTabContent
                        .tag(EventTab.details)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                generateQRCode()
            }
            .sheet(isPresented: $showShareSheet) {
                if let qrImage = qrCodeImage,
                   let icsURL = EventICSExporter.saveToTemporaryFile(
                    event: event,
                    organizerEmail: organizerEmail.isEmpty ? nil : organizerEmail,
                    attendeeEmails: parseAttendeeEmails()
                   ) {
                    EventShareSheet(items: [qrImage, icsURL, createShareText()])
                }
            }
        }
    }

    // MARK: - Tab Contents

    private var shareTabContent: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Event Info
                eventInfoSection

                // QR Code
                qrCodeSection

                // Meeting Invitation Section
                meetingInvitationSection

                // Share Button
                shareButton
            }
            .padding()
        }
    }

    private var tasksTabContent: some View {
        EventTasksTabView(event: event, fontManager: fontManager)
    }

    private var detailsTabContent: some View {
        EventDetailsTabView(event: event, calendarManager: calendarManager, fontManager: fontManager)
    }

    // MARK: - Event Info Section

    private var eventInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(event.title)
                .dynamicFont(size: 22, weight: .bold, fontManager: fontManager)
                .foregroundColor(.primary)

            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                Text(formatDate(event.startDate))
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "clock")
                    .foregroundColor(.secondary)
                Text(formatTimeRange(event.startDate, event.endDate))
                    .dynamicFont(size: 14, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }

            if let location = event.location, !location.isEmpty {
                HStack {
                    Image(systemName: "location")
                        .foregroundColor(.secondary)
                    Text(location)
                        .dynamicFont(size: 14, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - QR Code Section

    private var qrCodeSection: some View {
        VStack(spacing: 12) {
            Text("QR Code")
                .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            if let qrImage = qrCodeImage {
                Image(uiImage: qrImage)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .frame(width: 180, height: 180)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            } else {
                ProgressView()
                    .frame(width: 180, height: 180)
            }

            Text("Scan to add this event to your calendar")
                .dynamicFont(size: 12, fontManager: fontManager)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Meeting Invitation Section

    private var meetingInvitationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meeting Invitation (Optional)")
                .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            Text("Add your email and attendee emails to create a meeting invitation with RSVP")
                .dynamicFont(size: 14, fontManager: fontManager)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Organizer Email")
                    .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)
                    .foregroundColor(.primary)

                TextField("your@email.com", text: $organizerEmail)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .onChange(of: organizerEmail) { _ in
                        generateQRCode()
                    }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Attendee Emails")
                    .dynamicFont(size: 14, weight: .medium, fontManager: fontManager)
                    .foregroundColor(.primary)

                TextField("email1@example.com, email2@example.com", text: $attendeeEmails)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .keyboardType(.emailAddress)
                    .onChange(of: attendeeEmails) { _ in
                        generateQRCode()
                    }

                Text("Separate multiple emails with commas")
                    .dynamicFont(size: 12, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    // MARK: - Share Button

    private var shareButton: some View {
        Button(action: {
            showShareSheet = true
        }) {
            HStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                Text("Share Event")
                    .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
    }

    // MARK: - Helper Methods

    private func generateQRCode() {
        let dataURL = EventICSExporter.createDataURL(
            event: event,
            organizerEmail: organizerEmail.isEmpty ? nil : organizerEmail,
            attendeeEmails: parseAttendeeEmails()
        )

        qrCodeImage = QRCodeGenerator.generateQRCode(from: dataURL, size: CGSize(width: 512, height: 512))
    }

    private func parseAttendeeEmails() -> [String] {
        return attendeeEmails
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.contains("@") }
    }

    private func createShareText() -> String {
        var text = "📅 \(event.title)\n"
        text += "🗓 \(formatDate(event.startDate))\n"
        text += "🕐 \(formatTimeRange(event.startDate, event.endDate))\n"

        if let location = event.location, !location.isEmpty {
            text += "📍 \(location)\n"
        }

        if let description = event.description, !description.isEmpty {
            text += "\n\(description)\n"
        }

        text += "\n📲 Scan the QR code or open the attached .ics file to add this event to your calendar."

        if !organizerEmail.isEmpty && !parseAttendeeEmails().isEmpty {
            text += "\n\n✉️ This is a meeting invitation. Accept to send RSVP to the organizer."
        }

        return text
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func formatTimeRange(_ start: Date, _ end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - Event Share Sheet (UIKit wrapper)

struct EventShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
