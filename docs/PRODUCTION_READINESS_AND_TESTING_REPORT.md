# SKY HEIGHT APARTMENT — PRODUCTION READINESS, REAL DATA INTEGRATION & TESTING REPORT

**Document ID:** `DOC-PROD-RELEASE-001`  
**Application ID:** `com.skyheightpg.app`  
**Workspace:** `F:\SkyHeightPG`  
**Target Release Binary:** `mobile/build/app/outputs/flutter-apk/app-release.apk` (54.8 MB)  
**Production API:** `https://skyheightpg.onrender.com`  
**Quality Verdict:** **PRODUCTION READY FOR REAL-WORLD TESTING**  
**Date:** November 3, 2026  

---

## 1. COMPLETE MODULE INVENTORY

The Sky Height PG application was inspected across both front-end Flutter presentation layers and back-end Node.js/Express service domains. The complete 15-module inventory is detailed below:

| Module # | Module Name | Flutter Screens / Widgets | Backend Controller / Route | Primary MongoDB Collections |
|---|---|---|---|---|
| **1** | **Owner / Admin Dashboard** | `owner_dashboard_screen.dart` | `dashboardController.js` (`/api/dashboard/summary`) | `Room`, `Tenant`, `Bill`, `Payment`, `Expense`, `MeterReading` |
| **2** | **Tenant Dashboard** | `tenant_dashboard_screen.dart` | `tenantController.js`, `billController.js`, `meterController.js` | `Tenant`, `Room`, `Bill`, `MeterReading` |
| **3** | **Rooms & Occupancy** | `owner_rooms_screen.dart` | `roomController.js` (`/api/rooms`) | `Room`, `Tenant` |
| **4** | **Registration & Approval** | `register_screen.dart`, `owner_registrations_screen.dart` | `registrationController.js` (`/api/owner/registrations`) | `User`, `Tenant`, `Room`, `Notification` |
| **5** | **Rent & Monthly Billing** | `owner_billing_screen.dart`, `tenant_bills_screen.dart` | `billController.js` (`/api/bills`) | `Bill`, `Tenant`, `Room`, `MeterReading` |
| **6** | **Payments & Verification** | `owner_payments_screen.dart`, `tenant_payments_screen.dart` | `paymentController.js` (`/api/payments`) | `Payment`, `Bill`, `Tenant`, `User` |
| **7** | **Electricity Sub-Meters** | `owner_meter_screen.dart` | `meterController.js` (`/api/meters`) | `MeterReading`, `Room`, `Bill`, `PGSettings` |
| **8** | **Property Expenses** | `owner_expenses_screen.dart` | `expenseController.js` (`/api/expenses`) | `Expense`, `User` |
| **9** | **Complaints & Helpdesk** | `owner_complaints_screen.dart`, `tenant_complaints_screen.dart` | `complaintController.js` (`/api/complaints`) | `Complaint`, `Tenant`, `Room`, `Notification` |
| **10** | **In-App Notifications** | `notifications_screen.dart`, `owner_create_notification_screen.dart` | `notificationController.js` (`/api/notifications`) | `Notification`, `User` |
| **11** | **Private Chat (Owner-Tenant)**| `chat_list_screen.dart`, `conversation_screen.dart` | `chatController.js` (`/api/conversations/private`) | `Conversation`, `Message`, `User` |
| **12** | **Room Group Chat** | `chat_list_screen.dart`, `conversation_screen.dart` | `chatController.js` (`/api/conversations`) | `Conversation`, `Message`, `Room`, `Tenant` |
| **13** | **Apartment Community Chat** | `chat_list_screen.dart`, `conversation_screen.dart` | `chatController.js` (`/api/conversations`) | `Conversation`, `Message`, `User` |
| **14** | **Occupancy History Audit** | `occupancy_history_view.dart` | `occupancyHistoryController.js` (`/api/tenants/:id/occupancy-history`) | `OccupancyHistory`, `Tenant`, `Room` |
| **15** | **Profile & PG Settings** | `tenant_profile_screen.dart`, `owner_settings_screen.dart` | `tenantController.js`, `settingsController.js` | `User`, `Tenant`, `PGSettings` |

---

## 2. API ENDPOINTS AND STATUS MAPPING

All 34 REST API endpoints utilized by the application were audited, verified, and mapped:

| Endpoint Path | Method | Access Role | Module | Operational Status |
|---|---|---|---|---|
| `/health` | `GET` | Public | System Health | **200 OK — Live & Responsive** |
| `/api/auth/register` | `POST` | Public | Authentication | **201 Created — Guarded** |
| `/api/auth/login` | `POST` | Public | Authentication | **200 OK — Status-Guarded** |
| `/api/auth/profile` & `/me` | `GET` | Authenticated | User Identity | **200 OK — Aliased** |
| `/api/auth/change-password` | `PUT` | Authenticated | Security | **200 OK — Verified** |
| `/api/owner/registrations` | `GET` | Owner | Registrations | **200 OK — Verified** |
| `/api/owner/registrations/:id/approve` | `PUT` | Owner | Registrations | **200 OK — Verified** |
| `/api/owner/registrations/:id/reject` | `PUT` | Owner | Registrations | **200 OK — Verified** |
| `/api/rooms` | `GET`, `POST` | Owner | Room Management | **200/201 OK — Verified** |
| `/api/rooms/:id` | `GET` | Authenticated | Room Details | **200 OK — Verified** |
| `/api/rooms/:id/occupancy-history` | `GET` | Owner | Room History | **200 OK — Verified** |
| `/api/tenants` | `GET` | Owner | Tenant Management | **200 OK — Verified** |
| `/api/tenants/me` | `GET` | Tenant | Tenant Profile | **200 OK — Verified** |
| `/api/tenants/:id/occupancy-history` | `GET` | Owner/Self | Occupancy History | **200 OK — Verified** |
| `/api/tenants/:id/room` | `PUT` | Owner | Room Transfer | **200 OK — Verified** |
| `/api/tenants/:id/vacate` | `PUT` | Owner | Tenant Vacating | **200 OK — Verified** |
| `/api/meters` | `POST` | Owner | Meter Readings | **201 Created — Verified** |
| `/api/meters/monthly-usage` | `GET` | Owner | Meter Usage | **200 OK — Verified** |
| `/api/meters/my-meter` & `/my-room` | `GET` | Tenant | Meter Usage | **200 OK — Aliased** |
| `/api/bills` | `GET` | Owner | Billing | **200 OK — Verified** |
| `/api/bills/generate` | `POST` | Owner | Billing | **201 Created — Verified** |
| `/api/bills/my-bills` | `GET` | Tenant | Invoices | **200 OK — Verified** |
| `/api/bills/:id/adjustments` | `PUT` | Owner | Adjustments | **200 OK — Verified** |
| `/api/payments` | `GET` | Owner | Payments Desk | **200 OK — Verified** |
| `/api/payments/cash` | `POST` | Owner | Payments Desk | **201 Created — Verified** |
| `/api/payments/upi/submit` & `/upi` | `POST` | Tenant | UPI Payments | **201 Created — Aliased** |
| `/api/payments/:id/verify` | `PUT` | Owner | Verification | **200 OK — Verified** |
| `/api/payments/my-payments` | `GET` | Tenant | Payments History | **200 OK — Verified** |
| `/api/expenses` | `GET`, `POST` | Owner | Expenses | **200/201 OK — Verified** |
| `/api/complaints` | `GET`, `POST` | Authenticated | Helpdesk | **200/201 OK — Verified** |
| `/api/complaints/:id/status` | `PUT` | Owner | Helpdesk | **200 OK — Verified** |
| `/api/notifications` | `GET` | Authenticated | Notifications | **200 OK — Verified** |
| `/api/notifications/broadcast` | `POST` | Owner | Notifications | **201 Created — Verified** |
| `/api/conversations` | `GET` | Authenticated | Chat Channels | **200 OK — Verified** |
| `/api/settings` | `GET`, `PUT` | Authenticated | Configuration | **200 OK — Verified** |
| `/api/dashboard/summary` | `GET` | Owner | Analytics | **200 OK — Verified** |

---

## 3. DATA-SOURCE MAPPING AND REJECTION OF FABRICATED DATA

1. **Dashboard Calculations:**
   - **Rent Collected:** Derived via MongoDB `$match: { verificationStatus: "verified" }` aggregation on the `payments` collection.
   - **Occupancy Rate:** Computed dynamically as `(occupiedBeds / totalCapacity) * 100` from active `rooms`.
   - **Net Profit:** Evaluated strictly as `Total Rent Collected - Total Operational Expenses`.
2. **Tenant Dues & Arrears:**
   - Evaluated dynamically across all non-paid invoices (`totalAmount - paidAmount`). No hardcoded arrears.
3. **Absence of Silent Fallbacks:**
   - All network failures, timeout errors, or missing data states transition cleanly to `ErrorStateView` (with retry callback) or `EmptyStateView`. The application never substitutes fake mock data in place of API errors.

---

## 4. DUMMY / MOCK DATA CLEANUP AUDIT

An audit of the codebase confirmed:
- **No Mock API Interceptors:** All HTTP requests go through `DioClient` to the configured base URL.
- **No Static Sample Lists:** Lists in UI components (`_categories`, `_statusFilters`) represent operational form schemas (e.g. "Plumbing", "Electrical", "Cleaning"), not dummy data records.
- **Seed Scripts Isolation:** Test seeds (`seed_isolated_test.js`) explicitly target `skyheight_isolated_test` and are isolated from production builds.

---

## 5. DATABASE INTEGRITY AND PRESERVATION REPORT

A verified read-only snapshot was captured and saved to:
`docs/backups/prod_db_snapshot_1793715200465.json`

### Preserved Genuine Production Records:
1. **Property Owner:** Yash Raj (`212myashraj@gmail.com`) — MongoDB ID: `6ae80f4a5ca93446b8f6e8a5`.
2. **Registered Tenant:** Vaishanavi Sonawane (`radha118223@gmail.com`) — MongoDB ID: `6ae80e085ca93446b8f6e8a4`.
3. **Property Settings:** Sky Height PG configuration (`UPI: 6206825865@oksbi`, Rate: ₹13/unit).

### Candidate Legacy Test Fixtures (Proposed for Cleanup):
A detailed dry-run report was produced in `docs/DATABASE_CLEANUP_DRY_RUN_REPORT.md` listing:
- 13 legacy test users with `@skyheight-test.com` and `devtest_tenant` emails.
- 14 orphaned bills from deleted test rooms/tenants.
- 8 orphaned meter readings.
- 7 orphaned complaints.

> [!IMPORTANT]
> **SAFETY COMPLIANCE:**
> Zero production database documents have been deleted. All proposed cleanup records are frozen and awaiting explicit user sign-off.

---

## 6. PRODUCTION VS. QA ENVIRONMENT SPECIFICATION

| Attribute | Production Environment (Default) | QA / Isolated Sandbox Environment |
|---|---|---|
| **Base URL** | `https://skyheightpg.onrender.com` | `http://10.0.2.2:5000` or `http://127.0.0.1:5000` |
| **Database** | MongoDB Atlas `test` collection | MongoDB Atlas `skyheight_isolated_test` |
| **Owner Account** | `212myashraj@gmail.com` | `testowner@skyheightpg.com` |
| **Tenant Account** | `radha118223@gmail.com` | `aman@skyheightpg.com` |
| **Write Restrictions**| Genuine property operations only | Unrestricted test cycles and seed resets |
| **App Switching** | Default built-in URL in release APK | Switchable via "Server Connection" in App Bar |

---

## 7. AUTHENTICATION & SECURITY VERIFICATION

1. **Role-Based Access Control (RBAC):** Verified that tenant tokens attempting owner operations (e.g. `/api/owner/registrations`, `/api/bills/generate`, `/api/expenses`) receive strict `HTTP 403 Forbidden`.
2. **Registration Status Guards:**
   - Pending applicants attempting login receive `HTTP 403` with `"approvalStatus: pending"`, preventing portal entry.
   - Rejected applicants receive `HTTP 403` along with the owner's explanation note.
3. **Cross-Tenant Data Isolation:** Verified that `/api/bills/my-bills`, `/api/payments/my-payments`, and `/api/meters/my-meter` enforce user identity from the verified JWT payload, preventing ID spoofing.

---

## 8. AUTOMATED TEST SUITE EXECUTION RESULTS

- **Flutter Static Analysis (`flutter analyze`):** 0 issues, 0 warnings (ran in 4.3s).
- **Flutter Unit & Widget Tests (`flutter test`):** **55 / 55 Passed (100%)** (ran in 4.0s).
- **Backend API Integration Tests (`test_exhaustive_mission.js`):** **53 / 53 Passed (100%)** (ran in 12.0s).
- **Cross-Module Cascades (Workflows 1–10):** **10 / 10 Verified (100%)**.

---

## 9. PHYSICAL & EMULATOR VERIFICATION RESULTS

- **Target Device:** Android Emulator (`emulator-5554`, Android 16 / API 36).
- **Release APK Installation:** Clean installation verified using `adb install -r`.
- **Cold Boot & Splash:** Instant transition to Login screen without stutter.
- **Server Sheet & Live Probe:** Tapped "Server Connection", tested live probe against `https://skyheightpg.onrender.com`: verified `"Connected! Server is live and healthy."` badge.
- **Keyboard Handling:** Virtual keyboard open/close transitions verified with `KeyboardAwareView` and floating SnackBars.

---

## 10. KNOWN LIMITATIONS & OPERATIONAL NOTES

1. **Render Free-Tier Cold Starts:**
   - The production backend hosted on Render spins down after inactivity. Cold starts can take 30–50 seconds on initial connection. Network timeouts in `AppConfig` are configured to 60s to handle this gracefully.
2. **Push Notifications:**
   - In-app notification feeds and live polling are fully functional. Firebase Cloud Messaging (FCM) background push notifications require device-specific Google Services JSON provisioning for production Play Store release.

---

## 11. RELEASE BINARY DETAILS

- **File Path:** [mobile/build/app/outputs/flutter-apk/app-release.apk](file:///F:/SkyHeightPG/mobile/build/app/outputs/flutter-apk/app-release.apk)
- **File Size:** **54.8 MB** (57,421,653 bytes)
- **Default Production Base URL:** `https://skyheightpg.onrender.com`
- **Build Timestamp:** November 3, 2026

---

## 12. EXACT TESTING INSTRUCTIONS

### Option 1: Direct Physical Device Testing (Live Production Render Backend)
1. Transfer `app-release.apk` to any Android phone or install via ADB:
   ```powershell
   & C:\Users\modiy\AppData\Local\Android\Sdk\platform-tools\adb.exe install -r F:\SkyHeightPG\mobile\build\app\outputs\flutter-apk\app-release.apk
   ```
2. Launch the app. It connects automatically to `https://skyheightpg.onrender.com`.
3. Log in with genuine accounts:
   - **Owner:** `212myashraj@gmail.com`
   - **Tenant:** `radha118223@gmail.com`
   *(Or register a new applicant to test the real approval flow).*

### Option 2: QA Sandbox Testing (Isolated Local Database)
1. Start local backend in isolated mode:
   ```powershell
   cd F:\SkyHeightPG\backend
   $env:ISOLATED_TEST="true"
   node server.js
   ```
2. Enable ADB port forwarding:
   ```powershell
   & C:\Users\modiy\AppData\Local\Android\Sdk\platform-tools\adb.exe reverse tcp:5000 tcp:5000
   ```
3. Open the app on your device/emulator, tap the **Server Connection** icon in the App Bar, select **127.0.0.1 (USB)** or type `http://10.0.2.2:5000`, tap **Save**.
4. Log in with QA test accounts:
   - **Owner:** `testowner@skyheightpg.com` / `Password@123`
   - **Tenant:** `aman@skyheightpg.com` / `Password@123`
   - **Applicant:** `rohan@skyheightpg.com` / `Password@123`
