# Google & Microsoft Authentication Setup Guide for CalAI

This guide provides step-by-step instructions for setting up Google and Microsoft OAuth authentication for the CalAI app in production.

## 🚨 Critical Issues Found

Before proceeding with production deployment, these **CRITICAL** issues must be fixed:

### ❌ Issue #1: Bundle ID Mismatch
- **GoogleService-Info.plist**: `com.calai.CalAI`
- **Actual App Bundle**: `com.rasheuristics.calendarweaver`
- **Impact**: Google OAuth will fail
- **Fix Required**: [See Fix #1 below](#fix-1-bundle-id-mismatch)

### ❌ Issue #2: Missing Keychain Sharing
- **Problem**: Keychain Sharing capability not enabled in Xcode
- **Impact**: Error -34018 on physical devices
- **Fix Required**: [See Fix #2 below](#fix-2-enable-keychain-sharing)

---

## 📋 Current Authentication Status

### ✅ Already Implemented
- GoogleSignIn framework integrated
- MSAL (Microsoft Authentication Library) integrated
- Secure Keychain token storage
- Automatic token refresh mechanisms
- Complete OAuth flows for both providers
- Calendar API integration (Google Calendar v3, Microsoft Graph)

### 🔧 What's Already Configured
- **Google Project**: `calai-calendar`
- **Google Client ID**: `43431862733-2ath0e407kaj4m8n8faj5nt6orhf6vlo.apps.googleusercontent.com`
- **Microsoft App ID**: `1caae4b2-4f30-49d9-b486-5229dc148c3f`
- **OAuth Scopes**: Calendar read/write permissions
- **Redirect URIs**: Properly configured for iOS

---

## 🛠️ Critical Fixes Required

### Fix #1: Bundle ID Mismatch

**Option A: Update Google Configuration (Recommended)**
```bash
# 1. Go to Google Cloud Console: https://console.cloud.google.com/
# 2. Select project: calai-calendar
# 3. Navigate to: APIs & Services > Credentials
# 4. Edit OAuth 2.0 Client ID: 43431862733-2ath0e407kaj4m8n8faj5nt6orhf6vlo
# 5. Update Bundle ID from com.calai.CalAI to com.rasheuristics.calendarweaver
# 6. Download new GoogleService-Info.plist
# 7. Replace file in Xcode project
```

**Option B: Update App Bundle ID (Alternative)**
```bash
# 1. Open CalAI.xcodeproj in Xcode
# 2. Select CalAI target
# 3. Change Bundle Identifier to: com.calai.CalAI
# 4. Update all references in:
#    - SecureStorage.swift
#    - Keychain access groups
#    - Microsoft redirect URI in Azure
```

### Fix #2: Enable Keychain Sharing

**In Xcode:**
1. Open `CalAI.xcodeproj`
2. Select **CalAI** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Keychain Sharing**
6. Verify these access groups are listed:
   ```
   $(AppIdentifierPrefix)com.microsoft.adalcache
   $(AppIdentifierPrefix)com.rasheuristics.calendarweaver
   ```

**Verify Entitlements File:**
Check `CalAI/SupportingFiles/CalAI.entitlements`:
```xml
<key>keychain-access-groups</key>
<array>
    <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
    <string>$(AppIdentifierPrefix)com.rasheuristics.calendarweaver</string>
</array>
```

---

## 📱 Google Calendar Authentication Setup

### Prerequisites
- Google Cloud Project: `calai-calendar` ✅ (Already created)
- OAuth 2.0 Client ID ✅ (Already configured)
- Google Calendar API enabled ✅

### Current Configuration
```
Project ID: calai-calendar
Client ID: 43431862733-2ath0e407kaj4m8n8faj5nt6orhf6vlo.apps.googleusercontent.com
API Key: AIzaSyBJfEXBJF8nKIgKHJwUQ5I9b5vZxCRWQvQ
Bundle ID: com.calai.CalAI (NEEDS UPDATE to com.rasheuristics.calendarweaver)
```

### Steps for Production

1. **Update OAuth Consent Screen**
   ```bash
   # 1. Go to: https://console.cloud.google.com/apis/credentials/consent
   # 2. Select project: calai-calendar
   # 3. Edit OAuth consent screen
   # 4. Set User Type: External (for public app)
   # 5. Set Publishing Status: In Production
   # 6. Verify App Name, Logo, Privacy Policy URL
   # 7. Add test users if needed during development
   ```

2. **Verify API Quotas**
   ```bash
   # 1. Go to: https://console.cloud.google.com/apis/api/calendar-json.googleapis.com/quotas
   # 2. Check quota limits:
   #    - Queries per day: 1,000,000 (default)
   #    - Queries per 100 seconds per user: 100
   # 3. Request quota increase if needed for production scale
   ```

3. **Test OAuth Flow**
   ```swift
   // In GoogleCalendarManager.swift, verify this works:
   @objc func signIn() {
       guard let presentingViewController = UIApplication.shared.windows.first?.rootViewController else {
           return
       }

       GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
           // Should successfully authenticate and store tokens
       }
   }
   ```

### OAuth Scopes Used
```swift
private let scopes = ["https://www.googleapis.com/auth/calendar"]
```
**Permissions**: Read/write access to all user calendars

---

## 🏢 Microsoft Outlook Authentication Setup

### Prerequisites
- Azure App Registration ✅ (Already created)
- Microsoft Graph API permissions ✅ (Already configured)

### Current Configuration
```
Application (Client) ID: 1caae4b2-4f30-49d9-b486-5229dc148c3f
Redirect URI: msauth.com.rasheuristics.calendarweaver://auth
Tenant: Common (multi-tenant)
```

### Steps for Production

1. **Verify App Registration**
   ```bash
   # 1. Go to: https://portal.azure.com/
   # 2. Navigate to: Azure Active Directory > App registrations
   # 3. Find app: 1caae4b2-4f30-49d9-b486-5229dc148c3f
   # 4. Go to Authentication tab
   # 5. Verify Redirect URI: msauth.com.rasheuristics.calendarweaver://auth
   # 6. Enable "Public client flows": YES
   ```

2. **API Permissions Setup**
   ```bash
   # 1. Go to API permissions tab
   # 2. Verify these delegated permissions are added:
   #    - Calendars.ReadWrite (Microsoft Graph)
   #    - User.Read (Microsoft Graph)
   # 3. Grant admin consent if required by organization
   # 4. Status should show green checkmarks
   ```

3. **Supported Account Types**
   ```bash
   # Recommended for CalAI:
   # "Accounts in any organizational directory and personal Microsoft accounts"
   # This supports both:
   # - Personal Outlook.com accounts
   # - Work/School Office 365 accounts
   ```

### OAuth Scopes Used
```swift
private let scopes = [
    "https://graph.microsoft.com/Calendars.ReadWrite",
    "https://graph.microsoft.com/User.Read"
]
```

---

## 🔧 Xcode Project Configuration

### Required Capabilities
Ensure these are enabled in **Signing & Capabilities**:

- **Keychain Sharing** ⚠️ (NEEDS TO BE ADDED)
  ```
  $(AppIdentifierPrefix)com.microsoft.adalcache
  $(AppIdentifierPrefix)com.rasheuristics.calendarweaver
  ```

- **WeatherKit** ✅ (Already enabled)

### URL Schemes Configuration
Verify in `Info.plist`:

```xml
<!-- Google OAuth -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>com.googleusercontent.apps.43431862733-2ath0e407kaj4m8n8faj5nt6orhf6vlo</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>com.googleusercontent.apps.43431862733-2ath0e407kaj4m8n8faj5nt6orhf6vlo</string>
        </array>
    </dict>

    <!-- Microsoft OAuth -->
    <dict>
        <key>CFBundleURLName</key>
        <string>MSAL</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>msauth.com.rasheuristics.calendarweaver</string>
        </array>
    </dict>
</array>
```

### Privacy Permissions
Required in `Info.plist`:

```xml
<key>NSCalendarsUsageDescription</key>
<string>CalAI needs access to your calendar to help you manage your schedule with voice commands.</string>

<key>NSMicrophoneUsageDescription</key>
<string>CalAI needs microphone access to process your voice commands for calendar management.</string>

<key>NSSpeechRecognitionUsageDescription</key>
<string>CalAI uses speech recognition to understand your calendar management requests.</string>
```

---

## 🧪 Testing Authentication

### Pre-Production Testing

1. **Test on Physical Device** (Not Simulator)
   ```bash
   # Keychain access groups only work on real devices
   # Simulator may show success but device will fail with -34018

   # Test both authentication flows:
   # 1. Google Sign-In
   # 2. Microsoft Sign-In
   # 3. Token refresh after app restart
   # 4. Force quit app and relaunch
   ```

2. **Test Complete OAuth Flows**
   ```swift
   // 1. Fresh install (no cached tokens)
   // 2. Sign in with Google account
   // 3. Verify calendar access works
   // 4. Sign out and sign back in
   // 5. Repeat with Microsoft account
   // 6. Test with both personal and work Microsoft accounts
   ```

3. **Test Error Scenarios**
   ```swift
   // 1. Network offline during auth
   // 2. User cancels OAuth flow
   // 3. Invalid/expired tokens
   // 4. Keychain access denied
   // 5. App backgrounded during auth
   ```

### Debug Authentication Issues

**Enable Debug Logging:**
```swift
// Add to AppDelegate or early in app lifecycle
#if DEBUG
GIDSignIn.sharedInstance.configuration?.serverClientID = "YOUR_CLIENT_ID"
// Enable MSAL logging
MSALGlobalConfig.loggerConfig.logLevel = .verbose
#endif
```

**Check Keychain Status:**
```swift
// In SecureStorage.swift, verify this doesn't return -34018:
let status = SecItemAdd(query as CFDictionary, &result)
print("Keychain status: \(status)")
```

---

## 🚀 Production Deployment Checklist

### Pre-Deployment (Critical)
- [ ] **Fix bundle ID mismatch** (Google config vs app)
- [ ] **Enable Keychain Sharing** in Xcode capabilities
- [ ] **Test on physical device** (iPhone/iPad, not simulator)
- [ ] **Remove mock/fallback authentication** from OutlookCalendarManager
- [ ] **Test both Google and Microsoft flows** end-to-end
- [ ] **Verify token persistence** after app restart

### OAuth Provider Settings
- [ ] **Google**: Publish OAuth consent screen (not test mode)
- [ ] **Microsoft**: Verify app is published in Azure
- [ ] **Both**: Test with multiple account types
- [ ] **Both**: Monitor API usage/quotas

### Security & Performance
- [ ] **No API keys in source code** (use SecureStorage only)
- [ ] **HTTPS only** for all API calls
- [ ] **Token refresh working** automatically
- [ ] **Error handling** for network/auth failures
- [ ] **Background token refresh** when app returns to foreground

### App Store Requirements
- [ ] **Privacy Policy** must mention calendar and microphone access
- [ ] **Terms of Service** should cover OAuth data handling
- [ ] **App Review Notes** explain OAuth setup for Apple reviewers

---

## 🔍 Troubleshooting Common Issues

### Error -34018: Keychain Access Denied
```bash
# Cause: Missing Keychain Sharing capability
# Fix: Add "Keychain Sharing" capability in Xcode
# Verify: Check entitlements file has correct access groups
```

### Google Sign-In Fails Silently
```bash
# Cause: Bundle ID mismatch
# Check: GoogleService-Info.plist BUNDLE_ID matches app bundle
# Fix: Update Google OAuth client configuration
```

### Microsoft Auth Shows Error Page
```bash
# Cause: Incorrect redirect URI
# Check: Azure app registration redirect matches exactly
# Format: msauth.com.rasheuristics.calendarweaver://auth
```

### Tokens Don't Persist After App Restart
```bash
# Cause: Keychain storage failing
# Check: Device-specific issue (works on simulator, fails on device)
# Fix: Enable proper entitlements and test on physical device
```

### API Calls Return 401 Unauthorized
```bash
# Cause: Expired tokens not refreshing
# Check: Token refresh logic in managers
# Fix: Ensure refreshTokenIfNeeded() called before API requests
```

---

## 📚 Additional Resources

### Documentation
- [Google Sign-In for iOS](https://developers.google.com/identity/sign-in/ios)
- [Microsoft Authentication Library (MSAL)](https://docs.microsoft.com/en-us/azure/active-directory/develop/msal-overview)
- [Apple Keychain Services](https://developer.apple.com/documentation/security/keychain_services)

### API References
- [Google Calendar API v3](https://developers.google.com/calendar/api/v3/reference)
- [Microsoft Graph Calendar API](https://docs.microsoft.com/en-us/graph/api/resources/calendar)

### Project Files
- `GoogleCalendarManager.swift` - Google OAuth implementation
- `OutlookCalendarManager.swift` - Microsoft OAuth implementation
- `SecureStorage.swift` - Keychain token storage
- `KEYCHAIN_FIX_GUIDE.md` - Detailed keychain troubleshooting

---

## ⚡ Quick Start for Production

1. **Fix Critical Issues** (30 minutes)
   ```bash
   # 1. Update bundle ID in Google config OR app config
   # 2. Enable Keychain Sharing in Xcode
   # 3. Test on physical device
   ```

2. **Verify OAuth Providers** (15 minutes)
   ```bash
   # 1. Check Google consent screen is published
   # 2. Check Microsoft app registration is active
   # 3. Verify redirect URIs match exactly
   ```

3. **End-to-End Testing** (45 minutes)
   ```bash
   # 1. Fresh app install on device
   # 2. Test Google sign-in → calendar access
   # 3. Test Microsoft sign-in → calendar access
   # 4. Test app restart → tokens persist
   # 5. Test sign-out → clean state
   ```

4. **Deploy** 🚀
   ```bash
   # With fixes applied, authentication should work reliably
   # Monitor initial user sign-ins for any remaining issues
   ```

---

## 📧 Support

For authentication setup issues:

1. **Google OAuth**: Check [Google Cloud Console](https://console.cloud.google.com/) project `calai-calendar`
2. **Microsoft OAuth**: Check [Azure Portal](https://portal.azure.com/) app `1caae4b2-4f30-49d9-b486-5229dc148c3f`
3. **Keychain Issues**: Review `KEYCHAIN_FIX_GUIDE.md` in project root
4. **General**: Check debug logs in Xcode console during authentication

---

*Last Updated: November 2024*
*CalAI Version: v0.0.4b1*