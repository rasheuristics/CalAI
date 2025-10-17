import SwiftUI
import UIKit

/// View for sharing an event with QR code, tasks, and details
struct EventShareView: View {
    let event: UnifiedEvent
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @Environment(\.dismiss) var dismiss

    @State private var selectedTab: EventTab = .tasks
    @State private var organizerEmail: String = ""
    @State private var attendeeEmails: String = ""
    @State private var qrCodeImage: UIImage?
    @State private var showShareSheet = false
    @State private var useGoogleCalendarLink = false  // Default to ICS format for better compatibility

    enum EventTab: String, CaseIterable {
        case tasks = "Tasks"
        case share = "Share"
        case details = "Details"

        var icon: String {
            switch self {
            case .tasks: return "sparkles"
            case .share: return "square.and.arrow.up"
            case .details: return "info.circle"
            }
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("View", selection: $selectedTab) {
                    ForEach(EventTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                // Tab Content
                TabView(selection: $selectedTab) {
                    // Tasks Tab (First - AI icon)
                    tasksTabContent
                        .tag(EventTab.tasks)

                    // Share Tab
                    shareTabContent
                        .tag(EventTab.share)

                    // Details Tab
                    detailsTabContent
                        .tag(EventTab.details)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle(event.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showCalendarShareSheet()
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 17, weight: .medium))
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // No longer generate QR code on appear
            }
            .sheet(isPresented: $showShareSheet) {
                if let icsURL = EventICSExporter.saveToTemporaryFile(
                    event: event,
                    organizerEmail: organizerEmail.isEmpty ? nil : organizerEmail,
                    attendeeEmails: parseAttendeeEmails()
                ) {
                    EventShareSheet(items: [createShareText(), icsURL])
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

                // Share to Calendar Section
                qrCodeSection

                // Meeting Invitation Section
                meetingInvitationSection
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

    // MARK: - Share to Calendar Section

    private var qrCodeSection: some View {
        VStack(spacing: 16) {
            Text("Share Event")
                .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                .foregroundColor(.primary)

            // Calendar Source Badge
            HStack(spacing: 6) {
                Image(systemName: event.source.icon)
                    .font(.system(size: 12))
                    .foregroundColor(event.source.color)

                Text("From \(event.source.displayName)")
                    .dynamicFont(size: 12, weight: .medium, fontManager: fontManager)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(event.source.color.opacity(0.1))
            .cornerRadius(12)

            // Share to Calendar Button
            Button(action: {
                showCalendarShareSheet()
            }) {
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)

                    Text("Add to Calendar")
                        .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                        .foregroundColor(.primary)

                    Text("Choose any calendar app")
                        .dynamicFont(size: 13, fontManager: fontManager)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(.systemGray6))
                .cornerRadius(16)
            }
            .padding(.horizontal)

            // Benefits info
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("Works with all calendar apps")
                        .dynamicFont(size: 13, fontManager: fontManager)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("Share via text, email, or AirDrop")
                        .dynamicFont(size: 13, fontManager: fontManager)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                    Text("Add directly to any calendar")
                        .dynamicFont(size: 13, fontManager: fontManager)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal)
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

    // MARK: - Helper Methods

    private func showCalendarShareSheet() {
        // Create ICS file for the event
        guard let icsURL = EventICSExporter.saveToTemporaryFile(
            event: event,
            organizerEmail: organizerEmail.isEmpty ? nil : organizerEmail,
            attendeeEmails: parseAttendeeEmails()
        ) else {
            print("❌ Failed to create ICS file")
            return
        }

        print("✅ Created ICS file at: \(icsURL)")
        print("📅 Event: \(event.title)")
        print("🗓 Start: \(event.startDate)")
        print("🗓 End: \(event.endDate)")

        // Create share items
        let shareText = createShareText()
        let shareItems: [Any] = [shareText, icsURL]

        // Present native share sheet
        showShareSheet = true
    }

    private func generateQRCode() {
        let qrContent: String

        if useGoogleCalendarLink {
            // Use calendar-specific web link (shorter, universally scannable)
            qrContent = EventICSExporter.createUniversalCalendarURL(event: event)
            let calendarType = event.source == .outlook ? "Outlook" : "Google Calendar"
            print("📱 QR Code Format: Web Link (\(calendarType))")
        } else {
            // Use ICS format (more complete but larger)
            qrContent = EventICSExporter.createDataURL(
                event: event,
                organizerEmail: organizerEmail.isEmpty ? nil : organizerEmail,
                attendeeEmails: parseAttendeeEmails()
            )
            print("📱 QR Code Format: ICS File")
        }

        print("📱 Event Details in QR Code:")
        print("   - Title: \(event.title)")
        print("   - Start: \(event.startDate)")
        print("   - End: \(event.endDate)")
        print("   - Location: \(event.location ?? "None")")
        print("   - Description: \(event.description ?? "None")")
        print("   - All Day: \(event.isAllDay)")
        print("   - Calendar Source: \(event.source.displayName)")
        print("📱 QR Content length: \(qrContent.count) characters")
        print("📱 QR Content preview: \(String(qrContent.prefix(300)))")

        qrCodeImage = QRCodeGenerator.generateQRCode(from: qrContent, size: CGSize(width: 512, height: 512))

        if qrCodeImage != nil {
            print("✅ QR Code generated successfully")
        } else {
            print("❌ Failed to generate QR code - content may be too large")
        }
    }

    private var calendarNameForWebLink: String {
        switch event.source {
        case .google:
            return "Google Calendar"
        case .outlook:
            return "Outlook Calendar"
        case .ios:
            return "Google Calendar (universal)"
        }
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

        text += "\n📲 Open the attached calendar file to add this event to any calendar app."

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
