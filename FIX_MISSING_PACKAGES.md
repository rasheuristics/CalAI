# Fix Missing Swift Package Dependencies

## Issue
The following packages are showing as missing:
- ❌ Algorithms (apple/swift-algorithms)
- ❌ Discovery (googleapis/google-api-swift-client)
- ❌ SwiftAnthropic (jamesrochabrun/SwiftAnthropic)
- ❌ GoogleAPIRuntime (googleapis/google-api-swift-client)
- ❌ GoogleSignIn (google/GoogleSignIn-iOS)
- ❌ MSAL (AzureAD/microsoft-authentication-library-for-objc)
- ❌ GoogleSignInSwift (google/GoogleSignIn-iOS)

## Root Cause
Swift Package Manager dependencies need to be resolved/downloaded. This commonly happens:
- After cloning the project
- After cleaning build cache
- After updating Xcode
- After modifying Package.swift or project dependencies

## Solution: Fix in Xcode (RECOMMENDED)

### Method 1: Reset Package Caches (Usually Works)

1. **Open Xcode**
   ```bash
   open CalAI.xcodeproj
   ```

2. **Reset Package Caches**
   - In Xcode menu: `File` → `Packages` → `Reset Package Caches`
   - Wait for progress indicator in status bar

3. **Update to Latest Package Versions**
   - In Xcode menu: `File` → `Packages` → `Update to Latest Package Versions`
   - This will download all missing packages

4. **Clean Build Folder**
   - Press: `Cmd + Shift + K` (or `Product` → `Clean Build Folder`)

5. **Build Project**
   - Press: `Cmd + B` (or `Product` → `Build`)

### Method 2: Resolve Package Versions (If Method 1 Fails)

1. **Open Xcode**
   ```bash
   open CalAI.xcodeproj
   ```

2. **Go to Package Dependencies**
   - Select project in navigator (CalAI at top)
   - Select CalAI target
   - Click "Package Dependencies" tab

3. **Resolve Each Package**
   - Look for packages with warning icons
   - Select each package
   - Click "Resolve" or "Update to Latest"

4. **Manually Resolve Versions**
   - Right-click on project in navigator
   - Select "Resolve Package Versions"
   - Wait for resolution to complete

### Method 3: Remove and Re-add Packages (Nuclear Option)

1. **Remove All Packages**
   - Select project in navigator
   - Go to "Package Dependencies" tab
   - Click "-" button to remove each package

2. **Re-add Packages** (in this order):

   a. **Google Sign-In** (for Google Calendar integration)
   ```
   URL: https://github.com/google/GoogleSignIn-iOS
   Version: Up to Next Major (7.0.0)
   Products: GoogleSignIn, GoogleSignInSwift
   ```

   b. **MSAL** (for Outlook integration)
   ```
   URL: https://github.com/AzureAD/microsoft-authentication-library-for-objc
   Version: Up to Next Major (1.0.0)
   Product: MSAL
   ```

   c. **Google API Client** (for Calendar API)
   ```
   URL: https://github.com/googleapis/google-api-swift-client
   Branch: main
   Products: Discovery, GoogleAPIRuntime
   ```

   d. **Swift Algorithms** (Apple utility)
   ```
   URL: https://github.com/apple/swift-algorithms
   Version: Up to Next Major (1.0.0)
   Product: Algorithms
   ```

   e. **SwiftAnthropic** (for Claude AI integration)
   ```
   URL: https://github.com/jamesrochabrun/SwiftAnthropic
   Version: Up to Next Major (1.0.0)
   Product: SwiftAnthropic
   ```

## Solution: Command Line (Alternative)

If Xcode method doesn't work, try command line:

```bash
# 1. Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/CalAI-*

# 2. Clean SPM cache
rm -rf ~/Library/Caches/org.swift.swiftpm/
rm -rf ~/Library/Developer/Xcode/DerivedData/*/SourcePackages/

# 3. Resolve packages
cd /Users/btessema/Desktop/CalAI/CalAI
xcodebuild -resolvePackageDependencies -project CalAI.xcodeproj -scheme CalAI

# 4. Open in Xcode and build
open CalAI.xcodeproj
```

## Verification

After following the steps, verify all packages resolved:

1. In Xcode Navigator, expand the project
2. Look for "Package Dependencies" section
3. All packages should show version numbers (no warning icons)

**Expected packages:**
- ✅ Algorithms (swift-algorithms)
- ✅ AppAuth
- ✅ BigInt
- ✅ CryptoSwift
- ✅ Discovery
- ✅ GoogleAPIRuntime
- ✅ GoogleSignIn
- ✅ GoogleSignInSwift
- ✅ GTMAppAuth
- ✅ GTMSessionFetcher
- ✅ MSAL
- ✅ SwiftAnthropic
- ✅ And many transitive dependencies...

## Common Issues

### Issue: "Package resolution failed"
**Solution:** Check internet connection, try again

### Issue: "Repository not found"
**Solution:** Verify package URLs are correct in project settings

### Issue: "Version conflicts"
**Solution:**
- Update Xcode to latest version
- Try using exact version instead of "Up to Next Major"

### Issue: "Git authentication failed"
**Solution:**
- These are all public repos, no auth needed
- Check if firewall/VPN is blocking GitHub

### Issue: "Xcode hangs on 'Resolving Package Graph'"
**Solution:**
1. Force quit Xcode
2. Delete derived data: `rm -rf ~/Library/Developer/Xcode/DerivedData/`
3. Restart Xcode
4. Try again

## Package Details

### Required for Production

| Package | Purpose | Version |
|---------|---------|---------|
| GoogleSignIn | Google OAuth | 7.x |
| GoogleSignInSwift | Google OAuth (Swift) | 7.x |
| MSAL | Microsoft OAuth | 1.x |
| Discovery | Google API Client | main branch |
| GoogleAPIRuntime | Google API Runtime | main branch |

### Required for Features

| Package | Purpose | Version |
|---------|---------|---------|
| SwiftAnthropic | Claude AI integration | 1.x |
| Algorithms | Swift utilities | 1.x |

### Transitive Dependencies (Auto-installed)

- AppAuth (OAuth 2.0)
- BigInt (Large numbers)
- CryptoSwift (Cryptography)
- GTMAppAuth (Google auth)
- GTMSessionFetcher (Google networking)
- Swift Collections, Atomics, System, NIO, etc.

## After Fixing

Once all packages are resolved:

1. ✅ Build the project (`Cmd + B`)
2. ✅ Verify no "Missing package product" errors
3. ✅ Continue with keychain testing on physical device

## Quick Fix (Try This First!)

```bash
# Open Xcode
open /Users/btessema/Desktop/CalAI/CalAI/CalAI.xcodeproj

# Then in Xcode:
# File → Packages → Reset Package Caches
# File → Packages → Update to Latest Package Versions
# Product → Clean Build Folder (Cmd+Shift+K)
# Product → Build (Cmd+B)
```

This resolves the issue 90% of the time!

## Still Having Issues?

If packages still won't resolve:
1. Check Xcode version: `xcodebuild -version` (need Xcode 15+)
2. Check Swift version: `swift --version` (need Swift 5.9+)
3. Verify internet connectivity to GitHub
4. Try opening in Xcode and waiting 5-10 minutes (initial download takes time)
