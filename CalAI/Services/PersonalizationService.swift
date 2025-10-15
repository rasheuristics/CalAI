import Foundation
import CoreData

/// A service to analyze user behavior patterns and provide personalization suggestions.
class PersonalizationService {
    
    static let shared = PersonalizationService()
    private let coreDataManager: CoreDataManager
    
    private init(coreDataManager: CoreDataManager = .shared) {
        self.coreDataManager = coreDataManager
    }
    
    // MARK: - Public Methods
    
    /// Checks if a break should be suggested after a newly created event.
    /// - Parameter event: The event that was just created.
    /// - Returns: A boolean indicating whether to suggest a break.
    func checkForBreakSuggestion(after event: UnifiedEvent) -> Bool {
        // 1. Define the criteria for the suggestion
        let longMeetingDuration: TimeInterval = 90 * 60 // 90 minutes
        let confidenceThreshold = 0.3 // Suggest if pattern occurs in >30% of cases
        let minimumOccurrences = 2 // Require at least 2 past occurrences

        // 2. Check if the trigger condition is met (the new event is a long meeting)
        let eventDuration = event.endDate.timeIntervalSince(event.startDate)
        guard eventDuration >= longMeetingDuration else {
            return false
        }
        
        // 3. Fetch historical data from the database
        let request: NSFetchRequest<LoggedUserAction> = LoggedUserAction.fetchRequest()
        // Look for past instances of event creation in the last 90 days
        let ninetyDaysAgo = Date().addingTimeInterval(-90 * 24 * 60 * 60)
        request.predicate = NSPredicate(format: "actionType == %@ AND timestamp > %@", "eventCreated", ninetyDaysAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
        
        guard let actions = try? coreDataManager.context.fetch(request), !actions.isEmpty else {
            return false
        }
        
        // 4. Analyze the historical data for the specific pattern
        var longMeetingCount = 0
        var breakPatternCount = 0
        
        let breakKeywords = ["break", "coffee", "walk", "rest"]
        
        for action in actions where action.eventDuration >= longMeetingDuration {
            longMeetingCount += 1
            
            // Check if a "break" event was created shortly after this long meeting
            let longMeetingEndDate = action.timestamp!.addingTimeInterval(action.eventDuration)
            if let subsequentBreakAction = findSubsequentBreak(after: longMeetingEndDate, among: actions, keywords: breakKeywords) {
                // Pattern found
                breakPatternCount += 1
            }
        }
        
        // 5. Make a decision based on the analysis
        guard longMeetingCount > 0, breakPatternCount >= minimumOccurrences else {
            return false
        }
        
        let patternFrequency = Double(breakPatternCount) / Double(longMeetingCount)
        
        if patternFrequency >= confidenceThreshold {
            print("🧠 Personalization: Break suggestion pattern met! (Frequency: \(patternFrequency))")
            return true
        } else {
            return false
        }
    }
    
    /// Helper function to find a subsequent break action.
    private func findSubsequentBreak(after date: Date, among actions: [LoggedUserAction], keywords: [String]) -> LoggedUserAction? {
        let thirtyMinutes: TimeInterval = 30 * 60
        
        return actions.first { action in
            // Check if the action is within 30 minutes after the date
            guard let actionTimestamp = action.timestamp, actionTimestamp > date, actionTimestamp.timeIntervalSince(date) < thirtyMinutes else {
                return false
            }
            
            // Check if the title contains break-related keywords
            guard let title = action.eventTitle?.lowercased() else { return false }
            for keyword in keywords where title.contains(keyword) {
                return true
            }
            
            return false
        }
    }
}
