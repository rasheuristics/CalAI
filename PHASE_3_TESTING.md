# Phase 3 Testing Guide: Privacy Policy & Terms of Service

## Overview
Phase 3 adds comprehensive legal documentation (Privacy Policy and Terms of Service) with in-app viewing capabilities.

## Files Created
- ✅ `CalAI/PRIVACY_POLICY.md` - Comprehensive privacy policy
- ✅ `CalAI/TERMS_OF_SERVICE.md` - Complete terms of service
- ✅ `CalAI/Views/LegalDocumentView.swift` - In-app document viewer
- ✅ Updated `CalAI/Views/AdvancedSettingsView.swift` - Added legal document links

## Testing Checklist

### Test 1: Access Privacy Policy
1. Open CalAI app
2. Go to Settings → Advanced Settings
3. Scroll to "Privacy & Security" section
4. Tap "Privacy Policy"

**Expected Result:**
- ✅ Privacy Policy loads and displays
- ✅ Document is readable and formatted correctly
- ✅ Can scroll through entire document
- ✅ "Last updated: January 2025" is visible
- ✅ Share button is available in toolbar

### Test 2: Access Terms of Service
1. In Advanced Settings
2. Tap "Terms of Service"

**Expected Result:**
- ✅ Terms of Service loads and displays
- ✅ All 20 sections are present
- ✅ Document is readable and formatted
- ✅ Share button works

### Test 3: Share Documents
1. Open Privacy Policy
2. Tap Share button (top right)
3. Select a sharing method (Messages, Notes, etc.)

**Expected Result:**
- ✅ Share sheet appears
- ✅ Full document text is included
- ✅ Can successfully share via any method

**Repeat for Terms of Service**

### Test 4: Text Selection
1. Open either document
2. Long-press on any text
3. Try to select and copy text

**Expected Result:**
- ✅ Text is selectable
- ✅ Can copy sections of text
- ✅ Selection handles work properly

### Test 5: Navigation
1. Open Privacy Policy
2. Use back button to return to Settings
3. Open Terms of Service
4. Use back button to return to Settings

**Expected Result:**
- ✅ Navigation works smoothly
- ✅ No crashes or freezes
- ✅ Returns to correct screen

### Test 6: Content Verification

**Privacy Policy Should Include:**
- ✅ What data we collect (calendar, location, auth tokens, crash reports)
- ✅ What we DON'T collect (with ❌ markers)
- ✅ How we use data
- ✅ Third-party service integrations (Google, Microsoft, Apple)
- ✅ User privacy rights
- ✅ GDPR and CCPA compliance sections
- ✅ Contact information

**Terms of Service Should Include:**
- ✅ Acceptance of terms
- ✅ Service description
- ✅ User responsibilities
- ✅ Intellectual property rights
- ✅ Third-party services
- ✅ Disclaimers and limitations of liability
- ✅ Data and privacy (reference to Privacy Policy)
- ✅ Termination clauses
- ✅ Dispute resolution
- ✅ Contact information
- ✅ Feature-specific terms (voice, notifications, AI)

### Test 7: Dark Mode Compatibility
1. Enable Dark Mode (Settings → Display & Brightness → Dark)
2. Open Privacy Policy
3. Open Terms of Service

**Expected Result:**
- ✅ Documents are readable in Dark Mode
- ✅ Text contrast is sufficient
- ✅ Headers and sections are distinguishable

### Test 8: Accessibility
1. Enable VoiceOver (Settings → Accessibility → VoiceOver)
2. Navigate to Privacy Policy
3. Try to read sections with VoiceOver

**Expected Result:**
- ✅ VoiceOver reads document content
- ✅ Navigation elements are accessible
- ✅ Share button is announced

## Edge Cases

### Test 9: Missing Document Files
**Note:** This should not happen in production, but test error handling:

**Expected Result:**
- ✅ If documents are missing, error message is shown
- ✅ App doesn't crash
- ✅ Contact support message is displayed

### Test 10: Large Document Performance
1. Open Privacy Policy (longer document)
2. Scroll rapidly up and down
3. Jump to different sections quickly

**Expected Result:**
- ✅ No lag or stuttering
- ✅ Smooth scrolling performance
- ✅ Memory usage is reasonable

## Affirmative Checklist

Before moving to Phase 4, confirm:

- [ ] Privacy Policy displays correctly
- [ ] Terms of Service displays correctly
- [ ] Both documents are accessible from Advanced Settings
- [ ] Share functionality works for both documents
- [ ] Text selection works
- [ ] Navigation works smoothly
- [ ] Documents are readable in both Light and Dark mode
- [ ] All required content sections are present
- [ ] Contact information is accurate
- [ ] No spelling or grammar errors (review documents)
- [ ] Documents are legally sound (consider legal review if needed)

## Notes for Legal Review

Before App Store submission, you may want to:

1. **Review with Legal Counsel:** Have a lawyer review both documents
2. **Update Contact Information:** Replace placeholder email with actual support email
3. **Update Jurisdiction:** Fill in actual jurisdiction in Terms of Service section 13.1
4. **Verify Compliance:** Ensure GDPR and CCPA sections match your actual practices
5. **Add Company Information:** Include company name, address, registration number if required

## Next Phase Preview

**Phase 4: Create App Store Assets**
- App icon (1024x1024)
- Screenshots for all device sizes
- App Store description
- Keywords
- Promotional text
- App Store privacy labels

---

**Once all tests pass, provide the affirmative to proceed to Phase 4.**

Example: "Affirmative - Phase 3 legal documents tested successfully. Ready for Phase 4."
