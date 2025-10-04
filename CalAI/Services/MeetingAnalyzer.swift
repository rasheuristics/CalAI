import Foundation
import CoreLocation

enum MeetingType {
    case physical(location: String)
    case virtual(link: String, platform: VirtualPlatform)
    case hybrid(location: String, link: String, platform: VirtualPlatform)
    case unknown

    enum VirtualPlatform: String {
        case zoom = "Zoom"
        case teams = "Microsoft Teams"
        case googleMeet = "Google Meet"
        case webex = "Webex"
        case other = "Virtual Meeting"
    }
}

struct MeetingInfo {
    let title: String
    let startDate: Date
    let endDate: Date
    let type: MeetingType
    let notes: String?

    var hasPhysicalLocation: Bool {
        switch type {
        case .physical, .hybrid:
            return true
        case .virtual, .unknown:
            return false
        }
    }

    var hasVirtualLink: Bool {
        switch type {
        case .virtual, .hybrid:
            return true
        case .physical, .unknown:
            return false
        }
    }

    var physicalLocation: String? {
        switch type {
        case .physical(let location):
            return location
        case .hybrid(let location, _, _):
            return location
        case .virtual, .unknown:
            return nil
        }
    }

    var virtualLink: String? {
        switch type {
        case .virtual(let link, _):
            return link
        case .hybrid(_, let link, _):
            return link
        case .physical, .unknown:
            return nil
        }
    }
}

class MeetingAnalyzer {
    static let shared = MeetingAnalyzer()

    private init() {}

    // Virtual meeting link patterns
    private let virtualMeetingPatterns: [(regex: NSRegularExpression, platform: MeetingType.VirtualPlatform)] = {
        let patterns: [(String, MeetingType.VirtualPlatform)] = [
            (#"https?://[a-zA-Z0-9.-]*\.?zoom\.us/[^\s]+"#, .zoom),
            (#"https?://teams\.microsoft\.com/l/meetup-join/[^\s]+"#, .teams),
            (#"https?://meet\.google\.com/[^\s]+"#, .googleMeet),
            (#"https?://[a-zA-Z0-9.-]*\.?webex\.com/[^\s]+"#, .webex)
        ]

        return patterns.compactMap { pattern, platform in
            guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
                return nil
            }
            return (regex, platform)
        }
    }()

    /// Analyzes a calendar event and determines its meeting type
    func analyze(title: String, location: String?, notes: String?, startDate: Date, endDate: Date) -> MeetingInfo {
        let combinedText = [location, notes].compactMap { $0 }.joined(separator: " ")

        let virtualMeeting = detectVirtualMeeting(in: combinedText)
        let physicalLocation = detectPhysicalLocation(location: location)

        let meetingType: MeetingType
        if let virtual = virtualMeeting, let physical = physicalLocation {
            meetingType = .hybrid(location: physical, link: virtual.link, platform: virtual.platform)
        } else if let virtual = virtualMeeting {
            meetingType = .virtual(link: virtual.link, platform: virtual.platform)
        } else if let physical = physicalLocation {
            meetingType = .physical(location: physical)
        } else {
            meetingType = .unknown
        }

        return MeetingInfo(
            title: title,
            startDate: startDate,
            endDate: endDate,
            type: meetingType,
            notes: notes
        )
    }

    /// Detects virtual meeting links in text
    private func detectVirtualMeeting(in text: String) -> (link: String, platform: MeetingType.VirtualPlatform)? {
        for (regex, platform) in virtualMeetingPatterns {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let linkRange = Range(match.range, in: text) {
                let link = String(text[linkRange])
                return (link, platform)
            }
        }
        return nil
    }

    /// Detects physical location (address or venue name)
    private func detectPhysicalLocation(location: String?) -> String? {
        guard let location = location, !location.isEmpty else {
            return nil
        }

        // Filter out virtual meeting indicators
        let lowercased = location.lowercased()
        let virtualIndicators = ["zoom", "teams", "meet.google.com", "webex", "virtual", "online"]

        if virtualIndicators.contains(where: { lowercased.contains($0) }) {
            return nil
        }

        // If it looks like a real location, return it
        return location.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Attempts to geocode a location string into coordinates
    func geocodeLocation(_ locationString: String, completion: @escaping (CLLocationCoordinate2D?) -> Void) {
        let geocoder = CLGeocoder()

        geocoder.geocodeAddressString(locationString) { placemarks, error in
            if let error = error {
                print("❌ Geocoding error: \(error.localizedDescription)")
                completion(nil)
                return
            }

            guard let placemark = placemarks?.first,
                  let location = placemark.location else {
                print("⚠️ No location found for: \(locationString)")
                completion(nil)
                return
            }

            print("✅ Geocoded '\(locationString)' to \(location.coordinate.latitude), \(location.coordinate.longitude)")
            completion(location.coordinate)
        }
    }
}
