#!/bin/bash

echo "🔍 Verifying IntentClassifier.swift integration..."

PROJECT="/Users/btessema/Desktop/CalAI/CalAI"
cd "$PROJECT"

# Check file exists
if [ -f "CalAI/IntentClassifier.swift" ]; then
    echo "✅ File exists: CalAI/IntentClassifier.swift"
else
    echo "❌ File NOT found: CalAI/IntentClassifier.swift"
    exit 1
fi

# Check if in project.pbxproj
if grep -q "IntentClassifier.swift" CalAI.xcodeproj/project.pbxproj; then
    echo "✅ File referenced in project.pbxproj"
else
    echo "❌ File NOT in project.pbxproj"
    exit 1
fi

# Check if in Sources build phase
if grep -A200 "PBXSourcesBuildPhase" CalAI.xcodeproj/project.pbxproj | grep -q "IntentClassifier.swift in Sources"; then
    echo "✅ File in Sources build phase"
else
    echo "❌ File NOT in Sources build phase"
    exit 1
fi

# Check file compiles
echo ""
echo "🔨 Testing compilation..."
swiftc -typecheck CalAI/IntentClassifier.swift \
    -sdk $(xcrun --show-sdk-path --sdk iphonesimulator) \
    -target arm64-apple-ios16.0-simulator 2>&1

if [ $? -eq 0 ]; then
    echo "✅ IntentClassifier.swift compiles successfully"
else
    echo "❌ Compilation failed"
    exit 1
fi

echo ""
echo "✅ All checks passed!"
echo ""
echo "If Xcode still shows an error, try:"
echo "1. Close Xcode"
echo "2. rm -rf ~/Library/Developer/Xcode/DerivedData/CalAI-*"
echo "3. Reopen Xcode and let it re-index"
echo "4. Product → Clean Build Folder"
echo "5. Product → Build"
