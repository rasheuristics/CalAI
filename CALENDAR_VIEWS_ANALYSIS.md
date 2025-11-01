# Calendar Views: DayCalendarView & WeekCalendarView Analysis

## Overview
After thorough investigation, I discovered that **DayCalendarView and WeekCalendarView are defined but NOT actually used in the codebase**. Instead, the app uses modernized alternatives: `CompressedDayTimelineView` and `WeekViewWithCompressedTimeline`.

---

## Key Findings

### 1. Defined But Unused Views

#### DayCalendarView
- **Location**: `/Users/btessema/Desktop/CalAI/CalAI/CalAI/DayCalendarView.swift`
- **Parameters**:
  ```swift
  struct DayCalendarView: View {
      @Binding var selectedDate: Date
      let events: [EKEvent]  // Direct EKEvent array
      @Binding var zoomScale: CGFloat
      @Binding var offset: CGSize
  ```
- **Status**: Defined but NOT instantiated anywhere in the codebase

#### WeekCalendarView
- **Location**: `/Users/btessema/Desktop/CalAI/CalAI/CalAI/Features/Calendar/Views/WeekCalendarView.swift`
- **Parameters**:
  ```swift
  struct WeekCalendarView: View {
      @Binding var selectedDate: Date
      let events: [EKEvent]  // Direct EKEvent array
      @Binding var zoomScale: CGFloat
      @Binding var offset: CGSize
  ```
- **Status**: Defined but NOT instantiated anywhere in the codebase

---

## 2. Parent View Architecture (ACTUAL Implementation)

### CalendarTabView (Parent Container)
- **Location**: `/Users/btessema/Desktop/CalAI/CalAI/CalAI/Features/Calendar/Views/CalendarTabView.swift`
- **Type**: Main calendar view controller

#### State & Dependencies:
```swift
struct CalendarTabView: View {
    @ObservedObject var calendarManager: CalendarManager
    @ObservedObject var fontManager: FontManager
    @ObservedObject var appearanceManager: AppearanceManager
    @State private var selectedDate = Date()
    @State private var currentViewType: CalendarViewType = .day
    
    // Other state properties...
    private let eventFilterService = EventFilterService()
}
```

#### Key Observation Pattern:
- Uses **@ObservedObject for CalendarManager** (not @EnvironmentObject)
- Listens to `calendarManager.unifiedEvents` for event changes
- Passes filtered events to child views

---

## 3. How Events Flow to Child Views

### CalendarManager (Observable Object)
**Location**: `/Users/btessema/Desktop/CalAI/CalAI/CalendarManager.swift`

```swift
class CalendarManager: ObservableObject {
    @Published var events: [EKEvent] = []  // Raw iOS Calendar events
    @Published var unifiedEvents: [UnifiedEvent] = []  // Multi-source events
    @Published var hasCalendarAccess = false
    
    func loadEvents() {
        // Loads iOS Calendar events
    }
    
    func loadAllUnifiedEvents() {
        // Combines iOS + Google + Outlook events
    }
}
```

#### Event Flow:
1. **CalendarManager** publishes `@Published unifiedEvents`
2. **CalendarTabView** observes via `@ObservedObject calendarManager`
3. **Child views receive filtered events** via method calls

---

## 4. Actual Child Views & Event Passing

### Day View Implementation

#### CompressedDayTimelineView (Used for Day view)
**Location**: CalendarTabView.swift (lines 1909+)

**Instantiation in CalendarTabView** (lines 79-102):
```swift
case .day:
    let dayEvents = unifiedEventsForDate(selectedDate)
    if dayEvents.isEmpty && !calendarManager.isLoading {
        EmptyStateView(...)
    } else {
        CompressedDayTimelineView(
            date: selectedDate,
            events: dayEvents.map { TimelineEvent(from: $0) },
            fontManager: fontManager,
            isWeekView: false,
            refreshTrigger: calendarManager.unifiedEvents.map { 
                "\($0.id)-\($0.startDate.timeIntervalSince1970)" 
            }.joined(),
            onEventTap: { calendarEvent in
                // Handle tap
            }
        )
        .id("\(selectedDate.timeIntervalSince1970)-\(calendarManager.unifiedEvents.count)")
    }
```

**Parameters**:
```swift
struct CompressedDayTimelineView: View {
    let date: Date
    let events: [CalendarEvent]  // Converted from UnifiedEvent
    @ObservedObject var fontManager: FontManager
    var isWeekView: Bool = false
    var refreshTrigger: String = ""  // Force rebuild trigger
    var onEventTap: ((CalendarEvent) -> Void)? = nil
}
```

---

### Week View Implementation

#### WeekViewWithCompressedTimeline (Used for Week view)
**Location**: CalendarTabView.swift (lines 1282+)

**Instantiation in CalendarTabView** (lines 104-118):
```swift
case .week:
    WeekViewWithCompressedTimeline(
        selectedDate: $selectedDate,
        events: calendarManager.unifiedEvents,
        fontManager: fontManager,
        calendarManager: calendarManager,
        onEventTap: { calendarEvent in
            if let unifiedEvent = calendarManager.unifiedEvents.first(where: { $0.id == calendarEvent.id }) {
                selectedEventForEdit = unifiedEvent
                showingEditView = true
            }
        }
    )
```

**Parameters**:
```swift
struct WeekViewWithCompressedTimeline: View {
    @Binding var selectedDate: Date
    let events: [UnifiedEvent]
    @ObservedObject var fontManager: FontManager
    @ObservedObject var calendarManager: CalendarManager
    var onEventTap: ((CalendarEvent) -> Void)? = nil
}
```

#### Internal Timeline Rendering (lines 1605-1652):
The `weekTimelineView()` function creates 3 `CompressedDayTimelineView` instances (prev, current, next days):

```swift
private func weekTimelineView() -> some View {
    ZStack {
        // Previous day
        CompressedDayTimelineView(
            date: previousDay,
            events: eventsForDate(previousDay).map { TimelineEvent(from: $0) },
            fontManager: fontManager,
            isWeekView: true,
            refreshTrigger: calendarManager.unifiedEvents.map { 
                "\($0.id)-\($0.startDate.timeIntervalSince1970)" 
            }.joined(),
            onEventTap: onEventTap
        )
        
        // Current day
        CompressedDayTimelineView(
            date: selectedDate,
            events: eventsForDate(selectedDate).map { TimelineEvent(from: $0) },
            fontManager: fontManager,
            isWeekView: true,
            refreshTrigger: calendarManager.unifiedEvents.map { 
                "\($0.id)-\($0.startDate.timeIntervalSince1970)" 
            }.joined(),
            onEventTap: onEventTap
        )
        
        // Next day
        CompressedDayTimelineView(
            date: nextDay,
            events: eventsForDate(nextDay).map { TimelineEvent(from: $0) },
            fontManager: fontManager,
            isWeekView: true,
            refreshTrigger: calendarManager.unifiedEvents.map { 
                "\($0.id)-\($0.startDate.timeIntervalSince1970)" 
            }.joined(),
            onEventTap: onEventTap
        )
    }
}
```

---

## 5. View Update Mechanism

### Change Detection Strategy

**The system uses TWO mechanisms to trigger view updates:**

#### 1. **refreshTrigger Parameter** (Primary mechanism)
Located in CompressedDayTimelineView (line 2005-2013):

```swift
.onChange(of: refreshTrigger) { newValue in
    // Rebuild segments when events change (triggered by parent)
    print("📊 Refresh trigger changed, rebuilding segments")
    print("   New trigger: \(newValue.prefix(100))...")
    
    // Small delay to allow drag animations to complete before rebuilding
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        buildSegments()
    }
}
```

**How it works**:
```swift
refreshTrigger: calendarManager.unifiedEvents.map { 
    "\($0.id)-\($0.startDate.timeIntervalSince1970)" 
}.joined()
```
- Creates a string hash of all events with their IDs and timestamps
- When ANY event property changes (title, date, etc.), this hash changes
- SwiftUI detects the change and rebuilds the view
- Includes 0.1s delay to prevent animation conflicts

#### 2. **View ID for Full Reconstruction**
```swift
.id("\(selectedDate.timeIntervalSince1970)-\(calendarManager.unifiedEvents.count)")
```
- Forces complete view recreation when date changes OR event count changes
- Stronger reconstruction mechanism for critical state changes

---

### Date Change Handling
Located in CompressedDayTimelineView (line 1992-2004):

```swift
.onChange(of: date) { _ in
    // Clear ALL state and rebuild completely
    withAnimation(.none) {
        allDayEvents_internal = []
        segments = []
        expandedGaps = []
    }
    
    // Force immediate rebuild on main thread
    DispatchQueue.main.async {
        buildSegments()
    }
}
```

---

## 6. Observable Pattern Summary

### Observation Hierarchy:
```
CalendarManager (@Published properties)
    ↓
CalendarTabView (@ObservedObject)
    ↓
├─ CompressedDayTimelineView (receives filtered events)
├─ WeekViewWithCompressedTimeline
└─ Other views (Month, Year)
```

### Data Flow for Event Changes:
1. Event is created/modified/deleted in iOS Calendar
2. CalendarManager detects change via `loadEvents()`
3. CalendarManager publishes updated `unifiedEvents`
4. CalendarTabView receives update via @ObservedObject
5. Child views rebuild when:
   - `refreshTrigger` string changes (granular updates)
   - `.id()` changes (full reconstruction)

---

## 7. Custom Observation Points

### CalendarTabView tracks these for view updates:

1. **Selected Date**: `@State private var selectedDate = Date()`
   - Triggers filtering via `eventsForDate()`

2. **View Type**: `@State private var currentViewType: CalendarViewType`
   - Switches between Day, Week, Month, Year views

3. **Calendar Manager Events**: `calendarManager.unifiedEvents`
   - Automatically observed via @ObservedObject

4. **Error State**: `calendarManager.errorState`
   - Displays error banners

5. **Conflicts**: `calendarManager.detectedConflicts`
   - Shows conflict alerts

---

## 8. Event Filtering Methods

### eventsForDate(_:)
```swift
private func eventsForDate(_ date: Date) -> [UnifiedEvent] {
    return calendarManager.unifiedEvents.filter { event in
        if event.isAllDay {
            // Check if day is within all-day event's date range
            let eventStartDay = calendar.startOfDay(for: event.startDate)
            let eventEndDay = calendar.startOfDay(for: event.endDate)
            let selectedDay = calendar.startOfDay(for: date)
            return selectedDay >= eventStartDay && selectedDay <= eventEndDay
        } else {
            // For timed events, check same day
            return calendar.isDate(event.startDate, inSameDayAs: date)
        }
    }
}
```

### unifiedEventsForDate(_:)
Uses EventFilterService for duplicate removal:
```swift
private func unifiedEventsForDate(_ date: Date) -> [UnifiedEvent] {
    let filtered = eventFilterService.filterUnifiedEvents(
        calendarManager.unifiedEvents, 
        for: date
    )
    
    // Remove duplicates by ID and startDate
    let unique = filtered.reduce(into: [UnifiedEvent]()) { result, event in
        if !result.contains(where: { 
            $0.id == event.id && $0.startDate == event.startDate 
        }) {
            result.append(event)
        }
    }
    return unique
}
```

---

## Summary: Why Update Views When Event Properties Change?

### The `refreshTrigger` mechanism automatically triggers updates when:
- Event title changes
- Event start/end dates change
- Event location changes
- New events are added
- Events are deleted
- Any other property modification

### This works because:
1. The parent CalendarManager publishes changed `unifiedEvents`
2. CalendarTabView observes this and updates all derived data
3. Each child view receives an updated `refreshTrigger` string
4. SwiftUI detects the string change via `.onChange()`
5. The view rebuilds its segments/timeline

---

## File Paths Summary

| Component | Path |
|-----------|------|
| CalendarTabView | `/Users/btessema/Desktop/CalAI/CalAI/CalAI/Features/Calendar/Views/CalendarTabView.swift` |
| CalendarManager | `/Users/btessema/Desktop/CalAI/CalAI/CalendarManager.swift` |
| DayCalendarView (unused) | `/Users/btessema/Desktop/CalAI/CalAI/CalAI/DayCalendarView.swift` |
| WeekCalendarView (unused) | `/Users/btessema/Desktop/CalAI/CalAI/CalAI/Features/Calendar/Views/WeekCalendarView.swift` |
| CompressedDayTimelineView | CalendarTabView.swift (defined at line 1909) |
| WeekViewWithCompressedTimeline | CalendarTabView.swift (defined at line 1282) |

