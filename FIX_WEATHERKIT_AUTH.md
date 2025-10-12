# Fix WeatherKit Authentication (For Paid Developer Accounts)

## The Issue

You have a paid Apple Developer account, but WeatherKit still fails with Error 2.

**This happens because:** The WeatherKit capability isn't properly synced with your Apple Developer Portal.

## How to Fix (5 Minutes)

### Step 1: Open Xcode Project

1. Open `CalAI.xcodeproj` in Xcode
2. Click on **CalAI** project in the navigator (top of left panel)
3. Select **CalAI** target (under TARGETS)
4. Click **Signing & Capabilities** tab (top)

### Step 2: Check Your Team

1. Under **Signing**, look at **Team**
2. Make sure your **paid Apple Developer team** is selected
3. **NOT** "Personal Team" (that's the free account)

**If you see "Personal Team":**
- Click the dropdown
- Select your paid team (will show your name or company name)

### Step 3: Remove and Re-add WeatherKit Capability

This forces Xcode to re-register the capability with Apple:

1. In **Signing & Capabilities** tab, look for **WeatherKit** capability
2. Hover over "WeatherKit" and click the **X** (remove)
3. Click **+ Capability** button (top left)
4. Search for "WeatherKit"
5. Click **WeatherKit** to add it back

### Step 4: Clean and Rebuild

1. In Xcode menu: **Product** → **Clean Build Folder** (or `Cmd+Shift+K`)
2. Close Xcode completely
3. Reopen Xcode
4. Build and run on your device (not simulator)

### Step 5: Test Weather

1. Open Morning Briefing
2. Tap "Test Weather Fetch"
3. Should work now!

## Why This Happens

When you:
- Switch between teams
- Change bundle identifier
- Add capabilities manually in .entitlements file
- Sign in with different Apple ID

Xcode doesn't always sync the capability with Apple's servers properly.

**The fix:** Removing and re-adding forces Xcode to:
1. Contact Apple's servers
2. Verify your paid account
3. Register the WeatherKit capability
4. Update provisioning profile

## Verification Checklist

Before testing, verify:

- [ ] **Signed in with paid Apple Developer account** in Xcode Preferences → Accounts
- [ ] **Team is NOT "Personal Team"** in Signing & Capabilities
- [ ] **WeatherKit capability exists** in Signing & Capabilities
- [ ] **Bundle ID matches** your Apple Developer Portal (com.rasheuristics.calendarweaver)
- [ ] **Device is registered** in Apple Developer Portal
- [ ] **Testing on physical device** (not simulator - WeatherKit can be flaky on simulators)

## Alternative: Check Apple Developer Portal

If removing/re-adding doesn't work:

### Step 1: Go to Developer Portal
1. Go to: https://developer.apple.com/account
2. Sign in with your paid Apple Developer account
3. Click **Certificates, Identifiers & Profiles**

### Step 2: Check App ID
1. Click **Identifiers** (left sidebar)
2. Find your app: `com.rasheuristics.calendarweaver`
3. Click on it
4. Scroll down to **App Services**
5. **WeatherKit** should have a checkmark ✓

**If WeatherKit is NOT checked:**
- Check the WeatherKit box
- Click **Save** (top right)
- Go back to Xcode
- Clean build and rebuild

### Step 3: Regenerate Provisioning Profile
1. In Developer Portal, click **Profiles** (left sidebar)
2. Find your app's provisioning profile
3. Click **Edit**
4. Click **Generate** or **Save**
5. Download the new profile
6. In Xcode: Preferences → Accounts → Download Manual Profiles

## Common Issues

### Issue 1: "Personal Team" Selected
**Symptom:** Team shows "Your Name (Personal Team)"
**Fix:**
1. Xcode → Preferences → Accounts
2. Make sure your paid Apple Developer account is signed in
3. In Signing & Capabilities, change Team to your paid team

### Issue 2: Bundle ID Mismatch
**Symptom:** Error says bundle ID doesn't match
**Fix:**
1. Check Bundle Identifier in General tab: `com.rasheuristics.calendarweaver`
2. Make sure it matches in Developer Portal
3. If changed, remove and re-add WeatherKit capability

### Issue 3: Provisioning Profile Issue
**Symptom:** "Failed to register bundle identifier"
**Fix:**
1. Delete old provisioning profiles: Xcode → Preferences → Accounts → Team → Manage Certificates → Delete old profiles
2. Let Xcode automatically manage signing
3. In Signing & Capabilities, check "Automatically manage signing"

### Issue 4: Device Not Registered
**Symptom:** Works in Xcode but fails when running
**Fix:**
1. Go to Developer Portal
2. Devices → Register your device
3. Add device UDID
4. Regenerate provisioning profile

## After Fixing

Once fixed, you should see:

1. **No more Error 2** when testing weather
2. **WeatherKit works** without falling back to OpenWeatherMap
3. **Weather appears** in morning briefing immediately

## Reverting My Changes (Optional)

If you want to use WeatherKit without the OpenWeatherMap fallback:

1. Open `WeatherService.swift`
2. Remove the fallback code (lines 157-164)
3. Change back to just reporting the error

But I'd recommend **keeping the fallback** - it's a safety net in case WeatherKit has issues.

## Testing After Fix

1. **Clean build** (`Cmd+Shift+K`)
2. **Rebuild and run** on device
3. **Open Morning Briefing**
4. **Tap "Test Weather Fetch"**
5. Should see: "✅ Weather Fetch Successful!" with temperature
6. **Refresh briefing** - weather appears!

## Summary

The fix is simple:
1. ✅ Select paid team (not Personal Team)
2. ✅ Remove WeatherKit capability
3. ✅ Re-add WeatherKit capability
4. ✅ Clean build and run

This forces Xcode to properly authenticate with Apple's WeatherKit servers using your paid account.

Let me know if this fixes it!
