import Foundation

/// Detects and manages duplicate events across calendars
class DuplicateEventDetector {

    // MARK: - Types

    struct DuplicateGroup: Identifiable {
        let id = UUID()
        let events: [UnifiedEvent]
        let matchType: MatchType
        let confidence: Double // 0.0 to 1.0

        var primaryEvent: UnifiedEvent {
            // Return the first event as primary (could be enhanced with better logic)
            events.first!
        }

        var duplicates: [UnifiedEvent] {
            Array(events.dropFirst())
        }

        enum MatchType {
            case exact      // Exact title, time, and location match
            case strong     // Same title and overlapping time
            case moderate   // Similar title and close time
            case weak       // Similar title only
        }
    }

    // MARK: - Detection

    /// Detect all duplicate events in the provided list
    func detectDuplicates(in events: [UnifiedEvent]) -> [DuplicateGroup] {
        var duplicateGroups: [DuplicateGroup] = []
        var processedEventIds = Set<String>()

        for i in 0..<events.count {
            guard !processedEventIds.contains(events[i].id) else { continue }

            var matchingEvents: [UnifiedEvent] = [events[i]]
            var groupMatchType: DuplicateGroup.MatchType?
            processedEventIds.insert(events[i].id)

            // Find all events that match this event
            for j in (i+1)..<events.count {
                guard !processedEventIds.contains(events[j].id) else { continue }

                if let matchType = detectMatch(events[i], events[j]) {
                    matchingEvents.append(events[j])
                    processedEventIds.insert(events[j].id)

                    // Use the strongest match type found
                    if groupMatchType == nil {
                        groupMatchType = matchType
                    }
                }
            }

            // Only create a group if we found duplicates (2 or more matching events)
            if matchingEvents.count >= 2, let matchType = groupMatchType {
                let confidence = confidenceScore(for: matchType)
                duplicateGroups.append(DuplicateGroup(
                    events: matchingEvents,
                    matchType: matchType,
                    confidence: confidence
                ))
            }
        }

        return duplicateGroups.sorted { $0.confidence > $1.confidence }
    }

    /// Detect if two events match and return the match type
    private func detectMatch(_ event1: UnifiedEvent, _ event2: UnifiedEvent) -> DuplicateGroup.MatchType? {
        // Exact match: same title, same time, same location
        if isExactMatch(event1, event2) {
            return .exact
        }

        // Strong match: same title and overlapping time
        if isStrongMatch(event1, event2) {
            return .strong
        }

        // Moderate match: similar title and close time
        if isModerateMatch(event1, event2) {
            return .moderate
        }

        // Weak match: similar title only
        if isWeakMatch(event1, event2) {
            return .weak
        }

        return nil
    }

    // MARK: - Match Detection Methods

    private func isExactMatch(_ event1: UnifiedEvent, _ event2: UnifiedEvent) -> Bool {
        // Skip if same event from same source
        if event1.id == event2.id && event1.source == event2.source {
            return false
        }

        let titleMatch = event1.title.lowercased() == event2.title.lowercased()
        let timeMatch = abs(event1.startDate.timeIntervalSince(event2.startDate)) < 60 // Within 1 minute

        // Location match is optional - many events don't have location
        let location1 = event1.location?.lowercased() ?? ""
        let location2 = event2.location?.lowercased() ?? ""
        let locationMatch = location1.isEmpty && location2.isEmpty || location1 == location2

        return titleMatch && timeMatch && locationMatch
    }

    private func isStrongMatch(_ event1: UnifiedEvent, _ event2: UnifiedEvent) -> Bool {
        // Skip if same event from same source
        if event1.id == event2.id && event1.source == event2.source {
            return false
        }

        let titleMatch = event1.title.lowercased() == event2.title.lowercased()
        let timeOverlap = eventsOverlap(event1, event2)

        return titleMatch && timeOverlap
    }

    private func isModerateMatch(_ event1: UnifiedEvent, _ event2: UnifiedEvent) -> Bool {
        // Skip if same event from same source
        if event1.id == event2.id && event1.source == event2.source {
            return false
        }

        let titleSimilarity = calculateTitleSimilarity(event1.title, event2.title)
        let timeDifference = abs(event1.startDate.timeIntervalSince(event2.startDate))
        let closeTime = timeDifference < 1800 // Within 30 minutes (stricter)

        return titleSimilarity > 0.85 && closeTime // Stricter threshold
    }

    private func isWeakMatch(_ event1: UnifiedEvent, _ event2: UnifiedEvent) -> Bool {
        // Weak match disabled - too many false positives
        // Only use exact, strong, or moderate matches for duplicates
        return false
    }

    // MARK: - Helper Methods

    private func eventsOverlap(_ event1: UnifiedEvent, _ event2: UnifiedEvent) -> Bool {
        return event1.startDate < event2.endDate && event2.startDate < event1.endDate
    }

    private func calculateTitleSimilarity(_ title1: String, _ title2: String) -> Double {
        let normalized1 = normalizeTitle(title1)
        let normalized2 = normalizeTitle(title2)

        // Simple similarity: Levenshtein distance ratio
        let distance = levenshteinDistance(normalized1, normalized2)
        let maxLength = max(normalized1.count, normalized2.count)

        if maxLength == 0 { return 1.0 }

        return 1.0 - (Double(distance) / Double(maxLength))
    }

    private func normalizeTitle(_ title: String) -> String {
        return title
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[^a-z0-9 ]", with: "", options: .regularExpression)
    }

    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let empty = [Int](repeating: 0, count: s2.count)
        var last = [Int](0...s2.count)

        for (i, char1) in s1.enumerated() {
            var cur = [i + 1] + empty
            for (j, char2) in s2.enumerated() {
                cur[j + 1] = char1 == char2 ? last[j] : min(last[j], last[j + 1], cur[j]) + 1
            }
            last = cur
        }

        return last.last!
    }

    private func confidenceScore(for matchType: DuplicateGroup.MatchType) -> Double {
        switch matchType {
        case .exact: return 1.0
        case .strong: return 0.9
        case .moderate: return 0.7
        case .weak: return 0.5
        }
    }

    // MARK: - Filtering

    /// Filter out duplicate events from a list, keeping only the primary event from each group
    func filterDuplicates(from events: [UnifiedEvent]) -> [UnifiedEvent] {
        let duplicateGroups = detectDuplicates(in: events)
        var eventIdsToRemove = Set<String>()

        // Collect all duplicate event IDs (not the primary)
        for group in duplicateGroups where group.confidence > 0.7 {
            for duplicate in group.duplicates {
                eventIdsToRemove.insert(duplicate.id)
            }
        }

        // Filter out duplicates
        return events.filter { !eventIdsToRemove.contains($0.id) }
    }

    /// Get events that should be removed (duplicates only, not primary)
    func getDuplicateEventsToRemove(from groups: [DuplicateGroup], minimumConfidence: Double = 0.7) -> [UnifiedEvent] {
        var duplicates: [UnifiedEvent] = []

        for group in groups where group.confidence >= minimumConfidence {
            duplicates.append(contentsOf: group.duplicates)
        }

        return duplicates
    }
}
