# Performance Monitoring Guide

This guide explains how to evaluate and monitor the performance of CalAI to identify glitches, slow loading, and UI responsiveness issues.

## 🎯 Quick Start

### 1. Enable Performance Overlay (Easiest)

Add this to your ContentView to see live FPS:

```swift
ZStack {
    // Your existing content...

    #if DEBUG
    PerformanceOverlay()
    #endif
}
```

This shows:
- **Green dot**: App running smoothly (55+ FPS)
- **Red dot**: Performance issues detected
- **FPS counter**: Current frame rate
- Tap to expand and see dropped frames

### 2. Monitor Specific Operations

Measure how long operations take:

```swift
// Example: Measure tab loading
PerformanceMonitor.shared.startMeasuring("Calendar Tab Load")
// ... load calendar data ...
PerformanceMonitor.shared.stopMeasuring("Calendar Tab Load")
```

Or use the convenience method:

```swift
PerformanceMonitor.shared.measure("Load Events") {
    calendarManager.loadEvents()
}
```

### 3. Monitor View Appearances

Add to any view to measure how long it takes to appear:

```swift
CalendarTabView()
    .measureAppearance("Calendar Tab")
```

## 🔧 Built-in Xcode Tools (Recommended)

### Time Profiler (Find Slow Code)
1. Product → Profile (⌘+I)
2. Choose "Time Profiler"
3. Click Record
4. Use your app normally, switching tabs, loading events
5. Stop recording
6. Look at the "Heaviest Stack Trace" - shows slowest functions

**What to look for:**
- Functions taking > 16ms (causes 60 FPS drops)
- Main thread being blocked
- Repetitive expensive operations

### Animation Hitches Instrument (Find UI Stuttering)
1. Product → Profile (⌘+I)
2. Choose "SwiftUI" template
3. Enable "Animation Hitches"
4. Record while using the app
5. Look for red spikes = frame drops

**What to look for:**
- Hitches when scrolling event lists
- Hitches when switching tabs
- Hitches when tapping cards

### Leaks Instrument (Find Memory Issues)
1. Product → Profile (⌘+I)
2. Choose "Leaks"
3. Record and use the app
4. Check for memory leaks (red markers)

## 📊 Performance Metrics

### Custom Monitoring in Code

Add performance monitoring to key areas:

#### 1. Tab Switching
```swift
// In ContentView.swift
TabView(selection: $selectedTab) {
    // ...
}
.onChange(of: selectedTab) { newTab in
    PerformanceMonitor.shared.measure("Tab Switch to \(newTab)") {
        // Tab loading logic
    }
}
```

#### 2. Event Card Loading
```swift
// In CalendarTabView.swift
.onAppear {
    PerformanceMonitor.shared.measure("Load Calendar Events") {
        calendarManager.loadAllUnifiedEvents()
    }
}
```

#### 3. Settings Tab
```swift
// In SettingsTabView.swift
.onAppear {
    PerformanceMonitor.shared.measure("Settings Tab Load") {
        checkPermissions()
    }
}
```

#### 4. Event Detail View
```swift
EventDetailView()
    .measureAppearance("Event Detail")
```

### View Performance Summary

Check console for output like:
```
✅ Tab Switch to Calendar took 45.23ms
🟡 WARNING: Settings Tab Load took 234.56ms
🔴 CRITICAL: Load Calendar Events took 1234.56ms
```

- ✅ **< 100ms**: Good performance
- 🟡 **100-500ms**: Noticeable delay
- 🔴 **> 500ms**: Critical performance issue

## 🔍 Debug View Hierarchy

Check for expensive rendering:

1. Debug → View Debugging → Capture View Hierarchy
2. Look for:
   - Deep view hierarchies (> 10 levels)
   - Unnecessary transparency/blending
   - Large images being scaled

## 📈 Memory Monitoring

Check memory usage at key points:

```swift
// After loading lots of events
MemoryMonitor.logMemoryUsage(context: "After Loading 1000 Events")

// When switching tabs
MemoryMonitor.logMemoryUsage(context: "Calendar Tab Active")
```

Output:
```
✅ MEMORY [Calendar Tab Active]: 145.2MB (12.1%)
🟡 MEMORY [After Loading 1000 Events]: 456.7MB (38.1%)
🔴 HIGH MEMORY: 980.3MB (81.7%)
```

## 🎬 Common Performance Issues & Fixes

### Issue 1: Tab Switching Lag
**Symptom**: Delay when switching tabs
**Check**: Time Profiler → Look for main thread blocking
**Common causes:**
- Synchronous data loading in `onAppear`
- Heavy computations on main thread
- Too many published properties updating

**Fix**: Defer heavy work:
```swift
.onAppear {
    DispatchQueue.main.async {
        // Heavy work here
    }
}
```

### Issue 2: Scroll Stuttering
**Symptom**: Jerky scrolling in event lists
**Check**: Animation Hitches Instrument
**Common causes:**
- Complex cell views
- Images loading synchronously
- Too many subviews per cell

**Fix**: Simplify views, use LazyVStack

### Issue 3: Event Cards Load Slowly
**Symptom**: Cards appear one by one slowly
**Check**: Time Profiler + Memory Monitor
**Common causes:**
- Loading all data at once
- Not using lazy loading
- Fetching data synchronously

**Fix**: Use pagination, lazy loading

## 📋 Performance Checklist

Run through this checklist regularly:

- [ ] App launches in < 2 seconds
- [ ] Tabs switch in < 100ms
- [ ] Event lists scroll smoothly (60 FPS)
- [ ] Event cards are tappable immediately
- [ ] Settings tab loads in < 200ms
- [ ] No memory warnings in console
- [ ] No animation hitches when scrolling
- [ ] No dropped frames (FPS stays above 55)

## 🚀 Optimization Tips

1. **Defer Heavy Work**: Use `DispatchQueue.main.async` for non-UI work
2. **Lazy Loading**: Only load visible events/data
3. **Pagination**: Load events in batches
4. **Caching**: Cache expensive computations
5. **Image Optimization**: Resize images before displaying
6. **Reduce Redraws**: Minimize `@Published` property updates
7. **Background Threads**: Move network/database work off main thread

## 📝 Performance Report Template

When reporting performance issues, include:

```
Performance Issue Report
========================

Symptom: [What's slow/glitchy]
Location: [Which screen/tab]
Steps to Reproduce:
1. [Step 1]
2. [Step 2]

Performance Metrics:
- FPS: [X] fps
- Duration: [X] ms
- Memory: [X] MB

Time Profiler Results:
[Screenshot or top 3 slowest functions]

Expected: < 100ms
Actual: XXX ms
```

## 🎯 Automated Testing

You can add performance tests:

```swift
func testCalendarLoadPerformance() {
    measure {
        calendarManager.loadAllUnifiedEvents()
    }
    // Should complete in < 500ms
}
```

## 📞 Getting Help

If you identify a performance issue:
1. Run Time Profiler to identify the slow function
2. Check console for PerformanceMonitor warnings
3. Take screenshot of Animation Hitches
4. Note FPS during the issue
5. Report with specific metrics
