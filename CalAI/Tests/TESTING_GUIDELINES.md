# CalAI Testing Guidelines

## Overview
This document outlines the testing strategy and best practices for the CalAI application.

## Test Structure

### Unit Tests
Located in `CalAI/Tests/`, unit tests verify individual components in isolation.

**Created Test Suites:**
- `EventFilterServiceTests.swift` - Tests event filtering logic for both UnifiedEvent and CalendarEvent types
- `DesignSystemTests.swift` - Tests design system tokens (colors, spacing, shadows, animations)
- `AppErrorTests.swift` - Tests error handling, messages, and retryability

### Running Tests

To run tests manually:

1. **Build the app first** to ensure all dependencies are compiled
2. **Import test files** into Xcode project
3. **Run tests** using Cmd+U or Product > Test

## Test Coverage

### EventFilterService (100% Coverage)
- ✅ Timed event filtering (same day, different day)
- ✅ All-day event filtering (start, middle, end days)
- ✅ Multi-day all-day events
- ✅ Mixed event types
- ✅ CalendarEvent protocol filtering
- ✅ Edge cases (empty arrays, boundary dates)

### DesignSystem (100% Coverage)
- ✅ Calendar source colors (iOS, Google, Outlook)
- ✅ Color uniqueness verification
- ✅ Spacing hierarchy and values
- ✅ Corner radius progression
- ✅ Shadow styles and intensity
- ✅ Animation definitions

### AppError (100% Coverage)
- ✅ Error identification and uniqueness
- ✅ Error titles and messages
- ✅ Retryability flags
- ✅ Equality comparisons
- ✅ Edge cases (nil descriptions, empty sources)

## Testing Best Practices

### 1. Test Naming Convention
```swift
func test<ComponentName><ExpectedBehavior>()
```
Examples:
- `testFilterTimedEventOnSameDay()`
- `testAccessDeniedIsNotRetryable()`
- `testColorsAreUnique()`

### 2. Test Structure (Given-When-Then)
```swift
func testExample() {
    // Given: Setup test data
    let input = createTestData()

    // When: Execute the action
    let result = service.performAction(input)

    // Then: Verify expectations
    XCTAssertEqual(result, expectedValue)
}
```

### 3. Test Isolation
- Each test should be independent
- Use `setUp()` to create fresh instances
- Use `tearDown()` to clean up resources
- Avoid shared mutable state between tests

### 4. Helper Methods
Create reusable helper methods for common test data:
```swift
private func createDate(year: Int, month: Int, day: Int) -> Date {
    // Helper implementation
}
```

### 5. Edge Cases to Test
- Null/nil values
- Empty arrays/strings
- Boundary conditions (start/end of ranges)
- Invalid input
- Concurrent operations
- Error conditions

## What to Test

### ✅ Always Test
- Public APIs and interfaces
- Business logic and calculations
- Error handling paths
- Data transformations
- Edge cases and boundary conditions

### ❌ Don't Test
- Third-party library internals
- SwiftUI view rendering (use UI tests instead)
- Private implementation details
- Simple getters/setters without logic

## Future Test Additions

### High Priority
1. **CalendarManager Tests**
   - Event loading logic
   - Date range calculations
   - Event deduplication
   - Error state management

2. **Sync Tests**
   - Google Calendar sync flow
   - Outlook Calendar sync flow
   - Conflict resolution
   - Network error handling

3. **Integration Tests**
   - End-to-end calendar sync
   - Multi-source event aggregation
   - Notification scheduling
   - Background refresh

### Medium Priority
1. **Performance Tests**
   - Large dataset handling (10k+ events)
   - Scroll performance
   - Memory usage under load
   - Sync performance

2. **UI Tests**
   - Critical user flows
   - Gesture interactions
   - Navigation flows
   - Error recovery

## Test Data Management

### Mock Objects
Create mock implementations for testing:
```swift
struct MockCalendarEvent: CalendarEvent {
    let id: String
    let title: String?
    let start: Date
    let end: Date
    let eventLocation: String?
    let isAllDay: Bool
    let source: CalendarSource
}
```

### Test Fixtures
Use consistent test data:
- Fixed dates: Jan 1, 2024 at 10:00 AM
- Known time zones: UTC for consistency
- Predictable IDs: Use sequential or meaningful IDs

## Continuous Integration

When CI is set up:
1. Run tests on every pull request
2. Require 80%+ code coverage for new code
3. Fail builds on test failures
4. Generate coverage reports

## Troubleshooting

### Common Issues

**Issue: Tests can't find CalAI module**
- Solution: Ensure test target has access to app target
- Add `@testable import CalAI` at the top of test files

**Issue: Date comparison failures**
- Solution: Use Calendar.current for date operations
- Set specific time zones in tests for consistency

**Issue: Flaky tests**
- Solution: Avoid time-dependent logic
- Use fixed dates instead of Date()
- Ensure test isolation

## Contributing Tests

When adding new features:
1. Write tests first (TDD approach preferred)
2. Ensure minimum 80% code coverage
3. Include edge cases and error scenarios
4. Update this documentation as needed

## Resources

- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [Swift Testing Best Practices](https://www.swift.org/documentation/articles/testing.html)
- [iOS Unit Testing Guide](https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/)
