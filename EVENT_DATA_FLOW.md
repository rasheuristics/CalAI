# Event Data Flow Diagram

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      CalendarManager                          │
│                  (@Published properties)                      │
│                                                               │
│  @Published var events: [EKEvent]                           │
│  @Published var unifiedEvents: [UnifiedEvent]               │
│  @Published var hasCalendarAccess: Bool                     │
│  @Published var detectedConflicts: [ScheduleConflict]       │
│  @Published var errorState: AppError?                       │
└─────────────────────────────────────────────────────────────┘
                              ▲
                              │
                    observes via @ObservedObject
                              │
┌─────────────────────────────────────────────────────────────┐
│                    CalendarTabView                            │
│                   (Main View Container)                       │
│                                                               │
│  @ObservedObject var calendarManager: CalendarManager       │
│  @State var selectedDate: Date                              │
│  @State var currentViewType: CalendarViewType               │
│                                                               │
│  private func eventsForDate(_ date: Date) -> [UnifiedEvent] │
│  private func unifiedEventsForDate(_ date: Date)...         │
└─────────────────────────────────────────────────────────────┘
            │                          │                      │
            │                          │                      │
    ┌───────▼────────┐      ┌──────────▼────────┐    ┌────────▼────────┐
    │     Day View   │      │    Week View      │    │   Month View    │
    │   (case .day)  │      │   (case .week)    │    │  (case .month)  │
    └────────────────┘      └───────────────────┘    └─────────────────┘
            │                          │
     ┌──────▼──────────┐      ┌────────▼────────────┐
     │CompressedDay    │      │WeekViewWithCompressed│
     │TimelineView     │      │Timeline              │
     │                 │      │                      │
     │Parameters:      │      │Parameters:           │
     │ - date          │      │ - selectedDate       │
     │ - events[]      │      │ - events[]           │
     │ - fontManager   │      │ - fontManager        │
     │ - refreshTrigger│      │ - calendarManager    │
     │ - onEventTap    │      │ - onEventTap         │
     └────────┬────────┘      └────────┬─────────────┘
              │                        │
              │                  ┌─────▼──────────────┐
              │                  │ weekTimelineView() │
              │                  │                    │
              │                  │ Creates 3 Daily   │
              │                  │ Timeline Views:    │
              │                  │ - Previous Day     │
              │                  │ - Current Day      │
              │                  │ - Next Day         │
              │                  └────────────────────┘
              │                        │
              └──────────┬─────────────┘
                         │
            ┌────────────▼─────────────┐
            │  Renders Event Timeline  │
            │  - All-day events        │
            │  - Timed events          │
            │  - Drag/drop support     │
            │  - Now marker            │
            └──────────────────────────┘
```

---

## Event Update Flow

```
    Event Created/Modified/Deleted in iOS Calendar
                         ▼
              ┌──────────────────────┐
              │  EKEventStore        │
              │  (iOS Calendar API)  │
              └──────────┬───────────┘
                         │
                         ▼
            ┌────────────────────────┐
            │ CalendarManager        │
            │ .loadEvents()          │
            │ .loadAllUnifiedEvents()│
            └────────────┬───────────┘
                         │
                         ▼
        ┌─────────────────────────────┐
        │ @Published unifiedEvents    │
        │ fires objectWillChange()    │
        └────────────────┬────────────┘
                         │
                         ▼
        ┌─────────────────────────────────┐
        │ CalendarTabView observes        │
        │ @ObservedObject calendarManager │
        │ View rebuilds body              │
        └────────────────┬────────────────┘
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
┌──────────────────────┐      ┌────────────────────────┐
│ eventsForDate()      │      │ refreshTrigger updated │
│ filters events       │      │ = hashString of all    │
│ by selectedDate      │      │   event IDs + dates    │
└──────────┬───────────┘      └────────────┬───────────┘
           │                              │
           ▼                              ▼
┌──────────────────────┐      ┌────────────────────────┐
│ Pass to child view:  │      │ CompressedDayTimeline  │
│ CompressedDayTimeline│      │ .onChange(refreshTrigger)
│ events array updated │      │ buildSegments()        │
└──────────────────────┘      └────────────────────────┘
           │                              │
           └──────────────┬───────────────┘
                          ▼
                ┌──────────────────────┐
                │  View Re-renders    │
                │  Timeline Updated   │
                │  with New Events    │
                └──────────────────────┘
```

---

## refreshTrigger Mechanism (In Detail)

```
Step 1: Parent Computes Hash String
┌────────────────────────────────────────────────────────┐
│ calendarManager.unifiedEvents.map {                    │
│     "\($0.id)-\($0.startDate.timeIntervalSince1970)"   │
│ }.joined()                                             │
└────────────────────────────────────────────────────────┘
     │
     │ Example: "event1-707383600event2-707383620..."
     ▼
┌────────────────────────────────────────────────────────┐
│ Pass as refreshTrigger to CompressedDayTimelineView   │
└────────────────────────────────────────────────────────┘
     │
     ▼
Step 2: Child View Detects Change
┌────────────────────────────────────────────────────────┐
│ .onChange(of: refreshTrigger) { newValue in            │
│     print("📊 Refresh trigger changed")                │
│     DispatchQueue.main.asyncAfter(.now() + 0.1) {      │
│         buildSegments()                                │
│     }                                                  │
│ }                                                      │
└────────────────────────────────────────────────────────┘
     │
     ▼
Step 3: View Rebuilds Content
┌────────────────────────────────────────────────────────┐
│ buildSegments() creates:                               │
│ - TimelineSegment[] from current events                │
│ - ClampedEvent[] for all-day events                   │
│ - Positions events on timeline                        │
└────────────────────────────────────────────────────────┘
     │
     ▼
Step 4: View Renders with New Data
┌────────────────────────────────────────────────────────┐
│ SwiftUI re-renders:                                    │
│ - All-day events section                              │
│ - Scrollable timeline                                 │
│ - Hour labels                                         │
│ - Now marker (if today)                               │
│ - Drag handles on events                              │
└────────────────────────────────────────────────────────┘

TIMING: 100ms delay prevents animation jank when dragging
```

---

## View ID Reconstruction (Secondary Mechanism)

```
┌─────────────────────────────────────────────────┐
│ CompressedDayTimelineView.id()                  │
│                                                 │
│ "\(selectedDate.timeIntervalSince1970)-        │
│   \(calendarManager.unifiedEvents.count)"      │
└─────────────────────────────────────────────────┘
     │
     ├─ Changes when selectedDate changes
     │  (different day selected)
     │
     └─ Changes when event count changes
        (events added or removed)
        
        When id changes:
        ▼
        SwiftUI destroys and recreates view
        (more aggressive than refreshTrigger)
```

---

## Code Example: How Changes Flow Through System

```swift
// 1. User moves event to different time in Calendar app

// 2. CalendarManager detects change
class CalendarManager {
    func loadEvents() {
        let fetchedEvents = eventStore.events(matching: predicate)
        // Events now include the moved event with updated times
        DispatchQueue.main.async {
            self.events = fetchedEvents  // @Published triggers
            self.loadAllUnifiedEvents()
        }
    }
}

// 3. CalendarTabView receives update (it observes CalendarManager)
struct CalendarTabView: View {
    @ObservedObject var calendarManager: CalendarManager
    // Body gets called automatically when unifiedEvents changes
    
    var body: some View {
        switch currentViewType {
        case .day:
            let dayEvents = unifiedEventsForDate(selectedDate)
            CompressedDayTimelineView(
                date: selectedDate,
                events: dayEvents.map { TimelineEvent(from: $0) },
                // refreshTrigger changes here!
                refreshTrigger: calendarManager.unifiedEvents.map { 
                    "\($0.id)-\($0.startDate.timeIntervalSince1970)" 
                }.joined()  // <- New hash string with updated times
            )
        }
    }
}

// 4. CompressedDayTimelineView detects refreshTrigger change
struct CompressedDayTimelineView: View {
    var refreshTrigger: String = ""
    
    var body: some View {
        // ... view hierarchy ...
            .onChange(of: refreshTrigger) { newValue in
                // This fires because hash string changed
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    buildSegments()  // Rebuild with new event times
                }
            }
    }
}

// 5. Timeline is redrawn with event in new position
// Result: User sees event moved in calendar view
```

