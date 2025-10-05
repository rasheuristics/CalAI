# Phase 2: Crash Reporting - Testing Instructions

## ✅ What Was Implemented

### New Files Created:
1. **`CalAI/Services/CrashReporter.swift`** - Core crash reporting service
2. **`CalAI/Views/CrashReportingSettingsView.swift`** - Settings UI
3. **Modified: `CalAI/CalAIApp.swift`** - App initialization with crash reporting

---

## 📱 How to Test

### Test 1: Verify App Launches Successfully
1. Build and run the app (Cmd + R)
2. Check the console for: `✅ Crash reporting initialized (enabled: true)`
3. App should launch normally without crashes

**Expected Result:** ✅ App launches successfully

---

### Test 2: Access Crash Reporting Settings
1. Open the app
2. Navigate to: **Settings Tab** (if you want to add it to AdvancedSettingsView)
3. Or manually test the view in Preview

**To test in Preview:**
- Open `CrashReportingSettingsView.swift` in Xcode
- Click the "Resume" button in Canvas (or Cmd + Opt + P)
- Verify the settings UI displays correctly

**Expected Result:** ✅ Settings view shows crash reporting toggle and privacy info

---

### Test 3: Test Non-Fatal Error Logging (DEBUG mode)
1. Build and run in DEBUG mode
2. Go to Crash Reporting Settings (if integrated)
3. Tap **"Test Non-Fatal Error"**
4. Confirm the alert
5. Check Console for: `❌ ERROR: This is a test non-fatal error`

**Expected Result:**
- ✅ Error logged to console
- ✅ App continues running (doesn't crash)
- ✅ Log saved to Documents/crash_logs.txt

---

### Test 4: View Crash Logs (DEBUG mode)
1. After running Test 3
2. Tap **"View Crash Logs"** in settings
3. A sheet should appear with the crash log contents

**Expected Result:**
- ✅ Sheet opens with monospaced text
- ✅ Shows timestamp and error message
- ✅ Can share logs via share button

---

### Test 5: Toggle Crash Reporting
1. In Crash Reporting Settings
2. Toggle **"Enable Crash Reporting"** OFF
3. Check console for: `Crash reporting disabled`
4. Toggle it back ON
5. Check console for: `Crash reporting enabled`

**Expected Result:**
- ✅ Toggle works smoothly
- ✅ Haptic feedback on toggle
- ✅ Console messages confirm state changes

---

### Test 6: Check Local Crash Logs File
1. Run the app in Simulator
2. Trigger a test error (Test 3)
3. Open Finder
4. Navigate to: `~/Library/Developer/CoreSimulator/Devices/[DEVICE_ID]/data/Containers/Data/Application/[APP_ID]/Documents/crash_logs.txt`

**Easier method:**
```swift
// Add this to console
print(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0])
```
Then navigate to that path in Finder.

**Expected Result:**
- ✅ File exists
- ✅ Contains crash log entries
- ✅ Entries are timestamped and formatted

---

## 🔧 Integration Points (Future)

### To Add Firebase Crashlytics Later:

1. **Add Firebase SDK** to your project:
   ```swift
   // In Package.swift or SPM
   .package(url: "https://github.com/firebase/firebase-ios-sdk", from: "10.0.0")
   ```

2. **Uncomment Firebase code** in `CrashReporter.swift`:
   ```swift
   // Find lines like:
   // Firebase: Crashlytics.crashlytics().setUserID(userId)

   // Uncomment them:
   Crashlytics.crashlytics().setUserID(userId)
   ```

3. **Add GoogleService-Info.plist** from Firebase Console

4. **Initialize Firebase** in `CalAIApp.swift`:
   ```swift
   import Firebase

   init() {
       FirebaseApp.configure()
       setupCrashReporting()
   }
   ```

---

## ✅ Checklist for Affirmative

Before moving to Phase 3, confirm:

- [ ] App builds and runs successfully
- [ ] No compilation errors
- [ ] Crash reporter initializes on launch (check console)
- [ ] Can toggle crash reporting on/off in settings (if integrated)
- [ ] Test non-fatal error works (DEBUG mode)
- [ ] Logs are being saved locally
- [ ] No performance issues or lag

---

## 🎯 What to Tell Me

**If everything works:**
> "Affirmative - Phase 2 crash reporting tested successfully. Ready for Phase 3."

**If there are issues:**
> "Phase 2 has issues: [describe the problem]"

---

## 📋 Current Implementation Summary

### What's Working:
✅ Local crash logging with os.log
✅ Non-fatal error tracking
✅ User preferences for opt-in/opt-out
✅ Privacy-focused design
✅ Debug tools for testing
✅ Device and app info collection
✅ Breadcrumb tracking
✅ Severity levels (critical, error, warning, info)

### What's Ready (but not active):
🟡 Firebase Crashlytics integration points (commented out)
🟡 Analytics event recording (commented out)
🟡 User identifier tracking (commented out)

### What's NOT Included:
❌ Firebase SDK (you need to add it manually)
❌ GoogleService-Info.plist configuration
❌ Remote crash reporting backend
❌ Crash report aggregation/dashboard

---

## 🚀 Next Phase Preview

**Phase 3: Privacy Policy & Terms**
- Create privacy policy document
- Create terms of service document
- Add to app settings
- Add to onboarding flow
- Ensure compliance with App Store requirements

---

**Ready to test? Build the app and let me know the results!** ✨
