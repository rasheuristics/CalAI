# Project Structure Migration Guide

## Overview
The project has been reorganized following iOS best practices. Follow these steps to update your Xcode project.

## Step-by-Step Migration

### 1. Backup Your Project
```bash
cd /Users/btessema/Desktop/CalAI
git add -A
git commit -m "Backup before structure reorganization"
git push
```

### 2. Close Xcode
Make sure Xcode is completely closed before proceeding.

### 3. Open Xcode and Clean
1. Open `CalAI.xcodeproj` in Xcode
2. You'll see many files with red icons (missing references)
3. **Do NOT panic** - this is expected

### 4. Remove Old References
1. In the Project Navigator (left sidebar), select the "CalAI" folder (blue icon)
2. You'll see many files marked in red
3. Select all red files (Cmd+Click to multi-select)
4. Right-click → "Delete"
5. Choose "Remove Reference" (NOT "Move to Trash")

### 5. Add New Folder Structure
1. Open Finder and navigate to: `/Users/btessema/Desktop/CalAI/CalAI/CalAI/`
2. You should see the new folders: App, Core, Features, Models, Services, Utilities, Views, Resources, SupportingFiles, Tests
3. Drag these folders from Finder into Xcode's Project Navigator
4. In the dialog that appears:
   - ✅ **UNCHECK** "Copy items if needed"
   - ✅ **SELECT** "Create groups" (NOT "Create folder references")
   - ✅ **CHECK** "CalAI" target
   - Click "Finish"

### 6. Update Info.plist and Entitlements References
1. Select the CalAI project (blue icon at the top)
2. Select the CalAI target
3. Go to "Build Settings" tab
4. Search for "Info.plist"
5. Update "Info.plist File" to: `CalAI/SupportingFiles/Info.plist`
6. Search for "Code Signing Entitlements"
7. Update to: `CalAI/SupportingFiles/CalAI.entitlements`

### 7. Update Asset Catalog Reference
1. Still in Build Settings
2. Search for "Asset Catalog"
3. Update path to: `CalAI/Resources/Assets.xcassets`

### 8. Update Core Data Model Reference
1. In Build Settings, search for "Core Data"
2. Verify the model file path is: `CalAI/Core/Data/CalAIDataModel.xcdatamodeld`

### 9. Clean and Build
1. Product → Clean Build Folder (Shift+Cmd+K)
2. Product → Build (Cmd+B)
3. Fix any import errors that appear (see Common Issues below)

### 10. Run the App
1. Select a simulator or device
2. Product → Run (Cmd+R)
3. Test all major features

## Common Issues and Fixes

### Issue: "Cannot find 'X' in scope"
**Solution:** The file moved but import statements weren't updated. Since all files are in the same target, this should resolve automatically. If not, check that the file is added to the CalAI target.

### Issue: Red files still showing
**Solution:**
1. Select the red file
2. In the File Inspector (right sidebar), click the folder icon under "Location"
3. Navigate to the new location and select the file

### Issue: Build fails with "No such file or directory"
**Solution:** Check Build Phases → Compile Sources to ensure all Swift files are listed.

### Issue: Resources not found at runtime
**Solution:** Check Build Phases → Copy Bundle Resources to ensure Assets.xcassets and other resources are included.

## Verification Checklist

After migration, verify:
- [ ] App builds successfully
- [ ] App runs without crashes
- [ ] Calendar tab works
- [ ] Events tab works
- [ ] AI tab works
- [ ] Settings tab works
- [ ] Morning Briefing works
- [ ] Google Calendar sync works
- [ ] Outlook Calendar sync works
- [ ] All images/assets load correctly

## Rollback (If Needed)

If something goes wrong:
```bash
cd /Users/btessema/Desktop/CalAI
git reset --hard HEAD~1  # Reverts to backup commit
```

## New Project Structure

See `PROJECT_STRUCTURE.md` for detailed information about the new organization.

## Benefits of New Structure

✅ **Feature-based organization** - Easy to find related files
✅ **Clear separation of concerns** - Core, Features, Services
✅ **Scalable** - Easy to add new features
✅ **Maintainable** - Clear boundaries between components
✅ **Industry standard** - Follows iOS best practices

## Need Help?

If you encounter issues during migration:
1. Check Xcode's Issue Navigator (Cmd+5)
2. Read error messages carefully
3. Ensure all files are added to the CalAI target
4. Verify Build Settings paths are correct
