#!/bin/bash

echo "================================================"
echo "🌦️  WeatherKit Fix Script"
echo "================================================"
echo ""
echo "This script will fix WeatherKit Error 2 by:"
echo "1. Removing old provisioning profiles"
echo "2. Forcing Xcode to regenerate them with WeatherKit"
echo ""

# Check if Xcode is running
if pgrep -x "Xcode" > /dev/null; then
    echo "⚠️  Xcode is currently running."
    echo "Please QUIT Xcode completely before running this script."
    echo ""
    read -p "Press Enter once Xcode is closed..."
fi

echo "🗑️  Step 1: Removing old provisioning profiles..."
PROFILE_DIR=~/Library/MobileDevice/Provisioning\ Profiles
if [ -d "$PROFILE_DIR" ]; then
    rm -rf "$PROFILE_DIR"/*
    echo "✅ Removed old provisioning profiles"
else
    echo "ℹ️  No profiles directory found (this is okay)"
fi

echo ""
echo "🧹 Step 2: Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/CalAI-*
echo "✅ Cleaned DerivedData"

echo ""
echo "================================================"
echo "✅ Cleanup Complete!"
echo "================================================"
echo ""
echo "Next steps:"
echo "1. Open CalAI.xcodeproj in Xcode"
echo "2. Go to: CalAI target → Signing & Capabilities"
echo "3. Xcode will automatically download new profiles"
echo "4. Look for 'Provisioning Profile: [Your Team] - CalAI'"
echo "5. If you see an error, click 'Try Again' or 'Download Profile'"
echo "6. Build and run (Cmd+R)"
echo ""
echo "Expected result in console:"
echo "  ✅ WeatherKit available on this device"
echo "  ✅ Weather fetched successfully: 72°, Partly Cloudy"
echo ""
echo "If you still see Error 2, make sure WeatherKit is enabled"
echo "in your Apple Developer account for the CalAI App ID."
echo ""
