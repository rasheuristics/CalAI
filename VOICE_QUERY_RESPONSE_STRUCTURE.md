# Voice Query Response Structure

**Question**: "What is on my schedule today?"

This document explains the complete response structure for calendar queries in CalAI.

---

## Response Flow

```
User: "What is on my schedule today?"
  ↓
VoiceManager (Speech Recognition)
  ↓
AIManager.processVoiceCommand()
  ↓
classifyIntent() → .query
  ↓
handleQuery()
  ↓
VoiceResponseGenerator.generateQueryResponse()
  ↓
AICalendarResponse
  ↓
AITabView (Display + Voice Output)
```

---

## Data Structures

### 1. AICalendarResponse (CalendarCommand.swift:101)

**Primary response object returned to the UI:**

```swift
struct AICalendarResponse: Codable {
    var message: String                      // Natural language response
    var command: CalendarCommand?            // Command metadata
    let requiresConfirmation: Bool           // Whether user needs to confirm
    let confirmationMessage: String?         // Confirmation prompt
    let needsMoreInfo: Bool                  // Whether more details needed
    let partialCommand: CalendarCommand?     // Incomplete command
    let eventResults: [EventResult]?         // 📌 EVENTS FOR DISPLAY
    let shouldContinueListening: Bool        // Auto-restart listening
}
```

### 2. EventResult (CalendarCommand.swift:123)

**Individual event data for UI display:**

```swift
struct EventResult: Codable, Identifiable {
    let id: String              // Unique event ID
    let title: String           // Event title
    let startDate: Date         // Start time
    let endDate: Date           // End time
    let location: String?       // Location (optional)
    let source: String          // "iOS", "Google", "Outlook"
    let color: [Double]?        // RGB values [r, g, b]
}
```

### 3. VoiceResponse (VoiceResponseGenerator.swift:5)

**Internal structure for voice output:**

```swift
struct VoiceResponse {
    let greeting: String        // "Good morning!"
    let body: String           // Main narrative
    let insight: String?       // Additional context (e.g., busy periods)
    let followUp: String?      // Suggested next question

    var fullMessage: String {
        // Combines all parts: greeting + body + insight + followUp
        var parts = [greeting, body]
        if let insight = insight { parts.append(insight) }
        if let followUp = followUp { parts.append(followUp) }
        return parts.joined(separator: " ")
    }
}
```

### 4. ScheduleAnalysis (VoiceResponseGenerator.swift:25)

**Internal analysis for rich narratives:**

```swift
struct ScheduleAnalysis {
    let character: String               // "light", "moderate", "busy", "packed", "free"
    let totalEvents: Int                // Total event count
    let timedEvents: [UnifiedEvent]     // Events with specific times
    let allDayEvents: [UnifiedEvent]    // All-day events
    let busyPeriods: [BusyPeriod]       // 3+ back-to-back meetings
    let gaps: [TimeGap]                 // Free time windows
    let transitions: [Transition]       // Event-to-event movements
    let totalDuration: TimeInterval     // Total scheduled time
    let longestGap: TimeInterval?       // Longest break
    let earliestEvent: UnifiedEvent?    // First event
    let latestEvent: UnifiedEvent?      // Last event
}
```

---

## Complete Example

### Input
```swift
User: "What is on my schedule today?"
```

### Processing (AIManager.swift:1120)

```swift
func handleQuery(transcript: String, calendarEvents: [UnifiedEvent], completion: @escaping (AICalendarResponse) -> Void) async throws {

    // 1. Extract time range
    let (startDate, endDate) = extractTimeRange(from: transcript)
    // → startDate: 2025-10-21 00:00:00
    // → endDate: 2025-10-22 00:00:00

    // 2. Filter events in range
    let relevantEvents = calendarEvents.filter { event in
        event.startDate >= startDate && event.startDate < endDate
    }.sorted { $0.startDate < $1.startDate }
    // → Found 5 events

    // 3. Generate voice response
    let voiceResponse = voiceResponseGenerator.generateQueryResponse(
        events: relevantEvents,
        timeRange: (start: startDate, end: endDate)
    )

    // 4. Convert to EventResult format
    let eventResults = relevantEvents.map { event in
        EventResult(
            id: event.id,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            location: event.location,
            source: event.source.rawValue,
            color: nil
        )
    }

    // 5. Build response
    let response = AICalendarResponse(
        message: voiceResponse.fullMessage,
        command: CalendarCommand(
            type: .queryEvents,
            queryStartDate: startDate,
            queryEndDate: endDate
        ),
        eventResults: eventResults,
        shouldContinueListening: voiceResponse.followUp != nil
    )

    completion(response)
}
```

### Output Structure

```json
{
  "message": "Good morning! Today is busy - you're booked from 9 AM to 6 PM with 5 events. Your morning has 3 events starting with Team Standup at 9:00 AM, afternoon brings 2 events including Client Presentation. Note that Client Presentation is off-site at Downtown Office. Your busiest stretch is 3 back-to-back meetings from 2:00 PM to 5:00 PM.",

  "command": {
    "type": "queryEvents",
    "queryStartDate": "2025-10-21T00:00:00Z",
    "queryEndDate": "2025-10-22T00:00:00Z"
  },

  "eventResults": [
    {
      "id": "evt_001",
      "title": "Team Standup",
      "startDate": "2025-10-21T09:00:00Z",
      "endDate": "2025-10-21T09:30:00Z",
      "location": null,
      "source": "iOS",
      "color": null
    },
    {
      "id": "evt_002",
      "title": "Client Presentation",
      "startDate": "2025-10-21T10:30:00Z",
      "endDate": "2025-10-21T11:30:00Z",
      "location": "Downtown Office",
      "source": "Google",
      "color": [0.2, 0.5, 0.8]
    },
    {
      "id": "evt_003",
      "title": "Budget Review",
      "startDate": "2025-10-21T14:00:00Z",
      "endDate": "2025-10-21T15:00:00Z",
      "location": "Conference Room B",
      "source": "Outlook",
      "color": null
    },
    {
      "id": "evt_004",
      "title": "Team Sync",
      "startDate": "2025-10-21T15:00:00Z",
      "endDate": "2025-10-21T16:00:00Z",
      "location": null,
      "source": "iOS",
      "color": null
    },
    {
      "id": "evt_005",
      "title": "Project Review",
      "startDate": "2025-10-21T16:00:00Z",
      "endDate": "2025-10-21T18:00:00Z",
      "location": "Zoom",
      "source": "Google",
      "color": null
    }
  ],

  "requiresConfirmation": false,
  "confirmationMessage": null,
  "needsMoreInfo": false,
  "partialCommand": null,
  "shouldContinueListening": false
}
```

---

## Voice Response Generation (VoiceResponseGenerator.swift:343)

### Step 1: Analyze Schedule

```swift
let analysis = analyzeSchedule(events: events, timeRange: timeRange)
```

**Produces:**
```swift
ScheduleAnalysis(
    character: "busy",                    // 5-6 events or 4-6 hours
    totalEvents: 5,
    timedEvents: [all 5 events],
    allDayEvents: [],
    busyPeriods: [
        BusyPeriod(
            start: 2:00 PM,
            end: 5:00 PM,
            events: [Budget Review, Team Sync, Project Review],
            duration: 10800  // 3 hours
        )
    ],
    gaps: [
        TimeGap(start: 11:30 AM, end: 2:00 PM, duration: 150, isSignificant: true),
        TimeGap(start: 9:30 AM, end: 10:30 AM, duration: 60, isSignificant: true)
    ],
    transitions: [
        Transition(from: Team Standup, to: Client Presentation, isTight: false),
        Transition(from: Budget Review, to: Team Sync, isTight: true)
    ],
    totalDuration: 21600,  // 6 hours
    longestGap: 150 minutes,
    earliestEvent: Team Standup,
    latestEvent: Project Review
)
```

### Step 2: Build Narrative

```swift
let body = buildDayNarrative(analysis: analysis, timeRef: "Today")
```

**Components:**

1. **Overview**: "Today is busy"
2. **Time span**: "you're booked from 9 AM to 6 PM"
3. **Event count**: "with 5 events"
4. **Event flow**: "Your morning has 3 events starting with Team Standup at 9:00 AM, afternoon brings 2 events including Client Presentation"
5. **Logistics**: "Note that Client Presentation is off-site at Downtown Office"
6. **Breathing room**: (none - no significant gaps mentioned)

### Step 3: Add Insights

```swift
var insight: String? = nil
if !analysis.busyPeriods.isEmpty {
    let period = analysis.busyPeriods[0]
    insight = "Your busiest stretch is 3 back-to-back meetings from 2:00 PM to 5:00 PM."
}
```

### Step 4: Create VoiceResponse

```swift
return VoiceResponse(
    greeting: "Good morning!",
    body: "Today is busy - you're booked from 9 AM to 6 PM with 5 events...",
    insight: "Your busiest stretch is 3 back-to-back meetings from 2:00 PM to 5:00 PM.",
    followUp: nil
)
```

---

## UI Display (AITabView.swift:697-716)

### Text Display

```swift
if Config.aiOutputMode != .voiceOnly {
    let aiMessage = ConversationItem(
        message: response.message,
        isUser: false,
        eventResults: response.eventResults  // ← Events attached here
    )
    conversationHistory.append(aiMessage)
}
```

### Voice Output

```swift
if Config.aiOutputMode != .textOnly {
    SpeechManager.shared.speak(text: response.message) {
        // Auto-restart listening if in continuous mode
    }
}
```

### Event Cards (AITabView.swift:1011-1023)

```swift
if !item.isUser,
   let eventResults = item.eventResults,
   !eventResults.isEmpty,
   (queryDisplayMode == .eventsOnly || queryDisplayMode == .both) {
    VStack(alignment: .leading, spacing: 6) {
        ForEach(eventResults) { event in
            EventResultCard(event: event)  // Renders each event
        }
    }
}
```

### Event Card Component (AITabView.swift:1034)

```swift
struct EventResultCard: View {
    let event: EventResult

    var body: some View {
        HStack(spacing: 12) {
            // Time column
            VStack(alignment: .leading, spacing: 2) {
                Text("9:00 AM")              // startDate formatted
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                Text("30m")                  // duration
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Event details
            VStack(alignment: .leading, spacing: 4) {
                Text("Team Standup")         // title
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let location = event.location {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                HStack(spacing: 4) {
                    Image(systemName: "calendar")  // source icon
                    Text("iOS")                    // source
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}
```

---

## Display Modes (AITabView.swift:994)

User can control what's displayed via settings:

```swift
@AppStorage(UserDefaults.Keys.queryDisplayMode)
private var queryDisplayMode: QueryDisplayMode = .both

enum QueryDisplayMode {
    case summaryOnly   // Show only text: "Today is busy..."
    case eventsOnly    // Show only event cards
    case both          // Show text + event cards
}
```

---

## Summary

### For "What is on my schedule today?", the response contains:

1. **message** (String):
   - Rich narrative text
   - Examples: "Good morning! Today is busy - you're booked from 9 AM to 6 PM..."

2. **eventResults** (Array of EventResult):
   - Each event with: id, title, startDate, endDate, location, source, color
   - Used to render visual event cards
   - Can be shown/hidden based on display mode

3. **command** (CalendarCommand):
   - Metadata: type = `.queryEvents`, queryStartDate, queryEndDate
   - Used for tracking/analytics

4. **shouldContinueListening** (Bool):
   - Whether to auto-restart listening after response
   - Based on whether there's a followUp suggestion

### The UI then:
- Speaks the `message` (voice output)
- Displays the `message` (text bubble)
- Renders `eventResults` as visual cards (if display mode allows)
- Auto-restarts listening if `shouldContinueListening` is true

---

## Related Files

### Data Models
- `/Users/btessema/Desktop/CalAI/CalAI/CalAI/Features/Calendar/CalendarCommand.swift` (Lines 101-131)

### Processing Logic
- `/Users/btessema/Desktop/CalAI/CalAI/CalAI/AIManager.swift` (Lines 1120-1173)

### Response Generation
- `/Users/btessema/Desktop/CalAI/CalAI/CalAI/Features/AI/VoiceResponseGenerator.swift` (Lines 343-384)

### UI Display
- `/Users/btessema/Desktop/CalAI/CalAI/CalAI/Features/AI/Views/AITabView.swift` (Lines 697-716, 1011-1106)

---

**Last Updated**: 2025-10-21
