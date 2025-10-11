import Foundation

enum CalendarCommandType: String, Codable {
    case createEvent = "create_event"
    case queryEvents = "query_events"
    case updateEvent = "update_event"
    case deleteEvent = "delete_event"
    case checkAvailability = "check_availability"
    case rescheduleEvent = "reschedule_event"
    case extendEvent = "extend_event"
    case moveEvent = "move_event"
    case inviteAttendees = "invite_attendees"
    case removeAttendees = "remove_attendees"
    case setRecurring = "set_recurring"
    case clearSchedule = "clear_schedule"
    case getWorkloadSummary = "get_workload_summary"
    case findTimeSlot = "find_time_slot"
    case findBestTime = "find_best_time"
    case blockTime = "block_time"
    case showHelp = "show_help"
}

struct CalendarCommand: Codable {
    let type: CalendarCommandType
    let title: String?
    let startDate: Date?
    let endDate: Date?
    let location: String?
    let notes: String?
    let participants: [String]?
    let queryStartDate: Date?
    let queryEndDate: Date?
    let eventId: String?
    let searchQuery: String?
    let calendarSource: String? // "iOS", "Google", "Outlook"

    // Advanced parameters
    let newStartDate: Date?
    let newEndDate: Date?
    let newLocation: String?
    let newTitle: String?
    let durationMinutes: Int?
    let recurringPattern: String?
    let attendeesToAdd: [String]?
    let attendeesToRemove: [String]?
    let summaryType: String?
    let timeSlotDuration: Int?
    let preferredTimeRange: String?

    init(
        type: CalendarCommandType,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        location: String? = nil,
        notes: String? = nil,
        participants: [String]? = nil,
        queryStartDate: Date? = nil,
        queryEndDate: Date? = nil,
        eventId: String? = nil,
        searchQuery: String? = nil,
        calendarSource: String? = nil,
        newStartDate: Date? = nil,
        newEndDate: Date? = nil,
        newLocation: String? = nil,
        newTitle: String? = nil,
        durationMinutes: Int? = nil,
        recurringPattern: String? = nil,
        attendeesToAdd: [String]? = nil,
        attendeesToRemove: [String]? = nil,
        summaryType: String? = nil,
        timeSlotDuration: Int? = nil,
        preferredTimeRange: String? = nil
    ) {
        self.type = type
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.notes = notes
        self.participants = participants
        self.queryStartDate = queryStartDate
        self.queryEndDate = queryEndDate
        self.eventId = eventId
        self.searchQuery = searchQuery
        self.calendarSource = calendarSource
        self.newStartDate = newStartDate
        self.newEndDate = newEndDate
        self.newLocation = newLocation
        self.newTitle = newTitle
        self.durationMinutes = durationMinutes
        self.recurringPattern = recurringPattern
        self.attendeesToAdd = attendeesToAdd
        self.attendeesToRemove = attendeesToRemove
        self.summaryType = summaryType
        self.timeSlotDuration = timeSlotDuration
        self.preferredTimeRange = preferredTimeRange
    }
}

struct AICalendarResponse: Codable {
    let message: String
    let command: CalendarCommand?
    let requiresConfirmation: Bool
    let confirmationMessage: String?
    let needsMoreInfo: Bool
    let partialCommand: CalendarCommand?
    let eventResults: [EventResult]? // Events returned from queries

    init(message: String, command: CalendarCommand? = nil, requiresConfirmation: Bool = false, confirmationMessage: String? = nil, needsMoreInfo: Bool = false, partialCommand: CalendarCommand? = nil, eventResults: [EventResult]? = nil) {
        self.message = message
        self.command = command
        self.requiresConfirmation = requiresConfirmation
        self.confirmationMessage = confirmationMessage
        self.needsMoreInfo = needsMoreInfo
        self.partialCommand = partialCommand
        self.eventResults = eventResults
    }
}

struct EventResult: Codable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let source: String // "iOS", "Google", "Outlook"
    let color: [Double]? // RGB values [r, g, b]
}