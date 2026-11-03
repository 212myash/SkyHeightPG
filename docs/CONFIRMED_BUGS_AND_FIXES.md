# SKY HEIGHT APARTMENT — CONFIRMED BUGS & CODE FIXES REPORT

**Date:** November 3, 2026  
**Application Stack:** Flutter Mobile (`mobile/`), Node.js + Express Backend (`backend/`), MongoDB Atlas (`skyheight_isolated_test` sandbox)  
**Production API Base URL:** `https://skyheightpg.onrender.com`  
**Safety Protocol:** Read-Only against Production Atlas DB (`test`). Zero production migrations or mutations. All write tests performed on isolated test sandbox `skyheight_isolated_test`.

---

## EXECUTIVE SUMMARY OF REPAIRS

During the comprehensive functional audit and end-to-end recovery testing of Sky Height Apartment, four functional and cross-module synchronization bugs were diagnosed, repaired, and validated with zero regressions across the codebase.

| Bug ID | Component | Severity | Description | Status | Verification |
|---|---|---|---|---|---|
| **BUG-01** | Backend `meterController.js` | Medium | Retroactive bill electricity sync when meter reading is logged after bill generation | **RESOLVED & VERIFIED** | Automated E2E Test #13: 100% PASS |
| **BUG-02** | Backend `complaintController.js` | Low / UX | Automated in-app notifications missing on complaint creation and status resolution | **RESOLVED & VERIFIED** | Automated E2E Tests #20-21 & Android UI: 100% PASS |
| **BUG-03** | Mobile `tenant_dashboard_screen.dart` | Low / Data | Arrears display showed only latest single bill instead of cumulative unpaid balance | **RESOLVED & VERIFIED** | Unit Tests in `recovery_e2e_test.dart` & Flutter Analyze: 100% PASS |
| **BUG-04** | Mobile `app_router.dart` & `owner_dashboard_screen.dart` | Low / Navigation | Missing direct route `/owner/payments` and broken "View All" link on Owner Dashboard | **RESOLVED & VERIFIED** | Direct navigation & GoRouter audit: 100% PASS |

---

## DETAILED BUG AUDIT & CODE FIXES

### BUG-01: Bill Generation vs. Meter Reading Sequence Decoupling

#### 1. Problem Description
If the PG Owner clicks "Generate Bills" at the start of the month before entering that month's electricity meter reading, the generated tenant bills were issued with `electricityAmount: 0`. When the Owner subsequently recorded the room meter reading via `POST /api/meters`, the existing unpaid bills were never retroactively updated or recalculated, leaving tenants billed at ₹0 electricity for the month.

#### 2. Root Cause
`meterController.addMeterReading` inserted the `MeterReading` record but did not check for or update pre-existing pending bills (`paymentStatus: 'pending'`, `paidAmount: 0`) for that room and billing month.

#### 3. Exact Code Changes
**File:** [`backend/controllers/meterController.js`](file:///F:/SkyHeightPG/backend/controllers/meterController.js)

```diff
--- a/backend/controllers/meterController.js
+++ b/backend/controllers/meterController.js
@@ -1,5 +1,6 @@
 const MeterReading = require("../models/MeterReading");
 const Room = require("../models/Room");
 const Tenant = require("../models/Tenant");
+const Bill = require("../models/Bill");
 const PGSettings = require("../models/PGSettings");
 const { isValidObjectId } = require("../utils/validateObjectId");

@@ -120,6 +121,34 @@
       recordedBy: req.user._id,
       remarks: remarks ? remarks.trim() : ""
     });
+
+    // Retroactive sync: If pending uncredited bills were generated before this meter reading,
+    // update their electricity portion and recalculate total amounts
+    try {
+      const pendingBills = await Bill.find({
+        room: roomId,
+        billingMonth: readingMonth,
+        paidAmount: 0,
+        $or: [{ electricityAmount: 0 }, { meterReading: null }, { meterReading: { $exists: false } }]
+      });
+
+      if (pendingBills.length > 0) {
+        const activeRoommatesCount = await Tenant.countDocuments({ room: roomId, status: "active" });
+        const divisor = Math.max(1, activeRoommatesCount || pendingBills.length);
+        const splitElec = Math.round((meterReading.electricityAmount / divisor) * 100) / 100;
+        const splitUnits = Math.round((meterReading.unitsConsumed / divisor) * 100) / 100;
+
+        for (const bill of pendingBills) {
+          bill.electricityAmount = splitElec;
+          bill.unitsConsumed = splitUnits;
+          bill.previousReading = meterReading.previousReading;
+          bill.currentReading = meterReading.currentReading;
+          bill.meterReading = meterReading._id;
+          await bill.save(); // triggers pre-save hook to recalculate totalAmount
+        }
+      }
+    } catch (billSyncErr) {
+      console.error("Retroactive Bill Sync Error in addMeterReading:", billSyncErr);
+    }

     return res.status(201).json({
       success: true,
```

#### 4. Validation Evidence
- Automated test `Retroactive Meter Sync (Bug 1 Fix Verification)`:
  - December bill generated first: Rent ₹6,000, Electricity ₹0, Total ₹6,000.
  - Meter reading logged: 50 units @ ₹10 = ₹500.
  - Re-fetched December bill: Electricity auto-updated to ₹500, Total auto-updated to ₹6,500 (**PASS**).

---

### BUG-02: Missing Automated In-App Notifications on Complaint Events

#### 1. Problem Description
When a tenant submitted a maintenance complaint via `POST /api/complaints`, the Owner received no in-app notification. Similarly, when the Owner updated a complaint's status to "resolved" with technician notes, the tenant received no in-app notification.

#### 2. Root Cause
`backend/controllers/complaintController.js` did not import or instantiate `Notification` documents during `createComplaint` or `updateComplaintStatus`.

#### 3. Exact Code Changes
**File:** [`backend/controllers/complaintController.js`](file:///F:/SkyHeightPG/backend/controllers/complaintController.js)

```diff
--- a/backend/controllers/complaintController.js
+++ b/backend/controllers/complaintController.js
@@ -1,5 +1,7 @@
 const Complaint = require("../models/Complaint");
 const Tenant = require("../models/Tenant");
+const Notification = require("../models/Notification");
+const User = require("../models/User");
 const { isValidObjectId } = require("../utils/validateObjectId");

@@ -36,6 +38,26 @@
       status: "open"
     });
+
+    // Send in-app notification to all active Owners
+    try {
+      const owners = await User.find({ role: "owner", isActive: true });
+      for (const owner of owners) {
+        await Notification.create({
+          recipient: owner._id,
+          sender: req.user._id,
+          title: `New Complaint: ${complaint.title}`,
+          message: `${tenant.fullName} has filed a ${complaint.priority} priority complaint (${complaint.category}).`,
+          category: "complaint_update",
+          audience: "tenant",
+          targetTenant: tenant._id,
+          targetRoom: tenant.room,
+          relatedComplaint: complaint._id
+        });
+      }
+    } catch (notifErr) {
+      console.error("Failed to notify owners of new complaint:", notifErr);
+    }

     return res.status(201).json({
@@ -212,7 +234,7 @@
-    const complaint = await Complaint.findById(id).populate("tenant", "fullName");
+    const complaint = await Complaint.findById(id).populate("tenant", "fullName user");
     if (!complaint) {
       return res.status(404).json({
@@ -230,6 +252,23 @@
     await complaint.save();
+
+    // Send in-app notification to the tenant regarding complaint resolution/status change
+    try {
+      if (complaint.tenant && complaint.tenant.user) {
+        await Notification.create({
+          recipient: complaint.tenant.user,
+          sender: req.user._id,
+          title: `Complaint Updated: ${complaint.title}`,
+          message: `Your complaint status has been updated to '${status}'.${complaint.resolution ? ` Resolution notes: ${complaint.resolution}` : ""}`,
+          category: "complaint_update",
+          audience: "tenant",
+          targetTenant: complaint.tenant._id,
+          relatedComplaint: complaint._id
+        });
+      }
+    } catch (notifErr) {
+      console.error("Failed to notify tenant of complaint update:", notifErr);
+    }

     return res.status(200).json({
```

#### 4. Validation Evidence
- Automated test `Owner In-App Notification on Complaint Creation (Bug 2 Part 1)`: **PASS** (`Notif: New Complaint: Geyser not working in Room 101`).
- Automated test `Tenant In-App Notification on Complaint Resolution (Bug 2 Part 2)`: **PASS** (`Notif: Complaint Updated: Geyser not working in Room 101`).
- Android Emulator UI Inspection: Tenant device received and rendered notification badge and notification card with resolution notes: `"Heating element replaced by electrician."` (**PASS**).

---

### BUG-03: Cumulative Outstanding Arrears Display on Tenant Dashboard

#### 1. Problem Description
On `TenantDashboardScreen`, "Pending Due" displayed `(_latestBill['totalAmount'] - _latestBill['paidAmount'])`. If a tenant had unpaid bills from multiple prior months, the dashboard displayed only the current month's due, failing to alert the tenant of cumulative arrears across previous cycles.

#### 2. Root Cause
The screen only kept `_latestBill` from the bills array and did not sum across all unpaid bills.

#### 3. Exact Code Changes
**File:** [`mobile/lib/features/tenant/presentation/tenant_dashboard_screen.dart`](file:///F:/SkyHeightPG/mobile/lib/features/tenant/presentation/tenant_dashboard_screen.dart)

```diff
--- a/mobile/lib/features/tenant/presentation/tenant_dashboard_screen.dart
+++ b/mobile/lib/features/tenant/presentation/tenant_dashboard_screen.dart
@@ -26,4 +26,5 @@
   Map<String, dynamic>? _tenantData;
   Map<String, dynamic>? _latestBill;
+  List<dynamic> _allBills = [];
   Map<String, dynamic>? _latestMeter;

@@ -61,4 +62,5 @@
         if (billsRes != null && billsRes['success'] == true) {
           final bills = billsRes['data'] as List<dynamic>? ?? [];
+          _allBills = bills;
           if (bills.isNotEmpty) {
             _latestBill = bills.first as Map<String, dynamic>?;
@@ -164,4 +166,15 @@
     final paidAmount = _latestBill?['paidAmount'] ?? 0;
     final pendingAmount = (totalBill - paidAmount).clamp(0, double.infinity);
+
+    // Cumulative arrears across all historical unpaid bills
+    num totalArrears = 0;
+    for (final b in _allBills) {
+      final bStatus = (b['paymentStatus'] ?? '').toString().toLowerCase();
+      if (bStatus != 'paid') {
+        final tot = (b['totalAmount'] as num?) ?? 0;
+        final pd = (b['paidAmount'] as num?) ?? 0;
+        totalArrears += (tot - pd).clamp(0, double.infinity);
+      }
+    }
@@ -330,4 +343,26 @@
                               ),
                             ],
                           ),
                         ],
                       ),
+                      if (totalArrears > pendingAmount) ...[
+                        const Divider(height: 24),
+                        Row(
+                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
+                          children: [
+                            Text(
+                              'Total Arrears (All Bills)',
+                              style: AppTextStyles.bodySmall.copyWith(
+                                color: AppColors.error,
+                                fontWeight: FontWeight.w600,
+                              ),
+                            ),
+                            Text(
+                              CurrencyFormatter.format(totalArrears),
+                              style: AppTextStyles.h3.copyWith(
+                                color: AppColors.error,
+                                fontWeight: FontWeight.bold,
+                              ),
+                            ),
+                          ],
+                        ),
+                      ],
```

#### 4. Validation Evidence
- Flutter Unit Tests in `mobile/test/recovery_e2e_test.dart`:
  - `Cumulative arrears calculation sums across multiple unpaid bills`: **PASS** (₹6,000 + ₹6,850 = ₹12,850).
  - `Arrears calculation handles fully paid bills accurately`: **PASS** (₹0).
  - `Arrears calculation correctly handles partial payments`: **PASS** (₹4,000).

---

### BUG-04: Missing Direct `/owner/payments` Route & Broken Navigation Link

#### 1. Problem Description
On `OwnerDashboardScreen`, the "Recent Verified Payments" card contained a "View All" button that triggered `context.push('/owner/billing')`. In `app_router.dart`, there was no route definition for `/owner/payments`, making `OwnerPaymentsScreen` only accessible as an in-stack tab in `OwnerMainScreen`.

#### 2. Root Cause
Omission of `/owner/payments` `GoRoute` in router configuration and misdirected route target in dashboard button callback.

#### 3. Exact Code Changes
**Files:** [`mobile/lib/app/router/app_router.dart`](file:///F:/SkyHeightPG/mobile/lib/app/router/app_router.dart) & [`mobile/lib/features/owner/presentation/owner_dashboard_screen.dart`](file:///F:/SkyHeightPG/mobile/lib/features/owner/presentation/owner_dashboard_screen.dart)

```diff
--- a/mobile/lib/app/router/app_router.dart
+++ b/mobile/lib/app/router/app_router.dart
@@ -14,4 +14,5 @@
 import '../../features/owner/presentation/owner_expenses_screen.dart';
 import '../../features/owner/presentation/owner_registrations_screen.dart';
+import '../../features/owner/presentation/owner_payments_screen.dart';
 import '../../features/notifications/presentation/notifications_screen.dart';
@@ -124,4 +125,8 @@
       GoRoute(
         path: '/owner/registrations',
         builder: (context, state) => const OwnerRegistrationsScreen(),
       ),
+      GoRoute(
+        path: '/owner/payments',
+        builder: (context, state) => const OwnerPaymentsScreen(),
+      ),

--- a/mobile/lib/features/owner/presentation/owner_dashboard_screen.dart
+++ b/mobile/lib/features/owner/presentation/owner_dashboard_screen.dart
@@ -327,3 +327,3 @@
               TextButton(
-                onPressed: () => context.push('/owner/billing'),
+                onPressed: () => context.push('/owner/payments'),
                 child: const Text('View All'),
               ),
```

#### 4. Validation Evidence
- `flutter analyze`: **No issues found** (0 warnings, 0 errors).
- Android Emulator UI verification: Direct navigation to Payments desk opens `Payments & Ledger` with `Pending UPI` and `All Payments` tabs.

---

## VERIFICATION SUMMARY & ZERO-REGRESSION CONFIRMATION

1. **Backend Integration Suite:** 26 / 26 tests passing (100%).
2. **Flutter Test Suite:** 55 / 55 tests passing (100%).
3. **Flutter Static Analysis:** Clean (`flutter analyze` completed in 26.2s with 0 warnings).
4. **Android Device QA:** Clean live rendering on Android Emulator (`emulator-5554`) for both Owner and Tenant portals.
