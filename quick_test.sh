#!/bin/bash

echo "🚀 Quick Test for A, B, C Improvements"
echo "======================================="
echo ""

# Test A: Check for on-device AI support
echo "📱 TEST A: On-Device Apple LLM"
echo "-------------------------------"
echo "Building app..."
xcodebuild -scheme CalAI -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build 2>&1 | grep -E "(BUILD SUCCEEDED|error:)" | tail -1

echo ""
echo "Checking for on-device AI integration..."
if grep -q "onDeviceSession" CalAI/Services/EnhancedConversationalAI.swift; then
    echo "✅ On-device AI code present"
else
    echo "❌ On-device AI code missing"
fi

if grep -q "Apple Intelligence" CalAI/Services/EnhancedConversationalAI.swift; then
    echo "✅ Apple Intelligence initialization found"
else
    echo "❌ Apple Intelligence initialization missing"
fi

# Test B: Check for context-aware features
echo ""
echo "💬 TEST B: Context-Aware Follow-Ups"
echo "------------------------------------"

if grep -q "referencedEventIds" CalAI/Services/EnhancedConversationalAI.swift; then
    echo "✅ Event reference tracking present"
else
    echo "❌ Event reference tracking missing"
fi

if grep -q "PRONOUN RESOLUTION" CalAI/Services/EnhancedConversationalAI.swift; then
    echo "✅ Pronoun resolution guidance present"
else
    echo "❌ Pronoun resolution guidance missing"
fi

if grep -q "CONVERSATION HISTORY" CalAI/Services/EnhancedConversationalAI.swift; then
    echo "✅ Conversation history tracking present"
else
    echo "❌ Conversation history tracking missing"
fi

# Test C: Check for smart scheduling
echo ""
echo "🧠 TEST C: Smart Scheduling Suggestions"
echo "---------------------------------------"

if [ -f "CalAI/Services/SmartSchedulingService.swift" ]; then
    echo "✅ SmartSchedulingService.swift exists"
else
    echo "❌ SmartSchedulingService.swift missing"
fi

if grep -q "SmartSchedulingService" CalAI.xcodeproj/project.pbxproj; then
    echo "✅ SmartSchedulingService in Xcode project"
else
    echo "❌ SmartSchedulingService not in Xcode project"
fi

if grep -q "analyzeCalendarPatterns" CalAI/Services/SmartSchedulingService.swift; then
    echo "✅ Pattern analysis implemented"
else
    echo "❌ Pattern analysis missing"
fi

if grep -q "suggestOptimalTime" CalAI/Services/SmartSchedulingService.swift; then
    echo "✅ Optimal time suggestions implemented"
else
    echo "❌ Optimal time suggestions missing"
fi

if grep -q "SCHEDULING PATTERNS" CalAI/Services/EnhancedConversationalAI.swift; then
    echo "✅ Scheduling patterns integrated with AI prompts"
else
    echo "❌ Scheduling patterns not integrated"
fi

# Summary
echo ""
echo "📊 SUMMARY"
echo "=========="
echo ""
echo "To manually test:"
echo "1. Run app in Xcode (⌘R)"
echo "2. Open Console (⌘⇧Y)"
echo "3. Interact with AI voice/chat"
echo "4. Watch for these logs:"
echo "   • '✅ Enhanced AI initialized with Apple Intelligence'"
echo "   • '📌 Tracking event reference: [id]'"
echo "   • 'SCHEDULING PATTERNS:' section"
echo ""
echo "See TESTING_GUIDE.md for detailed test scenarios!"
echo ""
