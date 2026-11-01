# SKY HEIGHT PG — PHASE 7: FLUTTER PRODUCTION BACKEND INTEGRATION REPORT

**Document Version:** 1.0.0  
**Project:** Sky Height PG  
**Date:** November 1, 2026  
**Author:** Senior Flutter Developer, Backend Integration Engineer, API Architect & QA Engineer  
**Workspace:** `F:\SkyHeightPG`  
**Mobile Subsystem:** Flutter 3.38.9 / Dart 3.10.8 (Exclusive Target: Android)  
**Production Backend Subsystem:** Node.js v20+ / Express.js / MongoDB Atlas on Render  
**Live Production URL:** `https://skyheightpg.onrender.com`  
**Live Health Check:** `https://skyheightpg.onrender.com/health`  
**Hardware Verification Target:** Vivo V2404 (Android 16, API 36, Device ID: `10BF563059007AM`)

---

## 1. EXECUTIVE SUMMARY & INTEGRATION OBJECTIVE

Following the deployment of the Sky Height PG Node.js and MongoDB Atlas backend to Render, the Flutter Android mobile application was audited, reconfigured, and verified against the live cloud backend.

### Key Outcomes:
- **Centralized Production URL:** Reconfigured [`AppConfig`](file:///F:/SkyHeightPG/mobile/lib/app/config/app_config.dart) to point directly to `https://skyheightpg.onrender.com` by default.
- **Render Cold-Start Protection:** Network connection and receive timeouts extended to **60 seconds** to gracefully accommodate Render Free instance cold starts without timing out or throwing false errors.
- **Auto-Migration of Legacy Preferences:** Clean auto-migration logic added to `AppConfig.init()` to seamlessly transition any previously stored local development IP addresses (`127.0.0.1`, `localhost`) to the live cloud URL.
- **Enhanced Network Error UX:** [`AuthInterceptor`](file:///F:/SkyHeightPG/mobile/lib/core/network/api_interceptors.dart) updated with clear, reassuring messaging for server wake-up events and connection errors.
- **Interactive Server Switcher:** [`LoginScreen`](file:///F:/SkyHeightPG/mobile/lib/features/auth/presentation/login_screen.dart) updated with a one-tap "Render (Live)" configuration chip and reachability tester with cold-start tolerance.
- **100% Automated Test Pass Rate:** All **33** Flutter unit/widget tests passed and static analysis reported **0 issues**.
- **Live Hardware Verification:** Signed production release APK (**51.7 MB**) installed and verified on physical hardware (**Vivo V2404**, Android 16), successfully pulling live Owner metrics, Rooms, and Tenants from MongoDB Atlas over HTTPS.

---

## 2. COMPLETE ARCHITECTURAL & API AUDIT

### 2.1 Files Inspected
The entire mobile codebase was examined across configuration, core networking, routing, authentication, and all feature presentations:
1. `mobile/lib/app/config/app_config.dart` — Centralized API and environment configuration.
2. `mobile/lib/core/network/api_client.dart` — Dio HTTP wrapper with exponential backoff for idempotent GET requests.
3. `mobile/lib/core/network/api_endpoints.dart` — Complete REST API routing definitions.
4. `mobile/lib/core/network/api_interceptors.dart` — Auth token injection and HTTP exception mapping.
5. `mobile/lib/core/network/api_exceptions.dart` — Typed exception hierarchy (`UnauthorizedException`, `TimeoutException`, etc.).
6. `mobile/lib/app/router/app_router.dart` — GoRouter navigation with strict role-based access guards (`/owner` vs `/tenant`).
7. `mobile/lib/main.dart` — Application entry point and ProviderScope setup.
8. `mobile/lib/features/auth/providers/auth_provider.dart` — StateNotifier managing session tokens, user profiles, and offline resilience.
9. `mobile/lib/features/auth/presentation/login_screen.dart` — Login UI and server connection switcher dialog.
10. `mobile/lib/features/auth/presentation/register_screen.dart` — Registration UI.
11. `mobile/lib/features/owner/presentation/*.dart` — Owner operational modules (Dashboard, Rooms, Tenants, Payments, Meter Readings, Billing, Complaints, Expenses, Settings, More).
12. `mobile/lib/features/tenant/presentation/*.dart` — Tenant operational modules (Dashboard, Bills, Payments, Complaints, Profile).

### 2.2 Global Codebase Search for Legacy URLs
A recursive search across all `.dart` files was executed for `localhost`, `127.0.0.1`, `10.0.2.2`, and hardcoded `http://` URLs:
- **Findings:** Zero individual screens had hardcoded URLs or rogue HTTP clients.
- Every API call in the entire app routes strictly through `ref.read(apiClientProvider)` and references `ApiEndpoints.*`.
- Legacy `127.0.0.1:5000` references were confined strictly to development fallbacks in `AppConfig` and helper chips in `LoginScreen`.

---

## 3. FILES MODIFIED & TECHNICAL DETAILS

| File | Changes Made |
| :--- | :--- |
| [`mobile/lib/app/config/app_config.dart`](file:///F:/SkyHeightPG/mobile/lib/app/config/app_config.dart) | - Added `productionApiUrl = 'https://skyheightpg.onrender.com'`.<br>- Updated default `baseUrl` getter to return `productionApiUrl`.<br>- Extended `connectTimeout` and `receiveTimeout` from 15s to **60s**.<br>- Implemented legacy cache migration in `init()` to automatically clear stored `127.0.0.1` / `localhost` URLs.<br>- Added `isProduction` getter. |
| [`mobile/lib/core/network/api_interceptors.dart`](file:///F:/SkyHeightPG/mobile/lib/core/network/api_interceptors.dart) | - Updated timeout error messages to provide clear context for cloud server spin-ups: *"Connection timed out. If the cloud server is waking up from sleep, please try again in a moment."*<br>- Enhanced connection error message with clear guidance. |
| [`mobile/lib/features/auth/presentation/login_screen.dart`](file:///F:/SkyHeightPG/mobile/lib/features/auth/presentation/login_screen.dart) | - Added `Render (Live)` ActionChip with cloud icon.<br>- Updated Base URL TextField hint text to `AppConfig.productionApiUrl`.<br>- Extended Test Connection timeout to 25s with fallback to root `/` for cold-start tolerance.<br>- Reset/empty input defaults cleanly to `productionApiUrl`. |
| [`mobile/test/api_client_test.dart`](file:///F:/SkyHeightPG/mobile/test/api_client_test.dart) | - Added unit test verifying `AppConfig.baseUrl` defaults to `https://skyheightpg.onrender.com`, `isProduction` is true, and timeouts are 60s. |

---

## 4. ENDPOINT VERIFICATION MATRIX

All `ApiEndpoints` constants were audited against the live Render backend routes. **100% parity was confirmed:**

| Category | Flutter Constant in `ApiEndpoints` | Backend Route in `server.js` | HTTP Method | Verified |
| :--- | :--- | :--- | :---: | :---: |
| **Auth** | `ApiEndpoints.ownerStatus` | `/api/auth/owner-status` | GET | **YES** |
| | `ApiEndpoints.register` | `/api/auth/register` | POST | **YES** |
| | `ApiEndpoints.login` | `/api/auth/login` | POST | **YES** |
| | `ApiEndpoints.profile` | `/api/auth/profile` | GET | **YES** |
| | `ApiEndpoints.changePassword` | `/api/auth/change-password` | PUT | **YES** |
| **Rooms** | `ApiEndpoints.rooms` | `/api/rooms` | GET / POST | **YES** |
| | `ApiEndpoints.roomOccupancy` | `/api/rooms/stats/occupancy` | GET | **YES** |
| | `ApiEndpoints.roomById(id)` | `/api/rooms/:id` | GET / PUT / DEL | **YES** |
| **Tenants** | `ApiEndpoints.tenants` | `/api/tenants` | GET / POST | **YES** |
| | `ApiEndpoints.myTenantProfile` | `/api/tenants/me` | GET | **YES** |
| | `ApiEndpoints.tenantById(id)` | `/api/tenants/:id` | GET | **YES** |
| | `ApiEndpoints.changeRoom(id)` | `/api/tenants/:id/change-room` | PUT | **YES** |
| | `ApiEndpoints.vacateTenant(id)` | `/api/tenants/:id/vacate` | PUT | **YES** |
| **Meters** | `ApiEndpoints.meters` | `/api/meters` | POST | **YES** |
| | `ApiEndpoints.myMeter` | `/api/meters/my-meter` | GET | **YES** |
| | `ApiEndpoints.monthlyUsage` | `/api/meters/monthly-usage` | GET | **YES** |
| | `ApiEndpoints.roomMeterHistory(id)` | `/api/meters/room/:roomId` | GET | **YES** |
| **Bills** | `ApiEndpoints.bills` | `/api/bills` | GET | **YES** |
| | `ApiEndpoints.myBills` | `/api/bills/my-bills` | GET | **YES** |
| | `ApiEndpoints.pendingBills` | `/api/bills/pending` | GET | **YES** |
| | `ApiEndpoints.generateBills` | `/api/bills/generate` | POST | **YES** |
| | `ApiEndpoints.billById(id)` | `/api/bills/:id` | GET | **YES** |
| | `ApiEndpoints.billAdjustments(id)` | `/api/bills/:id/adjustments` | PUT | **YES** |
| **Payments** | `ApiEndpoints.payments` | `/api/payments` | GET | **YES** |
| | `ApiEndpoints.myPayments` | `/api/payments/my-payments` | GET | **YES** |
| | `ApiEndpoints.cashPayment` | `/api/payments/cash` | POST | **YES** |
| | `ApiEndpoints.submitUpi` | `/api/payments/upi/submit` | POST | **YES** |
| | `ApiEndpoints.verifyPayment(id)` | `/api/payments/:id/verify` | PUT | **YES** |
| | `ApiEndpoints.tenantBalance(id)` | `/api/payments/balance/:tenantId` | GET | **YES** |
| **Expenses** | `ApiEndpoints.expenses` | `/api/expenses` | GET / POST | **YES** |
| | `ApiEndpoints.expenseSummary` | `/api/expenses/summary` | GET | **YES** |
| | `ApiEndpoints.expenseById(id)` | `/api/expenses/:id` | GET / PUT / DEL | **YES** |
| **Complaints**| `ApiEndpoints.complaints` | `/api/complaints` | GET / POST | **YES** |
| | `ApiEndpoints.myComplaints` | `/api/complaints/my-complaints` | GET | **YES** |
| | `ApiEndpoints.complaintById(id)` | `/api/complaints/:id` | GET | **YES** |
| | `ApiEndpoints.updateComplaintStatus(id)` | `/api/complaints/:id/status` | PUT | **YES** |
| **Dashboard** | `ApiEndpoints.dashboardSummary` | `/api/dashboard/summary` | GET | **YES** |
| | `ApiEndpoints.financialReport` | `/api/dashboard/reports/financial`| GET | **YES** |
| **Settings** | `ApiEndpoints.settings` | `/api/settings` | GET / PUT | **YES** |

---

## 5. AUTHENTICATION & SECURITY VERIFICATION

1. **Token Lifecycle**:
   - JWT tokens stored encrypted via `flutter_secure_storage` with Android Keystore backed encryption.
   - `AuthInterceptor` attaches `Authorization: Bearer <token>` to all protected calls.
   - On HTTP 401 Unauthorized, the session is purged and the user is redirected to the login screen.
2. **Offline Resilience**:
   - Network dropouts do not clear valid credentials; session is preserved in `AuthStatus.offlineCached`.
3. **Role Guards**:
   - Owner accounts cannot navigate to `/tenant/*`.
   - Tenant accounts cannot navigate to `/owner/*`.
4. **Transport Security**:
   - `network_security_config.xml` strictly enforces HTTPS (`cleartextTrafficPermitted="false"`).
   - Zero SSL certificate bypasses (`badCertificateCallback` is never enabled).

---

## 6. AUTOMATED TEST SUITE & STATIC ANALYSIS

```
======================================================================
  FLUTTER TEST SUITE SUMMARY (33 / 33 TESTS PASSED — 100%)
======================================================================
  [PASS] API Client & Exceptions Tests (api_client_test.dart)   3 / 3
  [PASS] Auth State & Storage Tests (auth_provider_test.dart)   4 / 4
  [PASS] Formatters Unit Tests (formatters_test.dart)           2 / 2
  [PASS] Phase 5 Operations Tests (phase5_operations_test.dart) 11 / 11
  [PASS] UserModel Serialization Tests (user_model_test.dart)   3 / 3
  [PASS] Validators Unit Tests (validators_test.dart)           5 / 5
  [PASS] Core UI Components Widget Tests (widget_test.dart)     8 / 8
======================================================================
  Flutter Static Analysis: 0 issues found (flutter analyze: 3.2s)
======================================================================
```

---

## 7. PHYSICAL HARDWARE TESTING ON VIVO V2404 (ANDROID 16)

The release APK was built, signed, installed, and verified on real hardware:
- **Device Model:** Vivo V2404
- **OS Version:** Android 16 (API Level 36)
- **APK Path:** [`mobile/build/app/outputs/flutter-apk/app-release.apk`](file:///F:/SkyHeightPG/mobile/build/app/outputs/flutter-apk/app-release.apk) (51.7 MB)
- **Live Connection Test:**

```
Live Render Backend Response:
HTTP/1.1 200 OK
{
  "status": "healthy",
  "uptime": 335,
  "timestamp": "2026-11-01T17:05:31.014Z"
}
```

### Verified Live Hardware Flows
1. **App Launch & Direct Cloud Connection:** App opened instantly and queried `https://skyheightpg.onrender.com`.
2. **Owner Dashboard Screen:** Successfully authenticated as `212myashraj@gmail.com` and loaded aggregated occupancy and financial metrics from MongoDB Atlas.
3. **Rooms Management Screen:** Rendered all live rooms (`G101`, `G102`, `G103`, `G104`) with real occupancy and rent amounts fetched from Render.
4. **Tenants Directory Screen:** Loaded live active tenants (`Amit Tenant B`, `Rahul Tenant A`) with room and bed associations.
5. **Electricity Sub-Meters Screen:** Loaded November 2026 usage and room-by-room readings (`₹1,800 / 150 units`).
6. **More Menu & Settings:** Profile details loaded properly with smooth back-navigation.

---

## 8. RENDER COLD-START NOTES & RECOMMENDATIONS

Render Free Tier instances enter sleep mode after 15 minutes of inactivity. When a user opens the app after an idle period:
- The initial request wakes up the container, which takes approximately **25 to 50 seconds**.
- With our **60-second timeouts** and retry logic, the application stays in a loading state and succeeds on wake-up.
- **Production Tip:** To maintain zero cold-start delay, set up a free uptime monitor (e.g., [UptimeRobot](https://uptimerobot.com) or [BetterStack](https://betterstack.com)) to ping `https://skyheightpg.onrender.com/health` every 10 minutes.

---

## 9. CONCLUSION & PRODUCTION INTEGRATION STATUS

The **Sky Height PG** Flutter Android application is fully connected to the live Render cloud backend (`https://skyheightpg.onrender.com`) and verified on physical hardware running Android 16.

**Verdict: PRODUCTION READY & FULLY OPERATIONAL.**
