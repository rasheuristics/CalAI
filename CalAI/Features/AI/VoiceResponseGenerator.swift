import Foundation

// MARK: - Voice Response Structure

struct VoiceResponse {
    let greeting: String
    let body: String
    let insight: String?
    let followUp: String?

    var fullMessage: String {
        var parts = [greeting, body]
        if let insight = insight {
            parts.append(insight)
        }
        if let followUp = followUp {
            parts.append(followUp)
        }
        return parts.joined(separator: " ")
    }
}

// MARK: - Schedule Analysis Structure

struct ScheduleAnalysis {
    let character: String  // "light", "moderate", "busy", "packed", "free"
    let totalEvents: Int
    let timedEvents: [UnifiedEvent]
    let allDayEvents: [UnifiedEvent]
    let busyPeriods: [BusyPeriod]
    let gaps: [TimeGap]
    let transitions: [Transition]
    let totalDuration: TimeInterval
    let longestGap: TimeInterval?
    let earliestEvent: UnifiedEvent?
    let latestEvent: UnifiedEvent?
}

struct BusyPeriod {
    let start: Date
    let end: Date
    let events: [UnifiedEvent]
    let duration: TimeInterval
}

struct TimeGap {
    let start: Date
    let end: Date
    let duration: TimeInterval  // in minutes
    let isSignificant: Bool  // 30+ minutes
}

struct Transition {
    let from: UnifiedEvent
    let to: UnifiedEvent
    let travelTime: TimeInterval?
    let isTight: Bool  // Less than 15 minutes
}

// MARK: - Voice Response Generator

class VoiceResponseGenerator {

    // MARK: - Schedule Analysis

    func analyzeSchedule(
        events: [UnifiedEvent],
        timeRange: (start: Date, end: Date)
    ) -> ScheduleAnalysis {
        let calendar = Calendar.current
        let sorted = events.sorted { $0.startDate < $1.startDate }

        // Categorize events
        let timed = sorted.filter { !$0.isAllDay }
        let allDay = sorted.filter { $0.isAllDay }

        // Calculate character
        let character = determineScheduleCharacter(eventCount: events.count, timedDuration: calculateTotalDuration(timed))

        // Find busy periods (3+ back-to-back meetings)
        let busyPeriods = identifyBusyPeriods(events: timed)

        // Find gaps
        let gaps = findTimeGaps(events: timed)

        // Find transitions
        let transitions = identifyTransitions(events: timed)

        // Calculate totals
        let totalDuration = calculateTotalDuration(timed)
        let longestGap = gaps.max(by: { $0.duration < $1.duration })?.duration

        return ScheduleAnalysis(
            character: character,
            totalEvents: events.count,
            timedEvents: timed,
            allDayEvents: allDay,
            busyPeriods: busyPeriods,
            gaps: gaps,
            transitions: transitions,
            totalDuration: totalDuration,
            longestGap: longestGap,
            earliestEvent: timed.first,
            latestEvent: timed.last
        )
    }

    private func determineScheduleCharacter(eventCount: Int, timedDuration: TimeInterval) -> String {
        let hours = timedDuration / 3600

        if eventCount == 0 {
            return "completely clear"
        } else if eventCount <= 2 && hours < 2 {
            return "light"
        } else if eventCount <= 4 && hours < 4 {
            return "moderate"
        } else if eventCount <= 6 || hours < 6 {
            return "busy"
        } else {
            return "packed"
        }
    }

    private func calculateTotalDuration(_ events: [UnifiedEvent]) -> TimeInterval {
        return events.reduce(0) { total, event in
            total + event.endDate.timeIntervalSince(event.startDate)
        }
    }

    private func identifyBusyPeriods(events: [UnifiedEvent]) -> [BusyPeriod] {
        guard events.count >= 3 else { return [] }

        var periods: [BusyPeriod] = []
        var currentPeriod: [UnifiedEvent] = []

        for (index, event) in events.enumerated() {
            if currentPeriod.isEmpty {
                currentPeriod.append(event)
            } else if let lastEvent = currentPeriod.last {
                let gap = event.startDate.timeIntervalSince(lastEvent.endDate)
                if gap <= 900 { // 15 minutes or less
                    currentPeriod.append(event)
                } else {
                    if currentPeriod.count >= 3 {
                        if let first = currentPeriod.first, let last = currentPeriod.last {
                            let duration = last.endDate.timeIntervalSince(first.startDate)
                            periods.append(BusyPeriod(start: first.startDate, end: last.endDate, events: currentPeriod, duration: duration))
                        }
                    }
                    currentPeriod = [event]
                }
            }
        }

        // Check final period
        if currentPeriod.count >= 3, let first = currentPeriod.first, let last = currentPeriod.last {
            let duration = last.endDate.timeIntervalSince(first.startDate)
            periods.append(BusyPeriod(start: first.startDate, end: last.endDate, events: currentPeriod, duration: duration))
        }

        return periods
    }

    private func findTimeGaps(events: [UnifiedEvent]) -> [TimeGap] {
        guard events.count >= 2 else { return [] }

        var gaps: [TimeGap] = []
        for i in 0..<events.count-1 {
            let gapStart = events[i].endDate
            let gapEnd = events[i+1].startDate
            let duration = gapEnd.timeIntervalSince(gapStart)

            if duration > 0 {
                let minutes = duration / 60
                gaps.append(TimeGap(
                    start: gapStart,
                    end: gapEnd,
                    duration: minutes,
                    isSignificant: minutes >= 30
                ))
            }
        }
        return gaps
    }

    private func identifyTransitions(events: [UnifiedEvent]) -> [Transition] {
        guard events.count >= 2 else { return [] }

        var transitions: [Transition] = []
        for i in 0..<events.count-1 {
            let from = events[i]
            let to = events[i+1]
            let gap = to.startDate.timeIntervalSince(from.endDate)
            let isTight = gap < 900 // Less than 15 minutes

            // Check if locations differ (simple check)
            var travelTime: TimeInterval? = nil
            if let fromLoc = from.location, let toLoc = to.location, !fromLoc.isEmpty && !toLoc.isEmpty && fromLoc != toLoc {
                travelTime = 1200 // Assume 20 minutes for different locations
            }

            transitions.append(Transition(from: from, to: to, travelTime: travelTime, isTight: isTight))
        }
        return transitions
    }

    // MARK: - Greeting Generation

    func getGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())

        if hour >= 6 && hour < 12 {
            return "Good morning"
        } else if hour >= 12 && hour < 18 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    // MARK: - Narrative Building

    private func buildDayNarrative(analysis: ScheduleAnalysis, timeRef: String) -> String {
        guard !analysis.timedEvents.isEmpty else {
            return "your calendar is completely clear \(timeRef) - perfect for deep work or catching up!"
        }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        // Build overview
        var narrative = "\(timeRef) is \(analysis.character)"

        // Add time span
        if let earliest = analysis.earliestEvent, let latest = analysis.latestEvent {
            narrative += " - you're booked from \(timeFormatter.string(from: earliest.startDate)) to \(timeFormatter.string(from: latest.endDate))"
        }

        narrative += " with \(analysis.totalEvents) event\(analysis.totalEvents == 1 ? "" : "s"). "

        // Build chronological flow
        narrative += buildEventFlow(analysis.timedEvents)

        // Add logistics
        if let logistics = buildLogistics(analysis: analysis) {
            narrative += " " + logistics
        }

        // Add breathing room insight
        if let breathing = buildBreathingRoom(analysis: analysis) {
            narrative += " " + breathing
        }

        return narrative
    }

    private func buildEventFlow(_ events: [UnifiedEvent]) -> String {
        guard !events.isEmpty else { return "" }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        if events.count == 1 {
            let event = events[0]
            return "You have \(event.title) at \(timeFormatter.string(from: event.startDate))."
        } else if events.count == 2 {
            let e1 = events[0]
            let e2 = events[1]
            return "You have \(e1.title) at \(timeFormatter.string(from: e1.startDate)), then \(e2.title) at \(timeFormatter.string(from: e2.startDate))."
        } else {
            // Group by time period
            var parts: [String] = []

            // Morning events (before noon)
            let morning = events.filter { Calendar.current.component(.hour, from: $0.startDate) < 12 }
            if !morning.isEmpty {
                parts.append("Your morning has \(morning.count) event\(morning.count == 1 ? "" : "s") starting with \(morning[0].title) at \(timeFormatter.string(from: morning[0].startDate))")
            }

            // Afternoon events (noon to 5pm)
            let afternoon = events.filter {
                let hour = Calendar.current.component(.hour, from: $0.startDate)
                return hour >= 12 && hour < 17
            }
            if !afternoon.isEmpty {
                parts.append("afternoon brings \(afternoon.count) event\(afternoon.count == 1 ? "" : "s") including \(afternoon[0].title)")
            }

            // Evening events (after 5pm)
            let evening = events.filter { Calendar.current.component(.hour, from: $0.startDate) >= 17 }
            if !evening.isEmpty {
                parts.append("evening has \(evening.count) event\(evening.count == 1 ? "" : "s")")
            }

            return parts.joined(separator: ", ") + "."
        }
    }

    private func buildLogistics(analysis: ScheduleAnalysis) -> String? {
        var insights: [String] = []

        // Check for tight transitions
        let tightTransitions = analysis.transitions.filter { $0.isTight && $0.travelTime != nil }
        if !tightTransitions.isEmpty {
            let transition = tightTransitions[0]
            insights.append("Note that your transition from \(transition.from.title) to \(transition.to.title) is tight - plan to leave a few minutes early")
        }

        // Check for off-site meetings
        let offSite = analysis.timedEvents.filter { $0.location != nil && !($0.location?.isEmpty ?? true) }
        if offSite.count > 0 {
            if offSite.count == 1 {
                insights.append("\(offSite[0].title) is off-site at \(offSite[0].location!)")
            } else {
                insights.append("You have \(offSite.count) off-site meetings today")
            }
        }

        return insights.isEmpty ? nil : insights.joined(separator: ". ")
    }

    private func buildBreathingRoom(analysis: ScheduleAnalysis) -> String? {
        let significantGaps = analysis.gaps.filter { $0.isSignificant }

        if significantGaps.isEmpty && analysis.totalEvents > 3 {
            return "You're back-to-back with minimal breaks."
        }

        if let longestGap = significantGaps.max(by: { $0.duration < $1.duration }) {
            let hours = Int(longestGap.duration / 60)
            if hours >= 1 {
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                return "You have a \(hours)-hour window from \(timeFormatter.string(from: longestGap.start)) to \(timeFormatter.string(from: longestGap.end)) for focused work."
            }
        }

        return nil
    }

    // MARK: - Query Response Generation

    func generateQueryResponse(
        events: [UnifiedEvent],
        timeRange: (start: Date, end: Date),
        queryType: String = "general"
    ) -> VoiceResponse {
        let greeting = getGreeting() + "!"
        let calendar = Calendar.current

        // Determine time reference
        let timeRef: String
        if calendar.isDateInToday(timeRange.start) {
            timeRef = "Today"
        } else if calendar.isDateInTomorrow(timeRange.start) {
            timeRef = "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"  // Day name
            timeRef = formatter.string(from: timeRange.start)
        }

        // Analyze schedule
        let analysis = analyzeSchedule(events: events, timeRange: timeRange)

        // Build narrative response
        let body = buildDayNarrative(analysis: analysis, timeRef: timeRef)

        // Generate contextual insight
        var insight: String? = nil
        if !analysis.busyPeriods.isEmpty {
            let period = analysis.busyPeriods[0]
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            insight = "Your busiest stretch is \(period.events.count) back-to-back meetings from \(timeFormatter.string(from: period.start)) to \(timeFormatter.string(from: period.end))."
        }

        return VoiceResponse(
            greeting: greeting,
            body: body,
            insight: insight,
            followUp: nil
        )
    }

    // MARK: - "What's Next" Response

    func generateNextEventResponse(nextEvent: UnifiedEvent?, followingEvent: UnifiedEvent?, currentTime: Date) -> VoiceResponse {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        guard let event = nextEvent else {
            return VoiceResponse(
                greeting: "",
                body: "You don't have any upcoming events.",
                insight: nil,
                followUp: "Your calendar is clear for the rest of the day."
            )
        }

        let timeUntil = event.startDate.timeIntervalSince(currentTime)
        let minutes = Int(timeUntil / 60)

        var timing: String
        if minutes < 5 {
            timing = "starting now"
        } else if minutes < 30 {
            timing = "in \(minutes) minutes"
        } else if minutes < 120 {
            let hours = minutes / 60
            let remainingMins = minutes % 60
            if remainingMins == 0 {
                timing = "in \(hours) hour\(hours == 1 ? "" : "s")"
            } else {
                timing = "in \(hours) hour\(hours == 1 ? "" : "s") and \(remainingMins) minutes"
            }
        } else {
            timing = "at \(timeFormatter.string(from: event.startDate))"
        }

        var body = "Your next event is \(event.title) \(timing)"

        // Add location context
        if let location = event.location, !location.isEmpty {
            body += " at \(location)"
        }

        body += "."

        // Add preparation insight
        var insight: String? = nil
        if minutes > 5 && minutes < 30 {
            insight = "You should start wrapping up and preparing now."
        } else if let location = event.location, !location.isEmpty, minutes > 10 {
            insight = "I'd suggest heading to \(location) about 5 minutes early."
        }

        // Add what follows
        var followUp: String? = nil
        if let following = followingEvent {
            let gap = following.startDate.timeIntervalSince(event.endDate)
            let gapMinutes = Int(gap / 60)
            if gapMinutes < 15 {
                followUp = "After this you have \(following.title) immediately following with only \(gapMinutes) minutes between."
            } else if gapMinutes < 60 {
                followUp = "After this you have \(following.title) at \(timeFormatter.string(from: following.startDate)), giving you \(gapMinutes) minutes to decompress."
            }
        } else {
            followUp = "Your schedule is clear after this event."
        }

        return VoiceResponse(
            greeting: "",
            body: body,
            insight: insight,
            followUp: followUp
        )
    }

    // MARK: - Create Response Generation

    func generateCreateResponse(
        eventTitle: String,
        eventDate: Date,
        duration: TimeInterval?,
        conflicts: [UnifiedEvent],
        allEvents: [UnifiedEvent]
    ) -> VoiceResponse {
        let greeting = "Done!"

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium

        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(eventDate)
        let isTomorrow = calendar.isDateInTomorrow(eventDate)

        let timeRef = isToday ? "today" : (isTomorrow ? "tomorrow" : "on \(dateFormatter.string(from: eventDate))")

        var body = "I've scheduled \(eventTitle) for \(timeRef) at \(timeFormatter.string(from: eventDate))"

        // Add duration context
        if let dur = duration {
            let hours = Int(dur / 3600)
            let minutes = Int((dur.truncatingRemainder(dividingBy: 3600)) / 60)
            if hours > 0 {
                body += " for \(hours) hour\(hours == 1 ? "" : "s")"
                if minutes > 0 {
                    body += " and \(minutes) minutes"
                }
            } else if minutes > 0 {
                body += " for \(minutes) minutes"
            }
        }
        body += "."

        // Analyze position in schedule
        let dayEvents = allEvents.filter { calendar.isDate($0.startDate, inSameDayAs: eventDate) }.sorted { $0.startDate < $1.startDate }

        var insight: String? = nil
        if !conflicts.isEmpty {
            insight = formatConflictWarning(conflicts: conflicts)
        } else if !dayEvents.isEmpty {
            // Find where this fits in the day
            let beforeEvents = dayEvents.filter { $0.startDate < eventDate }
            let afterEvents = dayEvents.filter { $0.startDate > eventDate }

            if beforeEvents.isEmpty && !afterEvents.isEmpty {
                insight = "This is your first event of the day"
                if let next = afterEvents.first {
                    let gap = next.startDate.timeIntervalSince(eventDate + (duration ?? 3600))
                    let gapMinutes = Int(gap / 60)
                    if gapMinutes > 30 {
                        insight! += " with \(gapMinutes / 60) hours before your \(timeFormatter.string(from: next.startDate)) \(next.title)."
                    }
                }
            } else if afterEvents.isEmpty && !beforeEvents.isEmpty {
                insight = "This is your last event of the day."
            } else if let previous = beforeEvents.last, let next = afterEvents.first {
                let gapBefore = eventDate.timeIntervalSince(previous.endDate)
                let gapAfter = next.startDate.timeIntervalSince(eventDate + (duration ?? 3600))
                let minutesBefore = Int(gapBefore / 60)
                let minutesAfter = Int(gapAfter / 60)

                if minutesBefore < 15 || minutesAfter < 15 {
                    insight = "This creates a tight back-to-back schedule with your other meetings."
                } else {
                    insight = "You'll have good buffer time before and after this meeting."
                }
            }
        }

        let followUp = conflicts.isEmpty ? "Would you like me to set a reminder?" : nil

        return VoiceResponse(
            greeting: greeting,
            body: body,
            insight: insight,
            followUp: followUp
        )
    }

    // MARK: - Delete Response Generation

    func generateDeleteResponse(eventTitle: String, eventDate: Date, allEvents: [UnifiedEvent]) -> VoiceResponse {
        let greeting = "Done!"

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        let body = "I've cancelled \(eventTitle) at \(timeFormatter.string(from: eventDate)) and removed it from your calendar."

        // Analyze what this frees up
        let calendar = Calendar.current
        let dayEvents = allEvents.filter { calendar.isDate($0.startDate, inSameDayAs: eventDate) && $0.title != eventTitle }.sorted { $0.startDate < $1.startDate }

        var insight: String? = nil
        if dayEvents.isEmpty {
            insight = "Your calendar is now completely clear for that day."
        } else {
            // Find the gap created
            let beforeEvents = dayEvents.filter { $0.endDate <= eventDate }
            let afterEvents = dayEvents.filter { $0.startDate >= eventDate }

            if let previous = beforeEvents.last, let next = afterEvents.first {
                let gap = next.startDate.timeIntervalSince(previous.endDate)
                let hours = Int(gap / 3600)
                if hours >= 1 {
                    insight = "This opens up a \(hours)-hour block from \(timeFormatter.string(from: previous.endDate)) to \(timeFormatter.string(from: next.startDate)) for focused work."
                }
            } else if beforeEvents.isEmpty && !afterEvents.isEmpty {
                if let next = afterEvents.first {
                    insight = "Your next commitment is now \(next.title) at \(timeFormatter.string(from: next.startDate))."
                }
            } else if !beforeEvents.isEmpty && afterEvents.isEmpty {
                insight = "Your day now ends after \(beforeEvents.last!.title)."
            }
        }

        let followUp = "Would you like to reschedule this for another time?"

        return VoiceResponse(
            greeting: greeting,
            body: body,
            insight: insight,
            followUp: followUp
        )
    }

    // MARK: - Search Response Generation

    func generateSearchResponse(
        query: String,
        results: [UnifiedEvent]
    ) -> VoiceResponse {
        let greeting = ""

        let timeFormatter = DateFormatter()
        timeFormatter.dateStyle = .medium
        timeFormatter.timeStyle = .short

        var body: String
        if results.isEmpty {
            body = "I couldn't find any events matching '\(query)'."
        } else if results.count == 1 {
            let event = results[0]
            let calendar = Calendar.current
            let dayRef: String
            if calendar.isDateInToday(event.startDate) {
                dayRef = "today"
            } else if calendar.isDateInTomorrow(event.startDate) {
                dayRef = "tomorrow"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE, MMMM d"
                dayRef = formatter.string(from: event.startDate)
            }

            body = "Your \(event.title) is \(dayRef) at \(timeFormatter.string(from: event.startDate))"
            if let location = event.location, !location.isEmpty {
                body += " at \(location)"
            }
            body += "."
        } else {
            body = "I found \(results.count) events matching '\(query)'. "
            let sorted = results.sorted { $0.startDate < $1.startDate }.prefix(3)
            let eventDescriptions = sorted.map { event -> String in
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return "\(event.title) on \(formatter.string(from: event.startDate))"
            }
            body += eventDescriptions.joined(separator: ", ")
            if results.count > 3 {
                body += ", and \(results.count - 3) more"
            }
            body += "."
        }

        return VoiceResponse(
            greeting: greeting,
            body: body,
            insight: nil,
            followUp: nil
        )
    }

    // MARK: - Availability Response Generation

    func generateAvailabilityResponse(
        isFree: Bool,
        conflictingEvent: UnifiedEvent?,
        freeSlots: [(start: Date, end: Date)],
        queryTime: Date,
        allEvents: [UnifiedEvent]
    ) -> VoiceResponse {
        let greeting = ""

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        var body: String
        if isFree {
            body = "Yes, you're free at \(timeFormatter.string(from: queryTime))."

            // Find duration of free time
            if let nextEvent = allEvents.filter({ $0.startDate > queryTime }).sorted(by: { $0.startDate < $1.startDate }).first {
                let freeMinutes = Int(nextEvent.startDate.timeIntervalSince(queryTime) / 60)
                if freeMinutes >= 60 {
                    let hours = freeMinutes / 60
                    body += " You're available for the next \(hours) hour\(hours == 1 ? "" : "s") until \(timeFormatter.string(from: nextEvent.startDate))."
                } else {
                    body += " You have \(freeMinutes) minutes before your \(timeFormatter.string(from: nextEvent.startDate)) \(nextEvent.title)."
                }
            } else {
                body += " Your calendar is clear for the rest of the day."
            }
        } else if let conflict = conflictingEvent {
            body = "No, you have \(conflict.title) from \(timeFormatter.string(from: conflict.startDate)) to \(timeFormatter.string(from: conflict.endDate))."

            // Suggest alternatives
            if let nextFree = allEvents.filter({ $0.endDate > queryTime }).sorted(by: { $0.startDate < $1.startDate }).first,
               let following = allEvents.filter({ $0.startDate > nextFree.endDate }).sorted(by: { $0.startDate < $1.startDate }).first {
                let gap = following.startDate.timeIntervalSince(nextFree.endDate)
                let gapMinutes = Int(gap / 60)
                if gapMinutes >= 30 {
                    body += " Your next free slot is from \(timeFormatter.string(from: nextFree.endDate)) to \(timeFormatter.string(from: following.startDate))."
                }
            } else if let lastEvent = allEvents.sorted(by: { $0.endDate > $1.endDate }).first {
                body += " You're free after \(timeFormatter.string(from: lastEvent.endDate))."
            }
        } else {
            body = "You're not available at that time."
        }

        return VoiceResponse(
            greeting: greeting,
            body: body,
            insight: nil,
            followUp: nil
        )
    }

    // MARK: - Conflict Detection

    func checkConflicts(
        newEventStart: Date,
        newEventEnd: Date,
        in events: [UnifiedEvent]
    ) -> [UnifiedEvent] {
        return events.filter { event in
            newEventEnd > event.startDate && event.endDate > newEventStart
        }
    }

    func formatConflictWarning(conflicts: [UnifiedEvent]) -> String? {
        guard !conflicts.isEmpty else { return nil }

        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        if conflicts.count == 1 {
            let event = conflicts[0]
            return "Warning: This overlaps with \(event.title) at \(timeFormatter.string(from: event.startDate))."
        } else {
            return "Warning: This conflicts with \(conflicts.count) existing events."
        }
    }
}
