# Calendar Views - Quick Reference Guide

## Question 1: Which parent view creates these calendar views?

**Answer: CalendarTabView**
- **Path**: `/Users/btessema/Desktop/CalAI/CalAI/CalAI/Features/Calendar/Views/CalendarTabView.swift`
- **Type**: Main calendar view container that manages view selection
- **Responsibility**: Switches between Day, Week, Month, Year views

However, note that:
- **DayCalendarView** (unused) was designed to be directly used
- **WeekCalendarView** (unused) was designed to be directly used
- **Actually used**: CompressedDayTimelineView and WeekViewWithCompressedTimeline

---

## Question 2: How is the events array provided?

### Source: CalendarManager
```swift
class CalendarManager: ObservableObject {
    @Published var unifiedEvents: [UnifiedEvent] = []
}
```

### Flow to Views:
```
CalendarManager.unifiedEvents 
    ↓
CalendarTabView (@ObservedObject) 
    ↓
Filter via eventsForDate()
    ↓
Convert to TimelineEvent (for day view)
    ↓
Pass to CompressedDayTimelineView
```

### Key Methods in CalendarTabView:

#### eventsForDate(_ date: Date) -> [UnifiedEvent]
- Filters by selected date
- Handles all-day events (checks date range)
- Handles timed events (checks same day)

#### unifiedEventsForDate(_ date: Date) -> [UnifiedEvent]
- Uses EventFilterService
- Removes duplicates by ID and startDate
- Deduplicates recurring events

---

## Question 3: @ObservedObject or @EnvironmentObject?

**Answer: @ObservedObject**

### In CalendarTabView:
```swift
struct CalendarTabView: View {
    @ObservedObject var calendarManager: CalendarManager  // <-- Direct dependency
    @ObservedObject var fontManager: FontManager
    @ObservedObject var appearanceManager: AppearanceManager
}
```

### In Child Views:
```swift
struct CompressedDayTimelineView: View {
    @ObservedObject var fontManager: FontManager  // <-- Direct dependency
}

struct WeekViewWithCompressedTimeline: View {
    @ObservedObject var fontManager: FontManager  // <-- Direct dependency
    @ObservedObject var calendarManager: CalendarManager  // <-- Direct dependency
}
```

### Why not EnvironmentObject?
- Makes dependencies explicit
- Easier to test (can inject mock managers)
- Clearer view hierarchy

---

## Question 4: How to trigger view updates when event properties change?

### Mechanism: refreshTrigger Parameter

**The system uses a "refresh trigger" string that encodes event state**:

```swift
refreshTrigger: calendarManager.unifiedEvents.map { 
    "\($0.id)-\($0.startDate.timeIntervalSince1970)" 
}.joined()
```

This creates a string like: `"event1-707383600event2-707383620..."`

### How It Works:

1. **Parent computes hash** whenever `unifiedEvents` changes
2. **Child detects change** via `.onChange(of: refreshTrigger)`
3. **Child rebuilds** by calling `buildSegments()`
4. **View re-renders** with new event data

### Code in CompressedDayTimelineView:

```swift
.onChange(of: refreshTrigger) { newValue in
    print("📊 Refresh trigger changed, rebuilding segments")
    
    // 100ms delay prevents animation jank
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        buildSegments()
    }
}
```

### What Triggers Updates?

When ANY of these change:
- Event title
- Event start date
- Event end date
- Event location
- New events added
- Events deleted
- Any other UnifiedEvent property

---

## Summary Table

| Question | Answer |
|----------|--------|
| Parent view | CalendarTabView (CalendarTabView.swift) |
| Manager | CalendarManager (@Published unifiedEvents) |
| Dependency injection | @ObservedObject (not @EnvironmentObject) |
| Update mechanism | refreshTrigger string parameter |
| Update trigger | .onChange(of: refreshTrigger) in child views |
| Delay | 100ms to prevent animation jank |

---

## File Structure

```
CalendarManager.swift
  └─ publishes @Published unifiedEvents

Features/Calendar/Views/CalendarTabView.swift
  ├─ observes @ObservedObject calendarManager
  ├─ filters events via eventsForDate()
  ├─ instantiates CompressedDayTimelineView (day view)
  ├─ instantiates WeekViewWithCompressedTimeline (week view)
  ├─ contains struct CompressedDayTimelineView (line 1909)
  └─ contains struct WeekViewWithCompressedTimeline (line 1282)

NOT USED:
├─ DayCalendarView.swift (obsolete)
└─ WeekCalendarView.swift (obsolete)
```

---

## Example: Adding a New Observable Property

If you wanted to add another observable to trigger updates:

```swift
class CalendarManager: ObservableObject {
    @Published var unifiedEvents: [UnifiedEvent] = []
    @Published var selectedEventTitles: Set<String> = []  // NEW
    
    func toggleEventSelection(_ eventId: String) {
        // This would trigger updates in observing views
    }
}

// In CalendarTabView, pass it to child view:
CompressedDayTimelineView(
    // ... other parameters ...
    refreshTrigger: calendarManager.unifiedEvents.map { 
        "\($0.id)-\($0.startDate.timeIntervalSince1970)" 
    }.joined() + "-" + calendarManager.selectedEventTitles.sorted().joined(separator: ",")
)
```

---

## Performance Notes

- The 100ms delay in refreshTrigger prevents jank during drag animations
- View IDs also force reconstruction on date/count changes:
  ```swift
  .id("\(selectedDate.timeIntervalSince1970)-\(calendarManager.unifiedEvents.count)")
  ```
- This dual mechanism provides both responsive updates and animation smoothness

