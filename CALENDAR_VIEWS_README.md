# Calendar Views Documentation

This folder contains comprehensive documentation about how calendar views are instantiated and how events are passed through the view hierarchy in CalAI.

## Documents Overview

### 1. CALENDAR_VIEWS_QUICK_REFERENCE.md
**Start here for quick answers**
- Direct answers to your 4 main questions
- Summary table of key information
- File structure overview
- Performance notes

**Best for**: Getting quick answers to:
- Which parent view creates calendar views?
- How are events provided?
- @ObservedObject or @EnvironmentObject?
- How to trigger updates when properties change?

---

### 2. CALENDAR_VIEWS_ANALYSIS.md
**Comprehensive technical reference**
- Complete architecture documentation
- Detailed code examples
- Event filtering methods explained
- Observable pattern breakdown
- File paths and line numbers

**Best for**: Deep understanding of:
- View hierarchy and data flow
- Event filtering logic
- Observable patterns used
- Update mechanisms

---

### 3. EVENT_DATA_FLOW.md
**Visual architecture and flow diagrams**
- ASCII diagrams of the architecture
- Event update flow visualization
- refreshTrigger mechanism explained
- Code walkthrough examples
- Performance considerations

**Best for**: Visual learners who want to see:
- How components connect
- Data flow paths
- How updates propagate
- Timing and delays

---

## Key Finding

**Important Note**: The views you asked about (DayCalendarView and WeekCalendarView) are **defined but NOT used** in the codebase. The app actually uses:
- **CompressedDayTimelineView** for day view
- **WeekViewWithCompressedTimeline** for week view

Both are defined in CalendarTabView.swift

---

## Quick Start

### 1. To understand the overall architecture:
1. Read: CALENDAR_VIEWS_QUICK_REFERENCE.md
2. Scan: EVENT_DATA_FLOW.md (architecture diagram)

### 2. To modify event passing:
1. Read: CALENDAR_VIEWS_ANALYSIS.md (Section 3: "How Events Flow")
2. Look: CALENDAR_VIEWS_ANALYSIS.md (Section 8: "Event Filtering Methods")

### 3. To add a new observable property:
1. Read: CALENDAR_VIEWS_QUICK_REFERENCE.md (Example section)
2. Reference: CALENDAR_VIEWS_ANALYSIS.md (Section 6: "Observable Pattern Summary")

### 4. To debug update issues:
1. Read: EVENT_DATA_FLOW.md (refreshTrigger Mechanism section)
2. Check: CALENDAR_VIEWS_ANALYSIS.md (Section 5: "View Update Mechanism")

---

## File Structure Summary

```
CalendarManager.swift
└─ Publishes @Published var unifiedEvents

Features/Calendar/Views/CalendarTabView.swift
├─ Observes CalendarManager via @ObservedObject
├─ Filters events via eventsForDate()
├─ Switches between view types
├─ Instantiates day/week/month/year views
├─ Contains CompressedDayTimelineView definition (line 1909)
└─ Contains WeekViewWithCompressedTimeline definition (line 1282)

Obsolete (not used):
├─ DayCalendarView.swift
└─ WeekCalendarView.swift
```

---

## Core Concepts

### Event Flow
```
CalendarManager.unifiedEvents 
  ↓ (@Published)
CalendarTabView (@ObservedObject)
  ↓ (eventsForDate filtering)
CompressedDayTimelineView
  ↓ (refreshTrigger onChange)
View rebuilds with new events
```

### Update Triggers
1. **refreshTrigger string** - Detects when any event property changes
2. **View ID** - Forces full reconstruction on date/count changes

### Key Pattern
```swift
refreshTrigger: calendarManager.unifiedEvents.map { 
    "\($0.id)-\($0.startDate.timeIntervalSince1970)" 
}.joined()
```
This creates a unique string that changes whenever events change, triggering view updates.

---

## Questions Answered

### Q1: Which parent view creates these calendar views?
**A**: CalendarTabView (Features/Calendar/Views/CalendarTabView.swift)

### Q2: How is the events array provided?
**A**: From CalendarManager.unifiedEvents via filtering in eventsForDate()

### Q3: @ObservedObject or @EnvironmentObject?
**A**: @ObservedObject (makes dependencies explicit)

### Q4: How to trigger updates when event properties change?
**A**: The refreshTrigger string automatically detects changes via .onChange()

---

## Additional Resources

For implementation details, see:
- CalendarManager.swift (event loading)
- EventFilterService.swift (filtering logic)
- TimelineEvent.swift (event type conversions)

For UI components, see:
- CompressedDayTimelineView in CalendarTabView.swift
- WeekViewWithCompressedTimeline in CalendarTabView.swift

---

## Related Documentation

Other CalAI documentation files:
- PROJECT_STRUCTURE.md - Overall app structure
- SNAP_TO_GRID_FIXES.md - Event drag/drop implementation
- FINAL_DRAG_SNAP_SUMMARY.md - Detailed drag mechanics

