# Critical Task #8: Crash Reporting Implementation

## Current Status

✅ **Infrastructure Already Built!**
- `Utilities/CrashReporter.swift` - Complete crash reporting wrapper (279 lines)
- `Features/Settings/Views/CrashReportingSettingsView.swift` - User-facing settings UI
- `Tests/CrashReporterTests.swift` - Unit tests
- Local file logging working
- Exception handler configured
- User consent toggle implemented

**What's Missing:** Production crash reporting backend (currently only logs locally)

## Service Comparison: Sentry vs Firebase Crashlytics

| Feature | Sentry | Firebase Crashlytics | Winner |
|---------|--------|---------------------|--------|
| **Free Tier** | 5K events/month | Unlimited | Firebase |
| **Setup Complexity** | Medium | Easy | Firebase |
| **SDK Size** | ~2MB | ~1MB (part of Firebase) | Firebase |
| **Real-time Alerts** | ✅ Yes | ✅ Yes | Tie |
| **Error Grouping** | ✅ Excellent | ✅ Good | Sentry |
| **Release Tracking** | ✅ Yes | ✅ Yes | Tie |
| **Performance Monitoring** | ✅ Yes ($$$) | ✅ Yes (free) | Firebase |
| **Privacy Control** | ✅ Self-hosted option | ❌ Google only | Sentry |
| **Breadcrumbs** | ✅ Yes | ✅ Yes | Tie |
| **User Impact** | ✅ Excellent | ✅ Good | Sentry |
| **Swift Support** | ✅ Native | ✅ Native | Tie |
| **Symbolication** | ✅ Automatic | ✅ Automatic | Tie |
| **Cost (10K+ users)** | $26/month | Free | Firebase |

## Recommendation: Firebase Crashlytics

**Reasons:**
1. **Free forever** - No usage limits
2. **Already using Google Sign-In** - Reduces SDK bloat
3. **Easy integration** - Well-documented Swift SDK
4. **Performance monitoring included** - Track app speed for free
5. **Google Play Services** - Already have Google dependencies
6. **Proven at scale** - Used by millions of apps

**Trade-offs:**
- Less powerful error grouping than Sentry
- No self-hosted option (privacy concern for some users)
- Locked into Google ecosystem

## Implementation Plan

### Phase 1: Add Firebase SDK (15 min)

**Add Package Dependencies:**
```swift
// Package.swift or Xcode SPM
https://github.com/firebase/firebase-ios-sdk
Products:
- FirebaseCrashlytics
- FirebaseAnalytics (optional)
```

**Required versions:**
- Firebase iOS SDK: 10.0+
- Minimum iOS: 13.0 (we're on 16.0 ✅)

### Phase 2: Configure Firebase (20 min)

**1. Create Firebase Project:**
- Go to https://console.firebase.google.com
- Create new project: "CalAI"
- Add iOS app with bundle ID: `com.rasheuristics.calendarweaver`
- Download `GoogleService-Info.plist`

**2. Add GoogleService-Info.plist:**
```bash
# Place in CalAI/CalAI/SupportingFiles/
# Add to Xcode project (Copy if needed)
# Ensure it's included in CalAI target
```

**3. Initialize Firebase in App:**
```swift
// CalAI/CalAIApp.swift
import Firebase

@main
struct CalAIApp: App {
    init() {
        FirebaseApp.configure()
    }
    // ...
}
```

### Phase 3: Update CrashReporter.swift (30 min)

**Changes needed:**

1. **Add Firebase import**
```swift
import FirebaseCrashlytics
```

2. **Initialize Crashlytics**
```swift
private func setupCrashReporting() {
    // Existing NSSetUncaughtExceptionHandler...

    // Add Firebase
    Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(isEnabled)

    logger.info("✅ Crash reporting initialized (Firebase)")
}
```

3. **Update logCrash method**
```swift
private func logCrash(message: String, severity: CrashSeverity, error: Error? = nil) {
    // ... existing local logging ...

    // Send to Firebase
    if let error = error {
        Crashlytics.crashlytics().record(error: error)
    } else {
        let nsError = NSError(
            domain: "com.rasheuristics.calendarweaver",
            code: severity.errorCode,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        Crashlytics.crashlytics().record(error: nsError)
    }
}
```

4. **Implement user context methods**
```swift
func setUserIdentifier(_ userId: String) {
    logger.info("👤 User identifier set: \(userId)")
    Crashlytics.crashlytics().setUserID(userId)
}

func setCustomValue(_ value: String, forKey key: String) {
    logger.debug("🔧 Custom value set: \(key) = \(value)")
    Crashlytics.crashlytics().setCustomValue(value, forKey: key)
}

func leaveBreadcrumb(_ message: String) {
    logger.debug("🍞 Breadcrumb: \(message)")
    Crashlytics.crashlytics().log(message)
}
```

5. **Add severity mapping**
```swift
extension CrashSeverity {
    var errorCode: Int {
        switch self {
        case .critical: return 500
        case .error: return 400
        case .warning: return 300
        case .info: return 200
        }
    }
}
```

### Phase 4: Add Symbolication (15 min)

**Add Upload Symbols Script:**

1. **In Xcode:**
   - Select CalAI target
   - Build Phases → + → New Run Script Phase
   - Name: "Upload dSYMs to Firebase"
   - Script:
   ```bash
   "${BUILD_DIR%/Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"
   ```

2. **Input Files:**
   ```
   ${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}/Contents/Resources/DWARF/${TARGET_NAME}
   $(SRCROOT)/$(BUILT_PRODUCTS_DIR)/$(INFOPLIST_PATH)
   ```

### Phase 5: Test (20 min)

**1. Test Non-Fatal Error:**
```swift
// In debug build
CrashReporter.shared.testNonFatalError()
// Check Firebase Console → Crashlytics → Non-fatals
```

**2. Test Fatal Crash:**
```swift
// In debug build
CrashReporter.shared.testCrash()
// App crashes, restart, check Firebase Console
```

**3. Test Breadcrumbs:**
```swift
CrashReporter.shared.leaveBreadcrumb("User tapped button")
CrashReporter.shared.leaveBreadcrumb("API call started")
CrashReporter.shared.testNonFatalError()
// Check Firebase Console → Event details → Breadcrumbs
```

### Phase 6: Privacy Policy Update (10 min)

**Add to privacy policy:**
```
Crash and Performance Data

We use Firebase Crashlytics to collect crash reports and app performance data to improve app stability. This includes:
- Crash stack traces and error messages
- Device model, OS version, and app version
- Anonymous usage patterns
- Network connectivity status

We do NOT collect:
- Calendar event details
- Personal information
- Exact location data
- Credentials or API keys

You can disable crash reporting in Settings → Advanced → Crash Reporting.
```

## Integration Checklist

- [ ] Create Firebase project at console.firebase.google.com
- [ ] Add iOS app with bundle ID `com.rasheuristics.calendarweaver`
- [ ] Download GoogleService-Info.plist
- [ ] Add GoogleService-Info.plist to Xcode project
- [ ] Add Firebase SDK via Swift Package Manager
  - [ ] FirebaseCrashlytics
  - [ ] FirebaseAnalytics (optional)
- [ ] Initialize Firebase in CalAIApp.swift
- [ ] Update CrashReporter.swift with Firebase calls
- [ ] Add symbolication script to build phases
- [ ] Test non-fatal error logging
- [ ] Test fatal crash logging
- [ ] Test breadcrumbs
- [ ] Verify crashes appear in Firebase Console
- [ ] Update privacy policy
- [ ] Update Settings → About with crash reporting info

## Code Changes Required

### 1. CalAIApp.swift
```swift
import Firebase

@main
struct CalAIApp: App {
    init() {
        // Configure Firebase first
        FirebaseApp.configure()

        // Then existing initialization...
    }
}
```

### 2. CrashReporter.swift
**Minimal changes - replace TODO comments with Firebase calls**

See Phase 3 above for detailed code changes.

### 3. Info.plist (No changes needed)
Firebase automatically reads from GoogleService-Info.plist

### 4. Entitlements (No changes needed)
Firebase uses standard network permissions

## Alternative: Sentry Implementation

If you prefer Sentry instead:

**Add Package:**
```
https://github.com/getsentry/sentry-cocoa
Product: Sentry
```

**Initialize:**
```swift
import Sentry

SentrySDK.start { options in
    options.dsn = "YOUR_SENTRY_DSN"
    options.debug = false
    options.enableAutoSessionTracking = true
}
```

**Update CrashReporter:**
```swift
SentrySDK.capture(error: error)
SentrySDK.configureScope { scope in
    scope.setUser(User(userId: userId))
    scope.setContext(value: ["key": value], key: "custom")
}
```

**Pros:**
- Better error grouping
- More detailed stack traces
- Self-hosted option

**Cons:**
- Costs money after 5K events/month
- Requires separate Sentry account
- Larger SDK size

## Testing Scenarios

### Scenario 1: Keychain Error
```swift
do {
    try SecureStorage.store(key: "test", value: "value")
} catch {
    CrashReporter.shared.logError(error, context: "Keychain Test")
}
// Should appear in Firebase with "Keychain Test" context
```

### Scenario 2: API Failure
```swift
CrashReporter.shared.logAPIError(error, endpoint: "/calendar/events")
// Should be tagged with "API: /calendar/events"
```

### Scenario 3: User Journey
```swift
CrashReporter.shared.leaveBreadcrumb("User logged in")
CrashReporter.shared.leaveBreadcrumb("Navigated to settings")
CrashReporter.shared.leaveBreadcrumb("Changed theme")
// Breadcrumbs attached to next error
```

## Estimated Total Time

| Phase | Time | Status |
|-------|------|--------|
| Add Firebase SDK | 15 min | Pending |
| Configure Firebase Project | 20 min | Pending |
| Update CrashReporter Code | 30 min | Pending |
| Add Symbolication Script | 15 min | Pending |
| Testing | 20 min | Pending |
| Privacy Policy Update | 10 min | Pending |
| **Total** | **110 min (< 2 hours)** | |

## Success Criteria

✅ Crashes appear in Firebase Console within 5 minutes
✅ Non-fatal errors logged with full context
✅ Breadcrumbs attached to error reports
✅ Stack traces symbolicated (readable function names)
✅ User can opt-out via Settings
✅ Privacy policy updated
✅ No PII (personally identifiable information) collected

## Next Steps After Implementation

1. Monitor Firebase Console daily for first week
2. Set up Slack/email alerts for critical crashes
3. Triage and fix top 5 crashes
4. Add more breadcrumbs in critical user flows
5. Set up release tracking (tag builds with version)

## Resources

- Firebase Crashlytics Docs: https://firebase.google.com/docs/crashlytics
- Swift SDK Reference: https://firebase.google.com/docs/reference/swift/firebasecrashlytics/api/reference/Classes/Crashlytics
- Best Practices: https://firebase.google.com/docs/crashlytics/best-practices
