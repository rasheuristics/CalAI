#!/bin/bash

# Add test files to Xcode project
# This script helps add the test files if GUI method is not preferred

echo "🧪 Adding test files to Xcode project..."
echo ""

PROJECT_FILE="CalAI.xcodeproj/project.pbxproj"

# Check if project file exists
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: $PROJECT_FILE not found"
    echo "Please run this script from the CalAI project root directory"
    exit 1
fi

echo "⚠️  IMPORTANT: This script will attempt to add files to your Xcode project."
echo "It's recommended to:"
echo "  1. Commit your current changes first"
echo "  2. Use Xcode GUI method instead (see SETUP_CODE_COVERAGE.md)"
echo ""
echo "Test files to add:"
echo "  - CalAI/Tests/Helpers/TestHelpers.swift"
echo "  - CalAI/Tests/Mocks/MockEventStore.swift"
echo "  - CalAI/Tests/Managers/CalendarManagerTests.swift"
echo "  - CalAI/Tests/Managers/AIManagerTests.swift"
echo "  - CalAI/Tests/Managers/SyncManagerTests.swift"
echo ""

read -p "Do you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cancelled."
    exit 0
fi

echo ""
echo "✅ Opening Xcode project..."
open CalAI.xcodeproj

echo ""
echo "📋 Next steps in Xcode:"
echo ""
echo "1. In Project Navigator (left sidebar), find the 'Tests' folder"
echo ""
echo "2. Drag these files from Finder into the Tests folder:"
echo "   - CalAI/Tests/Helpers/TestHelpers.swift"
echo "   - CalAI/Tests/Mocks/MockEventStore.swift"
echo "   - CalAI/Tests/Managers/CalendarManagerTests.swift"
echo "   - CalAI/Tests/Managers/AIManagerTests.swift"
echo "   - CalAI/Tests/Managers/SyncManagerTests.swift"
echo ""
echo "3. In the dialog that appears:"
echo "   ✅ Check 'Add to targets: CalAITests'"
echo "   ⬜ Uncheck 'Add to targets: CalAI'"
echo ""
echo "4. Enable code coverage:"
echo "   - Click scheme dropdown (top left)"
echo "   - Edit Scheme... (⌘<)"
echo "   - Click 'Test' in sidebar"
echo "   - Check ✅ 'Code Coverage'"
echo ""
echo "5. Run tests: Press ⌘U"
echo ""
echo "See SETUP_CODE_COVERAGE.md for detailed instructions with screenshots"
