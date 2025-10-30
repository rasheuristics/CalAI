# Calendar Connection Persistence Issue - Why Settings Show "Not Connected" After Rebuild

## Problem ❌

**User Report**: Every time the app is rebuilt in Xcode, the Settings show that Google Calendar and Outlook Calendar are "not connected", even though they were previously authorized.

---

## Root Causes

### 1. **Xcode Development Reinstall Clears Keychain** (Primary Issue)

When Xcode rebuilds and reinstalls the app during development:

- ✅ **UserDefaults**: Cleared (app-specific)
- ✅ **App Documents**: Cleared (app-specific)
- ✅ **Keychain Items**: **MAY BE CLEARED** depending on provisioning profile

**Why Keychain Gets Cleared**:

The Keychain access group is based on the **App Identifier Prefix** (Team ID):

```xml
<!-- CalAI.entitlements -->
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
    <string>$(AppIdentifierPrefix)com.rasheuristics.calendarweaver</string>
</array>
```

**During Development Builds**:
- App ID changes: `com.rasheuristics.calendarweaver.debug` vs `com.rasheuristics.calendarweaver`
- Provisioning profile changes
- **Result**: Different Keychain access group → Can't access previous tokens

---

### 2. **Google Sign-In Token Storage**

**File**: `GoogleCalendarManager.swift:64-107`

**Storage Method**: Google Sign-In SDK stores tokens in Keychain automatically

**Problem**:
```swift
private func restorePreviousSignIn() {
    if let currentUser = GIDSignIn.sharedInstance.currentUser {
        // ✅ This works if Keychain persists
        currentUser.refreshTokensIfNeeded { ... }
    } else {
        GIDSignIn.sharedInstance.restorePreviousSignIn { user, error in
            // ❌ Returns nil after reinstall because Keychain was cleared
            if let user = user {
                self?.isSignedIn = true
            } else {
                self?.isSignedIn = false  // ← FAILS HERE
                print("❌ No previous Google sign-in found")
            }
        }
    }
}
```

**Console Output After Reinstall**:
```
🔄 Attempting to restore previous Google Sign-In...
❌ No previous Google sign-in found
```

**Result**: `isSignedIn = false` → Settings shows "Not Connected"

---

### 3. **Outlook MSAL Token Storage**

**File**: `OutlookCalendarManager.swift:1096-1111`

**Storage Method**:
1. Account info → SecureStorage (Keychain)
2. OAuth tokens → MSAL (Keychain)

**Problem**:
```swift
private func loadCurrentAccount() {
    if let account = loadAccountSecurely() {
        currentAccount = account
        isSignedIn = true  // ← Sets flag to true
        print("✅ Loaded account from secure storage")
    }
}
```

**But then when fetching events**:
```swift
func fetchEvents() {
    // Try to use stored access token
    if let token = accessToken {
        fetchEventsWithToken(token)
    } else {
        print("⚠️ No stored access token, need to re-authenticate")
        isLoading = false  // ← FAILS SILENTLY
    }
}
```

**The Issue**:
- ✅ Account info loads from Keychain → `isSignedIn = true`
- ❌ MSAL tokens cleared during reinstall → `accessToken = nil`
- ❌ Settings shows "Connected" but can't actually fetch events
- ❌ No fallback to re-authenticate

---

### 4. **Missing Token Refresh Logic**

**Current Code** (`OutlookCalendarManager.swift:1262-1279`):

```swift
func fetchEvents() {
    guard let selectedCalendar = selectedCalendar else { return }

    // Use stored access token if available
    if let token = accessToken {
        fetchEventsWithToken(token)
    } else {
        print("⚠️ No stored access token, need to re-authenticate")
        isLoading = false  // ← STOPS HERE, doesn't try to refresh
    }
}
```

**Problem**: No attempt to call `refreshTokenAndFetch()` when token is missing

---

## Solutions

### Solution 1: Add Automatic Token Refresh on App Launch ✅

**For Outlook Calendar**:

Modify `loadSavedData()` to attempt token refresh if account exists but token doesn't:

**File**: `OutlookCalendarManager.swift:1091-1094`

```swift
private func loadSavedData() {
    loadCurrentAccount()
    loadSelectedCalendar()

    // NEW: Attempt silent token refresh on app launch
    if isSignedIn && accessToken == nil {
        print("🔄 Account loaded but no access token - attempting silent refresh...")
        attemptSilentTokenRefresh()
    }
}

private func attemptSilentTokenRefresh() {
    guard let msalApp = msalApplication else {
        print("❌ MSAL not configured")
        isSignedIn = false  // Reset flag if MSAL unavailable
        return
    }

    msalApp.getCurrentAccount(with: nil) { [weak self] (account, _, error) in
        guard let self = self else { return }

        if let account = account {
            let silentParameters = MSALSilentTokenParameters(scopes: self.scopes, account: account)

            msalApp.acquireTokenSilent(with: silentParameters) { [weak self] (result, error) in
                DispatchQueue.main.async {
                    if let result = result {
                        self?.accessToken = result.accessToken
                        print("✅ Silent token refresh successful on launch")

                        // Fetch events automatically
                        if self?.selectedCalendar != nil {
                            self?.fetchEvents()
                        }
                    } else {
                        print("⚠️ Silent token refresh failed: \(error?.localizedDescription ?? "Unknown")")
                        // Don't set isSignedIn = false here, let user manually re-auth
                        // They're technically still signed in, just token expired
                    }
                }
            }
        } else {
            print("❌ No MSAL account found")
            DispatchQueue.main.async {
                self.isSignedIn = false
                self.currentAccount = nil
            }
        }
    }
}
```

---

**For Google Calendar**:

The existing code already handles this correctly via `refreshTokensIfNeeded()`, but we can add better logging:

**File**: `GoogleCalendarManager.swift:64-107`

```swift
private func restorePreviousSignIn() {
    print("🔄 Attempting to restore previous Google Sign-In...")

    if let currentUser = GIDSignIn.sharedInstance.currentUser {
        print("✅ Found current user, refreshing token if needed...")
        currentUser.refreshTokensIfNeeded { [weak self] refreshedUser, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Token refresh failed: \(error.localizedDescription)")
                    print("💡 This may be due to app reinstall clearing Keychain")
                    self?.isSignedIn = false
                    return
                }

                if let user = refreshedUser {
                    self?.isSignedIn = true
                    print("✅ Google user restored with refreshed token: \(user.profile?.email ?? "")")
                    self?.checkCalendarAccess(for: user)
                } else {
                    print("❌ No user after token refresh")
                    self?.isSignedIn = false
                }
            }
        }
    } else {
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to restore Google Sign-In: \(error.localizedDescription)")
                    print("💡 This is expected after app reinstall - Keychain was cleared")
                    self?.isSignedIn = false
                    return
                }

                if let user = user {
                    self?.isSignedIn = true
                    print("✅ Google user restored: \(user.profile?.email ?? "")")
                    self?.checkCalendarAccess(for: user)
                } else {
                    self?.isSignedIn = false
                    print("ℹ️ No previous Google sign-in found")
                }
            }
        }
    }
}
```

---

### Solution 2: Modify `fetchEvents()` to Auto-Refresh Token ✅

**File**: `OutlookCalendarManager.swift:1262-1279`

**Current (Broken)**:
```swift
func fetchEvents() {
    if let token = accessToken {
        fetchEventsWithToken(token)
    } else {
        print("⚠️ No stored access token, need to re-authenticate")
        isLoading = false  // ← STOPS HERE
    }
}
```

**Fixed**:
```swift
func fetchEvents(from startDate: Date = Date(), to endDate: Date = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()) {
    print("🔵 Fetching Outlook events...")

    guard let selectedCalendar = selectedCalendar else {
        print("❌ No calendar selected for Outlook events")
        return
    }

    // Try stored token first
    if let token = accessToken {
        print("✅ Using stored access token for event fetch")
        fetchEventsWithToken(token, startDate: startDate, endDate: endDate)
    } else if let msalApp = msalApplication {
        // No stored token - attempt silent refresh
        print("⚠️ No stored access token - attempting silent token acquisition...")
        refreshTokenAndFetch(msalApp: msalApp, startDate: startDate, endDate: endDate)
    } else {
        print("❌ MSAL not configured, cannot fetch events")
        isLoading = false
        isSignedIn = false  // Reset flag since we can't authenticate
    }
}
```

---

### Solution 3: Add Visual Feedback in Settings ✅

**File**: `SettingsTabView.swift:38-46`

**Current**:
```swift
private var outlookCalendarStatus: PermissionStatus {
    if outlookCalendarManager.isSignedIn && outlookCalendarManager.selectedCalendar != nil {
        return .granted
    } else if outlookCalendarManager.isSignedIn && outlookCalendarManager.selectedCalendar == nil {
        return .unknown
    } else {
        return .notGranted
    }
}
```

**Problem**: Doesn't check if token is actually valid

**Better**:
```swift
private var outlookCalendarStatus: PermissionStatus {
    if outlookCalendarManager.isSignedIn &&
       outlookCalendarManager.selectedCalendar != nil &&
       outlookCalendarManager.accessToken != nil {
        return .granted  // Fully authenticated
    } else if outlookCalendarManager.isSignedIn &&
              outlookCalendarManager.selectedCalendar != nil &&
              outlookCalendarManager.accessToken == nil {
        return .unknown  // Signed in but token expired
    } else if outlookCalendarManager.isSignedIn &&
              outlookCalendarManager.selectedCalendar == nil {
        return .unknown  // Signed in but no calendar selected
    } else {
        return .notGranted  // Not signed in at all
    }
}
```

**Add Visual Indicator**:
```swift
PermissionRow(
    title: "Outlook Calendar",
    systemImage: "envelope",
    status: outlookCalendarStatus,
    action: {
        if outlookCalendarManager.isSignedIn {
            if outlookCalendarManager.accessToken == nil {
                // Try to refresh token
                outlookCalendarManager.fetchEvents()
            } else if outlookCalendarManager.selectedCalendar == nil {
                outlookCalendarManager.showCalendarSelectionSheet()
            } else {
                outlookCalendarManager.signOut()
            }
        } else {
            outlookCalendarManager.signIn()
        }
    }
)

// Add helper text if token expired
if outlookCalendarManager.isSignedIn && outlookCalendarManager.accessToken == nil {
    Text("Token expired - tap to refresh")
        .font(.caption)
        .foregroundColor(.orange)
        .padding(.leading, 40)
}
```

---

### Solution 4: Add Keychain Access Group Compatibility ✅

**Issue**: Development and production builds may have different access groups

**File**: `CalAI.entitlements`

**Current**:
```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
    <string>$(AppIdentifierPrefix)com.rasheuristics.calendarweaver</string>
</array>
```

**Better**: Add additional access group for Google Sign-In

```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
    <string>$(AppIdentifierPrefix)com.rasheuristics.calendarweaver</string>
    <string>$(AppIdentifierPrefix)com.google.GIDSignIn</string>
</array>
```

---

## Why This Happens During Development But Not Production

| Scenario | Keychain Cleared? | Reason |
|----------|------------------|---------|
| **Xcode Clean Build** | ❌ No | Build artifacts cleared, not app data |
| **Xcode Rebuild + Reinstall** | ✅ Yes (often) | App removed and reinstalled with new bundle |
| **Xcode Different Provisioning Profile** | ✅ Yes | Different Team ID = different Keychain group |
| **TestFlight Build** | ❌ No | Upgrade in place, same bundle ID |
| **App Store Update** | ❌ No | Upgrade in place, same bundle ID |
| **User Deletes App** | ✅ Yes | Complete removal |

**Development Reinstall Behavior**:
```
1. Xcode stops app
2. Xcode removes app bundle
3. iOS sees "app uninstalled"
4. iOS clears app-specific data (UserDefaults, Documents, sometimes Keychain)
5. Xcode installs new build
6. iOS sees "new app installed"
7. Keychain items may or may not be accessible depending on entitlements
```

---

## Testing Scenarios

### Test 1: Clean Build (Should Persist)
```bash
# In Xcode
Product → Clean Build Folder (⇧⌘K)
Product → Run (⌘R)

Expected: Calendars still connected ✅
```

### Test 2: Delete + Rebuild (Will Clear)
```bash
# In Simulator
1. Delete CalAI app
2. In Xcode: Product → Run (⌘R)

Expected: Calendars not connected (Keychain cleared) ❌
Desired: Attempt silent token refresh on launch ✅
```

### Test 3: Different Provisioning Profile (Will Clear)
```bash
# In Xcode
1. Change Team ID in Signing & Capabilities
2. Product → Run (⌘R)

Expected: Calendars not connected (Different Keychain access group) ❌
Desired: Attempt silent token refresh on launch ✅
```

---

## Implementation Priority

### High Priority (Fix Now)

1. ✅ **Add `attemptSilentTokenRefresh()` to Outlook manager**
   - Call during `loadSavedData()`
   - Automatically refresh token on app launch if missing

2. ✅ **Modify `fetchEvents()` to auto-refresh token**
   - Don't fail silently when token is nil
   - Attempt `refreshTokenAndFetch()` before giving up

3. ✅ **Add better logging to Google Sign-In**
   - Explain why restoration fails after reinstall
   - Help developers understand expected behavior

### Medium Priority (Enhance UX)

4. ✅ **Add token validation to Settings status**
   - Check `accessToken != nil` for Outlook
   - Show "Token expired" state in UI

5. ✅ **Add visual feedback for expired tokens**
   - Show helper text: "Tap to refresh connection"
   - Use `.unknown` status instead of `.granted`

### Low Priority (Nice to Have)

6. ⚠️ **Add Google keychain-access-group**
   - May help with token persistence
   - Test if it actually makes a difference

7. ⚠️ **Add automatic retry logic**
   - If silent refresh fails, retry after delay
   - Max 3 retries before requiring user action

---

## Code Changes Required

### 1. OutlookCalendarManager.swift

**Line ~1091**: Modify `loadSavedData()`
```swift
private func loadSavedData() {
    loadCurrentAccount()
    loadSelectedCalendar()

    // Attempt silent token refresh if signed in but no token
    if isSignedIn && accessToken == nil {
        attemptSilentTokenRefresh()
    }
}
```

**Add new method** (after line 1136):
```swift
private func attemptSilentTokenRefresh() {
    // Implementation shown in Solution 1 above
}
```

**Line 1262**: Modify `fetchEvents()`
```swift
func fetchEvents(...) {
    if let token = accessToken {
        fetchEventsWithToken(token)
    } else if let msalApp = msalApplication {
        refreshTokenAndFetch(msalApp: msalApp, startDate: startDate, endDate: endDate)
    } else {
        isLoading = false
        isSignedIn = false
    }
}
```

### 2. GoogleCalendarManager.swift

**Line 64**: Enhance logging in `restorePreviousSignIn()`
- Add explanatory messages about Keychain clearing
- No logic changes needed (already correct)

### 3. SettingsTabView.swift

**Line 38**: Enhance `outlookCalendarStatus`
- Check `accessToken != nil`
- Show `.unknown` for expired tokens

---

## Summary

**Root Cause**:
- Xcode development reinstalls clear Keychain
- Managers load account info but tokens are gone
- `isSignedIn = true` but `accessToken = nil`
- Settings shows "Connected" but can't fetch events

**Solution**:
- Add silent token refresh on app launch
- Modify `fetchEvents()` to auto-refresh when token missing
- Better status checking in Settings UI
- Enhanced logging for developers

**Expected Result**:
- After rebuild: Settings may briefly show "Not Connected"
- Within 1-2 seconds: Silent token refresh completes
- Settings updates to "Connected"
- Events fetch automatically
- User never needs to manually re-authorize (unless tokens truly expired)

---

## Testing Checklist

After implementing fixes:

- [ ] Clean build → Calendars stay connected
- [ ] Delete app + rebuild → Calendars auto-reconnect within 2 seconds
- [ ] Change provisioning profile → Calendars auto-reconnect
- [ ] Check console logs → Should see "Silent token refresh successful"
- [ ] Settings UI → Should show correct status (.unknown while refreshing, .granted after)
- [ ] Events → Should auto-fetch after token refresh
- [ ] Google Calendar → Should auto-restore (already works)
- [ ] Outlook Calendar → Should auto-restore (after fix)

Expected console output after fix:
```
🔄 Attempting to restore previous Google Sign-In...
✅ Google user restored with refreshed token: user@gmail.com

✅ Loaded account from secure storage: user@outlook.com
✅ Loaded calendar from secure storage: Calendar (Default)
🔄 Account loaded but no access token - attempting silent refresh...
✅ Silent token refresh successful on launch
🔵 Fetching Outlook events...
✅ Fetched 25 Outlook events
```
