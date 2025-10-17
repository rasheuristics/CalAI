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

        // Add calendar source information to description
        let sourceInfo = "Source Calendar: \(event.source.displayName)"
        var fullDescription = sourceInfo

        if let description = event.description, !description.isEmpty {
            fullDescription = "\(description)\n\n\(sourceInfo)"
        }

        ics.append("DESCRIPTION:\(escapeICSText(fullDescription))")

        // Location
        if let location = event.location, !location.isEmpty {
            ics.append("LOCATION:\(escapeICSText(location))")
        }

        // Add custom property for calendar source
        let sourceValue: String
        switch event.source {
        case .ios: sourceValue = "ios"
        case .google: sourceValue = "google"
        case .outlook: sourceValue = "outlook"
        }
        ics.append("X-CALAI-SOURCE:\(sourceValue)")

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

    /// Create a calendar URL for QR codes
    /// - Parameters:
    ///   - event: The event to export
    ///   - organizerEmail: Email of the organizer
    ///   - attendeeEmails: List of attendee emails
    /// - Returns: Google Calendar web URL (most reliable for QR codes)
    static func createDataURL(
        event: UnifiedEvent,
        organizerEmail: String? = nil,
        attendeeEmails: [String] = []
    ) -> String {
        // For QR codes, use simple Google Calendar URL
        // This is the most reliable approach:
        // - Works on all devices and QR scanners
        // - Opens in browser and lets user choose calendar
        // - No size limitations
        // - No iOS Camera confusion with data URLs

        // Based on event source, choose appropriate calendar service
        switch event.source {
        case .google:
            return createGoogleCalendarURL(event: event)
        case .outlook:
            return createOutlookCalendarURL(event: event)
        case .ios:
            // For iOS events, use Google Calendar (most universal)
            return createGoogleCalendarURL(event: event)
        }
    }

    /// Create ultra-minimal ICS (no description/location) for very large events
    private static func createUltraMinimalICS(event: UnifiedEvent) -> String {
        var ics = [String]()

        ics.append("BEGIN:VCALENDAR")
        ics.append("VERSION:2.0")
        ics.append("BEGIN:VEVENT")
        ics.append("UID:\(event.id)")
        ics.append("DTSTAMP:\(formatICSDate(Date()))")
        ics.append("DTSTART:\(formatICSDate(event.startDate, allDay: event.isAllDay))")
        ics.append("DTEND:\(formatICSDate(event.endDate, allDay: event.isAllDay))")
        ics.append("SUMMARY:\(escapeICSText(event.title))")
        ics.append("END:VEVENT")
        ics.append("END:VCALENDAR")

        return ics.joined(separator: "\r\n")
    }

    /// Create minimal ICS format for QR codes (optimized for size)
    private static func createMinimalICS(event: UnifiedEvent) -> String {
        var ics = [String]()

        ics.append("BEGIN:VCALENDAR")
        ics.append("VERSION:2.0")
        ics.append("BEGIN:VEVENT")

        // Use short UID for QR codes
        let shortUID = String(event.id.prefix(20))
        ics.append("UID:\(shortUID)")
        ics.append("DTSTART:\(formatICSDate(event.startDate, allDay: event.isAllDay))")
        ics.append("DTEND:\(formatICSDate(event.endDate, allDay: event.isAllDay))")
        ics.append("SUMMARY:\(escapeICSText(event.title))")

        // Only add location if it's very short (under 50 chars)
        if let location = event.location, !location.isEmpty, location.count < 50 {
            ics.append("LOCATION:\(escapeICSText(location))")
        }

        // Skip description for QR codes (can be added after importing)

        ics.append("END:VEVENT")
        ics.append("END:VCALENDAR")

        return ics.joined(separator: "\r\n")
    }

    /// Create a Google Calendar app deep link (opens app if installed)
    /// - Parameter event: The event to create a link for
    /// - Returns: Google Calendar app URL
    static func createGoogleCalendarAppURL(event: UnifiedEvent) -> String {
        // Google Calendar app URL scheme
        // Format: googlecalendar:// or falls back to web URL

        // Use the web URL - iOS will automatically open the Google Calendar app if installed
        // This is more reliable than custom URL schemes
        return createGoogleCalendarURL(event: event)
    }

    /// Create an Outlook Calendar app deep link (opens app if installed)
    /// - Parameter event: The event to create a link for
    /// - Returns: Outlook Calendar app URL
    static func createOutlookCalendarAppURL(event: UnifiedEvent) -> String {
        // Outlook app URL scheme
        // Format: ms-outlook:// for app, falls back to web

        // Use the web URL - iOS will automatically open the Outlook app if installed
        // This is more reliable than custom URL schemes
        return createOutlookCalendarURL(event: event)
    }

    /// Escape HTML special characters
    private static func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }

    /// Create a universal calendar URL that works based on event source
    /// - Parameter event: The event to create a link for
    /// - Returns: Calendar URL appropriate for the event source
    static func createUniversalCalendarURL(event: UnifiedEvent) -> String {
        switch event.source {
        case .google:
            return createGoogleCalendarURL(event: event)
        case .outlook:
            return createOutlookCalendarURL(event: event)
        case .ios:
            // For iOS events, use Google Calendar as universal option
            // (iOS calendar doesn't have a web interface)
            return createGoogleCalendarURL(event: event)
        }
    }

    /// Create a Google Calendar URL for the event
    /// - Parameter event: The event to create a link for
    /// - Returns: Google Calendar URL
    static func createGoogleCalendarURL(event: UnifiedEvent) -> String {
        let baseURL = "https://calendar.google.com/calendar/render?action=TEMPLATE"

        // Format dates for Google Calendar (yyyyMMdd'T'HHmmss'Z')
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")
        dateFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"

        let startDate = dateFormatter.string(from: event.startDate)
        let endDate = dateFormatter.string(from: event.endDate)

        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "text", value: event.title),
            URLQueryItem(name: "dates", value: "\(startDate)/\(endDate)")
        ]

        if let location = event.location, !location.isEmpty {
            queryItems.append(URLQueryItem(name: "location", value: location))
        }

        // Add calendar source information to description
        let sourceInfo = "📅 Source: \(event.source.displayName)"
        var fullDescription = sourceInfo

        if let description = event.description, !description.isEmpty {
            fullDescription = "\(description)\n\n\(sourceInfo)"
        }

        queryItems.append(URLQueryItem(name: "details", value: fullDescription))

        components.queryItems = queryItems

        return components.url?.absoluteString ?? baseURL
    }

    /// Create an Outlook Calendar URL for the event
    /// - Parameter event: The event to create a link for
    /// - Returns: Outlook Calendar URL
    static func createOutlookCalendarURL(event: UnifiedEvent) -> String {
        let baseURL = "https://outlook.live.com/calendar/0/deeplink/compose"

        // Format dates for Outlook (ISO 8601 format)
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "UTC")

        let startDate = dateFormatter.string(from: event.startDate)
        let endDate = dateFormatter.string(from: event.endDate)

        var components = URLComponents(string: baseURL)!
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "subject", value: event.title),
            URLQueryItem(name: "startdt", value: startDate),
            URLQueryItem(name: "enddt", value: endDate),
            URLQueryItem(name: "path", value: "/calendar/action/compose")
        ]

        if let location = event.location, !location.isEmpty {
            queryItems.append(URLQueryItem(name: "location", value: location))
        }

        // Add calendar source information to description
        let sourceInfo = "📅 Source: \(event.source.displayName)"
        var fullDescription = sourceInfo

        if let description = event.description, !description.isEmpty {
            fullDescription = "\(description)\n\n\(sourceInfo)"
        }

        queryItems.append(URLQueryItem(name: "body", value: fullDescription))

        components.queryItems = queryItems

        return components.url?.absoluteString ?? baseURL
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
