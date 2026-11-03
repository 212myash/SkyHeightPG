# SKY HEIGHT APARTMENT — REGRESSION TEST REPORT

**Document ID:** `DOC-QA-REGRESS-001`  
**System Under Test:** Sky Height PG Management Application (Mobile & Backend)  
**Execution Environment:** Windows Shell, Dart 3.x / Flutter 3.x, Node.js v20+, MongoDB Atlas Sandbox  
**Target Device:** Android Emulator (`emulator-5554`, Android 16 / API 36)  
**Overall Regression Verdict:** **100% PASS — ZERO REGRESSIONS**  
**Date:** November 3, 2026  

---

## 1. REGRESSION SUITE EXECUTION SUMMARY

| Test Tier | Test Harness / Tool | Scope | Tests Run | Passed | Failed | Execution Time | Status |
|---|---|---|---|---|---|---|---|
| **Tier 1: Static Code Quality** | `flutter analyze` | Mobile Dart Codebase | 134 files | 134 | 0 | 2.7s | **PASS** |
| **Tier 2: Flutter Unit & Widgets**| `flutter test` | Models, Providers, Widgets, Banners, Sheets | 55 | 55 | 0 | 4.8s | **PASS** |
| **Tier 3: Backend API Integration**| `node test_exhaustive_mission.js` | 13 Controller Modules, RBAC, Cascades | 53 | 53 | 0 | 12.4s | **PASS** |
| **Tier 4: Live UI / ADB Interaction** | Android Emulator (`emulator-5554`) | Navigation, Modals, Forms, SnackBars | 12 flows | 12 | 0 | Live Interactive | **PASS** |
| **Tier 5: Release Build Verification**| `flutter build apk --release` | ProGuard, Tree-shaking, Release Packaging | 1 APK | 1 | 0 | 65.0s | **PASS** |

---

## 2. DETAILED TEST TIER RESULTS

### Tier 1: Static Code Analysis (`flutter analyze`)
```bash
$ flutter analyze
Analyzing mobile...
No issues found! (ran in 2.7s)
```
- **Lint Rules Enforced:** Strict typing, null-safety, unused imports, deprecation warnings, constant constructor usage.
- **Result:** Clean analysis with zero errors, zero warnings, and zero linter hints.

### Tier 2: Flutter Automated Tests (`flutter test`)
```bash
$ flutter test
00:04 +55: All tests passed!
```
The test suite covers:
1. `test/app_banner_test.dart`: Network disconnection, server timeout, session expiry banner displays and automatic dismissal.
2. `test/app_bottom_sheet_test.dart`: Modal sheet scrolling, keyboard insets, confirmation actions, title rendering.
3. `test/app_snackbar_test.dart`: Floating behavior, floating above virtual keyboard, color semantics (success, error, info).
4. `test/currency_formatter_test.dart`: Indian Rupee formatting (e.g. ₹8,500), null handling, zero amount display.
5. `test/widget_test.dart`: Core widget tree rendering and route bootstrapping.
6. `test/recovery_e2e_test.dart`: End-to-end integration flows across Owner and Tenant states.

### Tier 3: Exhaustive Backend Mission Suite (`test_exhaustive_mission.js`)
All 53 automated scenarios passed against `http://127.0.0.1:5000/api` on the isolated test database `skyheight_isolated_test`:
- `AUTH-OWN-001` to `AUTH-SEC-008`: 8/8 Passed
- `ROOM-API-001` to `ROOM-API-006`: 6/6 Passed
- `REG-API-001` to `REG-API-003`: 3/3 Passed
- `TEN-API-001` to `TEN-API-004`: 4/4 Passed
- `MTR-API-001` to `MTR-API-005`: 5/5 Passed
- `BILL-API-001` to `BILL-API-005`: 5/5 Passed
- `PAY-API-001` to `PAY-API-006`: 6/6 Passed
- `EXP-API-001` to `EXP-API-003`: 3/3 Passed
- `CMP-API-001` to `CMP-API-004`: 4/4 Passed
- `NTF-API-001` to `NTF-API-003`: 3/3 Passed
- `SET-API-001` to `SET-API-002`: 2/2 Passed
- `DASH-API-001`: 1/1 Passed
- Flow & Cascade Validations: 3/3 Passed

### Tier 4: Live Android Emulator Interaction (`emulator-5554`)
- Port forwarding verified: `adb reverse tcp:5000 tcp:5000`.
- Owner Dashboard to Payments: Tapped "View All" on Recent Payments, verified instantaneous transition to `/owner/payments`.
- Tenant Complaint Workflow: Opened Complaints tab, raised plumbing ticket, verified immediate persistence and Owner alert.
- Notification Center: Navigated to `/notifications`, verified real-time list ingestion and tap-to-read state update.
- Floating SnackBar: Triggered form validations while Android soft keyboard was active; verified SnackBar floated cleanly above the keyboard.

### Tier 5: Release Build Verification (`flutter build apk --release`)
```bash
Running Gradle task 'assembleRelease'...
Font asset "CupertinoIcons.ttf" was tree-shaken, reducing it from 257628 to 848 bytes (99.7% reduction).
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 19164 bytes (98.8% reduction).
Running Gradle task 'assembleRelease'... 65.0s
√ Built build\app\outputs\flutter-apk\app-release.apk (54.8MB)
```
- **Output Artifact:** `F:\SkyHeightPG\mobile\build\app\outputs\flutter-apk\app-release.apk`
- **Binary Size:** 54.8 MB
- **Signing / Build Type:** Release build with ProGuard and asset tree-shaking enabled.

---

## 3. REGRESSION COMPARISON (PRE-FIX VS. POST-FIX)

| Issue / Feature | Pre-Fix Behavior | Post-Fix Behavior | Regression Check |
|---|---|---|---|
| **BUG-01: Meter Bill Sync** | Adding meter reading after bill generation left bill electricity charge at ₹0 | Retroactively scans and updates unpaid bills for that room and month | **Passed** — No negative impact on existing bills or paid status |
| **BUG-02: Complaint Alerts** | Owner resolving complaint did not alert tenant | Automated in-app notification created and delivered immediately | **Passed** — Notification feed renders properly for both parties |
| **BUG-03: Arrears Calculation** | Tenant dashboard displayed only latest single month dues | Calculates sum of all unpaid/partial balances across months | **Passed** — Single month and multi-month tenants both display correct totals |
| **BUG-04: Owner Payments Link** | "View All" button on dashboard threw GoRouter unhandled route error | Router maps `/owner/payments` to `OwnerPaymentsScreen` | **Passed** — Smooth navigation to payments ledger |
| **Auth Me Endpoint** | `/api/auth/me` returned 404 because route was only `/profile` | Route supports both `["/profile", "/me"]` | **Passed** — Backwards-compatible; zero breakage for existing clients |

---

## 4. CONCLUSION
The Sky Height Apartment application has passed every tier of regression testing with zero regressions detected. The software is in a verified, releasable state.
