# Intent Classifier Implementation Guide

## Overview

The `IntentClassifier` uses Apple's Intents framework patterns to intelligently distinguish between **tasks** and **events** in voice commands. This approach mirrors how Siri differentiates between `INCreateTaskIntent` (reminders/todos) and `INAddCalendarEventIntent` (calendar events).

## Architecture

### Classification Flow

```
User Voice Input
      ↓
VoiceManager (Speech Recognition)
      ↓
AIManager (Enhanced Conversational AI)
      ↓
IntentClassifier.classify()
      ↓
Intent Correction (if needed)
      ↓
Execute Action (create_task or create_event)
```

### Intent Types

1. **Task** - INCreateTaskIntent-like patterns
   - Personal action items
   - No specific time or attendees
   - Examples: "I need to buy groceries", "remind me to call mom"

2. **Event** - INAddCalendarEventIntent-like patterns
   - Social or professional gatherings
   - Has specific time and/or attendees
   - Examples: "schedule lunch with John at 2pm", "meeting tomorrow at 3"

3. **Query** - Information requests
   - Examples: "what's on my schedule", "show me today's events"

4. **Update** - Modification requests
   - Examples: "move my 3pm meeting to 4pm", "change lunch to dinner"

5. **Delete** - Cancellation requests
   - Examples: "cancel my dentist appointment", "delete the team meeting"

## Classification Logic

### Task Scoring (Siri INCreateTaskIntent Patterns)

#### Strong Task Indicators (0.6-0.9 confidence)
```swift
"remind me to" → 0.9    // Explicit reminder
"i need to" → 0.8       // Personal obligation
"i have to" → 0.8       // Required action
"i should" → 0.7        // Suggested action
"i want to" → 0.6       // Desired action
"todo" → 0.9            // Explicit task list
"add task" → 0.9        // Explicit task creation
```

#### Task Verbs (0.6 confidence)
- **Shopping**: "buy", "get", "pick up", "grab", "purchase"
- **Communication**: "call", "email", "text", "message"
- **Work**: "finish", "complete", "submit", "send"
- **Personal**: "read", "review", "check", "clean", "organize"

#### Bonus Modifiers
- **No specific time**: +0.2
- **No attendees mentioned**: +0.1
- **Multiple tasks** (, and / then): sets to 0.7 minimum

### Event Scoring (Siri INAddCalendarEventIntent Patterns)

#### Strong Event Indicators (0.6-0.9 confidence)
```swift
"schedule" → 0.9           // Explicit calendar action
"meeting" → 0.9            // Social/work gathering
"book" → 0.8               // Reservation
"appointment" → 0.8        // Scheduled meeting
"arrange" → 0.7            // Planning
"add to calendar" → 0.9    // Explicit calendar
```

#### Event Types (0.8 confidence)
- **Meals**: "lunch", "dinner", "breakfast", "coffee"
- **Meetings**: "meeting", "call", "standup", "review", "interview"
- **Social**: "party", "hangout", "class", "session"

#### Bonus Modifiers
- **Has specific time** (at 2pm, 14:00): +0.2
- **Has specific date** (tomorrow, Monday): +0.1
- **Has attendees** (with John): +0.3
- **Has location** (at Starbucks): +0.2

## Test Phrases & Expected Classification

### Tasks (INCreateTaskIntent-like)

✅ **High Confidence Tasks (>0.8)**
```
"I need to buy groceries"
"Remind me to call the dentist"
"I have to finish the report"
"I should read that article"
"Add task to review pull requests"
"I need to pick up dry cleaning, buy milk, and call mom"
```

✅ **Medium Confidence Tasks (0.6-0.8)**
```
"Buy milk"
"Call John"
"Finish homework"
"Review the document"
"Clean the garage"
```

### Events (INAddCalendarEventIntent-like)

✅ **High Confidence Events (>0.8)**
```
"Schedule lunch with Sarah at noon tomorrow"
"Meeting with the team at 3pm"
"Book a dentist appointment for Monday at 2pm"
"Coffee with Mike at Starbucks at 4"
"Plan a standup tomorrow morning"
```

✅ **Medium Confidence Events (0.6-0.8)**
```
"Lunch tomorrow"
"Team meeting"
"Call with Sarah"
"Coffee break at 3"
"Dinner with family"
```

### Queries

✅ **Query Detection**
```
"What's on my schedule today?"
"Show me tomorrow's meetings"
"Do I have any calls this afternoon?"
"Tell me about my week"
"What tasks do I have?"
```

### Updates

✅ **Update Detection**
```
"Move my 3pm meeting to 4pm"
"Change lunch to dinner"
"Reschedule the dentist appointment"
"Update the team meeting time"
```

### Deletes

✅ **Delete Detection**
```
"Cancel my dentist appointment"
"Delete the team meeting"
"Remove lunch with John"
"Drop the 3pm call"
```

## Integration with AIManager

### How It Works

1. **Voice Input Received**
   ```swift
   VoiceManager captures: "I need to buy milk and call mom"
   ```

2. **Enhanced AI Processes**
   ```swift
   EnhancedConversationalAI returns:
   Intent: "query" (WRONG!)
   ```

3. **IntentClassifier Corrects**
   ```swift
   IntentClassifier.classify() → .task (confidence: 0.85)

   AIManager overrides:
   response.intent = "create_task"
   ```

4. **Task Creation Executes**
   ```swift
   executeEnhancedAction(type: "create_task")
   → Extracts multiple tasks
   → Creates 2 tasks: "buy milk", "call mom"
   ```

### Confidence Thresholds

- **>0.8**: High confidence - override AI classification
- **0.7-0.8**: Medium confidence - suggest correction
- **0.6-0.7**: Low-medium confidence - trust AI if agrees
- **<0.6**: Low confidence - trust AI classification

## Code Examples

### Using IntentClassifier Directly

```swift
let classifier = IntentClassifier()

// Classify a task
let result = classifier.classify("I need to buy groceries")
// result.type = .task
// result.confidence = 0.8
// result.details = "Task-related patterns detected"

// Classify an event
let result2 = classifier.classify("schedule lunch with John at 2pm")
// result2.type = .event
// result2.confidence = 0.95
// result2.details = "Event-related patterns detected"
```

### Integration in AIManager

```swift
// In processConversationalCommand()
let classification = intentClassifier.classify(transcript)
print("🎯 IntentClassifier: \(classification.type.description)")

switch classification.type {
case .task:
    if classification.confidence > 0.7 &&
       (response.intent == "query" || response.intent == "modify_schedule") {
        // Override AI's wrong classification
        response.intent = "create_task"
    }
case .event:
    if classification.confidence > 0.7 && response.intent == "create_task" {
        // Override to event
        response.intent = "create"
    }
// ... more cases
}
```

## Benefits Over Pattern Matching

### Before (Manual Pattern Matching)
```swift
// Brittle, hard to maintain
let hasTaskKeywords =
    lowercased.contains("i need to") ||
    lowercased.contains("i have to") ||
    lowercased.contains("i should ") ||
    // ... 10 more checks

let hasMultiTaskIndicators =
    lowercased.contains(", and ") ||
    lowercased.contains(" and ") ||
    // ... more checks
```

### After (IntentClassifier)
```swift
// Clean, extensible, confidence-based
let classification = intentClassifier.classify(transcript)
if classification.confidence > 0.7 {
    // Apply correction
}
```

### Advantages

1. **Siri-Inspired Patterns** - Leverages Apple's NLP knowledge
2. **Confidence Scoring** - Quantifies certainty of classification
3. **Extensible** - Easy to add new patterns
4. **Testable** - Clear input/output for unit tests
5. **Maintainable** - Centralized logic in one class
6. **Debug-Friendly** - Detailed logging of scoring

## Testing Strategy

### Unit Tests (Recommended)

```swift
func testTaskClassification() {
    let classifier = IntentClassifier()

    // Test task patterns
    XCTAssertEqual(
        classifier.classify("I need to buy milk").type,
        .task
    )

    // Test event patterns
    XCTAssertEqual(
        classifier.classify("schedule lunch with John at 2pm").type,
        .event
    )

    // Test confidence
    let result = classifier.classify("remind me to call mom")
    XCTAssertGreaterThan(result.confidence, 0.8)
}
```

### Manual Testing

Use the voice interface with test phrases from the sections above. Check console logs for:

```
🔍 IntentClassifier: Analyzing 'I need to buy milk'
  ✓ Task pattern 'i need to' matched (weight: 0.8)
  ✓ No specific time/date = +0.2 task score
📊 Task score: 0.8, Event score: 0.0
✅ Classified as TASK (score: 0.8)
```

## Future Enhancements

1. **Machine Learning** - Train on user patterns
2. **Context Awareness** - Consider previous commands
3. **Calendar Analysis** - Learn from existing events
4. **Custom Patterns** - User-defined keywords
5. **Multi-language** - Support non-English inputs

## Troubleshooting

### Issue: Misclassifying Tasks as Events

**Symptom**: "I need to buy milk" creates a calendar event

**Solution**: Check task keyword scoring
```swift
private func calculateTaskScore(_ text: String) -> Double {
    // Increase weight for strong task indicators
    "i need to": 0.9  // was 0.8
}
```

### Issue: Misclassifying Events as Tasks

**Symptom**: "Lunch with John at 2pm" creates a task

**Solution**: Check event scoring modifiers
```swift
// Ensure hasSpecificTime() is working
if hasSpecificTime(text) {
    score += 0.3  // Increase from 0.2
}
```

### Issue: Low Confidence Classifications

**Symptom**: Everything defaults to tasks (confidence < 0.6)

**Solution**: Review pattern matching regex and scoring weights

## Performance Metrics

- **Classification Time**: ~0.01s per input
- **Memory Usage**: Negligible (stateless class)
- **Accuracy Target**: >95% on test phrases
- **False Positive Rate**: <5%

## Conclusion

The `IntentClassifier` provides a robust, Siri-inspired approach to distinguishing tasks from events. By using confidence-based scoring and pattern matching, it significantly improves the accuracy of voice command classification while maintaining code quality and testability.
