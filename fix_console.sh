#!/bin/bash

echo "🔧 Fixing Xcode Console Logging..."
echo ""

# Step 1: Kill all Xcode processes
echo "1️⃣ Killing Xcode processes..."
killall Xcode 2>/dev/null
killall "Xcode Helper" 2>/dev/null
killall simctl 2>/dev/null
sleep 2

# Step 2: Clear DerivedData
echo "2️⃣ Clearing DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
echo "   ✅ DerivedData cleared"

# Step 3: Clear console logs
echo "3️⃣ Clearing console log cache..."
rm -rf ~/Library/Developer/Xcode/UserData/IDEEditorInteractivityHistory
rm -rf ~/Library/Logs/DiagnosticReports/Xcode*
echo "   ✅ Console cache cleared"

# Step 4: Kill simulators
echo "4️⃣ Killing simulators..."
killall Simulator 2>/dev/null
xcrun simctl shutdown all 2>/dev/null
sleep 2

echo ""
echo "✅ Console fix complete!"
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. Clean Build Folder (Cmd+Shift+K)"
echo "3. Build and Run (Cmd+R)"
echo "4. Make sure Console is visible (Cmd+Shift+Y)"
echo "5. Check filter in bottom-right of console (should show 'All Output')"
