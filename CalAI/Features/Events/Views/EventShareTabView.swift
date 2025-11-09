import SwiftUI
import UIKit
import EventKit
import MessageUI

#if canImport(FoundationModels)
import FoundationModels
#endif

/// Tab view for sharing event functionality
struct EventShareTabView: View {
    let event: UnifiedEvent
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager

    // Smart Export states
    @State private var isGeneratingInvitation = false
    @State private var generatedInvitation: String = ""
    @State private var selectedExportFormat: SmartExportFormat = .emailInvitation
    @State private var showAirDropSheet = false
    @State private var airDropItems: [Any] = []
    @State private var currentICSURL: URL?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Event Info
                eventInfoSection

                // AI Smart Export Section
                smartExportSection
            }
            .padding()
        }
        .sheet(isPresented: $showAirDropSheet) {
            if let icsURL = currentICSURL {
                EnhancedEventShareSheet(event: event, items: airDropItems, icsURL: icsURL)
            }
        }
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

    // MARK: - Helper Methods

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

    // MARK: - AI Smart Export Section

    private var smartExportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 20))
                    .foregroundColor(.purple)

                Text("AI Smart Export")
                    .dynamicFont(size: 18, weight: .semibold, fontManager: fontManager)
                    .foregroundColor(.primary)

                Spacer()

                if #available(iOS 26.0, *) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.green)
                }
            }

            Text("Export with AI-generated invitation text and calendar file")
                .dynamicFont(size: 14, fontManager: fontManager)
                .foregroundColor(.secondary)

            // Export Format Options
            VStack(spacing: 12) {
                SmartExportOptionRow(
                    icon: "envelope.fill",
                    title: "Email Invitation",
                    description: "Professional invitation text + .ics file",
                    color: .blue,
                    isSelected: selectedExportFormat == .emailInvitation
                ) {
                    selectedExportFormat = .emailInvitation
                }

                SmartExportOptionRow(
                    icon: "message.fill",
                    title: "Text Message",
                    description: "Share .ics file via Messages",
                    color: .green,
                    isSelected: selectedExportFormat == .textMessage
                ) {
                    selectedExportFormat = .textMessage
                }

                SmartExportOptionRow(
                    icon: "doc.text.fill",
                    title: "Formatted Invitation",
                    description: "Share formatted text + .ics file",
                    color: .orange,
                    isSelected: selectedExportFormat == .formattedInvitation
                ) {
                    selectedExportFormat = .formattedInvitation
                }

                SmartExportOptionRow(
                    icon: "calendar.badge.plus",
                    title: "Calendar File",
                    description: "Share .ics to add to any calendar",
                    color: .purple,
                    isSelected: selectedExportFormat == .enhancedICS
                ) {
                    selectedExportFormat = .enhancedICS
                }

                SmartExportOptionRow(
                    icon: "antenna.radiowaves.left.and.right",
                    title: "AirDrop Share",
                    description: "Touch phones to share instantly",
                    color: .cyan,
                    isSelected: selectedExportFormat == .airDrop
                ) {
                    selectedExportFormat = .airDrop
                }
            }

            // Generate & Share Button
            Button(action: {
                generateSmartExport()
            }) {
                HStack {
                    if isGeneratingInvitation {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: formatButtonIcon)
                            .font(.system(size: 18))
                    }

                    Text(isGeneratingInvitation ? "Generating..." : formatButtonText)
                        .dynamicFont(size: 16, weight: .semibold, fontManager: fontManager)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(isGeneratingInvitation ? Color.gray : formatButtonColor)
                .cornerRadius(12)
            }
            .disabled(isGeneratingInvitation)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple.opacity(0.3), lineWidth: 2)
        )
    }

    // MARK: - Button Appearance

    private var formatButtonIcon: String {
        switch selectedExportFormat {
        case .emailInvitation: return "envelope.fill"
        case .textMessage: return "message.fill"
        case .formattedInvitation: return "doc.text.fill"
        case .enhancedICS: return "calendar.badge.plus"
        case .airDrop: return "antenna.radiowaves.left.and.right"
        }
    }

    private var formatButtonText: String {
        switch selectedExportFormat {
        case .emailInvitation: return "Open in Mail"
        case .textMessage: return "Share via Messages"
        case .formattedInvitation: return "Share Invitation"
        case .enhancedICS: return "Share Calendar File"
        case .airDrop: return "Share via AirDrop"
        }
    }

    private var formatButtonColor: Color {
        switch selectedExportFormat {
        case .emailInvitation: return .blue
        case .textMessage: return .green
        case .formattedInvitation: return .orange
        case .enhancedICS: return .purple
        case .airDrop: return .cyan
        }
    }

    // MARK: - AI Smart Export Logic

    private func generateSmartExport() {
        isGeneratingInvitation = true

        if #available(iOS 26.0, *) {
            Task {
                do {
                    let invitation = try await generateAIInvitation(format: selectedExportFormat)
                    await MainActor.run {
                        generatedInvitation = invitation
                        isGeneratingInvitation = false
                        shareDirectly()
                    }
                } catch {
                    await MainActor.run {
                        // Fallback to template-based invitation
                        generatedInvitation = createFallbackInvitation(format: selectedExportFormat)
                        isGeneratingInvitation = false
                        shareDirectly()
                    }
                }
            }
        } else {
            // iOS < 26: Use template-based invitation
            generatedInvitation = createFallbackInvitation(format: selectedExportFormat)
            isGeneratingInvitation = false
            shareDirectly()
        }
    }

    private func shareDirectly() {
        // Create ICS file
        guard let icsURL = EventICSExporter.saveToTemporaryFile(event: event) else {
            print("❌ Failed to create ICS file")
            return
        }

        print("✅ Generated invitation for format: \(selectedExportFormat.rawValue)")
        print("✅ Created ICS file at: \(icsURL)")

        // Open appropriate app based on format
        switch selectedExportFormat {
        case .emailInvitation:
            openEmailApp(with: generatedInvitation, icsURL: icsURL)
        case .textMessage, .formattedInvitation, .enhancedICS, .airDrop:
            // All other formats use share sheet so recipient can import to calendar
            openShareSheet(with: generatedInvitation, icsURL: icsURL)
        }
    }

    private func openEmailApp(with text: String, icsURL: URL) {
        // Extract subject from generated text (first line after "Subject:")
        let lines = text.components(separatedBy: "\n")
        var subject = event.title
        var body = text

        if let subjectLine = lines.first(where: { $0.hasPrefix("Subject:") }) {
            subject = subjectLine.replacingOccurrences(of: "Subject:", with: "").trimmingCharacters(in: .whitespaces)
            // Remove subject line from body
            body = lines.filter { !$0.hasPrefix("Subject:") }.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Create mailto URL with subject and body
        var components = URLComponents(string: "mailto:")!
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]

        if let url = components.url {
            UIApplication.shared.open(url)
            print("📧 Opened Mail app with invitation")
        }
    }

    private func openShareSheet(with text: String, icsURL: URL) {
        // Prepare items for enhanced share sheet
        // The enhanced share sheet includes a custom "Add to Calendar" action
        // that appears at the top of the share options
        airDropItems = [text, icsURL]
        currentICSURL = icsURL
        showAirDropSheet = true

        let formatName = selectedExportFormat.rawValue
        print("📤 Opening enhanced share sheet for \(formatName)")
        print("   Sharing: \(icsURL.lastPathComponent)")
        print("   Custom actions available:")
        print("   • ⭐ Add to Calendar (custom action)")
        print("   • Share via Messages, Mail, AirDrop")
        print("   • Save to Files")
    }

    @available(iOS 26.0, *)
    private func generateAIInvitation(format: SmartExportFormat) async throws -> String {
        let aiService = OnDeviceAIService.shared
        let session = LanguageModelSession(
            instructions: "You are an expert at writing professional and friendly event invitations."
        )

        let prompt = """
        Generate a \(format.description) for this event:

        Title: \(event.title)
        Date: \(formatDate(event.startDate))
        Time: \(formatTimeRange(event.startDate, event.endDate))
        Location: \(event.location ?? "TBD")
        Description: \(event.description ?? "")

        Format: \(format.rawValue)

        Guidelines:
        - Email Invitation: Professional, warm tone with all event details
        - Text Message: Casual, brief, friendly tone
        - Formatted Invitation: Well-structured with headers and sections
        - Enhanced Calendar File: Professional description for .ics file

        Include:
        - Greeting appropriate to the format
        - Event details
        - Call to action (RSVP, save date, etc.)
        - Closing appropriate to the format

        Keep it natural, friendly, and appropriate for the format.
        """

        let response = try await session.respond(to: prompt, generating: InvitationContent.self)
        let content = response.content

        // Combine subject and body based on format
        switch format {
        case .emailInvitation:
            return "Subject: \(content.subject)\n\n\(content.invitationText)"
        case .textMessage:
            return content.invitationText
        case .formattedInvitation:
            return "\(content.subject)\n\n\(content.invitationText)"
        case .enhancedICS:
            return content.invitationText
        case .airDrop:
            return content.invitationText
        }
    }

    private func createFallbackInvitation(format: SmartExportFormat) -> String {
        switch format {
        case .airDrop:
            return """
            📅 \(event.title)

            🗓 \(formatDate(event.startDate))
            🕐 \(formatTimeRange(event.startDate, event.endDate))
            \(event.location != nil ? "📍 \(event.location!)" : "")

            \(event.description ?? "")

            Tap the calendar file to add this event to your calendar!
            """

        case .emailInvitation:
            return """
            Subject: Invitation: \(event.title)

            Hi there,

            You're invited to \(event.title).

            📅 Date: \(formatDate(event.startDate))
            🕐 Time: \(formatTimeRange(event.startDate, event.endDate))
            \(event.location != nil ? "📍 Location: \(event.location!)" : "")

            \(event.description ?? "")

            Please let me know if you can attend. Looking forward to seeing you!

            Best regards
            """

        case .textMessage:
            var msg = "Hey! \(event.title) on \(formatDate(event.startDate)) at \(formatTimeRange(event.startDate, event.endDate))"
            if let location = event.location {
                msg += " at \(location)"
            }
            msg += ". Can you make it?"
            return msg

        case .formattedInvitation:
            return """
            ═══════════════════════════════
            📅 EVENT INVITATION
            ═══════════════════════════════

            \(event.title)

            DATE & TIME
            \(formatDate(event.startDate))
            \(formatTimeRange(event.startDate, event.endDate))

            \(event.location != nil ? "LOCATION\n\(event.location!)\n\n" : "")DETAILS
            \(event.description ?? "More details to come.")

            ═══════════════════════════════

            Please RSVP at your earliest convenience.
            We look forward to seeing you there!
            """

        case .enhancedICS:
            return """
            \(event.description ?? "")

            Event Details:
            • Date: \(formatDate(event.startDate))
            • Time: \(formatTimeRange(event.startDate, event.endDate))
            \(event.location != nil ? "• Location: \(event.location!)" : "")

            Please add this event to your calendar and let us know if you can attend.
            """
        }
    }
}

// MARK: - Supporting Types & Views

@available(iOS 26.0, *)
@Generable
struct InvitationContent {
    @Guide(description: "The invitation text in the requested format")
    let invitationText: String

    @Guide(description: "Subject line for email or title for text message")
    let subject: String
}

enum SmartExportFormat: String, CaseIterable {
    case emailInvitation = "Email Invitation"
    case textMessage = "Text Message"
    case formattedInvitation = "Formatted Invitation"
    case enhancedICS = "Enhanced Calendar File"
    case airDrop = "AirDrop Share"

    var description: String {
        switch self {
        case .emailInvitation: return "professional email invitation"
        case .textMessage: return "casual text message invitation"
        case .formattedInvitation: return "formatted invitation with rich text"
        case .enhancedICS: return "enhanced calendar file description"
        case .airDrop: return "quick share to nearby devices"
        }
    }
}

// MARK: - Custom Activity for Adding to Calendar

@available(iOS 13.0, *)
class AddToCalendarActivity: UIActivity {
    var unifiedEvent: UnifiedEvent
    var eventStore = EKEventStore()

    init(event: UnifiedEvent) {
        self.unifiedEvent = event
        super.init()
    }

    override var activityType: UIActivity.ActivityType? {
        return UIActivity.ActivityType("com.calai.addtocalendar")
    }

    override var activityTitle: String? {
        return "Add to Calendar"
    }

    override var activityImage: UIImage? {
        return UIImage(systemName: "calendar.badge.plus")
    }

    override func canPerform(withActivityItems activityItems: [Any]) -> Bool {
        return true
    }

    override func prepare(withActivityItems activityItems: [Any]) {
        // Preparation if needed
    }

    override func perform() {
        // Request calendar access and add event
        eventStore.requestFullAccessToEvents { granted, error in
            if granted {
                DispatchQueue.main.async {
                    self.addEventToCalendar()
                }
            } else {
                print("❌ Calendar access not granted: \(error?.localizedDescription ?? "Unknown error")")
                self.activityDidFinish(false)
            }
        }
    }

    private func addEventToCalendar() {
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = unifiedEvent.title
        ekEvent.startDate = unifiedEvent.startDate
        ekEvent.endDate = unifiedEvent.endDate
        ekEvent.isAllDay = unifiedEvent.isAllDay
        ekEvent.notes = unifiedEvent.description
        ekEvent.location = unifiedEvent.location
        ekEvent.calendar = eventStore.defaultCalendarForNewEvents

        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            print("✅ Event added to calendar: \(unifiedEvent.title)")
            self.activityDidFinish(true)
        } catch {
            print("❌ Failed to add event to calendar: \(error.localizedDescription)")
            self.activityDidFinish(false)
        }
    }
}

// MARK: - Enhanced Share Sheet with Add to Calendar

struct EnhancedEventShareSheet: UIViewControllerRepresentable {
    let event: UnifiedEvent
    let items: [Any]
    let icsURL: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let addToCalendarActivity = AddToCalendarActivity(event: event)
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: [addToCalendarActivity]
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct SmartExportOptionRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)

                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
            }
            .padding(12)
            .background(isSelected ? color.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 2)
            )
        }
    }
}
