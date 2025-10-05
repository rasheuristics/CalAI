# Phase 5 Testing Guide: Test Coverage to 70%

## Overview
Phase 5 adds comprehensive unit tests to increase code coverage to 70% and ensure app stability.

## Test Files Created
- ✅ `Tests/EventFilterServiceTests.swift` - Existing (11 tests)
- ✅ `Tests/DesignSystemTests.swift` - Existing (10 tests)
- ✅ `Tests/AppErrorTests.swift` - Existing (17 tests)
- ✅ `Tests/MeetingAnalyzerTests.swift` - NEW (15 tests)
- ✅ `Tests/NotificationPreferencesTests.swift` - NEW (13 tests)
- ✅ `Tests/CrashReporterTests.swift` - NEW (30 tests)

**Total Tests:** 96 tests

---

## Running Tests

### Run All Tests
```bash
# In Xcode
Cmd + U

# Or specific test target
xcodebuild test -scheme CalAI -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### Run Specific Test File
```bash
# In Xcode
1. Open test file
2. Click diamond icon next to class name
3. Or Cmd + U with file selected
```

### Run Single Test
```bash
# Click diamond icon next to test function
# Or
Cmd + Ctrl + Option + U
```

---

## Test Coverage Checklist

### Services Tested

- [x] **EventFilterService** (11 tests)
  - UnifiedEvent filtering
  - CalendarEvent filtering
  - Timed vs all-day events
  - Multiple event types
  - Date range filtering

- [x] **DesignSystem** (10 tests)
  - Color schemes
  - Spacing hierarchy
  - Corner radius values
  - Shadow styles
  - Animation definitions

- [x] **MeetingAnalyzer** (15 tests)
  - Virtual meeting detection (Zoom, Teams, Meet)
  - Physical meeting detection
  - Hybrid meeting detection
  - Platform identification
  - Travel time requirements
  - Edge cases

- [x] **CrashReporter** (30 tests)
  - Error logging
  - Warning logging
  - Breadcrumb tracking
  - User context setting
  - Convenience methods (API, Database, Sync, AI errors)
  - Global functions
  - Severity levels
  - Device info collection
  - Bundle extensions
  - Analytics events
  - Thread safety
  - Integration flows

### Models Tested

- [x] **AppError** (17 tests)
  - Error identifiers
  - Error titles
  - Error messages
  - Retryability
  - Equality
  - Edge cases

- [x] **NotificationPreferences** (13 tests)
  - Default values
  - UserDefaults persistence
  - Loading/saving
  - Validation
  - Toggle functionality
  - Codable support
  - Edge cases

---

## Test Execution Guide

### Test 1: Run All Tests
**Purpose:** Verify all tests pass

**Steps:**
1. Open CalAI.xcodeproj in Xcode
2. Select CalAI scheme
3. Select iOS Simulator (iPhone 15 Pro)
4. Press Cmd + U

**Expected Result:**
- ✅ All 96 tests pass
- ✅ No failures or errors
- ✅ Test execution completes in < 30 seconds

---

### Test 2: Check Test Coverage
**Purpose:** Verify 70% coverage target met

**Steps:**
1. In Xcode, go to Product → Scheme → Edit Scheme
2. Select Test tab
3. Check "Gather coverage for: CalAI"
4. Run tests (Cmd + U)
5. Open Report Navigator (Cmd + 9)
6. Select latest test run
7. Click Coverage tab

**Expected Result:**
- ✅ Overall coverage ≥ 70%
- ✅ Core services have high coverage:
  - EventFilterService: ≥ 80%
  - MeetingAnalyzer: ≥ 80%
  - CrashReporter: ≥ 75%
  - AppError: ≥ 90%
  - NotificationPreferences: ≥ 85%

**How to Increase Coverage:**
- Identify uncovered files in Coverage tab
- Add tests for uncovered functions
- Focus on critical business logic first

---

### Test 3: Individual Test File Validation
**Purpose:** Verify each test file works independently

**Tests to run:**
1. EventFilterServiceTests
   - Run all tests in file
   - Verify 11 tests pass

2. DesignSystemTests
   - Run all tests in file
   - Verify 10 tests pass

3. AppErrorTests
   - Run all tests in file
   - Verify 17 tests pass

4. MeetingAnalyzerTests
   - Run all tests in file
   - Verify 15 tests pass

5. NotificationPreferencesTests
   - Run all tests in file
   - Verify 13 tests pass

6. CrashReporterTests
   - Run all tests in file
   - Verify 30 tests pass

**Expected Result:**
- ✅ All test files pass independently
- ✅ No flaky tests (intermittent failures)
- ✅ Fast execution (< 5 seconds per file)

---

### Test 4: Thread Safety Tests
**Purpose:** Verify concurrent operations don't cause crashes

**Specific Tests:**
- `CrashReporterTests.testConcurrentLogging`

**Steps:**
1. Run test 10 times
2. Verify no failures
3. Check for race conditions

**Expected Result:**
- ✅ Test passes consistently
- ✅ No threading errors
- ✅ No crashes or hangs

---

### Test 5: Integration Test Validation
**Purpose:** Verify end-to-end flows work correctly

**Specific Tests:**
- `CrashReporterTests.testFullErrorReportingFlow`
- `CrashReporterTests.testMultipleErrorsInSequence`

**Expected Result:**
- ✅ Full flows complete without errors
- ✅ All components work together
- ✅ State is properly managed

---

### Test 6: Edge Case Handling
**Purpose:** Verify app handles edge cases gracefully

**Test Categories:**
- Empty/nil inputs
- Invalid data
- Boundary values
- Concurrent access
- Missing permissions

**Expected Result:**
- ✅ No crashes on edge cases
- ✅ Graceful error handling
- ✅ Appropriate default values

---

### Test 7: UserDefaults Persistence Tests
**Purpose:** Verify data persists correctly

**Specific Tests:**
- `NotificationPreferencesTests.testSaveToUserDefaults`
- `NotificationPreferencesTests.testLoadFromUserDefaults`
- `NotificationPreferencesTests.testPersistenceAfterMultipleSaves`

**Expected Result:**
- ✅ Data saves correctly
- ✅ Data loads correctly
- ✅ No data corruption
- ✅ Cleanup works properly

---

### Test 8: Model Validation Tests
**Purpose:** Verify data models enforce constraints

**Specific Tests:**
- `NotificationPreferencesTests.testLeadTimeValidation`
- `NotificationPreferencesTests.testBufferTimeValidation`
- `AppErrorTests.testErrorIdentifiers`

**Expected Result:**
- ✅ Invalid values rejected
- ✅ Valid values accepted
- ✅ Constraints enforced

---

## Performance Benchmarks

### Test Execution Time
- **Individual test:** < 0.1 seconds
- **Test file:** < 5 seconds
- **All tests:** < 30 seconds

### Memory Usage
- Tests should not leak memory
- Each test should clean up properly
- Monitor memory in Instruments if needed

---

## Continuous Integration Setup

### GitHub Actions Configuration

Create `.github/workflows/ios-tests.yml`:

```yaml
name: iOS Tests

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main, develop ]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode_15.0.app

    - name: Build and Test
      run: |
        xcodebuild test \
          -scheme CalAI \
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
          -enableCodeCoverage YES \
          CODE_SIGN_IDENTITY="" \
          CODE_SIGNING_REQUIRED=NO

    - name: Generate Coverage Report
      run: |
        xcrun llvm-cov report \
          -instr-profile=$(find ~/Library/Developer/Xcode/DerivedData -name "*.profdata") \
          $(find ~/Library/Developer/Xcode/DerivedData -name "CalAI") \
          > coverage.txt

    - name: Upload Coverage
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage.txt
```

---

## Coverage Goals by Component

### Critical (Target: 80-90%)
- [x] EventFilterService
- [x] MeetingAnalyzer
- [x] CrashReporter
- [x] AppError
- [x] NotificationPreferences

### Important (Target: 70-80%)
- [ ] CalendarManager
- [ ] GoogleCalendarManager
- [ ] OutlookCalendarManager
- [ ] SmartNotificationManager
- [ ] TravelTimeManager

### Supporting (Target: 50-70%)
- [ ] VoiceManager
- [ ] HapticManager
- [ ] ThemeManager
- [ ] SecureStorage

### UI (Target: 30-50%)
- [ ] ContentView
- [ ] CalendarViews
- [ ] SettingsViews

---

## Common Test Issues

### Issue 1: Tests fail in CI but pass locally
**Cause:** Environment differences
**Solution:**
- Use consistent Xcode version
- Pin simulator version
- Clean derived data before running

### Issue 2: UserDefaults pollution between tests
**Cause:** Tests don't clean up
**Solution:**
- Implement proper `tearDown()` methods
- Clear UserDefaults keys after each test
- Use unique keys per test if needed

### Issue 3: Flaky async tests
**Cause:** Race conditions, timing issues
**Solution:**
- Use XCTestExpectation properly
- Increase timeout if needed
- Mock async dependencies

### Issue 4: Code coverage lower than expected
**Cause:** Untested edge cases, UI code
**Solution:**
- Identify uncovered lines in Coverage Report
- Add tests for critical paths
- Focus on business logic over UI

---

## Affirmative Checklist

Before moving to Phase 6, confirm:

### Test Execution
- [ ] All 96 tests pass
- [ ] No flaky tests (run 10 times, all pass)
- [ ] Tests complete in < 30 seconds
- [ ] No memory leaks detected

### Coverage Metrics
- [ ] Overall coverage ≥ 70%
- [ ] EventFilterService ≥ 80%
- [ ] MeetingAnalyzer ≥ 80%
- [ ] CrashReporter ≥ 75%
- [ ] AppError ≥ 90%
- [ ] NotificationPreferences ≥ 85%

### Code Quality
- [ ] All tests follow naming convention
- [ ] Tests are well-documented
- [ ] No commented-out tests
- [ ] setUp() and tearDown() properly implemented
- [ ] No hard-coded values (use constants)

### CI/CD
- [ ] GitHub Actions workflow created (optional)
- [ ] Tests run on push to main
- [ ] Coverage reports generated
- [ ] Passing build badge added to README (optional)

### Documentation
- [ ] PHASE_5_TESTING.md reviewed
- [ ] PHASE_5_SUMMARY.md reviewed
- [ ] Test coverage report reviewed
- [ ] Known issues documented

---

## Next Phase Preview

**Phase 6: Add User Analytics (Opt-In)**
After achieving 70% test coverage, we'll implement:
- Analytics service with privacy-first design
- Event tracking for feature usage
- User opt-in/opt-out UI
- Integration with analytics platform (or local-only)
- Privacy-compliant data collection

---

**Once all tests pass and coverage targets are met, provide the affirmative to proceed to Phase 6.**

Example: "Affirmative - Phase 5 test coverage complete at 72%. Ready for Phase 6."
