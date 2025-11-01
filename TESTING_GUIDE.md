# Testing Guide for A, B, C Improvements

## Quick Start

```bash
# 1. Build and run the app
xcodebuild -scheme CalAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# 2. Run unit tests for Smart Scheduling
xcodebuild -scheme CalAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' test -only-testing:CalAITests/SmartSchedulingTests

# 3. Launch app and watch console
open -a Simulator
# Then run the app from Xcode and watch the console output
```

---

## A. Testing On-Device Apple LLM Priority 🍎

### What to Look For

**In Xcode Console:**
- ✅ `✅ Enhanced AI initialized with Apple Intelligence (on-device)`
- ✅ `🍎 Using on-device Apple Intelligence`
- OR (on Simulator/older iOS):
- ✅ `☁️ Using cloud AI fallback`

### Manual Test Steps

1. **Run the app in Xcode** (⌘R)
2. **Open Console** (⌘⇧Y to show debug area)
3. **Interact with AI** (voice or text)
4. **Watch for initialization messages**

### Expected Results

| Scenario | Expected Log |
|----------|--------------|
| iOS 26+ with Apple Intelligence | `🍎 Using on-device Apple Intelligence` |
| iOS 26+ without Apple Intelligence | `⚠️ Failed to initialize` → `☁️ Using cloud AI fallback` |
| iOS < 26 | `☁️ Using cloud AI (FoundationModels not available)` |
| Simulator (most cases) | `☁️ Using cloud AI fallback` |

### How to Verify It's Working

```bash
# Filter console logs for AI initialization
xcodebuild -scheme CalAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' run 2>&1 | grep -E "(Enhanced AI|Apple Intelligence|cloud AI)"
```

---

## B. Testing Context-Aware Follow-Ups 💬

### Test Conversation Script

Run the app and have this conversation:

```
1️⃣ You: "What's my next meeting?"
   AI: "Your next meeting is Team Standup at 10 AM tomorrow"

   👀 WATCH CONSOLE FOR:
   📌 Tracking event reference: [some-event-id]

2️⃣ You: "Move that to 2 PM"
   AI: "I'll move Team Standup to 2 PM"

   👀 WATCH CONSOLE FOR:
   PRONOUN RESOLUTION:
   - When user says 'that event', 'it', 'this', they likely mean event ID:[id]

3️⃣ You: "Change it to Conference Room B"
   AI: "I'll update the location to Conference Room B"

   👀 WATCH CONSOLE FOR:
   RECENTLY DISCUSSED EVENTS:
   - ID:[id] 'Team Standup' at [time] [MOST RECENT]
```

### What to Check in Console

**Successful Context Tracking:**
```
💬 Enhanced AI processing: Move that to 2 PM
📚 Conversation history: 1 turns

CONVERSATION HISTORY:
[1] User: What's my next meeting?
[1] Assistant: Your next meeting is Team Standup...

RECENTLY DISCUSSED EVENTS:
- ID:ABC123 'Team Standup' at 10/26, 10:00 AM [MOST RECENT]

PRONOUN RESOLUTION:
- When user says 'that event', 'it', 'this', they likely mean event ID:ABC123
- Last action was: query
```

### Test Checklist

- [ ] AI understands "that" without repeating event name
- [ ] AI understands "it" in follow-up messages
- [ ] Console shows `📌 Tracking event reference: [id]`
- [ ] Console shows `CONVERSATION HISTORY:` with last 3 turns
- [ ] Console shows `PRONOUN RESOLUTION:` guidance
- [ ] Console shows `RECENTLY DISCUSSED EVENTS:` with `[MOST RECENT]` marker

---

## C. Testing Smart Scheduling Suggestions 🧠

### Prerequisites

**Add some test events to your calendar:**
- At least 5-10 events in the past 30 days
- Some recurring patterns (e.g., meetings at 10 AM daily)
- A few lunch blocks (12-1 PM)

### Test 1: Pattern Recognition

**Run the app and trigger any AI interaction**, then check console:

```
SCHEDULING PATTERNS:
- Preferred meeting times: 10AM, 2PM, 4PM
- Typical meeting duration: 30 minutes
- Lunch typically: 12PM-1PM
```

✅ **Success:** You see your actual calendar patterns reflected

### Test 2: Smart Time Suggestions

**Say:** "Schedule a 30-minute meeting with Sarah"

**Expected AI Response:**
```
I suggest Tuesday at 10 AM because:
• Matches your typical meeting time
• Good buffer before your 11:30 call
• Tuesday is typically a lighter day for you

Alternatives: Tuesday 2PM, Wednesday 10AM
```

**Console should show:**
```
🧠 Smart scheduling analyzing...
✅ Found optimal time with confidence: 0.85
   Reasons: Matches preferred hours, Good buffer time, Lighter day
```

### Test 3: Conflict Warnings

**Say:** "Schedule a meeting at 12:30 PM tomorrow" (during lunch)

**Expected Warning:**
```
⚠️ Note: During typical lunch hours
```

**Say:** "Schedule 6 meetings tomorrow"

**Expected Warning:**
```
⚠️ This would be meeting #7 on this day
```

### Test 4: Unit Tests

**Run the automated tests:**

```bash
xcodebuild -scheme CalAI \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test \
  -only-testing:CalAITests/SmartSchedulingTests
```

**Expected output:**
```
✅ testPatternAnalysis - PASSED
✅ testOptimalTimeSuggestion - PASSED
✅ testConflictDetection - PASSED
```

---

## Complete Integration Test

### Full Workflow Test

1. **Start fresh** (clear conversation history if needed)

2. **Ask:** "What meetings do I have tomorrow?"
   - ✅ Check: Uses on-device AI (if available)
   - ✅ Check: Shows scheduling patterns in console

3. **Ask:** "Move the first one to 2 PM"
   - ✅ Check: Understands "the first one" via context
   - ✅ Check: Tracks event reference

4. **Ask:** "Find me a good time for a team meeting"
   - ✅ Check: Suggests time based on patterns
   - ✅ Check: Provides reasons for suggestion
   - ✅ Check: Offers alternatives

5. **Ask:** "Make it 30 minutes earlier"
   - ✅ Check: Understands "it" refers to suggested meeting
   - ✅ Check: Conversation history includes previous turns

### Success Criteria

All features working together:

- [x] On-device AI processing (or fallback with explanation)
- [x] Pronoun resolution working
- [x] Conversation memory active (3 turns)
- [x] Scheduling patterns detected
- [x] Smart time suggestions with reasons
- [x] Conflict warnings when appropriate

---

## Troubleshooting

### "Cannot find SmartSchedulingService"
**Fix:** Build was likely cached. Clean build:
```bash
xcodebuild -scheme CalAI clean
xcodebuild -scheme CalAI build
```

### "Apple Intelligence not working"
**Expected on:**
- Simulator (most cases)
- iOS < 26
- Device without Apple Intelligence enabled

**Check Settings > Apple Intelligence & Siri**

### "No scheduling patterns shown"
**Cause:** Not enough calendar history
**Fix:** Add some test events to your calendar (past 30 days)

### "Context not working"
**Check:**
1. Are you seeing `📌 Tracking event reference:` in console?
2. Is `referencedEventIds` array being populated?
3. Try with a fresh conversation (clear history)

---

## Debug Commands

```bash
# Watch all AI-related logs
xcodebuild -scheme CalAI run 2>&1 | grep -E "(💬|🍎|☁️|📌|🧠)"

# Watch just context tracking
xcodebuild -scheme CalAI run 2>&1 | grep -E "(PRONOUN|HISTORY|REFERENCED)"

# Watch scheduling patterns
xcodebuild -scheme CalAI run 2>&1 | grep -E "(SCHEDULING PATTERNS|Preferred|Typical)"

# Watch all Enhanced AI logs
xcodebuild -scheme CalAI run 2>&1 | grep "Enhanced AI"
```

---

## Quick Visual Test

**Best way to see everything working:**

1. Open **Xcode**
2. Run app on **Simulator** (⌘R)
3. Open **Console** (⌘⇧Y)
4. Click **"All Output"** filter
5. Have a conversation with the AI
6. Watch the console logs flow!

You should see:
```
✅ Enhanced AI initialized...
💬 Enhanced AI processing: [message]
📚 Conversation history: X turns
SCHEDULING PATTERNS: ...
PRONOUN RESOLUTION: ...
🍎 Using on-device Apple Intelligence (or ☁️ fallback)
📌 Tracking event reference: [id]
✅ Enhanced AI completed: [intent]
```

**If you see all of these → Everything is working! 🎉**
