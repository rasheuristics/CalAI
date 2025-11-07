import Foundation

// MARK: - Insights Schedule Conflict
struct InsightsScheduleConflict: Identifiable, Codable {
    let id: String
    let event1Title: String
    let event2Title: String
    let event1Time: String
    let event2Time: String
    let event1Source: CalendarSource // NEW: Calendar source
    let event2Source: CalendarSource // NEW: Calendar source
    let overlapMinutes: Int
    let timeDescription: String
    let resolutionOptions: [String]
}

// MARK: - Insights Duplicate Event
struct InsightsDuplicateEvent: Identifiable, Codable {
    let id: String
    let eventTitle: String
    let eventTime: String
    let sources: [CalendarSource] // Calendars where duplicate appears
    let confidence: Double // 0.0-1.0
    let matchType: String // "exact", "strong", "moderate"
}

// MARK: - Insights Logistics Issue
struct InsightsLogisticsIssue: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let severity: Severity
    let icon: String
    let suggestion: String?

    enum Severity: String, Codable {
        case low
        case medium
        case high
    }
}

// MARK: - Insights Schedule Pattern
struct InsightsSchedulePattern: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let dataPoints: [Double] // Normalized values 0-1 for visualization
}

// MARK: - Insights AI Recommendation
struct InsightsAIRecommendation: Identifiable, Codable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let priority: Priority
    let actionTitle: String?
    let action: RecommendationAction

    enum Priority: String, Codable {
        case low
        case medium
        case high
    }

    enum RecommendationAction: String, Codable {
        case none
        case addBreaks
        case blockFocusTime
        case viewRoutes
    }
}

// MARK: - Calendar Source Color Extension
extension CalendarSource {
    /// Get the color for this calendar source
    /// Blue = Outlook, Red = iOS, Green = Google
    var displayColor: String {
        switch self {
        case .google:
            return "green"
        case .ios:
            return "red"
        case .outlook:
            return "blue"
        }
    }

    var iconName: String {
        switch self {
        case .google:
            return "g.circle.fill"
        case .ios:
            return "calendar.circle.fill"
        case .outlook:
            return "o.circle.fill"
        }
    }
}
