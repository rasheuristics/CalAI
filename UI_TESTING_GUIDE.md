# Smart Suggestion UI Testing Guide

## Quick Start - Testing in Xcode

### Method 1: Add Files Manually to Xcode (Recommended)

1. **Open Xcode**:
   ```bash
   open CalAI.xcodeproj
   ```

2. **Add SmartSuggestionView.swift to Project**:
   - In Xcode's Project Navigator (left sidebar)
   - Right-click on `Features/AI/Views` folder
   - Select "Add Files to CalAI..."
   - Navigate to: `CalAI/Features/AI/Views/SmartSuggestionView.swift`
   - Check "Copy items if needed"
   - Click "Add"

3. **View Live Preview**:
   - Open `SmartSuggestionView.swift` in Xcode
   - Click "Resume" button in Canvas (right side)
   - Or press `⌥⌘P` (Option-Command-P)

### Method 2: Test via Playground

You can also create a simple test view:

```swift
import SwiftUI

struct TestSmartSuggestionView: View {
    @State private var showSuggestion = true

    var body: some View {
        VStack {
            if showSuggestion {
                SmartSuggestionView(
                    suggestion: mockSuggestion,
                    onAccept: { time in
                        print("Accepted: \(time)")
                        showSuggestion = false
                    },
                    onDismiss: {
                        showSuggestion = false
                    }
                )
                .padding()
            }

            Button("Show Again") {
                showSuggestion = true
            }
        }
    }

    var mockSuggestion: SmartSchedulingService.SchedulingSuggestion {
        SmartSchedulingService.SchedulingSuggestion(
            suggestedTime: Date().addingTimeInterval(86400),
            confidence: 0.85,
            reasons: [
                "Matches your typical meeting time",
                "Good buffer before your 11:30 call",
                "Tuesday is typically a lighter day"
            ],
            alternatives: [
                Date().addingTimeInterval(86400 + 3600),
                Date().addingTimeInterval(86400 + 7200)
            ],
            warnings: nil
        )
    }
}
```

---

## Test Scenarios

### Scenario 1: High Confidence Suggestion ✅

**Setup:**
```swift
SmartSchedulingService.SchedulingSuggestion(
    suggestedTime: tomorrow at 10am,
    confidence: 0.95,
    reasons: [
        "Matches your typical meeting time",
        "Good buffer before next meeting",
        "Lighter day for you"
    ],
    alternatives: [2pm, 4pm],
    warnings: nil
)
```

**Expected:**
- Green "High Confidence" badge
- All 3 reasons displayed with checkmarks
- Blue "Use This Time" button
- "Show 2 Alternative Times" button
- No warning section

---

### Scenario 2: Medium Confidence with Warnings ⚠️

**Setup:**
```swift
SmartSchedulingService.SchedulingSuggestion(
    suggestedTime: tomorrow at 12:30pm,
    confidence: 0.65,
    reasons: [
        "Available time slot",
        "Works for participants"
    ],
    alternatives: [2pm],
    warnings: [
        "During typical lunch hours",
        "Back-to-back with other meetings"
    ]
)
```

**Expected:**
- Orange "Medium Confidence" badge
- 2 reasons with checkmarks
- Orange warning box with 2 warnings
- Triangle warning icons
- Alternative times available

---

### Scenario 3: Low Confidence (Sparse Calendar) 📊

**Setup:**
```swift
SmartSchedulingService.SchedulingSuggestion(
    suggestedTime: tomorrow at 2pm,
    confidence: 0.35,
    reasons: [
        "Available time slot"
    ],
    alternatives: [],
    warnings: [
        "Limited calendar data for personalization"
    ]
)
```

**Expected:**
- Red "Low Confidence" badge
- Single reason
- Warning about limited data
- No alternatives

---

### Scenario 4: Pattern Confidence View 🧠

**High Confidence Patterns:**
```swift
PatternConfidenceView(
    patterns: SmartSchedulingService.CalendarPatterns(
        preferredMeetingHours: [10, 14, 16],
        averageGapBetweenMeetings: 900,
        typicalMeetingDuration: 1800,
        busiestDays: [3, 5],
        quietestDays: [2, 6],
        hasLunchPattern: true,
        lunchHourRange: 12...13,
        confidence: .high,
        eventCount: 45
    )
)
```

**Expected:**
- Green "High pattern confidence" pill
- Shows all 3 pattern rows
- Displays lunch block
- Shows "Based on 45 events"

**No Confidence Patterns:**
```swift
PatternConfidenceView(
    patterns: SmartSchedulingService.CalendarPatterns(
        preferredMeetingHours: [10, 14, 16],
        averageGapBetweenMeetings: 900,
        typicalMeetingDuration: 1800,
        busiestDays: [3, 5],
        quietestDays: [2, 6],
        hasLunchPattern: false,
        lunchHourRange: nil,
        confidence: .none,
        eventCount: 1
    )
)
```

**Expected:**
- Gray "No pattern data yet" pill
- Message: "Not enough calendar data yet"
- No pattern rows shown

---

## UI Element Checklist

### SmartSuggestionView
- [ ] Header with sparkles icon
- [ ] "Smart Suggestion" title
- [ ] X button (dismiss)
- [ ] Suggested time in large text
- [ ] Confidence badge (color-coded)
- [ ] "Why this time?" section
- [ ] Checkmark bullets for reasons
- [ ] Warning section (conditional)
- [ ] Orange triangle icons for warnings
- [ ] "Use This Time" blue button
- [ ] "Show X Alternative Times" toggle
- [ ] Expandable alternatives list
- [ ] Alternative time cards clickable
- [ ] Smooth expand/collapse animation

### ConfidenceBadge
- [ ] Chart bar icon
- [ ] Text: "High/Medium/Low Confidence"
- [ ] Green for high (0.8-1.0)
- [ ] Orange for medium (0.5-0.8)
- [ ] Red for low (<0.5)
- [ ] Rounded pill shape
- [ ] Translucent background

### PatternConfidenceView
- [ ] Brain icon + "AI Insights" title
- [ ] Confidence pill
- [ ] Clock icon for preferred times
- [ ] Timer icon for duration
- [ ] Fork/knife icon for lunch
- [ ] Event count text
- [ ] Secondary background color
- [ ] Rounded corners

---

## Animation Testing

### Test 1: Alternatives Expansion
1. Click "Show Alternative Times"
2. **Expected**: Smooth slide-down animation
3. Click "Hide Alternatives"
4. **Expected**: Smooth slide-up animation

### Test 2: Accept Button
1. Tap "Use This Time"
2. **Expected**: Callback fires with selected time
3. View should dismiss (if integrated)

### Test 3: Alternative Selection
1. Expand alternatives
2. Tap an alternative time
3. **Expected**: Callback fires with that time instead

---

## Accessibility Testing

### VoiceOver Support
- [ ] All buttons labeled
- [ ] Time announced correctly
- [ ] Reasons list readable
- [ ] Confidence level announced
- [ ] Warnings announced with appropriate tone

### Dynamic Type
- [ ] Text scales with system font size
- [ ] Layout doesn't break at large sizes
- [ ] Buttons remain tappable

### Color Contrast
- [ ] Green badge readable
- [ ] Orange warning readable
- [ ] Text has sufficient contrast

---

## Integration Testing

### With Real Data

**Test with actual calendar:**
```swift
// Get real events
let events = calendarManager.getAllEvents()

// Analyze patterns
let patterns = SmartSchedulingService().analyzeCalendarPatterns(events: events)

// Show pattern view
PatternConfidenceView(patterns: patterns)

// Get suggestion
let suggestion = SmartSchedulingService().suggestOptimalTime(
    for: 1800,  // 30 min
    events: events
)

// Show suggestion
SmartSuggestionView(
    suggestion: suggestion,
    onAccept: { time in
        // Create event at this time
    },
    onDismiss: { }
)
```

---

## Screenshot Locations

Take screenshots for documentation:

1. **High Confidence Suggestion** (collapsed)
2. **High Confidence Suggestion** (expanded alternatives)
3. **Warning Suggestion** (with orange alerts)
4. **Low Confidence Suggestion**
5. **High Pattern Confidence View**
6. **No Pattern Data View**
7. **Dark Mode Versions** (all above)

---

## Known Issues to Watch For

1. **Date Formatting**: Check timezone handling
2. **Long Text**: Test with very long event titles
3. **Many Alternatives**: Test with 3+ alternatives
4. **No Internet**: Ensure UI works offline
5. **Slow Animation**: Check on older devices

---

## Next Steps After Testing

Once UI looks good:

1. ✅ Integrate into AddEventView
2. ✅ Add to AITabView as insights
3. ✅ Connect to real AI suggestions
4. ✅ Add haptic feedback
5. ✅ Polish animations
6. ✅ Add to MorningBriefing

---

## Quick Commands

```bash
# Open Xcode
open CalAI.xcodeproj

# View file in Xcode
open -a Xcode CalAI/Features/AI/Views/SmartSuggestionView.swift

# Run app in simulator
xcodebuild -scheme CalAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' run
```

---

## Support

If previews don't work:
1. Clean build folder (⇧⌘K)
2. Restart Xcode
3. Check that SmartSchedulingService.swift is in project
4. Verify all imports are correct
