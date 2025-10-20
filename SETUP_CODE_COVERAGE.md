# Setup Code Coverage - Step-by-Step Guide

## Overview

This guide walks you through setting up the new test files and enabling code coverage tracking in Xcode.

## ✅ What We've Created

**New Test Files** (Need to be added to Xcode project):
- `CalAI/Tests/Helpers/TestHelpers.swift` - Test fixtures and utilities
- `CalAI/Tests/Mocks/MockEventStore.swift` - Mock EventKit store
- `CalAI/Tests/Managers/CalendarManagerTests.swift` - CalendarManager tests (20+ test cases)
- `CalAI/Tests/Managers/AIManagerTests.swift` - SmartEventParser tests (30+ test cases)
- `CalAI/Tests/Managers/SyncManagerTests.swift` - SyncManager tests (25+ test cases)

**Total**: ~700 lines of new test code covering critical functionality

---

## Step 1: Add Test Files to Xcode Project

### Option A: Using Xcode GUI (Recommended)

1. **Open CalAI.xcodeproj in Xcode**
   ```bash
   open CalAI.xcodeproj
   ```

2. **Check if CalAITests target exists**:
   - In Xcode, go to top menu: **Product** → **Scheme** → **Edit Scheme...**
   - Click **Test** in the left sidebar
   - Check if there's a test target listed under **Test**

3. **If NO test target exists, create one**:
   - **File** → **New** → **Target...**
   - Select **iOS** → **Unit Testing Bundle**
   - Name: `CalAITests`
   - Select **CalAI** as the target to be tested
   - Language: Swift
   - Click **Finish**

4. **Add the new test files**:
   - In Project Navigator, select the `CalAI/Tests/` folder
   - Right-click → **Add Files to "CalAI"...**
   - Navigate to and select:
     - `Helpers/TestHelpers.swift`
     - `Mocks/MockEventStore.swift`
     - `Managers/CalendarManagerTests.swift`
     - `Managers/AIManagerTests.swift`
     - `Managers/SyncManagerTests.swift`
   - ✅ **IMPORTANT**: Check **"CalAITests"** target membership
   - ✅ **IMPORTANT**: Uncheck **"CalAI"** main target
   - Click **Add**

5. **Verify target membership**:
   - Select each test file in Project Navigator
   - In File Inspector (right panel), verify:
     - ✅ **CalAITests** is checked
     - ⬜ **CalAI** is unchecked

### Option B: Using Command Line (Advanced)

If you prefer command-line, you can use `xed` or modify `project.pbxproj` directly (not recommended unless you're experienced with Xcode project files).

---

## Step 2: Enable Code Coverage

### 2.1 Enable Coverage in Scheme

1. **Edit the CalAI scheme**:
   - **Product** → **Scheme** → **Edit Scheme...** (or ⌘<)
   - Click **Test** in the left sidebar

2. **Enable Code Coverage**:
   - Check ✅ **"Code Coverage"** checkbox
   - From dropdown, select **"CalAITests"** (or "Some Test Targets")
   - Click **Close**

### 2.2 Configure Coverage Options

1. **Open Test Navigator**:
   - Press ⌘6 or click the diamond icon in left panel

2. **View Coverage Settings**:
   - After running tests, you'll see coverage percentage next to each file

### 2.3 Enable Coverage for Specific Targets

1. **Product** → **Scheme** → **Edit Scheme...**
2. Click **Test** → **Options** tab
3. Under **Code Coverage**:
   - Select **"Gather coverage for: Some targets"**
   - Click **"+"** and add:
     - ✅ CalAI (main app target)
     - ✅ CalAITests
4. Click **Close**

---

## Step 3: Run Tests

### 3.1 Run All Tests

**Via Xcode**:
- Press **⌘U** (Command-U)
- Or: **Product** → **Test**

**Via Command Line**:
```bash
xcodebuild test \
  -scheme CalAI \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -enableCodeCoverage YES
```

### 3.2 Run Individual Test File

1. Open test file (e.g., `CalendarManagerTests.swift`)
2. Click the diamond icon next to class name
3. Or click individual diamond icons next to each test method

### 3.3 View Test Results

**In Xcode**:
- Press ⌘9 to open **Report Navigator**
- Select latest test run
- View:
  - ✅ Passed tests (green)
  - ❌ Failed tests (red)
  - ⏱️ Execution time
  - 📊 Code coverage

**In Terminal**:
```bash
# View coverage report
xcrun xccov view --report /path/to/TestResults.xcresult
```

---

## Step 4: View Code Coverage Report

### 4.1 In Xcode

1. **Run tests** (⌘U)
2. **Open Report Navigator** (⌘9)
3. Click on latest test run
4. Click **Coverage** tab
5. View coverage by:
   - **Target** (overall app coverage)
   - **Source File** (per-file coverage)
   - **Function** (per-function coverage)

### 4.2 Export Coverage Report

**Via Xcode**:
1. **Product** → **Test** (⌘U)
2. After tests complete:
   - **Product** → **Perform Action** → **Export Code Coverage Report**
3. Choose location and save

**Via Command Line**:
```bash
# Find latest test result bundle
RESULT_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" | head -1)

# Generate coverage report
xcrun xccov view --report --json "$RESULT_BUNDLE" > coverage.json

# View human-readable coverage
xcrun xccov view "$RESULT_BUNDLE"
```

### 4.3 Inline Coverage in Code

1. **Open any source file** (e.g., `CalendarManager.swift`)
2. **Editor** → **Show Code Coverage** (⇧⌘9)
3. You'll see:
   - 🟢 **Green sidebar**: Code covered by tests
   - 🔴 **Red sidebar**: Code NOT covered
   - **Numbers**: How many times each line was executed

---

## Step 5: Continuous Coverage Tracking

### 5.1 Set Coverage Baseline

After first test run:
1. **Report Navigator** (⌘9)
2. Right-click test run → **Set Baseline**
3. Future test runs will compare against this baseline

### 5.2 View Coverage Trends

1. **Report Navigator** (⌘9)
2. Select multiple test runs
3. View coverage changes over time

### 5.3 Generate Coverage HTML Report

```bash
# Install xcov (Ruby gem)
sudo gem install xcov

# Generate HTML coverage report
xcov --scheme CalAI \
     --output_directory coverage_report \
     --minimum_coverage_percentage 70
```

This generates a beautiful HTML coverage report you can open in browser.

---

## Step 6: CI/CD Integration (Optional)

### 6.1 GitHub Actions

Create `.github/workflows/tests.yml`:

```yaml
name: Run Tests

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: macos-latest

    steps:
    - uses: actions/checkout@v3

    - name: Select Xcode
      run: sudo xcode-select -s /Applications/Xcode.app

    - name: Run Tests
      run: |
        xcodebuild test \
          -scheme CalAI \
          -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
          -enableCodeCoverage YES \
          | xcpretty

    - name: Generate Coverage Report
      run: |
        RESULT_BUNDLE=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcresult" | head -1)
        xcrun xccov view --report --json "$RESULT_BUNDLE" > coverage.json

    - name: Upload Coverage
      uses: codecov/codecov-action@v3
      with:
        files: ./coverage.json
```

### 6.2 Codecov.io Setup

1. Sign up at https://codecov.io
2. Add your GitHub repository
3. Add to `.codecov.yml`:

```yaml
coverage:
  status:
    project:
      default:
        target: 70%
        threshold: 5%
    patch:
      default:
        target: 80%
```

---

## Expected Test Results

After adding files and running tests, you should see:

### Test Summary

```
Test Suite 'All tests' started at ...
Test Suite 'CalendarManagerTests' started at ...
✅ CalendarManager tests: 20 passed
✅ AIManagerTests: 30 passed
✅ SyncManagerTests: 25 passed
✅ Previous tests: 7 passed

Test Suite 'All tests' passed at ...
    Executed 82 tests, with 0 failures (0 unexpected) in 5.234 seconds
```

### Coverage Improvement

**Before**: ~8% coverage (7 test files, 200 lines)

**After**: ~35-40% coverage estimation
- CalendarManager: ~60% (core CRUD operations)
- SmartEventParser: ~70% (intent detection)
- SyncManager: ~50% (sync operations)
- Other managers: 0-20% (not yet tested)

### Coverage by File (Expected)

| File | Before | After | Change |
|------|--------|-------|--------|
| CalendarManager.swift | 5% | 60% | +55% |
| SmartEventParser.swift | 0% | 70% | +70% |
| SyncManager.swift | 0% | 50% | +50% |
| AIManager.swift | 0% | 30% | +30% |
| **Overall** | **8%** | **~40%** | **+32%** |

---

## Troubleshooting

### Issue: "Scheme CalAI is not currently configured for the test action"

**Solution**:
1. **Product** → **Scheme** → **Edit Scheme...**
2. Click **Test** in left sidebar
3. Click **"+"** at bottom
4. Select **CalAITests** target
5. Click **Close**

### Issue: Test files not found / Module 'CalAI' not found

**Solution**:
1. Verify test files have correct target membership
2. Check that `@testable import CalAI` is present
3. Ensure **CalAI** scheme has **"Enable Testability" = YES**:
   - Select CalAI project
   - Build Settings
   - Search "testability"
   - Set to **YES**

### Issue: MockEventStore conflicts with EKEventStore

**Solution**:
1. MockEventStore is a subclass, not a replacement
2. For full mocking, we may need protocol-based architecture
3. Current tests use what's available without major refactoring

### Issue: Tests fail due to missing permissions

**Expected**: Some tests may fail on first run if:
- Calendar permissions not granted
- Google/Outlook not configured

**Solution**: These are integration tests - failures are informational

---

## Next Steps

After setting up code coverage:

1. ✅ **Run tests** (⌘U) - Should see ~82 total tests pass
2. ✅ **Check coverage** - Should be ~35-40%
3. 📊 **Review coverage report** - Identify gaps
4. 🎯 **Iterate**:
   - Write tests for uncovered critical paths
   - Target 70% overall coverage
   - Focus on high-risk areas first

---

## Quick Reference

| Action | Shortcut | Menu |
|--------|----------|------|
| Run all tests | ⌘U | Product → Test |
| Run single test | Click diamond | N/A |
| Show coverage | ⇧⌘9 | Editor → Show Code Coverage |
| Test Navigator | ⌘6 | View → Navigators → Test |
| Report Navigator | ⌘9 | View → Navigators → Report |
| Edit Scheme | ⌘< | Product → Scheme → Edit Scheme |

---

## Resources

- **Xcode Testing Documentation**: https://developer.apple.com/documentation/xctest
- **Code Coverage Guide**: https://developer.apple.com/library/archive/documentation/DeveloperTools/Conceptual/testing_with_xcode/chapters/07-code_coverage.html
- **TESTING_STRATEGY.md**: Full 6-week testing roadmap
- **TESTING_GUIDELINES.md**: Existing test guidelines in repo

---

**Created**: 2025-10-20
**Status**: Ready for manual setup in Xcode
**Estimated Time**: 15-20 minutes to complete all steps
