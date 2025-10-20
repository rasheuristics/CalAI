# WeatherKit Fix Guide - Automatic Signing

**Issue:** WeatherKit authentication failing with "Error 2" - Provisioning profile missing WeatherKit entitlement

**Solution:** Add WeatherKit capability in Xcode (5 minutes)

**Status:** ✅ Entitlement already in code, just needs Xcode sync

---

## Prerequisites

- ✅ Active Apple Developer Account
- ✅ Xcode installed
- ✅ Project using Automatic Signing
- ✅ Internet connection

---

## Step-by-Step Instructions

### Step 1: Open Project in Xcode

1. Launch **Xcode**
2. Open `CalAI.xcodeproj` from:
   ```
   /Users/btessema/Desktop/CalAI/CalAI/CalAI.xcodeproj
   ```
3. Wait for Xcode to fully load the project

---

### Step 2: Navigate to Signing & Capabilities

1. In the **Project Navigator** (left sidebar), click on **CalAI** (blue icon at top)
2. Select the **CalAI** target (under TARGETS section)
3. Click the **Signing & Capabilities** tab at the top

You should see:
```
✓ Signing (Automatically manage signing ✓)
✓ Keychain Sharing
```

---

### Step 3: Add WeatherKit Capability

1. Click the **"+ Capability"** button (top-left of the Signing & Capabilities pane)
2. In the search box, type: **WeatherKit**
3. Double-click **"WeatherKit"** to add it

**What happens automatically:**
- ✅ Xcode contacts Apple Developer Portal
- ✅ Updates App Identifier: `com.rasheuristics.calendarweaver`
- ✅ Generates new provisioning profile with WeatherKit
- ✅ Downloads and installs profile automatically
- ✅ Updates entitlements file

**Expected result:**
You should now see:
```
✓ Signing (Automatically manage signing ✓)
✓ Keychain Sharing
✓ WeatherKit  ← NEW!
```

---

### Step 4: Clean Build Folder

1. In Xcode menu: **Product** → **Clean Build Folder** (⇧⌘K)
2. Wait for "Clean Succeeded" message

---

### Step 5: Rebuild and Test

1. Build the project: **Product** → **Build** (⌘B)
2. Run on device: **Product** → **Run** (⌘R)
3. Navigate to Morning Briefing
4. Grant location permission when prompted
5. Verify weather data displays

---

## Success Criteria

✅ **Fix Complete When:**
1. WeatherKit capability visible in Xcode
2. Project builds successfully
3. Weather data appears in Morning Briefing
4. No "Error 2" in console logs

---

**Estimated Time:** 5 minutes
**Difficulty:** ⭐ Easy
