# Floating Action Buttons - Behavior Breakdown

## Overview

The AI Tab has **4 floating action buttons** at the bottom. Here's what each one does when clicked:

```
[🔵 Today/What's Next/Tomorrow] [🟢 Schedule] [🟠 Manage] [🟣 AI Insight]
```

---

## 1. 🔵 Queries Button (Blue)

### Display Text (Time-Aware)
- **Before 10 AM**: "Today"
- **10 AM - 6 PM**: "What's Next"
- **After 6 PM**: "Tomorrow"

### When Clicked
1. **Button highlights** (blue background)
2. **Conversation window opens**
3. **Sends automatic query** to AI:
   - Before 10 AM: "What's my schedule today?"
   - 10 AM - 6 PM: "What's next?"
   - After 6 PM: "What's tomorrow?"
4. **AI processes and responds** in conversation window
5. **Auto-dismisses after 0.5s** (button deselects)

### User Experience
```
User taps [🔵 Today]
↓
Conversation window opens
↓
AI responds: "You have 3 events today:
- 9:00 AM Team Standup
- 2:00 PM Client Call
- 5:00 PM Code Review"
↓
Button auto-deselects after 0.5s
```

### Purpose
**Quick schedule queries** - Get instant overview of what's coming up based on time of day.

---

## 2. 🟢 Schedule Button (Green)

### Display Text
- Always: "Schedule"

### When Clicked
1. **Button highlights** (green background)
2. **Conversation window opens**
3. **AI speaks**: "What would you like to schedule?"
4. **Activates continuous voice listening** (auto-loop mode)
5. **Waits for user to speak**
6. User says something like "Meeting with Sarah tomorrow at 2 PM"
7. **AI processes voice command** and schedules event
8. **Auto-dismisses after 0.5s** (button deselects)

### User Experience
```
User taps [🟢 Schedule]
↓
AI speaks: "What would you like to schedule?"
↓
Voice listening starts automatically
↓
User speaks: "Team meeting tomorrow at 10 AM"
↓
AI responds: "Scheduled Team Meeting for tomorrow at 10 AM"
↓
Event created
↓
Button auto-deselects after 0.5s
```

### Purpose
**Voice-first scheduling** - Quick way to add events using voice without typing or opening the full add event form.

---

## 3. 🟠 Manage Button (Orange)

### Display Text
- Always: "Manage"

### When Clicked
1. **Button highlights** (orange background)
2. **Conversation window opens**
3. **Sends automatic query** to AI: "What needs my attention?"
4. **AI analyzes calendar and responds** with items needing attention:
   - Conflicts
   - Events without locations
   - Back-to-back meetings
   - Missing attendees
   - Overbooked days
5. **Auto-dismisses after 0.5s** (button deselects)

### User Experience
```
User taps [🟠 Manage]
↓
Conversation window opens
↓
AI responds: "You have 2 items needing attention:
⚠️ Tuesday: 3 back-to-back meetings
⚠️ 'Client Call' tomorrow has no location"
↓
Button auto-deselects after 0.5s
```

### Purpose
**Attention dashboard** - Proactively surface calendar issues that need fixing.

---

## 4. 🟣 AI Insight Button (Purple) ✨ NEW

### Display Text
- Always: "AI Insight"

### When Clicked (First Time)
1. **Button highlights** (purple background)
2. **No conversation window opens**
3. **PatternConfidenceView card slides in** from bottom
4. **Card displays**:
   ```
   🧠 AI Insights [High Confidence]

   🕐 Preferred Times    10AM, 2PM, 4PM
   ⏱️  Typical Duration         30 min
   🍴 Lunch Block               12-1PM

   Based on 45 events from past 30 days
   ```
5. **Button stays selected** (NO auto-dismiss)

### When Clicked (Second Time)
1. **Button deselects** (returns to normal purple)
2. **Card slides out** to bottom
3. **Card disappears**

### User Experience
```
User taps [🟣 AI Insight]
↓
Card slides in from bottom
↓
User reads their scheduling patterns
↓
User taps [🟣 AI Insight] again when done
↓
Card slides out
```

### Purpose
**Pattern insights viewer** - Shows what the AI has learned about user's scheduling habits. Non-intrusive, on-demand information display.

---

## Comparison Table

| Feature | 🔵 Queries | 🟢 Schedule | 🟠 Manage | 🟣 AI Insight |
|---------|-----------|------------|----------|--------------|
| **Opens Chat** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **Sends Query** | ✅ Yes | ✅ Yes | ✅ Yes | ❌ No |
| **Voice Activation** | ❌ No | ✅ Yes | ❌ No | ❌ No |
| **Shows UI Card** | ❌ No | ❌ No | ❌ No | ✅ Yes |
| **Auto-Dismiss** | ✅ 0.5s | ✅ 0.5s | ✅ 0.5s | ❌ Manual toggle |
| **Query Text** | Time-aware | "What would you like to schedule?" | "What needs my attention?" | None |
| **AI Response** | Schedule info | Event creation | Attention items | None (shows card) |

---

## Detailed Flow Diagrams

### 🔵 Queries Button Flow
```
TAP
  ↓
Button Selects (blue bg)
  ↓
Conversation Window Opens
  ↓
handleTranscript("What's next?")
  ↓
AI Processes Query
  ↓
AI Responds in Chat
  ↓
Wait 0.5s
  ↓
Button Auto-Deselects
  ↓
END
```

### 🟢 Schedule Button Flow
```
TAP
  ↓
Button Selects (green bg)
  ↓
Conversation Window Opens
  ↓
AI Speaks: "What would you like to schedule?"
  ↓
Wait 0.3s
  ↓
Start Auto-Loop Voice Listening
  ↓
User Speaks
  ↓
Voice → Text Transcript
  ↓
handleTranscript(userSpeech)
  ↓
AI Processes & Creates Event
  ↓
AI Responds with Confirmation
  ↓
Wait 0.5s
  ↓
Button Auto-Deselects
  ↓
END
```

### 🟠 Manage Button Flow
```
TAP
  ↓
Button Selects (orange bg)
  ↓
Conversation Window Opens
  ↓
handleTranscript("What needs my attention?")
  ↓
AI Analyzes Calendar
  ↓
AI Lists Attention Items
  ↓
Wait 0.5s
  ↓
Button Auto-Deselects
  ↓
END
```

### 🟣 AI Insight Button Flow
```
TAP (First Time)
  ↓
Button Selects (purple bg)
  ↓
selectedActionCategory = .aiInsight
  ↓
PatternConfidenceView Appears
  ↓
Card Slides In (animation)
  ↓
User Reads Insights
  ↓
Button STAYS Selected
  ↓
(User must tap again to dismiss)

TAP (Second Time)
  ↓
Button Deselects
  ↓
selectedActionCategory = nil
  ↓
PatternConfidenceView Hides
  ↓
Card Slides Out (animation)
  ↓
END
```

---

## Code Logic

### handleActionButtonTap() Function

```swift
private func handleActionButtonTap(_ category: CommandCategory) {
    // TOGGLE: If same button tapped again, deselect
    if selectedActionCategory == category {
        withAnimation {
            selectedActionCategory = nil  // Deselect
        }
        return
    }

    // SELECT: New button tapped
    withAnimation {
        selectedActionCategory = category

        // Only show conversation window for non-AI Insight
        if category != .aiInsight {
            showConversationWindow = true
        }
    }

    switch category {
    case .eventQueries:
        // Send automatic query
        handleTranscript("What's next?")  // Time-aware query

    case .scheduleManagement:
        // Speak prompt, then start voice listening
        SpeechManager.shared.speak(text: "What would you like to schedule?") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isInAutoLoopMode = true
                self.startListeningWithAutoLoop()
            }
        }

    case .eventManagement:
        // Send automatic attention query
        handleTranscript("What needs my attention?")

    case .aiInsight:
        // Just show the card - no query or conversation
        // Card appears because: selectedActionCategory == .aiInsight
        return  // Don't auto-dismiss
    }

    // AUTO-DISMISS (except AI Insight)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
        withAnimation {
            self.selectedActionCategory = nil
        }
    }
}
```

---

## Card Visibility Logic

### PatternConfidenceView Display Condition

```swift
// AI Pattern Insights Card (only shown when AI Insight button is tapped)
if showPatternInsights,
   let patterns = aiPatterns,
   selectedActionCategory == .aiInsight {  // ← Key condition
    PatternConfidenceView(patterns: patterns)
        .padding(.horizontal, 20)
        .padding(.bottom, 16)
        .transition(.move(edge: .bottom).combined(with: .opacity))
}
```

**Breakdown**:
- `showPatternInsights` → true if patterns were loaded successfully
- `let patterns = aiPatterns` → unwrap the patterns data
- `selectedActionCategory == .aiInsight` → **ONLY show when button is selected**

---

## User Scenarios

### Scenario 1: Morning Check-In
```
8:30 AM - User opens AI Tab
↓
Taps [🔵 Today]
↓
Sees: "You have 4 meetings today: 9 AM Standup, 11 AM Planning..."
```

### Scenario 2: Quick Voice Scheduling
```
User needs to add meeting quickly
↓
Taps [🟢 Schedule]
↓
AI asks: "What would you like to schedule?"
↓
User says: "Coffee with John tomorrow at 3 PM"
↓
AI confirms: "Scheduled Coffee with John for tomorrow at 3 PM"
```

### Scenario 3: Calendar Health Check
```
User wants to see if there are issues
↓
Taps [🟠 Manage]
↓
AI shows: "2 items need attention: Tuesday has 3 back-to-back meetings..."
```

### Scenario 4: Understanding AI Patterns
```
User wonders what AI knows about their schedule
↓
Taps [🟣 AI Insight]
↓
Sees card: "Preferred Times: 10AM, 2PM, 4PM..."
↓
Reads insights
↓
Taps [🟣 AI Insight] again to close
```

---

## Design Philosophy

### Buttons 1-3 (Blue, Green, Orange)
**Philosophy**: **Active Actions** - They trigger AI processing
- Open conversation
- Send queries/commands
- Get AI responses
- Auto-dismiss (fire and forget)

### Button 4 (Purple)
**Philosophy**: **Passive Display** - Shows information without AI interaction
- No conversation
- No query processing
- Just displays existing data
- Manual toggle (user controls visibility)

---

## Why AI Insight is Different

| Aspect | Buttons 1-3 | AI Insight |
|--------|-------------|------------|
| **Purpose** | Do something (query, schedule, manage) | See something (view insights) |
| **Interaction** | AI processes request | No AI processing |
| **Output** | Conversation response | UI card |
| **Duration** | Quick (0.5s auto-dismiss) | User-controlled |
| **Use Case** | "I need AI to help me with X" | "I want to see what AI knows" |

---

## Summary

### 🔵 Queries (Blue)
**One-Liner**: Get instant schedule overview based on time of day
**Type**: Query → Response
**Duration**: Auto-dismiss

### 🟢 Schedule (Green)
**One-Liner**: Voice-first event creation with AI assistance
**Type**: Voice Command → Action
**Duration**: Auto-dismiss

### 🟠 Manage (Orange)
**One-Liner**: Proactive attention dashboard for calendar health
**Type**: Query → Analysis
**Duration**: Auto-dismiss

### 🟣 AI Insight (Purple)
**One-Liner**: View learned scheduling patterns on-demand
**Type**: Display → Information
**Duration**: Manual toggle

---

## Future Enhancement Ideas

### Potential Improvements

**🔵 Queries**:
- Add option to see next week
- Show events as cards (not just text)
- Add quick action buttons per event

**🟢 Schedule**:
- Show suggested times based on patterns
- One-tap templates ("Lunch with...", "Meeting with...")
- Voice shortcuts ("Schedule lunch")

**🟠 Manage**:
- Show severity levels (critical, warning, info)
- One-tap fixes ("Add location", "Resolve conflict")
- Smart suggestions ("Combine these meetings?")

**🟣 AI Insight**:
- Add "Why?" explanations for each pattern
- Show pattern changes over time (graphs)
- Compare to previous weeks/months
- Export insights as report

---

All buttons work together to provide a complete AI-assisted calendar experience! 🎉
