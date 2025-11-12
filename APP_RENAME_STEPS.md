# App Rename to "Heu Calendar AI" - Completion Guide

This document outlines the changes made to rename the app from "CalAI" to "Heu Calendar AI" and update the bundle identifier to `ai.heucalendar.app` with URL scheme `ai.heucalendar.ios`.

## ✅ Changes Already Completed

### 1. App Display Name & Privacy Descriptions
**File: `/CalAI/SupportingFiles/Info.plist`**
- Updated all privacy usage descriptions to reference "Heu Calendar AI"
- Updated CFBundleURLName for app URL scheme to "Heu Calendar AI"
- Changed URL scheme from `calai` to `ai.heucalendar.ios`

### 2. Microsoft OAuth Redirect URI
**File: `/CalAI/SupportingFiles/Info.plist`**
- Updated MSAL redirect from `msauth.com.rasheuristics.calendarweaver` to `msauth.ai.heucalendar.app`

### 3. Bundle Identifier & Keychain Configuration
**File: `/CalAI/Utilities/SecureStorage.swift`**
- Updated bundle identifier from `com.rasheuristics.calendarweaver` to `ai.heucalendar.app`
- Updated keychain access group to match new bundle ID

**File: `/CalAI/SupportingFiles/CalAI.entitlements`**
- Updated application groups from `group.com.rasheuristics.calendarweaver` to `group.ai.heucalendar.app`
- Updated keychain access groups from `com.rasheuristics.calendarweaver` to `ai.heucalendar.app`

### 4. Deep Link URL Scheme
**File: `/CalAI/ContentView.swift`**
- Updated deep link handling from `calai://` to `ai.heucalendar.ios://`

### 5. iCloud Container & Cache References
**File: `/CalAI/CrossDeviceSyncManager.swift`**
- Updated CloudKit container from `iCloud.com.calai.CalAI` to `iCloud.ai.heucalendar.app`

**File: `/CalAI/Services/CacheManager.swift`**
- Updated disk cache folder from "CalAICache" to "HeuCalendarAICache"

### 6. User-Facing Tutorial Text
**File: `/CalAI/Services/TutorialCoordinator.swift`**
- Updated tutorial title and welcome messages to reference "Heu Calendar AI"

---

## 🚨 Critical OAuth Provider Setups Required

The following external service configurations **MUST** be created/updated for the new "Heu Calendar AI" app before it will work in production:

## 🍎 1. Apple Developer Portal Setup

**Create New App ID and Configurations**

### Step 1: Create New App ID
```bash
# 1. Go to: https://developer.apple.com/account/
# 2. Sign in with your Apple Developer Account
# 3. Navigate to: Certificates, Identifiers & Profiles
# 4. Click "Identifiers" in sidebar
# 5. Click the "+" button to create new identifier
# 6. Select "App IDs" and click Continue
# 7. Select "App" and click Continue
# 8. Fill in details:
#    - Description: Heu Calendar AI
#    - Bundle ID: ai.heucalendar.app (Explicit)
# 9. Under "Capabilities", enable:
#    ✅ App Groups
#    ✅ iCloud (including CloudKit compatibility)
#    ✅ Keychain Sharing
#    ✅ WeatherKit
# 10. Click Continue and Register
```

### Step 2: Create iCloud Container
```bash
# 1. In Certificates, Identifiers & Profiles
# 2. Click "Identifiers" > "iCloud Containers"
# 3. Click the "+" button
# 4. Fill in:
#    - Description: Heu Calendar AI iCloud Container
#    - Identifier: iCloud.ai.heucalendar.app
# 5. Click Continue and Register
```

### Step 3: Create App Group
```bash
# 1. In Certificates, Identifiers & Profiles
# 2. Click "Identifiers" > "App Groups"
# 3. Click the "+" button
# 4. Fill in:
#    - Description: Heu Calendar AI App Group
#    - Identifier: group.ai.heucalendar.app
# 5. Click Continue and Register
```

### Step 4: Update App ID with Services
```bash
# 1. Go back to "App IDs" and select your new ai.heucalendar.app
# 2. Click "Edit"
# 3. Under iCloud, click "Edit"
# 4. Select "Include CloudKit support"
# 5. Add the iCloud container: iCloud.ai.heucalendar.app
# 6. Under App Groups, click "Edit"
# 7. Add the app group: group.ai.heucalendar.app
# 8. Save changes
```

### Step 5: Generate New Provisioning Profiles
```bash
# 1. Navigate to "Profiles"
# 2. Click the "+" button
# 3. Select "iOS App Development" (for development)
# 4. Select your App ID: ai.heucalendar.app
# 5. Select your development certificates
# 6. Select your test devices
# 7. Name it: "Heu Calendar AI Development"
# 8. Generate and download
# 9. Repeat for "iOS App Store" distribution profile
```

---

## 🔵 2. Google Cloud Console Setup

**Create New OAuth 2.0 Client for Heu Calendar AI**

### Step 1: Create New Project (Recommended)
```bash
# 1. Go to: https://console.cloud.google.com/
# 2. Click project dropdown at top
# 3. Click "New Project"
# 4. Fill in:
#    - Project name: heu-calendar-ai
#    - Organization: (your organization if applicable)
# 5. Click "Create"
# 6. Select the new project
```

### Step 2: Enable Google Calendar API
```bash
# 1. Navigate to: APIs & Services > Library
# 2. Search for "Google Calendar API"
# 3. Click on "Google Calendar API"
# 4. Click "Enable"
# 5. Wait for enablement to complete
```

### Step 3: Configure OAuth Consent Screen
```bash
# 1. Navigate to: APIs & Services > OAuth consent screen
# 2. Select "External" user type (for public app)
# 3. Click "Create"
# 4. Fill in App Information:
#    - App name: Heu Calendar AI
#    - User support email: your-email@heucalendar.ai
#    - App logo: (upload your app icon)
# 5. Fill in App domain:
#    - Application home page: https://heucalendar.ai
#    - Application privacy policy: https://heucalendar.ai/privacy
#    - Application terms of service: https://heucalendar.ai/terms
# 6. Add Developer contact information
# 7. Click "Save and Continue"
# 8. On Scopes page, click "Add or Remove Scopes"
# 9. Add: https://www.googleapis.com/auth/calendar
# 10. Click "Save and Continue"
# 11. Add test users if in development
# 12. Click "Save and Continue"
```

### Step 4: Create OAuth 2.0 Client ID
```bash
# 1. Navigate to: APIs & Services > Credentials
# 2. Click "Create Credentials" > "OAuth 2.0 Client ID"
# 3. Select "iOS" as application type
# 4. Fill in:
#    - Name: Heu Calendar AI iOS Client
#    - Bundle ID: ai.heucalendar.app
# 5. Click "Create"
# 6. Note down:
#    - Client ID: [copy this - you'll need it]
#    - iOS URL scheme: [copy this - you'll need it]
# 7. Click "Download JSON"
# 8. Rename downloaded file to: GoogleService-Info.plist
# 9. Replace the existing GoogleService-Info.plist in your Xcode project
```

### Step 5: Publish OAuth Consent Screen
```bash
# 1. Go back to: APIs & Services > OAuth consent screen
# 2. Click "Publish App"
# 3. Confirm you want to make it public
# 4. Your app will be reviewed by Google (may take 1-7 days)
```

---

## 🔵 3. Microsoft Azure Portal Setup

**Create New App Registration for Heu Calendar AI**

### Step 1: Create New App Registration
```bash
# 1. Go to: https://portal.azure.com/
# 2. Sign in with your Microsoft account
# 3. Navigate to: Azure Active Directory
# 4. Click "App registrations" in left sidebar
# 5. Click "New registration"
# 6. Fill in:
#    - Name: Heu Calendar AI
#    - Supported account types: "Accounts in any organizational directory and personal Microsoft accounts"
#    - Redirect URI: Leave blank for now
# 7. Click "Register"
# 8. Note down the "Application (client) ID" - you'll need this
```

### Step 2: Configure Authentication
```bash
# 1. In your new app registration, click "Authentication"
# 2. Click "Add a platform"
# 3. Select "iOS / macOS"
# 4. Fill in:
#    - Bundle ID: ai.heucalendar.app
# 5. Click "Configure"
# 6. Under "Redirect URIs", you should now see:
#    msauth.ai.heucalendar.app://auth
# 7. Under "Advanced settings":
#    - Enable "Allow public client flows": YES
# 8. Click "Save"
```

### Step 3: Configure API Permissions
```bash
# 1. Click "API permissions"
# 2. Click "Add a permission"
# 3. Click "Microsoft Graph"
# 4. Click "Delegated permissions"
# 5. Search and add these permissions:
#    ✅ Calendars.ReadWrite (Read and write user calendars)
#    ✅ User.Read (Sign in and read user profile)
# 6. Click "Add permissions"
# 7. Click "Grant admin consent for [your organization]" if required
# 8. Ensure all permissions show green checkmarks
```

### Step 4: Configure Optional Claims (for better UX)
```bash
# 1. Click "Token configuration"
# 2. Click "Add optional claim"
# 3. Select "ID" token type
# 4. Check these claims:
#    ✅ email
#    ✅ family_name
#    ✅ given_name
# 5. Click "Add"
# 6. If prompted about Graph permissions, click "Yes"
```

### Step 5: Update Your App's Info.plist
```bash
# 1. Note your Application (client) ID from the Overview page
# 2. Update CalAI/SupportingFiles/Info.plist:
#    Replace MSALClientID value with your new Application (client) ID
# 3. Verify the redirect URI is correct:
#    msauth.ai.heucalendar.app://auth
```

---

## 🔧 4. Xcode Project Configuration Updates

**Update Target Settings with New Configurations**

### Step 1: Update Bundle Identifier and Display Name
```bash
# 1. Open CalAI.xcodeproj in Xcode
# 2. Select "CalAI" target in project navigator
# 3. Go to "General" tab
# 4. Update:
#    - Bundle Identifier: ai.heucalendar.app
#    - Display Name: Heu Calendar AI
#    - Version: 1.0
#    - Build: 1
```

### Step 2: Install New Provisioning Profiles
```bash
# 1. Double-click downloaded .mobileprovision files from Apple Developer Portal
# 2. They will be installed automatically
# 3. In Xcode, go to "Signing & Capabilities" tab
# 4. Select "Automatically manage signing" or manually select your profiles
# 5. Verify your Apple Developer Team is selected
```

### Step 3: Verify Capabilities
```bash
# 1. In "Signing & Capabilities" tab, ensure these are enabled:
#    ✅ iCloud (with CloudKit and Documents)
#    ✅ App Groups (with group.ai.heucalendar.app)
#    ✅ Keychain Sharing (with access groups)
#    ✅ WeatherKit
# 2. If any are missing, click "+ Capability" to add them
```

### Step 4: Update GoogleService-Info.plist
```bash
# 1. Delete the old GoogleService-Info.plist from your project
# 2. Drag the new GoogleService-Info.plist (downloaded from Google Cloud Console) into your Xcode project
# 3. Ensure "Add to target" is checked for CalAI target
# 4. Verify the bundle identifier in the file matches: ai.heucalendar.app
```

### Step 5: Update Info.plist with New Microsoft Client ID
```bash
# 1. Open CalAI/SupportingFiles/Info.plist
# 2. Find the MSALClientID key
# 3. Replace the value with your new Microsoft Application (client) ID
# 4. Verify the URL schemes are correct:
#    - ai.heucalendar.ios (for deep links)
#    - [Google URL scheme from GoogleService-Info.plist]
#    - msauth.ai.heucalendar.app (for Microsoft)
```

---

## 📋 **New Configuration Summary**

After completing all setups, you should have:

### Apple Developer Portal
- **App ID**: `ai.heucalendar.app`
- **iCloud Container**: `iCloud.ai.heucalendar.app`
- **App Group**: `group.ai.heucalendar.app`
- **Development Profile**: Downloaded and installed
- **Distribution Profile**: Downloaded and installed

### Google Cloud Console
- **Project**: `heu-calendar-ai` (or updated existing)
- **OAuth Client ID**: New iOS client with bundle `ai.heucalendar.app`
- **GoogleService-Info.plist**: Downloaded and added to Xcode
- **Calendar API**: Enabled
- **Consent Screen**: Published

### Microsoft Azure Portal
- **App Registration**: "Heu Calendar AI"
- **Application ID**: New client ID (update in Info.plist)
- **Redirect URI**: `msauth.ai.heucalendar.app://auth`
- **Permissions**: Calendars.ReadWrite, User.Read (consented)

### Xcode Project
- **Bundle ID**: `ai.heucalendar.app`
- **Display Name**: "Heu Calendar AI"
- **Provisioning**: New profiles installed
- **Capabilities**: All required capabilities enabled
- **GoogleService-Info.plist**: Updated with new configuration
- **MSALClientID**: Updated with new Microsoft client ID

---

## 📱 Testing Checklist

After completing OAuth provider updates:

### Pre-Testing Setup
- [ ] Download new GoogleService-Info.plist from Google Cloud Console
- [ ] Replace existing GoogleService-Info.plist in Xcode project
- [ ] Update Xcode target bundle identifier to `com.heucalendar.ai`
- [ ] Update Xcode target display name to "Heu Calendar AI"
- [ ] Regenerate and install new provisioning profiles

### Authentication Flow Testing
- [ ] **Google OAuth**: Test sign-in flow works with new bundle ID
- [ ] **Microsoft OAuth**: Test sign-in flow works with new redirect URI
- [ ] **Deep Links**: Test `ai.heucalendar.ios://morning-briefing` opens app
- [ ] **Keychain**: Verify tokens persist after app restart (test on physical device)
- [ ] **iCloud Sync**: Verify CloudKit sync works with new container

### Device Testing Requirements
- [ ] Test on **physical device** (not simulator) for keychain functionality
- [ ] Test with fresh app install (no cached tokens)
- [ ] Test OAuth sign-out and sign-in flows
- [ ] Verify calendar access works after authentication
- [ ] Test background token refresh functionality

---

## 🔧 File Summary: What Was Changed

### Core Configuration Files
```
/CalAI/SupportingFiles/Info.plist
├── App URL scheme: calai → ai.heucalendar.ios
├── App display name references: CalAI → Heu Calendar AI
├── Privacy descriptions: Updated all to reference new name
└── Microsoft redirect: msauth.com.rasheuristics.calendarweaver → msauth.com.heucalendar.ai

/CalAI/SupportingFiles/CalAI.entitlements
├── Application groups: group.com.rasheuristics.calendarweaver → group.com.heucalendar.ai
└── Keychain groups: com.rasheuristics.calendarweaver → com.heucalendar.ai

/CalAI/Utilities/SecureStorage.swift
├── Bundle identifier: com.rasheuristics.calendarweaver → com.heucalendar.ai
└── Keychain access group: com.rasheuristics.calendarweaver → com.heucalendar.ai
```

### Application Logic Files
```
/CalAI/ContentView.swift
└── Deep link scheme validation: "calai" → "ai.heucalendar.ios"

/CalAI/CrossDeviceSyncManager.swift
└── CloudKit container: iCloud.com.calai.CalAI → iCloud.com.heucalendar.ai

/CalAI/Services/CacheManager.swift
└── Cache directory: CalAICache → HeuCalendarAICache

/CalAI/Services/TutorialCoordinator.swift
└── Tutorial text: CalAI → Heu Calendar AI references
```

---

## ⚠️ Important Notes

### OAuth Provider Dependencies
- **Google**: Requires new GoogleService-Info.plist with updated bundle ID
- **Microsoft**: Redirect URI already updated in Info.plist, needs Azure portal update
- **Apple**: Requires new App ID, iCloud container, and provisioning profiles

### Breaking Changes
- **iCloud Data**: Changing CloudKit container will lose existing sync data
- **Keychain**: New keychain access groups will require fresh OAuth tokens
- **Deep Links**: External apps linking with old `calai://` scheme will break

### Migration Considerations
- Users will need to re-authenticate with Google and Microsoft
- Existing iCloud sync data will not migrate automatically
- Deep link bookmarks/shortcuts will need updating

---

## 🚀 Deployment Order

1. **Update Apple Developer Portal** (App ID, iCloud, App Groups)
2. **Update Google Cloud Console** (OAuth client bundle ID)
3. **Update Microsoft Azure Portal** (redirect URI)
4. **Update Xcode Project** (bundle ID, display name, capabilities)
5. **Test OAuth flows** on physical device
6. **Deploy to TestFlight** for additional testing
7. **Submit to App Store** with updated metadata

---

## 📞 Support Resources

### OAuth Configuration Help
- **Google**: [iOS OAuth Setup Guide](https://developers.google.com/identity/sign-in/ios)
- **Microsoft**: [MSAL iOS Configuration](https://docs.microsoft.com/en-us/azure/active-directory/develop/msal-configuration)
- **Apple**: [App ID Configuration](https://developer.apple.com/help/account/manage-identifiers/)

### Project Configuration Files
- Current GoogleService-Info.plist: `43431862733-2ath0e407kaj4m8n8faj5nt6orhf6vlo`
- Microsoft App ID: `1caae4b2-4f30-49d9-b486-5229dc148c3f`
- Bundle ID (new): `ai.heucalendar.app`
- URL Scheme (new): `ai.heucalendar.ios`

---

*Document created: November 2024*
*App Version: v0.0.4b1 → Heu Calendar AI v1.0*