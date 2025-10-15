# Fix Build Errors: ExtractedEntities, SmartEventParser Not Found

## Problem
After pulling the latest code, you may see errors like:
- `Cannot find 'ExtractedEntities' in scope`
- `Cannot find 'SmartEventParser' in scope`

## Root Cause
These types are defined in `SmartEventParser.swift` but Xcode may not have properly indexed them after the pull. This is a common Xcode issue with new files or structural changes.

## Solution

### Step 1: Clean Build Folder
1. In Xcode, press `Cmd + Shift + K` (Product → Clean Build Folder)
2. Wait for the clean to complete

### Step 2: Delete Derived Data
1. Close Xcode completely
2. Open Terminal and run:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/CalAI-*
   ```
3. This removes all cached build artifacts

### Step 3: Verify File References
1. Open Xcode
2. In the Project Navigator, locate `Services/SmartEventParser.swift`
3. Select the file and check the File Inspector (right panel)
4. Ensure "Target Membership" shows "CalAI" is checked
5. Do the same for `AIManager.swift`

### Step 4: Rebuild
1. Press `Cmd + B` to rebuild the project
2. The errors should be resolved

## Alternative: Quick Terminal Fix

Run these commands from the project root:
```bash
# Clean and rebuild using xcodebuild
cd /path/to/CalAI
xcodebuild -project CalAI.xcodeproj -scheme CalAI -destination 'platform=iOS Simulator,name=iPhone 16' clean build
```

## Still Having Issues?

### Check File Locations
Verify these files exist:
```bash
ls -la CalAI/Services/SmartEventParser.swift
ls -la CalAI/AIManager.swift
```

Both should show up with file sizes.

### Check Git Status
Make sure you've pulled all files:
```bash
git status
git pull origin main
```

### Verify Target Membership via Command Line
```bash
# Check if SmartEventParser.swift is in the project
grep "SmartEventParser.swift" CalAI.xcodeproj/project.pbxproj
```

You should see entries like:
```
SmartEventParser.swift in Sources
```

## What These Files Contain

**SmartEventParser.swift** defines:
- `ExtractedEntities` struct - holds parsed event data
- `EventAction` enum - create, update, delete, move, query
- `ParseResult` enum - success, needs clarification, failure
- `SmartEventParser` class - natural language parser

**AIManager.swift** uses:
- `ExtractedEntities` for event creation workflow
- `SmartEventParser` for parsing user input

## Prevention

When pulling changes that add new files:
1. Always do `Cmd + Shift + K` (Clean Build Folder) first
2. If still having issues, delete Derived Data
3. This forces Xcode to re-index all files

## Contact
If these steps don't work, share the exact error message and the output of:
```bash
ls -la CalAI/Services/SmartEventParser.swift
grep "SmartEventParser.swift" CalAI.xcodeproj/project.pbxproj | head -5
```
