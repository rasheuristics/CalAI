# WeatherKit Error 2 Fix Guide

## Problem
You're getting: `WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors error 2`

This means WeatherKit authentication is failing even though you have:
- ✅ Paid Apple Developer Account
- ✅ WeatherKit enabled in Developer Portal
- ✅ WeatherKit entitlement in CalAI.entitlements file

## The Solution: Regenerate Provisioning Profile

### Option A: Let Xcode Auto-Generate (Recommended)

1. Open Xcode project
2. Select **CalAI** target (top-left)
3. Go to **Signing & Capabilities** tab
4. Under **Team**, click the dropdown and:
   - Select "None"
   - Then select your team again
5. This forces Xcode to regenerate the provisioning profile with WeatherKit
6. Clean Build Folder (Cmd+Shift+K)
7. Build and Run (Cmd+R)

### Option B: Manual Provisioning Profile Regeneration

1. Go to: https://developer.apple.com/account/resources/profiles/list
2. Find your provisioning profile for `com.rasheuristics.calendarweaver`
3. Click on it and click **Delete**
4. Click **+** to create a new profile
5. Choose **iOS App Development** (or Distribution if releasing)
6. Select your App ID: `com.rasheuristics.calendarweaver`
7. Select your certificate
8. Select your device
9. Give it a name and click **Generate**
10. Download the profile
11. Double-click to install it in Xcode
12. In Xcode → Signing & Capabilities → Select the new profile
13. Clean Build Folder (Cmd+Shift+K)
14. Build and Run (Cmd+R)

### Option C: Add WeatherKit Capability in Xcode

1. Open Xcode project
2. Select **CalAI** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** (top-left)
5. Search for "WeatherKit"
6. Add it (even though entitlements file already has it)
7. This forces Xcode to update the profile
8. Clean Build Folder (Cmd+Shift+K)
9. Build and Run (Cmd+R)

## Verify Fix

After following one of the above options, run the app and check console:
- ✅ Should see: `WeatherKit data received`
- ❌ If still error 2: Try Option B (manual profile regeneration)

## If Still Not Working

The issue might be that WeatherKit service is not activated for your account:
1. Go to: https://developer.apple.com/account
2. Click on your account name (top-right)
3. Verify you have a **paid** Apple Developer Program membership
4. WeatherKit requires an **active paid subscription** (not expired)
