//
//  CalendarInvitation.swift
//  CalAI
//
//  Created by Claude Code on 11/9/25.
//

import Foundation
import EventKit

/// Represents a calendar invitation from any source
struct CalendarInvitation: Identifiable {
    let id: String
    let title: String
    let organizer: String?
    let startDate: Date
    let endDate: Date
    let location: String?
    let notes: String?
    let source: CalendarSource
    let status: InvitationStatus
    let originalEvent: EKEvent?
    let calendarName: String?

    var hasResponded: Bool {
        status != .pending
    }
}

/// Status of a calendar invitation
enum InvitationStatus: String, Codable {
    case pending = "Pending"
    case accepted = "Accepted"
    case declined = "Declined"
    case tentative = "Tentative"

    var displayName: String {
        rawValue
    }

    var icon: String {
        switch self {
        case .pending: return "envelope"
        case .accepted: return "checkmark.circle.fill"
        case .declined: return "xmark.circle.fill"
        case .tentative: return "questionmark.circle.fill"
        }
    }
}

/// Calendar display information for selector
struct CalendarDisplayInfo: Identifiable {
    let id: String
    let name: String
    let source: CalendarSource
    let color: String
    let isVisible: Bool
    let eventCount: Int

    var sourceIcon: String {
        switch source {
        case .ios: return "calendar"
        case .google: return "globe"
        case .outlook: return "envelope"
        }
    }
}
