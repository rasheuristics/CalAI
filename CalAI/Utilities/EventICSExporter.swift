import Foundation
import EventKit

/// Utility for exporting UnifiedEvent to iCalendar (.ics) format
class EventICSExporter {

    /// Export a UnifiedEvent to iCalendar (.ics) format string
    /// - Parameters:
    ///   - event: The event to export
    ///   - organizerEmail: Email of the organizer (for meeting invitations)
    ///   - attendeeEmails: List of attendee emails (for meeting invitations)
    ///   - method: iCalendar method (REQUEST for invitations, PUBLISH for sharing)
    /// - Returns: .ics format string
    static func exportToICS(
        event: UnifiedEvent,
        organizerEmail: String? = nil,
        attendeeEmails: [String] = [],
        method: ICSMethod = .publish
    ) -> String {
        var ics = [String]()

        // Calendar header
        ics.append("BEGIN:VCALENDAR")
        ics.append("VERSION:2.0")
        ics.append("PRODID:-//CalAI//Calendar Event//EN")
        ics.append("CALSCALE:GREGORIAN")
        ics.append("METHOD:\(method.rawValue)")

        // Event (VEVENT)
        ics.append("BEGIN:VEVENT")

        // Unique identifier
        let uid = event.id.replacingOccurrences(of: " ", with: "-")
        ics.append("UID:\(uid)")

        // Timestamps
        ics.append("DTSTAMP:\(formatICSDate(Date()))")
        ics.append("DTSTART:\(formatICSDate(event.startDate, allDay: event.isAllDay))")
        ics.append("DTEND:\(formatICSDate(event.endDate, allDay: event.isAllDay))")

        // Title and description
        ics.append("SUMMARY:\(escapeICSText(event.title))")
        if let description = event.description, !description.isEmpty {
            ics.append("DESCRIPTION:\(escapeICSText(description))")
        }

        // Location
        if let location = event.location, !location.isEmpty {
            ics.append("LOCATION:\(escapeICSText(location))")
        }

        // Organizer (for meeting invitations)
        if let organizerEmail = organizerEmail, !organizerEmail.isEmpty {
            let organizerName = event.organizer ?? "Organizer"
            ics.append("ORGANIZER;CN=\(escapeICSText(organizerName)):mailto:\(organizerEmail)")
        }

        // Attendees (for meeting invitations)
        for attendeeEmail in attendeeEmails {
            ics.append("ATTENDEE;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE:mailto:\(attendeeEmail)")
        }

        // Status
        ics.append("STATUS:CONFIRMED")

        // Sequence (version number)
        ics.append("SEQUENCE:0")

        // Transparency (show as busy)
        ics.append("TRANSP:OPAQUE")

        ics.append("END:VEVENT")
        ics.append("END:VCALENDAR")

        return ics.joined(separator: "\r\n")
    }

    /// Format date for iCalendar format
    private static func formatICSDate(_ date: Date, allDay: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")

        if allDay {
            formatter.dateFormat = "yyyyMMdd"
            return formatter.string(from: date)
        } else {
            formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            return formatter.string(from: date)
        }
    }

    /// Escape text for iCalendar format
    private static func escapeICSText(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    /// Create a data URL for the .ics content (suitable for QR codes)
    /// - Parameters:
    ///   - event: The event to export
    ///   - organizerEmail: Email of the organizer
    ///   - attendeeEmails: List of attendee emails
    /// - Returns: Data URL string that can be embedded in QR code
    static func createDataURL(
        event: UnifiedEvent,
        organizerEmail: String? = nil,
        attendeeEmails: [String] = []
    ) -> String {
        let method: ICSMethod = (organizerEmail != nil && !attendeeEmails.isEmpty) ? .request : .publish
        let icsContent = exportToICS(
            event: event,
            organizerEmail: organizerEmail,
            attendeeEmails: attendeeEmails,
            method: method
        )

        // Base64 encode for data URL
        if let data = icsContent.data(using: .utf8) {
            let base64 = data.base64EncodedString()
            return "data:text/calendar;base64,\(base64)"
        }

        return ""
    }

    /// Save .ics file to temporary directory and return URL
    /// - Parameters:
    ///   - event: The event to export
    ///   - organizerEmail: Email of the organizer
    ///   - attendeeEmails: List of attendee emails
    /// - Returns: URL to the temporary .ics file
    static func saveToTemporaryFile(
        event: UnifiedEvent,
        organizerEmail: String? = nil,
        attendeeEmails: [String] = []
    ) -> URL? {
        let method: ICSMethod = (organizerEmail != nil && !attendeeEmails.isEmpty) ? .request : .publish
        let icsContent = exportToICS(
            event: event,
            organizerEmail: organizerEmail,
            attendeeEmails: attendeeEmails,
            method: method
        )

        let fileName = "\(event.title.replacingOccurrences(of: " ", with: "_")).ics"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)

        do {
            try icsContent.write(to: tempURL, atomically: true, encoding: .utf8)
            return tempURL
        } catch {
            print("❌ Failed to save .ics file: \(error)")
            return nil
        }
    }
}

/// iCalendar method types
enum ICSMethod: String {
    case publish = "PUBLISH"   // For sharing events
    case request = "REQUEST"   // For meeting invitations with RSVP
    case cancel = "CANCEL"     // For cancelling events
    case reply = "REPLY"       // For attendee responses
}
