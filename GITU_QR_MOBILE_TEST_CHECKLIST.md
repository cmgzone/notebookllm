# Gitu QR Auth Mobile Test Checklist

## Quick Reference Guide for Mobile Testing

This checklist provides a quick reference for testing the QR authentication flow on mobile devices.

---

## Pre-Test Setup ✅

### Backend Setup
- [ ] Backend server is running and accessible
- [ ] WebSocket endpoint `/api/gitu/terminal/qr-auth` is working
- [ ] Database is connected and migrations are applied
- [ ] Test user account exists and can log in

### Mobile App Setup
- [ ] NotebookLLM app is installed on test device
- [ ] App is updated to latest version with QR auth feature
- [ ] User is logged in to the app
- [ ] Camera permissions are granted
- [ ] Internet connection is stable (WiFi or mobile data)

### Terminal Setup
- [ ] Terminal has `gitu` CLI installed
- [ ] Terminal can connect to backend server
- [ ] Terminal can establish WebSocket connections

---

## Core Functionality Tests 🧪

### Test 1: Basic QR Scan ⭐ CRITICAL
**Priority:** HIGH  
**Time:** 2 minutes

1. [ ] Run `gitu auth --qr` in terminal
2. [ ] Verify QR code displays within 2 seconds
3. [ ] Open NotebookLLM app on mobile
4. [ ] Navigate to Settings → Agent Connections → Terminal Connections
5. [ ] Tap "Scan QR Code"
6. [ ] Camera opens successfully
7. [ ] Point camera at QR code
8. [ ] QR code is detected within 3 seconds
9. [ ] "Linking terminal..." message appears
10. [ ] Terminal shows "QR code scanned, authenticating..."
11. [ ] Success dialog appears in app
12. [ ] Terminal shows "Authentication successful!"
13. [ ] Terminal receives auth token
14. [ ] New terminal appears in "Linked Terminals" list

**Pass Criteria:** All steps complete without errors

---

### Test 2: Manual Code Entry
**Priority:** MEDIUM  
**Time:** 2 minutes

1. [ ] Run `gitu auth --qr` in terminal
2. [ ] Note the session ID displayed
3. [ ] Open app → Terminal Connections → Scan QR Code
4. [ ] Tap "Enter Code Manually" at bottom
5. [ ] Enter session ID
6. [ ] Tap "Link"
7. [ ] Linking succeeds same as QR scan

**Pass Criteria:** Manual entry works identically to QR scan

---

### Test 3: Multiple Terminals
**Priority:** MEDIUM  
**Time:** 5 minutes

1. [ ] Link first terminal via QR code
2. [ ] Verify it appears in list
3. [ ] Open second terminal
4. [ ] Run `gitu auth --qr` in second terminal
5. [ ] Scan QR code with app
6. [ ] Verify both terminals appear in list
7. [ ] Each has unique device ID
8. [ ] Each has correct device name

**Pass Criteria:** Multiple terminals can be linked independently

---

### Test 4: Unlinking Terminal
**Priority:** HIGH  
**Time:** 2 minutes

1. [ ] Link a terminal
2. [ ] In app, go to Terminal Connections
3. [ ] Find terminal in list
4. [ ] Tap trash icon
5. [ ] Confirmation dialog appears
6. [ ] Tap "Unlink"
7. [ ] Terminal removed from list
8. [ ] Success message appears
9. [ ] Try to use Gitu in unlinked terminal
10. [ ] Terminal shows "Not authenticated" error

**Pass Criteria:** Unlinking works and terminal cannot use Gitu

---

## Error Handling Tests 🚨

### Test 5: Expired QR Code
**Priority:** HIGH  
**Time:** 3 minutes

1. [ ] Run `gitu auth --qr` in terminal
2. [ ] Wait 2 minutes (do not scan)
3. [ ] Terminal shows "QR code expired" message
4. [ ] Try to scan expired QR code
5. [ ] App shows "Session expired" error
6. [ ] Error can be dismissed
7. [ ] Scanner remains active for retry

**Pass Criteria:** Expired QR codes are properly rejected

---

### Test 6: Invalid QR Code
**Priority:** MEDIUM  
**Time:** 2 minutes

1. [ ] Create fake QR code with random text
2. [ ] Open app → Scan QR Code
3. [ ] Scan fake QR code
4. [ ] App shows "Invalid QR code" error
5. [ ] Error message is clear
6. [ ] Scanner remains active

**Pass Criteria:** Invalid QR codes are detected and rejected

---

### Test 7: Network Interruption
**Priority:** HIGH  
**Time:** 3 minutes

1. [ ] Run `gitu auth --qr` in terminal
2. [ ] Open app → Scan QR Code
3. [ ] Disable WiFi/mobile data
4. [ ] Try to scan QR code
5. [ ] App shows network error
6. [ ] Error message is user-friendly
7. [ ] Re-enable network
8. [ ] Retry scan
9. [ ] Scan succeeds

**Pass Criteria:** Network errors are handled gracefully

---

### Test 8: Camera Permissions
**Priority:** HIGH  
**Time:** 2 minutes

1. [ ] Deny camera permissions for app
2. [ ] Open app → Scan QR Code
3. [ ] Permission request appears
4. [ ] If denied, helpful error message shows
5. [ ] Message includes instructions
6. [ ] Grant permission in settings
7. [ ] Return to app
8. [ ] Scanner works

**Pass Criteria:** Permission flow is smooth and helpful

---

## UI/UX Tests 🎨

### Test 9: Scanner UI
**Priority:** MEDIUM  
**Time:** 2 minutes

1. [ ] Open scanner
2. [ ] Overlay is clearly visible
3. [ ] Corner indicators are green
4. [ ] Instructions are readable
5. [ ] Flashlight icon is visible
6. [ ] Switch camera icon is visible
7. [ ] Manual entry button is visible
8. [ ] All text is legible

**Pass Criteria:** UI is polished and professional

---

### Test 10: Flashlight Toggle
**Priority:** LOW  
**Time:** 1 minute

1. [ ] Open scanner in low light
2. [ ] Tap flashlight icon
3. [ ] Device torch turns on
4. [ ] Icon indicates torch is on
5. [ ] Tap again to turn off
6. [ ] Torch turns off
7. [ ] Close scanner
8. [ ] Torch is off

**Pass Criteria:** Flashlight works correctly

---

### Test 11: Camera Switch
**Priority:** LOW  
**Time:** 1 minute

1. [ ] Open scanner
2. [ ] Tap switch camera icon
3. [ ] Camera switches to front
4. [ ] Tap again
5. [ ] Camera switches back to rear

**Pass Criteria:** Camera switching works (if device has multiple cameras)

---

## Performance Tests ⚡

### Test 12: QR Detection Speed
**Priority:** MEDIUM  
**Time:** 2 minutes

1. [ ] Run `gitu auth --qr`
2. [ ] Open scanner
3. [ ] Point at QR code
4. [ ] Measure time to detection
5. [ ] Should be < 3 seconds

**Pass Criteria:** Detection is fast and responsive

---

### Test 13: Authentication Speed
**Priority:** MEDIUM  
**Time:** 2 minutes

1. [ ] Run `gitu auth --qr`
2. [ ] Scan QR code
3. [ ] Measure time from scan to terminal receiving token
4. [ ] Should be < 5 seconds

**Pass Criteria:** End-to-end flow is fast

---

## Device-Specific Tests 📱

### iOS Testing
- [ ] iPhone (small screen)
- [ ] iPhone (large screen)
- [ ] iPad
- [ ] Portrait orientation
- [ ] Landscape orientation
- [ ] Dark mode
- [ ] Light mode

### Android Testing
- [ ] Android phone (small screen)
- [ ] Android phone (large screen)
- [ ] Android tablet
- [ ] Portrait orientation
- [ ] Landscape orientation
- [ ] Dark mode
- [ ] Light mode

---

## Edge Cases 🔍

### Test 14: Background/Foreground
**Priority:** MEDIUM  
**Time:** 2 minutes

1. [ ] Open scanner
2. [ ] Press home button (app goes to background)
3. [ ] Wait 10 seconds
4. [ ] Return to app
5. [ ] Scanner resumes
6. [ ] QR code can still be scanned

**Pass Criteria:** App handles background transitions

---

### Test 15: Rapid Scanning
**Priority:** LOW  
**Time:** 3 minutes

1. [ ] Open 3 terminals with QR codes
2. [ ] Rapidly scan all 3 QR codes
3. [ ] All 3 terminals link successfully
4. [ ] No crashes or freezes
5. [ ] All appear in list

**Pass Criteria:** App handles rapid scans

---

### Test 16: Different Screen Sizes
**Priority:** LOW  
**Time:** 3 minutes

1. [ ] Display QR code on small terminal window
2. [ ] Scan successfully
3. [ ] Display QR code on full screen
4. [ ] Scan successfully
5. [ ] Display QR code on external monitor
6. [ ] Scan successfully

**Pass Criteria:** QR codes scan regardless of display size

---

## Regression Tests 🔄

After any code changes, verify:

- [ ] Existing linked terminals still work
- [ ] Token-based auth (manual) still works
- [ ] Device listing still works
- [ ] Unlinking still works
- [ ] QR generation still works
- [ ] WebSocket connection still works
- [ ] No new crashes introduced
- [ ] Performance hasn't degraded

---

## Test Results 📊

### Test Session Info
- **Date:** _______________
- **Tester:** _______________
- **Device:** _______________
- **OS Version:** _______________
- **App Version:** _______________
- **Backend Version:** _______________

### Results Summary
- **Total Tests:** _____ / 16
- **Passed:** _____
- **Failed:** _____
- **Skipped:** _____

### Critical Issues Found
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

### Minor Issues Found
1. _______________________________________________
2. _______________________________________________
3. _______________________________________________

### Performance Notes
- QR Detection Speed: _____ seconds
- Authentication Speed: _____ seconds
- Any lag or stuttering: _______________

### UX Feedback
- _______________________________________________
- _______________________________________________
- _______________________________________________

---

## Sign-Off ✍️

### Tester Sign-Off
- [ ] All critical tests passed
- [ ] All issues documented
- [ ] Ready for production

**Signature:** _______________  
**Date:** _______________

### Reviewer Sign-Off
- [ ] Test results reviewed
- [ ] Issues triaged
- [ ] Approved for deployment

**Signature:** _______________  
**Date:** _______________

---

## Quick Commands Reference 📝

### Backend
```bash
# Start backend
npm run dev

# Run automated tests
npm run test:qr-mobile

# Check WebSocket
curl -i -N -H "Connection: Upgrade" -H "Upgrade: websocket" \
  http://localhost:3000/api/gitu/terminal/qr-auth
```

### Terminal
```bash
# Link with QR code
gitu auth --qr

# Link with token
gitu auth GITU-ABCD-1234

# Check auth status
gitu auth status

# Logout
gitu auth logout
```

### Mobile App
```
Settings → Agent Connections → Terminal Connections
```

---

## Support 🆘

### Common Issues

**Issue:** QR code not detected  
**Solution:** Ensure good lighting, hold steady, try flashlight

**Issue:** "Session expired" error  
**Solution:** QR codes expire in 2 minutes, generate new one

**Issue:** "Network error"  
**Solution:** Check internet connection, verify backend is running

**Issue:** Camera not opening  
**Solution:** Check camera permissions in device settings

**Issue:** Terminal not receiving token  
**Solution:** Check WebSocket connection, verify backend logs

---

## Next Steps ➡️

After completing this checklist:

1. [ ] Document all findings
2. [ ] Create bug reports for issues
3. [ ] Update test plan based on results
4. [ ] Share results with team
5. [ ] Fix critical issues
6. [ ] Re-test after fixes
7. [ ] Approve for production deployment
