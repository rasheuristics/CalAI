#!/bin/bash

echo "================================================"
echo "🔧 Force Provisioning Profile Regeneration"
echo "================================================"
echo ""
echo "This script will:"
echo "1. Delete ALL provisioning profiles for your team"
echo "2. Clear Xcode's profile cache"
echo "3. Force Xcode to download fresh profiles"
echo ""

read -p "⚠️  This will delete all local profiles. Continue? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 1
fi

echo ""
echo "🛑 Checking if Xcode is running..."
if pgrep -x "Xcode" > /dev/null; then
    echo "⚠️  Please quit Xcode first!"
    exit 1
fi

echo "🗑️  Deleting provisioning profiles..."
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*
echo "✅ Deleted profiles"

echo "🗑️  Clearing Xcode derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
echo "✅ Cleared derived data"

echo "🗑️  Clearing Xcode caches..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode/*
echo "✅ Cleared caches"

echo ""
echo "================================================"
echo "✅ Complete!"
echo "================================================"
echo ""
echo "NOW:"
echo "1. Open Xcode"
echo "2. Open your CalAI project"
echo "3. Go to Xcode → Settings → Accounts"
echo "4. Select your Apple ID"
echo "5. Click 'Download Manual Profiles'"
echo "6. Go to your project → Signing & Capabilities"
echo "7. Toggle 'Automatically manage signing' OFF then ON"
echo "8. Build and run"
echo ""
