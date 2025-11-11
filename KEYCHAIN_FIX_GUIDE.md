# Keychain Error -34018 Fix Guide
**Date:** November 10, 2025
**Critical Priority Task #7**

## Executive Summary

Fixed keychain error -34018 (`errSecMissingEntitlement`) that prevented secure storage of OAuth tokens for Google Calendar and Microsoft Outlook integration.

## Root Causes Identified

### 1. Bundle Identifier Mismatch ❌ FIXED
**Problem:** `SecureStorage.swift` used fallback bundle ID `com.calai.CalAI`
**Actual Bundle ID:** `com.rasheuristics.calendarweaver`
**Impact:** Keychain couldn't match stored items to app

**Fix Applied:**
```swift
// OLD (WRONG):
kSecAttrService as String: Bundle.main.bundleIdentifier ?? "com.calai.CalAI"

// NEW (CORRECT):
private static let bundleIdentifier = "com.rasheuristics.calendarweaver"
kSecAttrService as String: bundleIdentifier
```

### 2. Missing Keychain Access Group ❌ FIXED
**Problem:** SecureStorage queries didn't specify `kSecAttrAccessGroup`
**Impact:** On physical devices, keychain items require explicit access group

**Fix Applied:**
```swift
// Add to all keychain queries (store, retrieve, delete, update)
#if !targetEnvironment(simulator)
query[kSecAttrAccessGroup as String] = keychainAccessGroup
#endif
```

**Why simulator check?**
- Simulator: Keychain access groups not required
- Physical device: Access groups REQUIRED or get -34018 error

### 3. Accessibility Setting ❌ FIXED
**Problem:** Used `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
**Issue:** Too restrictive for background refresh and widget access

**Fix Applied:**
```swift
// OLD: Too restrictive
kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly

// NEW: Allows background access
kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
```

## Changes Made

### File: `Utilities/SecureStorage.swift`

**1. Added Configuration Constants** (Lines 7-13)
```swift
/// App's bundle identifier (must match Xcode project)
private static let bundleIdentifier = "com.rasheuristics.calendarweaver"

/// Keychain access group for sharing data (must match entitlements)
private static let keychainAccessGroup = "com.rasheuristics.calendarweaver"
```

**2. Enhanced Error Reporting** (Lines 36-48)
```swift
private static func statusMessage(for status: OSStatus) -> String {
    switch status {
    case errSecSuccess: return "Success"
    case errSecItemNotFound: return "Item not found"
    case errSecDuplicateItem: return "Duplicate item"
    case errSecAuthFailed: return "Authentication failed"
    case -34018: return "Missing entitlement or keychain access group"
    case errSecInteractionNotAllowed: return "User interaction not allowed"
    case errSecMissingEntitlement: return "Missing entitlement"
    default: return "Unknown error"
    }
}
```

**3. Updated All Keychain Methods**
- `store()` - Added access group, better error logging
- `retrieve()` - Added access group, better error logging
- `delete()` - Added access group, better error logging
- `update()` - Added access group, better error logging

## Entitlements Configuration

### File: `SupportingFiles/CalAI.entitlements`

**Current configuration** (already correct):
```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
    <string>$(AppIdentifierPrefix)com.rasheuristics.calendarweaver</string>
</array>
```

**Explanation:**
- `$(AppIdentifierPrefix)` - Team ID prefix (auto-populated by Xcode)
- `com.microsoft.adalcache` - Required for Microsoft MSAL library
- `com.rasheuristics.calendarweaver` - App's keychain access group

## Xcode Configuration Required

### ⚠️ CRITICAL: Must Enable Capability in Xcode

**Steps to verify/enable:**

1. Open Xcode project
2. Select "CalAI" target
3. Go to "Signing & Capabilities" tab
4. Verify "Keychain Sharing" capability is added
5. If not present, click "+ Capability" and add "Keychain Sharing"
6. Verify keychain groups match entitlements:
   - `$(AppIdentifierPrefix)com.microsoft.adalcache`
   - `$(AppIdentifierPrefix)com.rasheuristics.calendarweaver`

**Screenshot location:** *Need to verify in Xcode UI*

## Testing Requirements

### ✅ Simulator Testing (Optional)
```swift
// Simulator: Access groups ignored, should work without changes
try SecureStorage.store(key: "test", value: "hello")
let value = try SecureStorage.retrieve(key: "test")
print(value) // Should print: hello
```

### 🔴 Physical Device Testing (REQUIRED)
**Why required:** Error -34018 ONLY occurs on physical devices

**Test Steps:**

1. **Clean Install**
   ```bash
   # Delete app from device
   # Install fresh build from Xcode
   ```

2. **Test Google Sign-In**
   - Launch app
   - Go to Settings → Calendar Sources
   - Tap "Connect Google Calendar"
   - Complete OAuth flow
   - **Expected:** No -34018 errors in console
   - **Verify:** Tokens stored successfully

3. **Test Outlook Sign-In**
   - Go to Settings → Calendar Sources
   - Tap "Connect Outlook Calendar"
   - Complete OAuth flow
   - **Expected:** No -34018 errors in console
   - **Verify:** Tokens stored successfully

4. **Test Token Retrieval After App Restart**
   - Force quit app
   - Relaunch app
   - **Verify:** Calendars load without re-authentication
   - **Expected:** Tokens retrieved from keychain successfully

5. **Test Background Access**
   - Enable morning briefing
   - Lock device
   - Wait for background refresh
   - **Verify:** Widget updates with calendar data
   - **Expected:** Keychain accessible in background

### Test Devices
- iPhone (iOS 16+) - Minimum supported version
- iPhone (iOS 18+) - Latest version
- iPad (optional if supporting iPad)

## Common Error Codes

| Code | Constant | Meaning | Fix |
|------|----------|---------|-----|
| 0 | errSecSuccess | Success | N/A |
| -25300 | errSecItemNotFound | Item not in keychain | Normal - item doesn't exist yet |
| -25299 | errSecDuplicateItem | Item already exists | Delete first, then store |
| -34018 | errSecMissingEntitlement | Missing entitlement/access group | Enable Keychain Sharing capability |
| -25308 | errSecInteractionNotAllowed | Device locked | Use kSecAttrAccessibleAfterFirstUnlock |

## Verification Checklist

- [x] Bundle identifier matches project (`com.rasheuristics.calendarweaver`)
- [x] Keychain access group added to all queries
- [x] Accessibility changed to `kSecAttrAccessibleAfterFirstUnlock`
- [x] Error logging enhanced with human-readable messages
- [x] Simulator conditional compilation added
- [ ] **TODO:** Enable "Keychain Sharing" capability in Xcode
- [ ] **TODO:** Test on physical device with Google OAuth
- [ ] **TODO:** Test on physical device with Outlook OAuth
- [ ] **TODO:** Test token retrieval after app restart
- [ ] **TODO:** Test background keychain access

## Rollback Plan

If issues persist, revert to previous version:

```bash
git diff HEAD~1 Utilities/SecureStorage.swift
git checkout HEAD~1 -- Utilities/SecureStorage.swift
```

## Known Limitations

### Simulator Behavior
- Keychain access groups not enforced
- May work on simulator but fail on device
- **Always test on physical device before release**

### MSAL Library Issues
- Microsoft MSAL creates its own keychain items
- Uses separate access group: `com.microsoft.adalcache`
- May have -34018 errors if MSAL not configured correctly
- See `Services/OutlookCalendarManager.swift` for MSAL-specific handling

### iCloud Keychain
- Not currently enabled
- If enabling later, add `kSecAttrSynchronizable` attribute
- Requires additional entitlement

## Next Steps

1. ✅ Code changes complete
2. ⚠️ **Open Xcode and verify "Keychain Sharing" capability enabled**
3. ⚠️ **Test on physical iPhone with iOS 16+**
4. ⚠️ **Test Google Calendar OAuth flow end-to-end**
5. ⚠️ **Test Outlook Calendar OAuth flow end-to-end**
6. ✅ Mark Task #7 complete when device testing passes

## Additional Resources

- [Apple Keychain Services Documentation](https://developer.apple.com/documentation/security/keychain_services)
- [Keychain Access Groups Guide](https://developer.apple.com/documentation/security/keychain_services/keychain_items/sharing_access_to_keychain_items_among_a_collection_of_apps)
- [Error Code Reference](https://www.osstatus.com/)
- MSAL iOS Documentation: https://github.com/AzureAD/microsoft-authentication-library-for-objc

## Support

For keychain issues:
1. Check console logs for specific error codes
2. Verify entitlements file matches Xcode capabilities
3. Test on physical device (never rely on simulator alone)
4. Check Team ID in provisioning profile matches `$(AppIdentifierPrefix)`
