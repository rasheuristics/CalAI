import Foundation

// MARK: - Insights Schedule Conflict
struct InsightsScheduleConflict: Identifiable, Codable {
    let id: String
    let event1Title: String
    let event2Title: String
    let event1Time: String
    let event2Time: String
    let overlapMinutes: Int
    let timeDescription: String
    let resolutionOptions: [String]
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
