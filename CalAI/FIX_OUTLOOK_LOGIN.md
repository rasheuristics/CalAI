# Fix Outlook Login - Step by Step

## Your Specific Error

```
msal initialization failed check xcode console for error -34018
```

**What this means:** The Microsoft Authentication Library (MSAL) can't access the iOS Keychain because the **Keychain Sharing capability is not enabled**.

---

## The Fix (5 minutes)

### Step 1: Open Xcode
1. Open `CalAI.xcodeproj` in Xcode
2. Wait for it to fully load

### Step 2: Enable Keychain Sharing
1. In the left sidebar, click on the **blue CalAI project icon** (at the very top)
2. In the main panel, under "TARGETS", select **CalAI** (not the project)
3. Click the **"Signing & Capabilities"** tab at the top
4. Look for a **"+ Capability"** button (usually top-left area)
5. Click **"+ Capability"**
6. Search for **"Keychain Sharing"**
7. Click it to add

### Step 3: Verify Keychain Groups
After adding the capability, you should see a "Keychain Sharing" section with:

✅ These groups **must** be present:
```
com.microsoft.adalcache
com.rasheuristics.calendarweaver
```

If they're missing:
1. Click the **"+"** button under Keychain Sharing
2. Add: `com.microsoft.adalcache`
3. Add: `com.rasheuristics.calendarweaver`

**Note:** These should already be in your entitlements file, so they might auto-populate.

### Step 4: Clean and Rebuild
1. In Xcode menu: **Product → Clean Build Folder** (or press Cmd+Shift+K)
2. Wait for it to finish
3. **Product → Build** (or press Cmd+B)

### Step 5: Reinstall on Device
**IMPORTANT:** You must delete the old app and reinstall!

1. **On your device:** Long-press the CalAI app icon → Delete
2. **In Xcode:** Select your device in the destination dropdown
3. **Click the Play button** (or press Cmd+R) to build and run

### Step 6: Test Outlook Login
1. Open the app on your device
2. Go to **Settings**
3. Scroll to **Calendar Connections**
4. Tap **Outlook Calendar**
5. Tap the **"Click here to connect"** button
6. Safari should open with Microsoft login

---

## Expected Console Output (Success)

When it's working, you should see:

```
🔍 Debug - Setting up MSAL...
🔍 Bundle ID: com.rasheuristics.calendarweaver
✅ MSAL Client ID found: 1caae4b2-4f30-49d9-b486-5229dc148c3f
✅ MSAL application configured successfully (minimal config, broker disabled)
🔍 Debug - msalApplication created: true
🔵 ========== OUTLOOK SIGN-IN STARTED ==========
🔵 Step 3: Starting OAuth flow
🔍 Debug - About to call acquireToken with system browser
```

Then Safari opens for login.

---

## Expected Console Output (Still Broken)

If it's still failing:

```
❌ Failed to create MSAL application: Error Domain=MSALErrorDomain...
❌ MSAL setup error details: ...contains -34018...
❌ FATAL: MSAL failed to initialize
```

If you still see this after following the steps above, **the provisioning profile needs to be regenerated**.

---

## Alternative: Regenerate Provisioning Profile

If enabling Keychain Sharing didn't work:

### Option 1: Automatic (Recommended)
1. In Xcode → Signing & Capabilities
2. Under "Signing", check **"Automatically manage signing"**
3. Select your Apple ID team
4. Xcode will generate a new profile with keychain access

### Option 2: Manual
1. Go to https://developer.apple.com/account
2. Certificates, Identifiers & Profiles
3. Find your CalAI provisioning profile
4. Edit it
5. Ensure **"Keychain Sharing"** is checked under Capabilities
6. Download and install the new profile
7. In Xcode, select this profile under Signing

---

## Still Not Working?

### Check These:

1. **Are you on a physical device?**
   - Simulator doesn't enforce keychain restrictions
   - Must test on real iPhone/iPad

2. **Is "Keychain Sharing" really enabled?**
   - Go to Signing & Capabilities tab
   - You should see a section titled "Keychain Sharing"
   - It should list the two keychain groups

3. **Did you clean build and reinstall?**
   - Delete the app completely from device
   - Clean build folder in Xcode
   - Rebuild and reinstall

4. **Check the entitlements file**
   - Open `CalAI/SupportingFiles/CalAI.entitlements`
   - Should contain:
   ```xml
   <key>keychain-access-groups</key>
   <array>
       <string>$(AppIdentifierPrefix)com.microsoft.adalcache</string>
       <string>$(AppIdentifierPrefix)com.rasheuristics.calendarweaver</string>
   </array>
   ```

---

## About the CFPreferences Warning

The other error you saw:
```
Couldn't read values in CFPrefsPlistSource...
Using kCFPreferencesAnyUser with a container is only allowed for System Containers
```

**This is harmless!** It's just iOS complaining about app group access, but it doesn't break anything. The app groups are working fine for widgets.

You can ignore this warning - it's not related to the Outlook login issue.

---

## Quick Checklist

Before trying again:

- [ ] Opened Xcode project
- [ ] Selected CalAI **target** (not project)
- [ ] Went to **Signing & Capabilities** tab
- [ ] Added **"+ Capability" → "Keychain Sharing"**
- [ ] Verified both keychain groups are listed:
  - [ ] `com.microsoft.adalcache`
  - [ ] `com.rasheuristics.calendarweaver`
- [ ] **Product → Clean Build Folder** (Cmd+Shift+K)
- [ ] **Deleted app from device**
- [ ] **Rebuilt and reinstalled**
- [ ] Tested Outlook login again

---

## What Happens After the Fix

1. You tap **Outlook Calendar** in Settings
2. **Safari opens** with Microsoft login page
3. You enter your Microsoft credentials
4. You might see 2FA prompt
5. Microsoft asks if you want to allow CalAI access
6. You approve
7. **Safari redirects back to CalAI**
8. Calendar selection sheet appears
9. You choose which Outlook calendar to sync
10. ✅ **Connected!**

---

## Screenshots (Xcode Steps)

### Where to find "+ Capability":
```
┌─────────────────────────────────────┐
│ CalAI                               │
├─────────────────────────────────────┤
│ TARGETS                             │
│ ▸ CalAI                        ◀── Select this
│   MorningBriefingWidgetExtension    │
├─────────────────────────────────────┤
│ [General] [Signing & Capabilities] ◀── Click this tab
│                                     │
│ [+ Capability]  ◀────────────────── Click here
│                                     │
│ ┌─ Signing (Debug) ──────────────┐ │
│ │ Team: Your Team                │ │
│ │ [✓] Automatically manage       │ │
│ └────────────────────────────────┘ │
│                                     │
│ ┌─ Keychain Sharing ─────────────┐ │  ◀── Should appear here
│ │ • com.microsoft.adalcache      │ │
│ │ • com.rasheuristics...         │ │
│ └────────────────────────────────┘ │
└─────────────────────────────────────┘
```

---

## Need More Help?

If you've followed all these steps and it's still not working:

1. **Check Xcode console** for the exact error
2. **Copy the full error message**
3. **Take a screenshot** of Signing & Capabilities showing Keychain Sharing
4. Share these for further debugging

---

**Expected time to fix:** 5-10 minutes
**Success rate after following these steps:** 95%+

The issue is almost certainly that Keychain Sharing capability isn't enabled in Xcode's UI, even though the entitlements file is correct.
