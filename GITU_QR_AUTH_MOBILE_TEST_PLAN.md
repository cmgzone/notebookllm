# Gitu QR Auth Mobile Testing Plan

## Overview
This document provides a comprehensive testing plan for the Gitu QR authentication flow on mobile devices (iOS and Android).

## Test Environment Setup

### Prerequisites
1. **Backend Server Running**
   - Ensure backend is running with WebSocket support
   - Verify `/api/gitu/terminal/qr-auth` WebSocket endpoint is accessible
   - Check that all QR auth routes are registered

2. **Flutter App Installed**
   - Install NotebookLLM app on test device (iOS or Android)
   - Ensure user is logged in
   - Verify camera permissions are granted

3. **Terminal Access**
   - Have terminal with `gitu` CLI installed
   - Ensure terminal can connect to backend WebSocket

## Test Scenarios

### Scenario 1: Happy Path - QR Code Scan Success

**Steps:**
1. Open terminal and run: `gitu auth --qr`
2. Terminal displays QR code
3. Open NotebookLLM app on mobile device
4. Navigate to Settings → Agent Connections → Terminal Connections
5. Tap "Scan QR Code" button
6. Point camera at QR code displayed in terminal
7. Wait for QR code to be detected

**Expected Results:**
- ✅ Terminal displays QR code within 2 seconds
- ✅ QR code is clearly visible and scannable
- ✅ Mobile app camera opens successfully
- ✅ QR code is detected within 3 seconds
- ✅ App shows "Linking terminal..." loading indicator
- ✅ Terminal shows "QR code scanned, authenticating..." message
- ✅ App shows success dialog with session ID
- ✅ Terminal shows "Authentication successful!" message
- ✅ Terminal receives and stores auth token
- ✅ New terminal appears in "Linked Terminals" list
- ✅ Terminal can now execute Gitu commands

**Test on:**
- [ ] iOS (iPhone)
- [ ] iOS (iPad)
- [ ] Android (Phone)
- [ ] Android (Tablet)

---

### Scenario 2: QR Code Expiry

**Steps:**
1. Open terminal and run: `gitu auth --qr`
2. Terminal displays QR code
3. Wait for 2 minutes (QR code expiry time)
4. Try to scan the expired QR code with mobile app

**Expected Results:**
- ✅ Terminal shows countdown timer (120 seconds)
- ✅ After 2 minutes, terminal shows "QR code expired" message
- ✅ If scanned after expiry, app shows error: "Session expired"
- ✅ Terminal prompts user to run command again
- ✅ WebSocket connection closes gracefully

**Test on:**
- [ ] iOS
- [ ] Android

---

### Scenario 3: Manual Code Entry

**Steps:**
1. Open terminal and run: `gitu auth --qr`
2. Note the session ID displayed below QR code
3. Open NotebookLLM app
4. Navigate to Terminal Connections
5. Tap "Scan QR Code"
6. Tap "Enter Code Manually" button at bottom
7. Enter the session ID manually
8. Tap "Link" button

**Expected Results:**
- ✅ Manual entry dialog opens
- ✅ Session ID can be entered (copy-paste or typing)
- ✅ Linking proceeds same as QR scan
- ✅ Success dialog appears
- ✅ Terminal receives auth token

**Test on:**
- [ ] iOS
- [ ] Android

---

### Scenario 4: Invalid QR Code

**Steps:**
1. Create a fake QR code with invalid session ID
2. Open NotebookLLM app
3. Navigate to Terminal Connections → Scan QR Code
4. Scan the fake QR code

**Expected Results:**
- ✅ App detects QR code
- ✅ App shows error: "Invalid QR code or session expired"
- ✅ Scanner remains active for retry
- ✅ Error message can be dismissed
- ✅ User can scan again

**Test on:**
- [ ] iOS
- [ ] Android

---

### Scenario 5: Network Interruption During Scan

**Steps:**
1. Open terminal and run: `gitu auth --qr`
2. Open NotebookLLM app
3. Start scanning QR code
4. Disable WiFi/mobile data mid-scan
5. Complete the scan

**Expected Results:**
- ✅ App shows network error message
- ✅ Error is user-friendly (not technical stack trace)
- ✅ Scanner remains active
- ✅ User can retry after reconnecting
- ✅ Terminal shows timeout message after 30 seconds

**Test on:**
- [ ] iOS
- [ ] Android

---

### Scenario 6: Multiple Terminals Linking

**Steps:**
1. Link first terminal via QR code
2. Keep first terminal linked
3. Open second terminal and run: `gitu auth --qr`
4. Scan QR code with mobile app
5. Verify both terminals appear in list

**Expected Results:**
- ✅ Both terminals appear in "Linked Terminals" list
- ✅ Each terminal has unique device ID
- ✅ Each terminal has correct device name
- ✅ Both terminals can execute Gitu commands independently
- ✅ Last used timestamps update correctly

**Test on:**
- [ ] iOS
- [ ] Android

---

### Scenario 7: Unlinking Terminal

**Steps:**
1. Link a terminal via QR code
2. In mobile app, go to Terminal Connections
3. Find the linked terminal in list
4. Tap trash icon
5. Confirm unlinking in dialog
6. Try to use Gitu in the unlinked terminal

**Expected Results:**
- ✅ Confirmation dialog appears
- ✅ After confirmation, terminal is removed from list
- ✅ Success snackbar appears
- ✅ Terminal shows "Not authenticated" error when trying to use Gitu
- ✅ Terminal can be re-linked with new QR code

**Test on:**
- [ ] iOS
- [ ] Android

---

### Scenario 8: Camera Permissions Denied

**Steps:**
1. Deny camera permissions for NotebookLLM app
2. Open app and navigate to Terminal Connections
3. Tap "Scan QR Code"

**Expected Results:**
- ✅ App shows permission request dialog
- ✅ If denied, app shows helpful error message
- ✅ Error message includes instructions to enable in settings
- ✅ User can navigate to app settings
- ✅ After granting permission, scanner works

**Test on:**
- [ ] iOS
- [ ] Android

---

### Scenario 9: Low Light Conditions

**Steps:**
1. Open terminal and run: `gitu auth --qr`
2. Open NotebookLLM app in low light environment
3. Tap "Scan QR Code"
4. Try to scan QR code
5. Tap flashlight icon to enable torch

**Expected Results:**
- ✅ Scanner opens in low light
- ✅ Flashlight icon is visible and accessible
- ✅ Tapping flashlight icon enables device torch
- ✅ QR code can be scanned with torch enabled
- ✅ Torch turns off when scanner closes

**Test on:**
- [ ] iOS
- [ ] Android

---

### Scenario 10: Background/Foreground Transitions

**Steps:**
1. Open terminal and run: `gitu auth --qr`
2. Open NotebookLLM app and start scanning
3. Press home button (app goes to background)
4. Wait 10 seconds
5. Return to app

**Expected Results:**
- ✅ Scanner pauses when app goes to background
- ✅ Scanner resumes when app returns to foreground
- ✅ QR code can still be scanned after returning
- ✅ No crashes or freezes
- ✅ WebSocket connection remains stable

**Test on:**
- [ ] iOS
- [ ] Android

---

### Scenario 11: Rapid QR Code Scanning

**Steps:**
1. Open multiple terminals with QR codes
2. Rapidly scan multiple QR codes in succession
3. Verify all terminals are linked correctly

**Expected Results:**
- ✅ App handles rapid scans without crashes
- ✅ Each scan is processed independently
- ✅ No duplicate terminal entries
- ✅ All terminals receive auth tokens
- ✅ UI updates correctly for each scan

**Test on:**
- [ ] iOS
- [ ] Android

---

### Scenario 12: QR Code from Different Screen Sizes

**Steps:**
1. Display QR code on various screen sizes:
   - Small terminal window
   - Full screen terminal
   - External monitor
   - Laptop screen
2. Scan each QR code with mobile app

**Expected Results:**
- ✅ QR codes are scannable regardless of display size
- ✅ Scanner detects QR codes at various distances
- ✅ No issues with QR code resolution
- ✅ Successful linking in all cases

**Test on:**
- [ ] iOS
- [ ] Android

---

## Performance Tests

### Test 1: QR Code Generation Speed
**Metric:** Time from running `gitu auth --qr` to QR code display
**Target:** < 2 seconds
**Test on:** All platforms

### Test 2: QR Code Detection Speed
**Metric:** Time from pointing camera to QR code detection
**Target:** < 3 seconds
**Test on:** iOS and Android

### Test 3: Authentication Completion Speed
**Metric:** Time from QR scan to terminal receiving auth token
**Target:** < 5 seconds
**Test on:** iOS and Android

### Test 4: WebSocket Connection Stability
**Metric:** Connection remains stable for 2 minutes (QR expiry time)
**Target:** 100% uptime
**Test on:** All platforms

---

## UI/UX Tests

### Visual Tests
- [ ] QR scanner overlay is clearly visible
- [ ] Corner indicators are green and prominent
- [ ] Instructions are easy to read
- [ ] Loading indicators are smooth
- [ ] Success/error messages are clear
- [ ] Icons are appropriate and recognizable

### Accessibility Tests
- [ ] Screen reader announces scanner state
- [ ] Buttons have proper labels
- [ ] Color contrast meets WCAG standards
- [ ] Touch targets are at least 44x44 points
- [ ] Error messages are announced

### Responsive Design Tests
- [ ] Scanner works on small phones (iPhone SE)
- [ ] Scanner works on large phones (iPhone Pro Max)
- [ ] Scanner works on tablets
- [ ] Scanner works in portrait orientation
- [ ] Scanner works in landscape orientation

---

## Error Handling Tests

### Test 1: Backend Unavailable
**Steps:** Stop backend server, try to scan QR code
**Expected:** Clear error message, retry option

### Test 2: WebSocket Connection Failure
**Steps:** Block WebSocket port, run `gitu auth --qr`
**Expected:** Terminal shows connection error, helpful message

### Test 3: Invalid Session ID Format
**Steps:** Enter malformed session ID manually
**Expected:** Validation error, clear message

### Test 4: Concurrent Session Conflicts
**Steps:** Try to scan same QR code from two devices simultaneously
**Expected:** First scan succeeds, second shows "already used" error

---

## Security Tests

### Test 1: Session ID Uniqueness
**Steps:** Generate multiple QR codes, verify session IDs are unique
**Expected:** All session IDs are unique

### Test 2: Token Expiry Enforcement
**Steps:** Wait for QR code to expire, try to use it
**Expected:** Expired QR codes are rejected

### Test 3: Auth Token Security
**Steps:** Inspect stored auth token in terminal
**Expected:** Token is JWT format, properly signed, 90-day expiry

### Test 4: Device ID Uniqueness
**Steps:** Link multiple terminals, verify device IDs
**Expected:** Each terminal has unique device ID

---

## Regression Tests

After any code changes, verify:
- [ ] Existing linked terminals still work
- [ ] Token-based auth still works
- [ ] Device listing still works
- [ ] Unlinking still works
- [ ] QR code generation still works
- [ ] WebSocket connection still works

---

## Test Execution Checklist

### Pre-Test Setup
- [ ] Backend server is running
- [ ] Database is accessible
- [ ] WebSocket endpoint is reachable
- [ ] Flutter app is installed on test devices
- [ ] Terminal has `gitu` CLI installed
- [ ] Test user account is created and logged in

### During Testing
- [ ] Record any crashes or errors
- [ ] Note performance issues
- [ ] Screenshot any UI problems
- [ ] Document unexpected behavior
- [ ] Test on both WiFi and mobile data

### Post-Test
- [ ] Document all findings
- [ ] Create bug reports for issues
- [ ] Update test plan based on findings
- [ ] Share results with team

---

## Known Issues / Limitations

1. **QR Code Size:** Very small QR codes (< 100px) may be hard to scan
2. **Camera Quality:** Low-quality cameras may struggle in low light
3. **Network Latency:** High latency (> 1s) may cause timeouts
4. **WebSocket Limits:** Some corporate networks block WebSocket connections

---

## Test Results Summary

### iOS Testing
- **Device:** [Device model]
- **OS Version:** [iOS version]
- **Date:** [Test date]
- **Tester:** [Name]
- **Pass Rate:** [X/Y scenarios passed]
- **Issues Found:** [Number]

### Android Testing
- **Device:** [Device model]
- **OS Version:** [Android version]
- **Date:** [Test date]
- **Tester:** [Name]
- **Pass Rate:** [X/Y scenarios passed]
- **Issues Found:** [Number]

---

## Next Steps

After completing mobile testing:
1. Fix any critical bugs found
2. Optimize performance bottlenecks
3. Improve error messages based on feedback
4. Update documentation with findings
5. Proceed to production deployment

---

## Contact

For questions or issues during testing:
- **Backend Issues:** Check backend logs
- **Mobile Issues:** Check Flutter console logs
- **WebSocket Issues:** Check browser/terminal network logs
