# Outlook Login Troubleshooting Guide

## Current Issue
User reports: "I am not able to log into Outlook"

## System Configuration ✅

The following are already correctly configured:

### 1. Entitlements (CalAI.entitlements)
✅ `keychain-access-groups` includes:
  - `$(AppIdentifierPrefix)com.microsoft.adalcache` (MSAL keychain)
  - `$(AppIdentifierPrefix)com.rasheuristics.calendarweaver` (App keychain)

✅ `com.apple.security.application-groups`:
  - `group.com.rasheuristics.calendarweaver`

### 2. Info.plist Configuration
✅ MSALClientID: `1caae4b2-4f30-49d9-b486-5229dc148c3f`
✅ CFBundleURLSchemes includes `MSALRedirect`

### 3. OutlookCalendarManager Features
✅ Aggressive keychain cleanup on init
✅ Broker disabled to avoid keychain conflicts
✅ System browser (Safari) OAuth flow
✅ Comprehensive error logging

## Common Issues & Solutions

### Issue 1: Keychain Error -34018 on Physical Device

**Symptoms:**
- "MSAL initialization failed" error
- Console shows: "Keychain error -34018"
- Works on simulator but fails on device

**Root Causes:**
1. Keychain Sharing capability not enabled in Xcode
2. Provisioning profile doesn't include keychain groups
3. Code signing issue

**Solutions:**

#### Step 1: Enable Keychain Sharing in Xcode
1. Open Xcode project
2. Select CalAI target
3. Go to "Signing & Capabilities" tab
4. Click "+ Capability"
5. Add "Keychain Sharing"
6. Verify these groups are listed:
   - `$(AppIdentifierPrefix)com.microsoft.adalcache`
   - `$(AppIdentifierPrefix)com.rasheuristics.calendarweaver`

#### Step 2: Clean Build Folder
```bash
# In Xcode:
Product → Clean Build Folder (Cmd+Shift+K)

# Or via command line:
rm -rf ~/Library/Developer/Xcode/DerivedData/CalAI-*
```

#### Step 3: Delete App from Device
1. Delete CalAI app from device
2. Rebuild and reinstall

#### Step 4: Verify Provisioning Profile
1. Go to Xcode → Preferences → Accounts
2. Select your Apple ID
3. Download Manual Profiles
4. Verify profile includes keychain access groups

---

### Issue 2: User Cancels Sign-In

**Symptoms:**
- Safari/browser opens for OAuth
- User closes browser without completing sign-in
- No error shown (this is correct behavior)

**Solution:**
- This is normal - just retry the sign-in
- Tap "Connect" button again in Settings

---

### Issue 3: MSAL Not Initialized

**Symptoms:**
- Sign-in button does nothing
- Console: "MSAL not configured properly"

**Root Cause:**
- MSALClientID missing or incorrect in Info.plist

**Solution:**
1. Open `CalAI/SupportingFiles/Info.plist`
2. Verify `MSALClientID` key exists
3. Value should be: `1caae4b2-4f30-49d9-b486-5229dc148c3f`

---

### Issue 4: Redirect URI Mismatch

**Symptoms:**
- Browser redirects but app doesn't respond
- Stuck on OAuth page

**Solution:**
1. Verify `CFBundleURLSchemes` in Info.plist includes `msauth.com.rasheuristics.calendarweaver`
2. Check Azure App Registration:
   - Go to https://portal.azure.com
   - Navigate to App Registrations
   - Select your CalAI app
   - Go to Authentication
   - Verify redirect URI: `msauth.com.rasheuristics.calendarweaver://auth`

---

### Issue 5: Simulator vs Device Differences

**Symptoms:**
- Works perfectly on simulator
- Fails on physical device

**Explanation:**
- Simulator doesn't enforce keychain access groups strictly
- Physical devices require proper entitlements

**Solution:**
- Always test OAuth on a physical device
- Follow Issue 1 solutions above

---

## Debugging Steps

### Step 1: Check Console Logs

When attempting Outlook sign-in, look for these log messages:

**Good Signs:**
```
🔵 ========== OUTLOOK SIGN-IN STARTED ==========
✅ MSAL application configured successfully
🔍 Debug - About to call acquireToken with system browser
✅ MSAL authentication successful!
```

**Bad Signs:**
```
❌ FATAL: MSAL failed to initialize
❌ KEYCHAIN ERROR -34018
❌ Missing entitlement for query
```

### Step 2: Test OAuth Flow

1. Open CalAI app
2. Go to Settings → Calendar Connections
3. Tap "Outlook Calendar" → Connect
4. Watch for:
   - Safari should open
   - Microsoft login page should load
   - After login, should redirect back to app

### Step 3: Verify Keychain Access

Run this test code in the app:

```swift
// In OutlookCalendarManager.swift, add this test method:
func testKeychainAccess() {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "test-service",
        kSecAttrAccount as String: "test-account",
        kSecValueData as String: "test-data".data(using: .utf8)!,
        kSecAttrAccessGroup as String: "$(AppIdentifierPrefix)com.microsoft.adalcache"
    ]

    let status = SecItemAdd(query as CFDictionary, nil)
    print("Keychain test status: \(status)")

    if status == errSecSuccess || status == errSecDuplicateItem {
        print("✅ Keychain access working!")
    } else if status == -34018 {
        print("❌ Keychain error -34018 - entitlements issue")
    }

    // Clean up
    SecItemDelete(query as CFDictionary)
}
```

---

## Quick Fix Checklist

Try these in order:

- [ ] Enable "Keychain Sharing" capability in Xcode
- [ ] Clean Build Folder (Cmd+Shift+K)
- [ ] Delete app from device and reinstall
- [ ] Verify MSALClientID in Info.plist
- [ ] Check provisioning profile includes keychain groups
- [ ] Test on physical device (not simulator)
- [ ] Check console logs for specific error
- [ ] Verify internet connection
- [ ] Check if Safari can access login.microsoftonline.com

---

## What Happens During Outlook Sign-In?

1. **User taps "Connect" in Settings**
   - `signIn()` called
   - `setupMSAL()` initializes MSAL library
   - Clears any cached credentials

2. **OAuth Flow Starts**
   - `signInWithOAuth()` called
   - Safari browser opens
   - Navigates to Microsoft login page

3. **User Logs In**
   - Enters Microsoft credentials
   - Completes 2FA if required
   - Microsoft authorizes app

4. **Redirect Back to App**
   - Safari redirects to `msauth://` URL
   - App receives authorization code
   - MSAL exchanges code for access token

5. **Token Stored**
   - Access token saved in keychain
   - User account info retrieved from Graph API
   - Calendar list fetched

6. **Success**
   - `isSignedIn = true`
   - Calendar selection sheet appears

---

## Error Messages Explained

### "MSAL initialization failed"
**Meaning:** The MSAL library couldn't start
**Likely Cause:** Keychain access error or missing Info.plist key
**Fix:** Enable Keychain Sharing capability

### "Keychain configuration error. Enable Keychain Sharing"
**Meaning:** App can't access the keychain group for MSAL
**Likely Cause:** Missing Keychain Sharing capability
**Fix:** Add capability in Xcode project settings

### "Unable to find window for authentication"
**Meaning:** App couldn't present the Safari browser
**Likely Cause:** UI hierarchy issue (rare)
**Fix:** Restart app

### "Authentication failed: user_cancelled"
**Meaning:** User closed browser without completing sign-in
**Likely Cause:** User action
**Fix:** Not an error - retry sign-in

---

## Testing Outlook Sign-In

### On Simulator (macOS):
1. Run app in Xcode
2. Go to Settings → Outlook Calendar → Connect
3. Safari simulator opens with login page
4. Enter Microsoft credentials
5. Should redirect back automatically

### On Physical Device (iOS):
1. Install via Xcode or TestFlight
2. Open app
3. Settings → Outlook Calendar → Connect
4. Device Safari opens
5. Sign in with Microsoft account
6. Tap "Continue" on redirect prompt
7. Should return to app

---

## Advanced Debugging

### Enable MSAL Logging

Add this to `setupMSAL()` after creating msalApplication:

```swift
MSALGlobalConfig.loggerConfig.logLevel = .verbose
MSALGlobalConfig.loggerConfig.setLogCallback { (level, message, containsPII) in
    if !containsPII {
        print("[MSAL] \(message ?? "nil")")
    }
}
```

### Check Azure App Registration

1. Go to https://portal.azure.com
2. App Registrations → CalAI
3. Verify:
   - **Client ID** matches Info.plist
   - **Redirect URIs** include `msauth.com.rasheuristics.calendarweaver://auth`
   - **API Permissions** include:
     - Calendars.ReadWrite
     - User.Read
   - **Authentication** → Mobile applications enabled

---

## Still Not Working?

If you've tried everything above and still can't sign in:

### Collect Debug Info:

1. **Console logs** from sign-in attempt
2. **Xcode version** you're using
3. **Device model** and iOS version
4. **Build configuration** (Debug/Release)
5. **Provisioning profile** type (Dev/Ad Hoc/App Store)

### Check These:

- Is the Azure app registration active?
- Has the client secret expired (if applicable)?
- Are you using the correct Microsoft account?
- Does your account have calendar permissions?
- Is there a corporate policy blocking OAuth?

### Last Resort:

1. Create a new Azure App Registration
2. Update MSALClientID in Info.plist
3. Clean build and reinstall app

---

## Success Indicators

You'll know Outlook sign-in is working when:

✅ Console shows: "✅ MSAL authentication successful!"
✅ Calendar selection sheet appears
✅ Settings shows "Connected" with green checkmark
✅ Calendar list populated with your Outlook calendars

---

## Related Issues

- [KEYCHAIN_FIX_GUIDE.md](KEYCHAIN_FIX_GUIDE.md) - General keychain troubleshooting
- OutlookCalendarManager.swift:169-210 - MSAL setup code
- CalAI.entitlements - Keychain access group configuration

---

**Last Updated:** November 11, 2025
**Status:** Diagnostic guide - awaiting specific error details from user
