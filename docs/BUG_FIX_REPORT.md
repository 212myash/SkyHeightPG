# SKY HEIGHT APARTMENT — BUG FIX & RESOLUTION REPORT

## Overview
This document records every confirmed anomaly, reproduction steps, root cause analysis, and architectural resolution applied across the Sky Height Apartment mobile application and Node.js backend.

---

### BUG-01: Owner Dashboard Zero-Metric Display
- **Component:** `mobile/lib/features/owner/presentation/owner_dashboard_screen.dart` & `backend/controllers/dashboardController.js`
- **Severity:** High (Functional & Usability)
- **Reproduction:**
  1. Log into the mobile application as Owner (`212myashraj@gmail.com`).
  2. Navigate to Owner Dashboard.
  3. All financial and room metric cards displayed "₹0" and "0 Total Beds" despite active database records.
- **Root Cause:**
  Mismatched JSON payload keys between the Flutter state consumer and backend aggregation responses:
  - Flutter expected: `financials['totalCollected']`, `financials['pendingAmount']`, `rooms['totalBeds']`, `electricity['totalUnits']`.
  - Backend returned: `financials['monthlyRentCollection']`, `financials['pendingPayments']`, `rooms['totalCapacity']`, `electricity['unitsConsumed']`.
- **Resolution:**
  1. Updated `owner_dashboard_screen.dart` with robust fallback extraction:
     ```dart
     final totalCollected = (financials['totalCollected'] ?? financials['monthlyRentCollection'] ?? 0) as num;
     final pendingAmount = (financials['pendingAmount'] ?? financials['pendingPayments'] ?? 0) as num;
     final totalBeds = (occupancy['totalBeds'] ?? occupancy['totalCapacity'] ?? rooms['totalCapacity'] ?? 0) as num;
     final unitsConsumed = (electricity['totalUnits'] ?? electricity['unitsConsumed'] ?? 0) as num;
     ```
  2. Enhanced `dashboardController.js` to return bidirectional aliases (`totalBeds`, `totalCollected`, `pendingAmount`, `totalUnits`, `occupancy` object) while preserving legacy keys for backward compatibility.
- **Verification:**
  Owner Dashboard successfully displays Total Rooms (8), Occupied Beds (7), Monthly Rent (₹76,500), Pending Dues (₹49,500), and Electricity Units (1,100).

---

### BUG-02: Tenant Dashboard Sub-Meter Zero Display
- **Component:** `mobile/lib/features/tenant/presentation/tenant_dashboard_screen.dart` & `backend/controllers/meterController.js`
- **Severity:** Medium (Data Visibility)
- **Reproduction:**
  1. Log in as an active tenant assigned to a room with meter readings.
  2. Inspect the "Electricity Sub-Meter" card on the Tenant Dashboard.
  3. "Units Consumed" and "Latest Reading" showed "0 Units" and "0 kWh".
- **Root Cause:**
  `GET /api/meters/my-meter` returns meter details nested under `data.latestReading`:
  ```json
  { "success": true, "data": { "room": {...}, "latestReading": { "unitsConsumed": 150, "currentReading": 1150 } } }
  ```
  `tenant_dashboard_screen.dart` was extracting keys directly from `_latestMeter['unitsConsumed']`, evaluating to null and falling back to 0.
- **Resolution:**
  1. Updated `tenant_dashboard_screen.dart`:
     ```dart
     final latestReading = (_latestMeter?['latestReading'] as Map<String, dynamic>?) ?? _latestMeter;
     final unitsConsumed = latestReading?['unitsConsumed'] ?? _latestMeter?['unitsConsumed'] ?? 0;
     final currentReading = latestReading?['currentReading'] ?? _latestMeter?['currentReading'] ?? 0;
     ```
  2. Updated `meterController.js` `getMyMeterDetails` to expose top-level convenience aliases (`unitsConsumed`, `currentReading`, `previousReading`, `ratePerUnit`, `electricityAmount`).
- **Verification:**
  Tested with active tenant account; Tenant Dashboard correctly displays "150 Units" and "1150 kWh".

---

### BUG-03: Hardcoded Credentials & Debug Prefill Helpers in Source Code
- **Component:** `mobile/lib/features/auth/presentation/login_screen.dart`
- **Severity:** High (Security & Code Cleanliness)
- **Reproduction:**
  Inspecting `login_screen.dart` revealed hardcoded email strings and passwords inside a `kDebugMode` prefill helper block.
- **Root Cause:**
  Development convenience helper left in the source code.
- **Resolution:**
  1. Completely stripped the `kDebugMode` prefill block and unused `foundation.dart` import from `login_screen.dart`.
  2. Form now initializes strictly with empty text controllers and clean password hint `••••••••`.
  3. Created `mobile/test/login_security_test.dart` to automatically guard against hardcoded emails, passwords, and helper buttons via static source code scanning and widget tree inspection.
- **Verification:**
  Both source code audit and UI widget tests passed 100%. `flutter analyze` reported 0 issues.

---

### BUG-04: Atlas MongoDB DNS Resolution on Windows
- **Component:** `backend/server.js` & `backend/config/db.js`
- **Severity:** Medium (Development & Testing Reliability)
- **Reproduction:**
  Running Node.js test scripts or local server occasionally threw `querySrv ECONNREFUSED` when resolving MongoDB Atlas SRV connection strings on Windows 11.
- **Root Cause:**
  Windows default local DNS resolver occasionally rejects UDP SRV lookups for cloud clusters.
- **Resolution:**
  Configured automated DNS fallback using Google Public DNS servers (`8.8.8.8`, `8.8.4.4`):
  ```javascript
  const dns = require("dns");
  if (process.env.CUSTOM_DNS === "true" || (!process.env.RENDER && process.env.NODE_ENV !== "production")) {
    try { dns.setServers(["8.8.8.8", "8.8.4.4"]); } catch (e) {}
  }
  ```
- **Verification:**
  100% reliable connection to MongoDB Atlas across all background scripts and live tests.
