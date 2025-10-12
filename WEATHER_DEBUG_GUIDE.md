# Weather Debug Guide

## How to Debug Weather Issues

### Step 1: Check Console Logs

When you run the app, you should see these logs in Xcode Console:

#### On App Startup:
```
📋 MorningBriefingService: Configuring...
📋 MorningBriefingService: WeatherService set to ✅ shared instance
🌦️ WeatherService: Current location status: <status>
📋 MorningBriefingService: Location permission requested
📋 MorningBriefingService: Configuration complete
```

#### When Generating Briefing:
```
📋 Starting briefing generation...
📋 CalendarManager configured, checking weather service...
✅ WeatherService is configured
📋 Fetching weather data...
🌦️ WeatherService: Checking location authorization - status: <status>
✅ WeatherService: Location authorized, requesting location...
✅ WeatherService: Location received - <lat>, <lon>
🌦️ WeatherService: Fetching weather for location: <lat>, <lon>
🌦️ WeatherService: Using WeatherKit (iOS 16+)
🌦️ WeatherService: Requesting weather from WeatherKit...
✅ WeatherService: WeatherKit data received - <temp>°C, <condition>
✅ WeatherService: Weather data converted and ready
✅ Weather fetched successfully: <temp>°, <condition>
📋 Briefing created:
   - Date: <date>
   - Weather: ✅ Available (<temp>°)
   - Events: <count>
   - Suggestions: <count>
```

### Step 2: Check Location Permission Status

Location authorization status codes:
- `0` = notDetermined (needs user approval)
- `1` = restricted
- `2` = denied
- `3` = authorizedAlways
- `4` = authorizedWhenInUse

### Step 3: Common Issues and Solutions

#### Issue: "WeatherService not configured"
**Symptom:** Log shows `❌ WeatherService not configured!`
**Solution:** Check that `MorningBriefingService.configure()` is called in ContentView.onAppear

#### Issue: "Location permission denied"
**Symptom:** Status is `2` (denied) or `1` (restricted)
**Solution:**
1. Go to iOS Settings → Privacy & Security → Location Services
2. Find "CalAI"
3. Change to "While Using the App" or "Always"
4. Restart the app

#### Issue: "Location permission not determined"
**Symptom:** Status is `0` and no permission popup appears
**Solution:**
1. Delete the app
2. Reinstall
3. When prompted, tap "Allow While Using App"

#### Issue: Weather fetch timeout
**Symptom:** No weather success or failure log after 30+ seconds
**Solution:**
1. Check device/simulator has internet connection
2. Check if WeatherKit entitlement is properly configured
3. Try on a physical device instead of simulator

#### Issue: "WeatherKit error"
**Symptom:** Log shows `❌ WeatherService: WeatherKit error - <error>`
**Solution:**
- Ensure you're using iOS 16+ (WeatherKit requirement)
- Verify WeatherKit entitlement is enabled in `.entitlements` file
- Check if you're signed in with a valid Apple Developer account
- Try cleaning build folder (Cmd+Shift+K) and rebuilding

#### Issue: Weather shows nil in briefing
**Symptom:** Briefing created log shows `Weather: ❌ Not available`
**Solution:**
1. Check earlier logs for `❌ Weather fetch failed: <reason>`
2. Address the specific error shown
3. Verify location permission is granted
4. Check internet connectivity

### Step 4: Testing on Simulator vs Device

**iOS Simulator:**
- WeatherKit works on iOS 16+ simulators
- Simulator uses Apple's default location (Cupertino, CA)
- To change location: Debug → Location → Custom Location

**Physical Device:**
- More reliable for location services
- Uses actual GPS coordinates
- Better for testing real-world scenarios

### Step 5: Manual Test Commands

To test weather service directly, add this to your view:

```swift
Button("Test Weather") {
    WeatherService.shared.fetchCurrentWeather { result in
        switch result {
        case .success(let weather):
            print("✅ Manual test success: \(weather.temperature)°")
        case .failure(let error):
            print("❌ Manual test failed: \(error)")
        }
    }
}
```

### Step 6: Check Info.plist

Verify these keys exist in Info.plist:
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>CalAI needs your location to calculate travel time to meeting locations and send timely departure notifications.</string>
```

### Step 7: Check Entitlements

Verify in `CalAI.entitlements`:
```xml
<key>com.apple.developer.weatherkit</key>
<true/>
```

## Expected Behavior

### First Launch:
1. App requests location permission
2. User taps "Allow While Using App"
3. Location is obtained
4. Weather is fetched
5. Morning briefing displays with weather

### Subsequent Launches:
1. Location permission already granted
2. Weather fetches automatically
3. Morning briefing displays with weather

## Still Having Issues?

1. Check all logs in Xcode Console (filter by 🌦️ or 📋)
2. Note the exact error message
3. Check which step in the flow is failing
4. Verify all prerequisites (iOS version, permissions, entitlements)
5. Try a clean build and restart

## Quick Checklist

- [ ] iOS 16+ (for WeatherKit)
- [ ] Location permission granted
- [ ] WeatherKit entitlement enabled
- [ ] Signed with valid Apple Developer account
- [ ] Internet connection available
- [ ] MorningBriefingService.configure() is called
- [ ] Location services enabled on device
- [ ] Info.plist has location usage description
