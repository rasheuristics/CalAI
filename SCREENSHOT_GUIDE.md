# CalAI App Store Screenshot Guide

## Required Screenshot Sizes

### iPhone Screenshots
1. **iPhone 6.7"** (Required) - 1290 x 2796 px (2796 x 1290 landscape)
   - iPhone 15 Pro Max, 15 Plus
   - iPhone 14 Pro Max, 14 Plus
   - iPhone 13 Pro Max, 12 Pro Max

2. **iPhone 6.5"** (Required) - 1242 x 2688 px (2688 x 1242 landscape)
   - iPhone 11 Pro Max, 11, XS Max, XR

### iPad Screenshots (if supporting iPad)
1. **iPad Pro 12.9" (6th Gen)** (Required) - 2048 x 2732 px (2732 x 2048 landscape)
2. **iPad Pro 12.9" (2nd Gen)** (Optional) - 2048 x 2732 px

---

## How to Capture Screenshots

### Option 1: Using Simulator (Recommended for Consistency)

#### Setup Simulator
```bash
# Open specific simulator
xcrun simctl list devices | grep "iPhone 15 Pro Max"
open -a Simulator --args -CurrentDeviceUDID <device-id>

# Or launch from Xcode:
# Product → Destination → iPhone 15 Pro Max
# Run the app (Cmd + R)
```

#### Capture Screenshots
1. **In Simulator:**
   - Navigate to the screen you want to capture
   - Press `Cmd + S` to save screenshot
   - Screenshots save to Desktop by default
   - File name format: `Simulator Screen Shot - Device - DateTime.png`

2. **Verify Dimensions:**
   ```bash
   # Check screenshot size
   sips -g pixelWidth -g pixelHeight screenshot.png
   ```

#### Simulator Devices for Each Size:
- **6.7":** iPhone 15 Pro Max, iPhone 14 Pro Max
- **6.5":** iPhone 11 Pro Max, iPhone XS Max
- **iPad 12.9":** iPad Pro (12.9-inch) (6th generation)

---

### Option 2: Using Physical Device

#### Capture on Device
1. Press **Volume Up + Side Button** simultaneously
2. Screenshot appears in bottom-left corner
3. Tap to preview, swipe away to save
4. Screenshots save to Photos app

#### Transfer to Mac
1. Connect device via USB
2. Open **Image Capture** app
3. Select your device
4. Select screenshots
5. Click **Import** to download

#### Resize for App Store (if needed)
Most modern iPhones capture at correct resolution, but verify:
```bash
# Resize if needed using ImageMagick
brew install imagemagick
magick screenshot.png -resize 1290x2796 resized.png

# Or use sips (built-in macOS)
sips -z 2796 1290 screenshot.png --out resized.png
```

---

## Screenshot Content Plan

### Screenshot 1: Day View - Home Screen
**Purpose:** First impression - beautiful, clean interface

**Setup:**
1. Navigate to Day view
2. Add 4-5 sample events with varying times:
   - 9:00 AM - Team Standup
   - 11:00 AM - Client Presentation (with location)
   - 1:00 PM - Lunch Meeting
   - 3:00 PM - Project Review (Zoom link)
   - 5:00 PM - Doctor Appointment (with location)
3. Mix event colors (different calendars)
4. Current time indicator should be visible
5. Clean, uncluttered view

**Text Overlay:**
- Title: "Your Day at a Glance"
- Subtitle: "Beautiful, intuitive calendar interface"

**Screenshot Checklist:**
- [ ] 4-5 events visible
- [ ] Current time indicator showing
- [ ] Multiple calendar colors
- [ ] Clear time labels
- [ ] Navigation buttons visible

---

### Screenshot 2: Smart Notification - Travel Alert
**Purpose:** Highlight intelligent travel time feature

**Setup:**
1. Create an event with a physical location (e.g., "Coffee Shop, 123 Main St")
2. Enable travel time notifications
3. Wait for or simulate a travel time notification
4. Capture notification banner or notification center

**Alternative:** Show notification settings with travel time toggle

**Text Overlay:**
- Title: "Never Miss a Meeting"
- Subtitle: "Smart travel alerts with real-time traffic"

**Screenshot Checklist:**
- [ ] Notification clearly visible
- [ ] Shows travel time/departure time
- [ ] Event location visible
- [ ] "Get Directions" action visible
- [ ] Time-sensitive indicator present

---

### Screenshot 3: Multi-Calendar Integration
**Purpose:** Showcase calendar source management

**Setup:**
1. Navigate to Settings → Calendar Accounts
2. Show connected calendars:
   - Google Calendar (connected, green checkmark)
   - Outlook Calendar (connected, green checkmark)
   - Apple Calendar (connected, green checkmark)
3. Show sync status "Last synced: Just now"

**Text Overlay:**
- Title: "All Your Calendars, One Place"
- Subtitle: "Seamlessly sync Google, Outlook & Apple calendars"

**Screenshot Checklist:**
- [ ] All three calendar types visible
- [ ] Connection status shown
- [ ] Sync indicators visible
- [ ] Clean settings interface
- [ ] Add account button visible

---

### Screenshot 4: Week View
**Purpose:** Show alternative view option and multi-day planning

**Setup:**
1. Navigate to Week view
2. Show current week with varied event distribution
3. Multiple events on different days
4. Mix of short and long events
5. Today's column highlighted

**Text Overlay:**
- Title: "See Your Week Ahead"
- Subtitle: "Multiple views: Day, Week, Month, Year"

**Screenshot Checklist:**
- [ ] 7 days visible
- [ ] Current day highlighted
- [ ] Multiple events across days
- [ ] Time grid visible
- [ ] Navigation controls shown

---

### Screenshot 5: Notification Preferences
**Purpose:** Demonstrate customization options

**Setup:**
1. Navigate to Settings → Advanced Settings → Notification Settings
2. Show notification type toggles:
   - 15-minute reminder (ON)
   - Travel time alert (ON)
   - Virtual meeting join alert (ON)
3. Show customization options (lead times, buffer times)

**Text Overlay:**
- Title: "Customize Your Alerts"
- Subtitle: "Control exactly when and how you're notified"

**Screenshot Checklist:**
- [ ] Multiple notification types shown
- [ ] Toggle switches visible
- [ ] Customization options displayed
- [ ] Clear labels and descriptions
- [ ] Settings organized in sections

---

### Screenshot 6: Month View
**Purpose:** Show long-term planning capability

**Setup:**
1. Navigate to Month view
2. Show current month with events distributed throughout
3. Color-coded event dots for different calendars
4. Current day circled or highlighted

**Text Overlay:**
- Title: "Plan Your Month"
- Subtitle: "See your entire schedule at a glance"

**Screenshot Checklist:**
- [ ] Full month calendar visible
- [ ] Multiple events (dots) on various dates
- [ ] Current day highlighted
- [ ] Color coding visible
- [ ] Month/year label clear

---

### Screenshot 7: Voice Commands (Optional)
**Purpose:** Highlight AI-powered voice features

**Setup:**
1. Tap microphone icon to activate voice input
2. Show voice input interface
3. Example text: "Create meeting tomorrow at 2pm with John"
4. Or show after voice command with event being created

**Text Overlay:**
- Title: "Schedule Hands-Free"
- Subtitle: "AI-powered voice commands for quick scheduling"

**Screenshot Checklist:**
- [ ] Microphone interface visible
- [ ] Voice input indication shown
- [ ] Example command text visible
- [ ] AI processing indicator
- [ ] Clean, focused interface

---

### Screenshot 8: Dark Mode
**Purpose:** Show dark mode support

**Setup:**
1. Enable Dark Mode (Settings → Display & Brightness → Dark)
2. Navigate to Day or Week view
3. Show same beautiful interface in dark theme
4. Events should be clearly visible against dark background

**Text Overlay:**
- Title: "Beautiful in Light and Dark"
- Subtitle: "Designed for iOS with attention to detail"

**Screenshot Checklist:**
- [ ] Dark background
- [ ] Events clearly visible
- [ ] Good contrast
- [ ] All UI elements readable
- [ ] Polished appearance

---

## Adding Text Overlays to Screenshots

### Tools for Adding Text/Graphics

**Option 1: Figma (Recommended)**
1. Create artboards matching screenshot dimensions
2. Import screenshots
3. Add text overlays with consistent styling
4. Export as PNG

**Option 2: Apple Keynote**
1. Create slides matching screenshot dimensions
2. Import screenshots as backgrounds
3. Add text boxes
4. Export as images

**Option 3: Photoshop/Sketch**
1. Create documents at exact screenshot dimensions
2. Import screenshots
3. Add text layers
4. Export for web (PNG)

**Option 4: Online Tools**
- Canva (canva.com) - Free templates available
- Screenshot.rocks - Quick mockup generator
- Placeit - Device mockup generator

### Text Overlay Style Guide

**Title Text:**
- Font: SF Pro Display Bold or Helvetica Bold
- Size: 80-100px
- Color: White or Black (high contrast with background)
- Position: Top third of screenshot
- Shadow: Optional drop shadow for readability

**Subtitle Text:**
- Font: SF Pro Display Regular or Helvetica Regular
- Size: 50-60px
- Color: Slightly transparent white/black (80% opacity)
- Position: Below title
- Line height: 1.2-1.4

**Background Gradient (Optional):**
- Add subtle gradient overlay at top for text readability
- Example: Linear gradient from rgba(0,0,0,0.6) to transparent

---

## Device Mockups (Optional but Recommended)

### Free Mockup Generators
1. **Screenshot.rocks**
   - URL: screenshot.rocks
   - Upload screenshot → choose device → download

2. **MockUPhone**
   - URL: mockuphone.com
   - Free device frames
   - Multiple device types

3. **Smartmockups**
   - URL: smartmockups.com
   - Free tier available
   - High-quality mockups

### DIY Device Frames
- Apple provides official device frames in design resources
- Download from: developer.apple.com/design/resources

---

## Screenshot Organization

### Naming Convention
```
CalAI_iPhone67_01_DayView.png
CalAI_iPhone67_02_SmartNotification.png
CalAI_iPhone67_03_MultiCalendar.png
CalAI_iPhone67_04_WeekView.png
CalAI_iPhone67_05_NotificationPrefs.png
CalAI_iPhone65_01_DayView.png
CalAI_iPhone65_02_SmartNotification.png
...
```

### Folder Structure
```
AppStoreAssets/
├── Screenshots/
│   ├── iPhone_6.7/
│   │   ├── 01_DayView.png
│   │   ├── 02_SmartNotification.png
│   │   └── ...
│   ├── iPhone_6.5/
│   │   └── ...
│   └── iPad_12.9/
│       └── ...
├── Icons/
│   └── AppIcon_1024.png
└── Previews/
    └── app_preview.mov
```

---

## Sample Event Data for Screenshots

Use these realistic events to populate your calendar:

### Morning Events
- 8:00 AM - Morning Workout (30 min)
- 9:00 AM - Team Standup (Zoom: https://zoom.us/j/123456789)
- 10:30 AM - Coffee with Sarah (Starbucks, 123 Main St)

### Afternoon Events
- 12:00 PM - Lunch Meeting (The Bistro, 456 Oak Ave)
- 2:00 PM - Client Presentation (Teams: https://teams.microsoft.com/l/...)
- 3:30 PM - Project Review (Meet: https://meet.google.com/abc-defg-hij)

### Evening Events
- 5:00 PM - Gym Session (24 Hour Fitness, 789 Elm St)
- 6:30 PM - Dinner with Family (Home)

### Color Coding
- Work events: Blue
- Personal events: Green
- Meetings with others: Orange
- Focus time: Purple

---

## Pre-Submission Checklist

### Screenshot Requirements
- [ ] Minimum 3 screenshots per device size (recommended 5-8)
- [ ] Maximum 10 screenshots per device size
- [ ] Correct dimensions for each device category
- [ ] PNG or JPEG format
- [ ] sRGB or P3 color space
- [ ] No transparency (alpha channel)
- [ ] File size under 500KB per screenshot (recommended)

### Screenshot Quality
- [ ] High resolution and sharp (no blur)
- [ ] Actual app interface (no mockups of non-existent features)
- [ ] Device status bar visible or hidden consistently
- [ ] Text overlays are readable
- [ ] Features shown actually work in the app
- [ ] No competitor branding visible
- [ ] No inappropriate content

### Screenshot Content
- [ ] Screenshots show actual app functionality
- [ ] Most important features highlighted first
- [ ] Consistent visual style across all screenshots
- [ ] Text overlays don't cover important UI
- [ ] Events use realistic, professional content
- [ ] No personal information visible (phone numbers, emails, addresses)

### App Store Connect Upload
- [ ] Screenshots uploaded in correct device categories
- [ ] Screenshots in correct order (first is most important)
- [ ] Localized screenshots if supporting multiple languages
- [ ] Preview video uploaded (optional but recommended)

---

## Screenshot Capture Workflow

### Step-by-Step Process

1. **Prepare App**
   - Build and run on simulator/device
   - Clear any test data
   - Add sample events (use list above)
   - Set up different calendar connections

2. **Capture Base Screenshots**
   - iPhone 6.7": Capture all 8 screenshots
   - iPhone 6.5": Capture all 8 screenshots
   - iPad 12.9": Capture relevant screenshots (if supporting iPad)

3. **Verify Screenshots**
   - Check dimensions
   - Verify clarity and sharpness
   - Ensure no sensitive data visible
   - Confirm UI elements are visible

4. **Add Text Overlays**
   - Import to design tool
   - Add titles and subtitles
   - Maintain consistent style
   - Export at original dimensions

5. **Optional: Add Device Mockups**
   - Upload to mockup generator
   - Download with device frames
   - Verify dimensions still match

6. **Organize Files**
   - Name consistently
   - Create folder structure
   - Keep both raw and edited versions

7. **Upload to App Store Connect**
   - Log in to App Store Connect
   - Navigate to app → Screenshots
   - Upload for each device size
   - Arrange in desired order

---

## Tips for Great Screenshots

### DO:
✅ Show your app's unique features
✅ Use real, realistic data
✅ Maintain consistent visual style
✅ Highlight benefits, not just features
✅ Put your best screenshot first
✅ Show the app in action
✅ Use high-quality text overlays
✅ Demonstrate value proposition

### DON'T:
❌ Use outdated app versions
❌ Show competitor apps or branding
❌ Include personal information
❌ Use low-resolution images
❌ Misrepresent app functionality
❌ Overcrowd with too much text
❌ Use poor contrast text
❌ Forget to check dimensions

---

## Quick Reference: Screenshot Dimensions

| Device Category | Portrait | Landscape |
|----------------|----------|-----------|
| iPhone 6.7" | 1290 x 2796 | 2796 x 1290 |
| iPhone 6.5" | 1242 x 2688 | 2688 x 1242 |
| iPhone 5.5" | 1242 x 2208 | 2208 x 1242 |
| iPad Pro 12.9" (6th) | 2048 x 2732 | 2732 x 2048 |
| iPad Pro 12.9" (2nd) | 2048 x 2732 | 2732 x 2048 |

---

**Ready to create stunning App Store screenshots!**

For questions or help, refer to Apple's official documentation:
https://developer.apple.com/app-store/product-page/
