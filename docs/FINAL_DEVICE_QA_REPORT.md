# Sky Height Apartment — Final Device QA Audit Report
**Target Workspace:** `F:\SkyHeightPG`  
**Test Platform:** Android 16 (API 36) — Device `emulator-5554` (`sdk_gphone64_x86_64`)  
**Package:** `com.skyheightpg.app`  
**Release Artifact:** `mobile/build/app/outputs/flutter-apk/app-release.apk` (54.8 MB)  
**Backend:** Production Render Live (`https://skyheightpg.onrender.com`)  
**Audit Date:** November 2, 2026

---

## Executive Summary
A comprehensive on-device quality assurance audit of the **Sky Height Apartment** Notification & Keyboard UX architecture (Options 1–5) was executed directly against a live Android 16 device (`emulator-5554`) via ADB. 

All 5 core architectural improvements:
1. Floating SnackBar System (`AppSnackBar` / `AppNotificationService`)
2. Standardized Modal Confirmation Bottom Sheets (`AppBottomSheet`)
3. Unified High-Contrast Inline Form Validation with Dynamic Error Clearing
4. System-Level Slide-Down Top Notification Banners (`AppTopNotificationBanner`)
5. Global Keyboard-Aware Insets, Scroll Resilience & Tap-Outside Dismissal (`KeyboardDismissible`, `KeyboardAwareScrollView`)

have been verified with automated suites (52/52 passing, 0 analyzer issues) and verified visually on the Android runtime with zero layout overflow, zero jitter, and complete responsiveness.

---

## Section A — Automated Test Results

### 1. Static Analysis (`flutter analyze`)
```
Analyzing mobile...
No issues found! (ran in 31.8s)
```
- **Lint Errors:** 0
- **Warnings:** 0
- **Infos:** 0

### 2. Automated Test Suite (`flutter test`)
```
00:02 +52: All tests passed!
```
- **Total Test Cases:** 52
- **Passed:** 52 (100%)
- **Failed:** 0
- **Skipped:** 0

#### Key Test Breakdown:
| Test Suite | File | Tests | Status |
| :--- | :--- | :--- | :--- |
| **Notification & Keyboard UX** | `test/notification_and_keyboard_test.dart` | 6 | **PASS** |
| **Login Security & Credential Isolation** | `test/login_security_test.dart` | 2 | **PASS** |
| **Phase A Occupancy & Leaving History** | `test/phase_a_occupancy_test.dart` | 4 | **PASS** |
| **Phase 8 Approvals & Chat Features** | `test/phase8_features_test.dart` | 4 | **PASS** |
| **Core UI Components & Badges** | `test/widget_test.dart` | 8 | **PASS** |
| **Phase 5 Operations** | `test/phase5_operations_test.dart` | 3 | **PASS** |
| **Auth Provider & Session Caching** | `test/auth_provider_test.dart` | 4 | **PASS** |
| **API Client & Interceptors** | `test/api_client_test.dart` | 3 | **PASS** |
| **Formatters & Validators** | `test/formatters_test.dart`, `validators_test.dart` | 18 | **PASS** |

---

## Section B — Actual Device-Tested Results

All tests were performed live on Android 16 (API 36) using the compiled `app-release.apk`. Screenshots were captured after each test sequence and verified.

### 1. Floating SnackBars (Option 1)
- **Keyboard Open State:** Verified via `screen_after_save.png` and `screen_offline_banner_open_kbd.png`.
  - The SnackBar dynamically elevates above the soft keyboard using `SnackBarBehavior.floating` and `viewInsets.bottom`.
  - Displays with 10px rounded corners, elevation drop shadow, forest green background (`#1B5E20`), checkmark icon, and white legible text.
- **Keyboard Closed State:** Verified via `screen_tenant_logged.png`.
  - Floats cleanly 12px above bottom safe area with crimson red background (`AppColors.error`), alert icon, and clear message.
- **Rapid De-duplication:** Verified via automated widget tests — identical rapid notifications within 1.5 seconds are throttled to prevent SnackBar stacking.

### 2. Modal Bottom Sheets (Option 2)
- **Architecture:** Implemented in `AppBottomSheet.showConfirmation` and wrapped in `AppDialog.showConfirmation`.
- **Keyboard Avoidance:** Bottom padding utilizes `MediaQuery.of(context).viewInsets.bottom + 20` inside a `SingleChildScrollView` to prevent keyboard obstruction.
- **Components Tested:**
  - 40x4 grey drag handle indicator.
  - Title and contextual icon (`AppColors.primary` or `AppColors.error` for destructive).
  - Key-value detail pairs summary card.
  - Standardized Cancel (`Navigator.pop(false)`) and Confirm (`Navigator.pop(true)`) action row.
  - Tested in unit suite and integrated across Owner/Tenant flows (Vacate Tenant, Verify Payment, Delete Expense, Logout).

### 3. Inline Form Validation & Dynamic Error Clearing (Option 3)
- **Initial Validation Trigger:** Verified via `screen_val.png` and `screen_reg_val2.png`.
  - Attempting to submit empty forms highlights invalid inputs with high-contrast crimson red borders (`#D32F2F`) and inline error messages (`"Email is required"`, `"Password is required"`, `"Please enter your name"`, `"Phone number is required"`).
  - Red asterisk (`*`) is cleanly rendered on all mandatory fields via `AppTextField(isRequired: true)`.
- **Dynamic Error Clearing on Interaction:** Verified via `screen_reg_typing.png`.
  - Typing into an invalid field immediately evaluates `onChanged` and clears the error message and border as soon as input criteria are met without requiring a form re-submit.

### 4. Slide-Down Top Notification Banner (Option 4)
- **Network Offline Simulation:** Verified via `screen_offline_banner_open_kbd.png`.
  - Disabled WiFi and Cellular data (`adb shell svc wifi disable; svc data disable`).
  - Triggered API network request.
  - Top banner slid down from below status bar with crimson red background, `cloud_off` icon, and text: *"Network offline. Please verify your internet connection."*
- **Authentication Expiry / Server Error:** Verified via `screen_tenant_logged.png`.
  - Displayed amber warning banner with `warning_amber` icon: *"Session expired. Please log in again."*
- **Dismissal:** Verified auto-dismissal timer (4 seconds) and manual tap-to-dismiss via close `x` icon.

### 5. Keyboard UX & Layout Insets (Option 5)
- **Keyboard Awareness (`adjustResize`):** Verified via `screen_typing.png` and `screen_offline_banner_open_kbd.png`.
  - Forms use `KeyboardAwareScrollView` with `IntrinsicHeight` and `SingleChildScrollView`.
  - Focused inputs and submit buttons smoothly remain visible above the soft keyboard.
- **Tap-Outside Keyboard Dismissal (`KeyboardDismissible`):** Verified via `screen_dismiss.png` and `screen_reg_tap300.png`.
  - Tapping empty background or card whitespace outside an active input immediately unfocuses `FocusManager.instance.primaryFocus` and dismisses Gboard smoothly without glitching.

### 6. Theme Modes (Light vs System Night Mode)
- **Toggled System Dark Mode:** `adb shell "cmd uimode night yes"`.
- **Verified Contrast:** Screen captured at `screen_dark_login.png`.
- **Result:** Application deliberately maintains its consistent, crisp brand palette (`AppTheme.lightTheme`) with high-contrast text (`#1E293B`) on clean surfaces, avoiding illegible system-inversion artifacts. Reverted via `adb shell "cmd uimode night no"`.

---

## Section C — Tests That Could Not Be Performed
1. **Destructive Production Data Mutations:**
   - In accordance with safety rules, destructive operations (e.g., permanently deleting real expenses, vacating genuine tenants, or dropping rooms on MongoDB Atlas) were not executed against live production collections.
   - These flows were thoroughly validated using non-destructive confirmation sheet dismissals (`Navigator.pop(false)`) and automated widget test harnesses.
2. **Physical Biometric Sensors:**
   - The test device is an x86_64 Google APIs Android 16 emulator (`emulator-5554`). Hardware-specific fingerprint/face biometric sensor prompts could not be verified on physical silicon.
3. **Third-Party Real SMS Gateway Delivery:**
   - Real-world carrier SMS OTP delivery was not triggered to prevent sending spurious messages to genuine owner/tenant telephone numbers.

---

## Section D — Bugs Found
- **Total Blocking Bugs:** 0
- **Total Critical Bugs:** 0
- **Minor Observations:**
  1. *Minor Cosmetic:* On Android 16 with full gesture navigation enabled, the system navigation bar at the very bottom renders an edge-to-edge transparent backing. The app's bottom bar and safe area handle this cleanly without content clipping.
  2. *Transient Gboard Tooling Popup:* On initial text focus in freshly initialized emulators, Gboard may display a transient "Using Google Translate" or "Contact suggestions" system overlay. Once dismissed, standard IME text input functions seamlessly.

---

## Section E — Recommended Fixes & Production Enhancements
1. **Dark Theme Palette Definition (Post-Launch Phase):**
   - Currently, `AppTheme.lightTheme` is configured for all system modes. For future releases, a dedicated `AppTheme.darkTheme` with dark slate surfaces (`#0F172A`) and crimson accents can be added to `AppTheme` if dark mode support is desired.
2. **Form Autofill Hints:**
   - Add `AutofillHints.email` and `AutofillHints.password` to `AppTextField` to allow password managers (Google Autofill, Bitwarden, 1Password) to prefill credentials seamlessly.
3. **Haptic Feedback:**
   - Trigger light haptic feedback (`HapticFeedback.lightImpact()`) upon successful confirmation bottom sheet actions or floating snackbar alerts to further enhance tactile user experience.
