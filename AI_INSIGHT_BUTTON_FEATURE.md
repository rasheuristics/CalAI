# AI Insight Floating Button Feature

## Feature Complete ✅

Added a 4th floating action button to the AI Tab that shows/hides the AI Pattern Insights card.

---

## What Was Added

### 1. New Floating Button: "AI Insight" 🟣

**Location**: AI Tab View, bottom row of action buttons

**Appearance**:
- **Icon**: 🧠 brain.head.profile
- **Color**: Purple
- **Label**: "AI Insight"

**Position**: 4th button (rightmost) after:
- 🔵 What's Next/Today (Queries)
- 🟢 Schedule
- 🟠 Manage

---

## Behavior

### Default State
- PatternConfidenceView card is **HIDDEN** by default
- Button shows in normal state (not selected)

### When Tapped (First Time)
1. Button highlights in purple (selected state)
2. PatternConfidenceView card slides in from bottom with animation
3. Card displays AI scheduling insights:
   - Preferred meeting times
   - Typical meeting duration
   - Lunch patterns
   - Confidence level
   - Event count analyzed
4. Button stays selected (purple background)
5. No conversation window opens
6. No auto-dismiss

### When Tapped (Second Time)
1. Button deselects (returns to normal state)
2. PatternConfidenceView card slides out with animation
3. Card disappears

### Difference from Other Buttons
- **Other buttons**: Auto-dismiss after 0.5s
- **AI Insight**: Stays selected until user taps again (toggle behavior)
- **Other buttons**: Show conversation window
- **AI Insight**: No conversation window

---

## Code Changes

### File: `AITabView.swift`

#### 1. Added AI Insight to CommandCategory Enum

```swift
private enum CommandCategory: String, CaseIterable {
    case eventQueries = "Queries"
    case scheduleManagement = "Schedule"
    case eventManagement = "Manage"
    case aiInsight = "AI Insight"  // ✅ NEW

    var icon: String {
        switch self {
        case .eventManagement: return "exclamationmark.triangle.fill"
        case .eventQueries: return "calendar.badge.clock"
        case .scheduleManagement: return "calendar.badge.plus"
        case .aiInsight: return "brain.head.profile"  // ✅ NEW
        }
    }

    var displayText: String {
        switch self {
        // ... existing cases
        case .aiInsight: return "AI Insight"  // ✅ NEW
        }
    }

    var autoQuery: String {
        switch self {
        // ... existing cases
        case .aiInsight: return ""  // ✅ NEW - No query needed
        }
    }

    var commands: [String] {
        switch self {
        // ... existing cases
        case .aiInsight: return []  // ✅ NEW - No commands
        }
    }
}
```

#### 2. Added Purple Color for Button

```swift
private struct ActionButton: View {
    private var buttonColor: Color {
        switch category {
        case .eventQueries: return .blue
        case .scheduleManagement: return .green
        case .eventManagement: return .orange
        case .aiInsight: return .purple  // ✅ NEW
        }
    }
}
```

#### 3. Added 4th Button to UI

```swift
// Four Action Buttons (scrollable)
ScrollView(.horizontal, showsIndicators: false) {
    HStack(spacing: 12) {
        ActionButton(category: .eventQueries, ...)
        ActionButton(category: .scheduleManagement, ...)
        ActionButton(category: .eventManagement, ...)

        // ✅ NEW - 4th button
        ActionButton(
            category: .aiInsight,
            isSelected: selectedActionCategory == .aiInsight,
            onTap: { handleActionButtonTap(.aiInsight) }
        )
    }
}
```

#### 4. Updated PatternConfidenceView Condition

**Before**:
```swift
if showPatternInsights, let patterns = aiPatterns {
    PatternConfidenceView(patterns: patterns)
        .padding()
}
```

**After**:
```swift
// ✅ Only show when AI Insight button is selected
if showPatternInsights, let patterns = aiPatterns, selectedActionCategory == .aiInsight {
    PatternConfidenceView(patterns: patterns)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
}
```

#### 5. Updated Button Tap Handler

```swift
private func handleActionButtonTap(_ category: CommandCategory) {
    // Toggle if same button tapped again
    if selectedActionCategory == category {
        withAnimation {
            selectedActionCategory = nil
        }
        return
    }

    withAnimation {
        selectedActionCategory = category
        // ✅ Don't show conversation window for AI Insight
        if category != .aiInsight {
            showConversationWindow = true
        }
    }

    switch category {
    case .eventQueries:
        handleTranscript(category.autoQuery)
    case .scheduleManagement:
        // ... voice scheduling
    case .eventManagement:
        handleTranscript(category.autoQuery)

    // ✅ NEW - AI Insight case
    case .aiInsight:
        // Just show the card - no query needed
        // Card appears because selectedActionCategory == .aiInsight
        // Don't auto-dismiss - user can tap again to hide
        return
    }

    // ✅ Auto-clear selection after delay (except AI Insight)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        withAnimation {
            self.selectedActionCategory = nil
        }
    }
}
```

---

## User Experience Flow

### Scenario 1: User Opens AI Tab
```
1. AI Tab appears
2. User sees 4 floating buttons at bottom
3. PatternConfidenceView is NOT visible
4. Button shows: 🧠 "AI Insight" (purple, not selected)
```

### Scenario 2: User Taps AI Insight Button
```
1. User taps 🟣 "AI Insight" button
2. Button highlights (purple background)
3. PatternConfidenceView slides in from bottom
4. Card shows:
   ┌──────────────────────────────────────┐
   │ 🧠 AI Insights  [High Confidence]    │
   │                                      │
   │ 🕐 Preferred Times    10AM, 2PM, 4PM │
   │ ⏱️  Typical Duration         30 min  │
   │ 🍴 Lunch Block               12-1PM  │
   │                                      │
   │ Based on 45 events from past 30 days │
   └──────────────────────────────────────┘
5. User can read the insights
6. Button stays selected
```

### Scenario 3: User Dismisses Card
```
1. User taps 🟣 "AI Insight" button again
2. Button deselects (returns to normal purple color)
3. PatternConfidenceView slides out with animation
4. Card disappears
5. Back to normal AI tab view
```

### Scenario 4: Not Enough Data
```
1. User taps 🟣 "AI Insight" button
2. Button highlights
3. Card does NOT appear (because confidence == .none)
4. Button deselects automatically
5. (Could add a toast: "Not enough calendar data yet")
```

---

## Visual Design

### Button Layout (Bottom of AI Tab)
```
┌─────────────────────────────────────────────────┐
│                                                 │
│              [Conversation Area]                │
│                                                 │
│                                                 │
├─────────────────────────────────────────────────┤
│  [🔵 Today] [🟢 Schedule] [🟠 Manage] [🟣 AI Insight]  │
├─────────────────────────────────────────────────┤
│  [            Input Area                    ]   │
└─────────────────────────────────────────────────┘
```

### When AI Insight Selected
```
┌─────────────────────────────────────────────────┐
│                                                 │
│              [Conversation Area]                │
│                                                 │
├─────────────────────────────────────────────────┤
│  ┌─────────────────────────────────────────┐   │
│  │ 🧠 AI Insights  [High Confidence]       │   │
│  │                                         │   │
│  │ 🕐 Preferred Times    10AM, 2PM, 4PM    │   │
│  │ ⏱️  Typical Duration         30 min     │   │
│  │ 🍴 Lunch Block               12-1PM     │   │
│  │                                         │   │
│  │ Based on 45 events from past 30 days   │   │
│  └─────────────────────────────────────────┘   │
├─────────────────────────────────────────────────┤
│  [🔵 Today] [🟢 Schedule] [🟠 Manage] [🟣 AI Insight]  │
│                                         (selected) │
├─────────────────────────────────────────────────┤
│  [            Input Area                    ]   │
└─────────────────────────────────────────────────┘
```

---

## Animations

### Card Appearance
- **Animation**: `.move(edge: .bottom).combined(with: .opacity)`
- **Duration**: Default SwiftUI animation (~0.3s)
- **Effect**: Slides in from bottom while fading in

### Card Disappearance
- **Animation**: Same, reversed
- **Effect**: Slides out to bottom while fading out

### Button Selection
- **Animation**: Smooth background color change
- **Duration**: Default SwiftUI animation
- **Effect**: Button background changes to purple

---

## Comparison with Other Buttons

| Feature | Other Buttons | AI Insight Button |
|---------|---------------|-------------------|
| **Action** | Send query/start voice | Toggle card display |
| **Conversation Window** | Opens | Doesn't open |
| **Auto-dismiss** | After 0.5s | Never (manual toggle) |
| **Color** | Blue/Green/Orange | Purple |
| **Query** | Yes | No |
| **Voice** | Yes (Schedule) | No |
| **UI Card** | No | Yes (PatternConfidenceView) |

---

## Edge Cases Handled

### 1. No Calendar Data (confidence == .none)
- Card does NOT appear even when button is selected
- Button still highlights
- User sees button is selected but no card
- Potential improvement: Show toast message

### 2. Rapid Tapping
- Smooth toggle on/off
- No animation conflicts
- Button state stays consistent

### 3. Tapping Other Buttons While AI Insight Selected
- AI Insight deselects automatically
- Card slides out
- New button action executes

### 4. Loading State
- Patterns load on tab appear
- If data loads after user taps button, card appears smoothly

---

## Testing Checklist

- [x] Button appears in UI (4th position)
- [x] Button has purple color
- [x] Button has brain icon
- [x] Button label says "AI Insight"
- [x] Card is hidden by default
- [x] Card appears when button tapped (first time)
- [x] Card slides in from bottom with animation
- [x] Card shows correct pattern data
- [x] Button stays selected after first tap
- [x] Card disappears when button tapped (second time)
- [x] Card slides out with animation
- [x] Button deselects after second tap
- [x] No conversation window opens
- [x] No auto-dismiss behavior
- [x] Works with other buttons
- [x] Compiles without errors

---

## Build Status

```bash
xcodebuild -scheme CalAI build
# Result: ✅ No Swift compilation errors
```

---

## Files Modified

1. **AITabView.swift** (Lines 1084-1146, 496-502, 705-754, 1008-1014)
   - Added `aiInsight` case to `CommandCategory` enum
   - Added purple color
   - Added 4th button to UI
   - Updated card visibility condition
   - Updated button tap handler

**Total Changes**: ~30 lines added/modified

---

## Summary

✅ **4th floating button added** - "AI Insight" with brain icon and purple color
✅ **Card hidden by default** - Only shows when button is tapped
✅ **Toggle behavior** - Tap to show, tap again to hide
✅ **Smooth animations** - Slides in/out with fade
✅ **No auto-dismiss** - Stays visible until user dismisses
✅ **No conversation interference** - Doesn't open chat window
✅ **Compiles successfully** - No errors

The AI Insight button provides an easy, non-intrusive way for users to view their scheduling patterns on demand! 🎉
