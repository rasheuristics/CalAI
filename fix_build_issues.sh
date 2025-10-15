#!/bin/bash

# Fix Build Issues Script for CalAI
# Resolves "Cannot find type" errors after pulling new code

set -e  # Exit on error

echo "🔧 CalAI Build Issues Fix Script"
echo "=================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Verify we're in the right directory
if [ ! -f "CalAI.xcodeproj/project.pbxproj" ]; then
    echo -e "${RED}❌ Error: CalAI.xcodeproj not found in current directory${NC}"
    echo "Please run this script from the CalAI project root directory"
    exit 1
fi

echo -e "${GREEN}✓ Found CalAI.xcodeproj${NC}"

# Step 2: Check if critical files exist
echo ""
echo "📁 Checking critical files..."

if [ ! -f "CalAI/Services/SmartEventParser.swift" ]; then
    echo -e "${RED}❌ Error: SmartEventParser.swift not found${NC}"
    echo "Please run: git pull origin main"
    exit 1
fi
echo -e "${GREEN}✓ SmartEventParser.swift exists${NC}"

if [ ! -f "CalAI/AIManager.swift" ]; then
    echo -e "${RED}❌ Error: AIManager.swift not found${NC}"
    echo "Please run: git pull origin main"
    exit 1
fi
echo -e "${GREEN}✓ AIManager.swift exists${NC}"

# Step 3: Check if files are in project
echo ""
echo "🔍 Verifying files are in Xcode project..."

if ! grep -q "SmartEventParser.swift" CalAI.xcodeproj/project.pbxproj; then
    echo -e "${RED}❌ Warning: SmartEventParser.swift not referenced in project${NC}"
    echo "You may need to add it manually in Xcode"
else
    echo -e "${GREEN}✓ SmartEventParser.swift is in project${NC}"
fi

if ! grep -q "AIManager.swift" CalAI.xcodeproj/project.pbxproj; then
    echo -e "${RED}❌ Warning: AIManager.swift not referenced in project${NC}"
    echo "You may need to add it manually in Xcode"
else
    echo -e "${GREEN}✓ AIManager.swift is in project${NC}"
fi

# Step 4: Close Xcode
echo ""
echo "🛑 Checking if Xcode is running..."

if pgrep -x "Xcode" > /dev/null; then
    echo -e "${YELLOW}⚠️  Xcode is running. Please close Xcode before continuing.${NC}"
    read -p "Press Enter after closing Xcode..."

    # Wait and verify
    sleep 2
    if pgrep -x "Xcode" > /dev/null; then
        echo -e "${RED}❌ Xcode is still running. Please close it and run this script again.${NC}"
        exit 1
    fi
fi
echo -e "${GREEN}✓ Xcode is not running${NC}"

# Step 5: Clean Derived Data
echo ""
echo "🗑️  Cleaning Derived Data..."

DERIVED_DATA_PATH=~/Library/Developer/Xcode/DerivedData/CalAI-*

if ls $DERIVED_DATA_PATH 2>/dev/null | grep -q .; then
    rm -rf $DERIVED_DATA_PATH
    echo -e "${GREEN}✓ Derived Data cleaned${NC}"
else
    echo -e "${YELLOW}ℹ️  No Derived Data found (this is okay)${NC}"
fi

# Step 6: Clean build artifacts in project
echo ""
echo "🧹 Cleaning build artifacts..."

if [ -d "build" ]; then
    rm -rf build
    echo -e "${GREEN}✓ Build folder cleaned${NC}"
else
    echo -e "${YELLOW}ℹ️  No build folder found (this is okay)${NC}"
fi

# Step 7: Git status check
echo ""
echo "📊 Checking git status..."
git status --short

echo ""
echo -e "${GREEN}✅ Cleanup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Open Xcode"
echo "2. Press Cmd+Shift+K to clean build folder"
echo "3. Press Cmd+B to rebuild"
echo ""
echo "If errors persist, check FIX_BUILD_ERRORS.md for detailed troubleshooting"
