import Foundation
import EventKit

/// Detects and extracts video meeting URLs from event descriptions and locations
class VideoMeetingDetector {

    // MARK: - Types

    enum MeetingPlatform: String {
        case zoom = "Zoom"
        case googleMeet = "Google Meet"
        case webex = "Webex"
        case microsoftTeams = "Microsoft Teams"
        case unknown = "Video Meeting"

        var icon: String {
            switch self {
            case .zoom: return "video.fill"
            case .googleMeet: return "video.fill"
            case .webex: return "video.fill"
            case .microsoftTeams: return "video.fill"
            case .unknown: return "link"
            }
        }

        var color: String {
            switch self {
            case .zoom: return "blue"
            case .googleMeet: return "green"
            case .webex: return "blue"
            case .microsoftTeams: return "purple"
            case .unknown: return "blue"
            }
        }
    }

    struct VideoMeeting {
        let platform: MeetingPlatform
        let url: URL
        let meetingID: String?
    }

    // MARK: - Detection

    /// Detect video meeting URL from event description, location, and URL field
    func detectMeeting(from event: UnifiedEvent) -> VideoMeeting? {
        print("🔎 [VideoMeetingDetector] Checking event: '\(event.title)'")

        // Check location first
        if let location = event.location, !location.isEmpty {
            print("   📍 Location (full text): \(location)")
            if let meeting = extractMeeting(from: location) {
                print("   ✅ Found meeting in location!")
                return meeting
            }
        } else {
            print("   📍 Location: (empty)")
        }

        // Check description/notes
        if let description = event.description, !description.isEmpty {
            print("   📝 Description (full text): \(description)")
            if let meeting = extractMeeting(from: description) {
                print("   ✅ Found meeting in description!")
                return meeting
            }
        } else {
            print("   📝 Description: (empty)")
        }

        // Check if event has a URL field (common in calendar events)
        if let originalEvent = event.originalEvent as? EKEvent,
           let url = originalEvent.url {
            print("   🔗 URL field: \(url.absoluteString)")
            // Try to detect meeting platform from the URL directly
            if let meeting = detectFromURL(url) {
                print("   ✅ Found meeting in URL field!")
                return meeting
            }
        } else {
            print("   🔗 URL field: (empty)")
        }

        print("   ❌ No video meeting detected for '\(event.title)'")
        return nil
    }

    /// Detect meeting directly from a URL
    private func detectFromURL(_ url: URL) -> VideoMeeting? {
        let urlString = url.absoluteString

        // Check if it matches any video meeting patterns
        if urlString.contains("zoom.us") {
            return VideoMeeting(
                platform: .zoom,
                url: url,
                meetingID: extractZoomMeetingID(from: urlString)
            )
        }

        if urlString.contains("meet.google.com") {
            return VideoMeeting(
                platform: .googleMeet,
                url: url,
                meetingID: nil
            )
        }

        if urlString.contains("webex.com") {
            return VideoMeeting(
                platform: .webex,
                url: url,
                meetingID: nil
            )
        }

        if urlString.contains("teams.microsoft.com") {
            return VideoMeeting(
                platform: .microsoftTeams,
                url: url,
                meetingID: nil
            )
        }

        return nil
    }

    /// Extract video meeting from text
    private func extractMeeting(from text: String) -> VideoMeeting? {
        // Zoom patterns
        if let zoomURL = extractZoomURL(from: text) {
            return VideoMeeting(
                platform: .zoom,
                url: zoomURL,
                meetingID: extractZoomMeetingID(from: text)
            )
        }

        // Google Meet patterns
        if let meetURL = extractGoogleMeetURL(from: text) {
            return VideoMeeting(
                platform: .googleMeet,
                url: meetURL,
                meetingID: nil
            )
        }

        // Webex patterns
        if let webexURL = extractWebexURL(from: text) {
            return VideoMeeting(
                platform: .webex,
                url: webexURL,
                meetingID: nil
            )
        }

        // Microsoft Teams patterns
        if let teamsURL = extractTeamsURL(from: text) {
            return VideoMeeting(
                platform: .microsoftTeams,
                url: teamsURL,
                meetingID: nil
            )
        }

        return nil
    }

    // MARK: - URL Extraction

    private func extractZoomURL(from text: String) -> URL? {
        // Zoom URL patterns:
        // https://zoom.us/j/123456789
        // https://us02web.zoom.us/j/123456789?pwd=...
        // https://zoom.us/wc/join/123456789

        let patterns = [
            "https?://[\\w.-]*zoom\\.us/j/[0-9?=&\\w-]+",
            "https?://[\\w.-]*zoom\\.us/wc/join/[0-9?=&\\w-]+"
        ]

        return extractURL(from: text, patterns: patterns)
    }

    private func extractGoogleMeetURL(from text: String) -> URL? {
        // Google Meet patterns:
        // https://meet.google.com/abc-defg-hij

        let patterns = [
            "https?://meet\\.google\\.com/[a-z0-9-]+"
        ]

        return extractURL(from: text, patterns: patterns)
    }

    private func extractWebexURL(from text: String) -> URL? {
        // Webex patterns:
        // https://company.webex.com/meet/username
        // https://company.webex.com/company/j.php?MTID=...

        let patterns = [
            "https?://[\\w.-]+\\.webex\\.com/[\\w./\\-?=&]+"
        ]

        return extractURL(from: text, patterns: patterns)
    }

    private func extractTeamsURL(from text: String) -> URL? {
        // Microsoft Teams patterns:
        // https://teams.microsoft.com/l/meetup-join/...

        let patterns = [
            "https?://teams\\.microsoft\\.com/l/meetup-join/[\\w/%?=&\\-._~:@!$'()*+,;]+"
        ]

        return extractURL(from: text, patterns: patterns)
    }

    private func extractURL(from text: String, patterns: [String]) -> URL? {
        print("      🔍 Extracting URL from text: \(text.prefix(100))...")
        for pattern in patterns {
            print("      🔍 Trying pattern: \(pattern)")
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range),
                   let urlRange = Range(match.range, in: text) {
                    let urlString = String(text[urlRange])
                    print("      ✅ Matched URL: \(urlString)")
                    return URL(string: urlString)
                }
            }
        }
        print("      ❌ No URL matched")
        return nil
    }

    private func extractZoomMeetingID(from text: String) -> String? {
        // Extract meeting ID from patterns like:
        // Meeting ID: 123 456 789
        // ID: 123456789

        let patterns = [
            "Meeting ID:?\\s*([0-9\\s]+)",
            "ID:?\\s*([0-9\\s]+)"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range),
                   match.numberOfRanges > 1,
                   let idRange = Range(match.range(at: 1), in: text) {
                    let id = String(text[idRange])
                    // Remove spaces
                    return id.replacingOccurrences(of: " ", with: "")
                }
            }
        }
        return nil
    }
}
