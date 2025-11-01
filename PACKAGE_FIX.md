# Fix: Missing Package Product 'FBLPromises'

## Error
```
Missing package product 'FBLPromises'
Could not resolve package dependencies
```

## Quick Fix (Try in order)

### Option 1: Reset Package Caches in Xcode
```bash
# 1. Open Xcode
open CalAI.xcodeproj

# 2. In Xcode menu:
File > Packages > Reset Package Caches

# 3. Then:
File > Packages > Update to Latest Package Versions

# 4. Build (⌘B)
```

### Option 2: Delete Derived Data
```bash
# Close Xcode first, then:
rm -rf ~/Library/Developer/Xcode/DerivedData/*

# Reopen Xcode
open CalAI.xcodeproj

# Build (⌘B)
```

### Option 3: Command Line Reset
```bash
# Navigate to project
cd /Users/btessema/Desktop/CalAI/CalAI

# Remove package cache
rm -rf .build
rm -rf ~/Library/Caches/org.swift.swiftpm

# Resolve packages
xcodebuild -resolvePackageDependencies

# Build
xcodebuild -scheme CalAI build
```

### Option 4: Manual Package Resolution (if above don't work)
```bash
# 1. Open Xcode
open CalAI.xcodeproj

# 2. In Project Navigator, select CalAI project (top)

# 3. Go to "Package Dependencies" tab

# 4. Look for packages with warning icons

# 5. Click each package and select "Update to Latest Version"

# 6. If any show errors, remove and re-add:
#    - Click "-" to remove
#    - Click "+" to add back
#    - Search for package name
#    - Add it again
```

## Why This Happens

FBLPromises is a Firebase dependency. This error usually means:
1. Package cache is stale
2. Network issue during download
3. Xcode needs to re-resolve dependencies

## Prevention

After fixing, to prevent this in the future:
1. Commit `Package.resolved` to git
2. Use Xcode's "Reset Package Caches" regularly
3. Update packages explicitly rather than automatically

## If Nothing Works

The project should still build in Xcode GUI even if command-line fails. The error is likely a Swift Package Manager cache issue, not a code issue.

**Just open Xcode and build from there (⌘B) - it usually works fine!**
