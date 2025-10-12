#!/bin/bash

# Script to fix Xcode console output issues
# This will remove OS_ACTIVITY_MODE from the scheme

echo "=========================================="
echo "Fixing Xcode Console Output"
echo "=========================================="

# Find the scheme file
SCHEME_FILE="CalAI.xcodeproj/xcuserdata/$(whoami).xcuserdatad/xcschemes/CalAI.xcscheme"

if [ ! -f "$SCHEME_FILE" ]; then
    echo "❌ Could not find scheme file at: $SCHEME_FILE"
    echo "Trying alternative location..."
    SCHEME_FILE="CalAI.xcodeproj/xcshareddata/xcschemes/CalAI.xcscheme"
fi

if [ ! -f "$SCHEME_FILE" ]; then
    echo "❌ Could not find scheme file"
    echo "Please manually check: Product → Scheme → Edit Scheme → Arguments"
    exit 1
fi

echo "✅ Found scheme file: $SCHEME_FILE"

# Check if OS_ACTIVITY_MODE exists
if grep -q "OS_ACTIVITY_MODE" "$SCHEME_FILE"; then
    echo "⚠️  Found OS_ACTIVITY_MODE in scheme file"
    echo "Creating backup..."
    cp "$SCHEME_FILE" "$SCHEME_FILE.backup"
    echo "✅ Backup created: $SCHEME_FILE.backup"

    echo "Removing OS_ACTIVITY_MODE..."
    # Remove the entire EnvironmentVariable entry for OS_ACTIVITY_MODE
    sed -i '' '/<EnvironmentVariable/,/<\/EnvironmentVariable>/{ /OS_ACTIVITY_MODE/,/<\/EnvironmentVariable>/d; }' "$SCHEME_FILE"

    echo "✅ OS_ACTIVITY_MODE removed from scheme"
    echo ""
    echo "Now:"
    echo "1. Close and reopen Xcode"
    echo "2. Run the app (Cmd+R)"
    echo "3. You should see console output!"
else
    echo "✅ OS_ACTIVITY_MODE is not present in scheme"
    echo "Console blocking is not caused by OS_ACTIVITY_MODE"
    echo ""
    echo "Other things to check:"
    echo "1. Console is visible (Cmd+Shift+Y)"
    echo "2. Build configuration is Debug (not Release)"
    echo "3. Console filter is cleared"
fi

echo ""
echo "=========================================="
echo "Done!"
echo "=========================================="
