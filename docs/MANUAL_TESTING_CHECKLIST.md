# SKY HEIGHT APARTMENT — MANUAL TESTING CHECKLIST

**Document ID:** `DOC-QA-MANUAL-001`  
**Purpose:** Comprehensive, step-by-step physical device & emulator verification checklist for QA testers and product stakeholders.  
**Release Artifact:** `mobile/build/app/outputs/flutter-apk/app-release.apk` (54.8 MB)  
**Date:** November 3, 2026  

---

## 1. PRE-REQUISITES & ENVIRONMENT SETUP

### Device / Network Options
- **Option A (Local Isolated Test Backend):**
  - Run local backend: `Set-Location F:\SkyHeightPG\backend; $env:ISOLATED_TEST="true"; node server.js`
  - Forward port via ADB: `adb reverse tcp:5000 tcp:5000`
  - Install APK: `adb install -r F:\SkyHeightPG\mobile\build\app\outputs\flutter-apk\app-release.apk`
- **Option B (Production Render API):**
  - Use production API: `https://skyheightpg.onrender.com`

### Verified Test Credentials
| Role | Email | Password | Assigned Room / State |
|---|---|---|---|
| **Owner / Admin** | `testowner@skyheightpg.com` | `Password@123` | Property Administrator |
| **Tenant 1 (Active)** | `aman@skyheightpg.com` | `Password@123` | Room 101 (Occupant) |
| **Tenant 2 (Active)** | `vikram@skyheightpg.com` | `Password@123` | Room 102 (Occupant) |
| **Pending Applicant** | `rohan@skyheightpg.com` | `Password@123` | Awaiting Owner Approval |

---

## 2. OWNER / ADMIN MANUAL TESTING CHECKLIST

### A. Authentication & Session
- [ ] **TC-OWN-01: Owner Login**
  - Action: Enter `testowner@skyheightpg.com` and `Password@123`, tap "Sign In".
  - Expected: Authenticates successfully, navigates to Owner Dashboard (`/owner`).
- [ ] **TC-OWN-02: Session Persistence**
  - Action: Close app completely from Recents, reopen app.
  - Expected: Splash screen rehydrates token, opens Owner Dashboard directly without asking for credentials.

### B. Owner Dashboard (`/owner`)
- [ ] **TC-OWN-03: Dashboard Metrics Display**
  - Action: Inspect Top Metrics: Total Rooms, Occupied Beds, Active Tenants, Rent Collected, Expenses, Net Profit.
  - Expected: Numbers match active database counts; Net Profit = Rent Collected - Expenses.
- [ ] **TC-OWN-04: Pull-to-Refresh**
  - Action: Pull down from the top of the dashboard screen.
  - Expected: Circular progress indicator displays, data refreshes smoothly without UI glitch.
- [ ] **TC-OWN-05: Quick Actions Navigation**
  - Action: Tap badge icon (Registrations), bell icon (Notifications), chat icon (Messages).
  - Expected: Routes to `/owner/registrations`, `/notifications`, and `/chat` respectively.
- [ ] **TC-OWN-06: Recent Payments "View All" Link (BUG-04 Fix)**
  - Action: Scroll to "Recent Payments" card, tap "View All".
  - Expected: Navigates cleanly to `/owner/payments` without router errors.

### C. Room Management (`/owner` Tab 1)
- [ ] **TC-OWN-07: Room Inventory & Status Filters**
  - Action: Tap "Rooms" tab. Tap "All", "Available", "Occupied" filter chips.
  - Expected: Room cards update based on occupancy state.
- [ ] **TC-OWN-08: Add Room Modal Form**
  - Action: Tap floating (+) button. Enter Room: 303, Floor: 3, Rent: 8000, Capacity: 2. Tap "Save".
  - Expected: Bottom sheet dismisses, Room 303 appears at top of room list.
- [ ] **TC-OWN-09: Duplicate Room Number Validation**
  - Action: Tap (+), enter Room: "101". Tap "Save".
  - Expected: Floating error SnackBar indicates room number already exists.
- [ ] **TC-OWN-10: Room Details & Occupancy History**
  - Action: Tap on Room 101 card.
  - Expected: Bottom sheet displays active occupant (Aman Sharma) and "Occupancy History" button showing historical occupant timeline.

### D. Registration Desk (`/owner/registrations`)
- [ ] **TC-OWN-11: Review Pending Applicant**
  - Action: Open Registrations screen.
  - Expected: Rohan Gupta displayed with "Pending" status badge.
- [ ] **TC-OWN-12: Approve Applicant with Room Allocation**
  - Action: Tap "Approve", select Room 102, Rent ₹7,500, Deposit ₹7,500. Tap "Confirm".
  - Expected: Applicant disappears from pending list; Room 102 occupied beds increments; user receives active status.

### E. Tenant Management (`/owner` Tab 2)
- [ ] **TC-OWN-13: Active Tenants Search**
  - Action: Tap "Tenants" tab. Type "Aman" in search bar.
  - Expected: Displays Aman Sharma with room badge and contact details.
- [ ] **TC-OWN-14: Tenant Room Transfer**
  - Action: Tap tenant card -> "Transfer Room" -> select destination room with vacancy -> tap "Confirm".
  - Expected: Tenant room updates, bed counts adjust for both rooms, occupancy history record created.
- [ ] **TC-OWN-15: Vacate Tenant**
  - Action: Tap tenant card -> "Vacate Tenant" -> enter leaving date and reason -> tap "Confirm".
  - Expected: Tenant marked vacated, room bed released, final occupancy record closed.

### F. Electricity Meter Logging (`/owner/meter`)
- [ ] **TC-OWN-16: Log Sub-Meter Reading**
  - Action: Open Meter screen, tap "Log Reading" on Room 101. Enter reading higher than previous.
  - Expected: Units consumed and cost auto-calculated using PG tariff.
- [ ] **TC-OWN-17: Lower Reading Validation**
  - Action: Enter reading lower than previous reading.
  - Expected: Error shown: "Current reading cannot be lower than previous reading".
- [ ] **TC-OWN-18: Retroactive Bill Sync (BUG-01 Fix)**
  - Action: Log reading for a room with an existing unpaid bill for current month.
  - Expected: Bill's electricity charge and total amount update automatically.

### G. Invoicing & Billing (`/owner/billing`)
- [ ] **TC-OWN-19: Generate Monthly Bill**
  - Action: Tap (+) button, select tenant, month (YYYY-MM), due date. Tap "Generate".
  - Expected: Bill generated with base rent + electricity charge.
- [ ] **TC-OWN-20: Duplicate Bill Prevention**
  - Action: Attempt generating bill for same tenant and month again.
  - Expected: Backend rejects with error: bill already exists for this month.
- [ ] **TC-OWN-21: Concession / Discount Adjustment**
  - Action: Tap "Adjust" on unpaid bill, enter discount ₹500.
  - Expected: Total payable updates to reflect discount.

### H. Payments Desk (`/owner/payments`)
- [ ] **TC-OWN-22: Verify Pending UPI Payment**
  - Action: Open `/owner/payments`, find pending UPI payment card with UTR, tap "Verify".
  - Expected: Payment marked verified, bill `paidAmount` credited, bill status updated to "paid".
- [ ] **TC-OWN-23: Record Direct Cash Payment**
  - Action: Tap "Record Cash", select tenant bill, enter cash amount, tap "Confirm".
  - Expected: Verified cash payment record created, bill credited instantly.

### I. Expenses & Net Profit (`/owner/expenses`)
- [ ] **TC-OWN-24: Add Operational Expense**
  - Action: Open Expenses, tap (+), Title: "Water Filter Service", Amount: ₹800, Category: "Maintenance".
  - Expected: Expense saved; Owner Dashboard Net Profit decreases by exactly ₹800.

### J. Complaints Helpdesk (`/owner/complaints`)
- [ ] **TC-OWN-25: Resolve Complaint with Note (BUG-02 Fix)**
  - Action: Open Complaints, tap ticket, change status to "Resolved", add note: "Technician fixed issue".
  - Expected: Ticket marked resolved; filing tenant receives automated in-app resolution alert.

### K. Broadcast Notices (`/notifications/create`)
- [ ] **TC-OWN-26: Create Property Notice**
  - Action: Open Notifications -> (+), Audience: "All Tenants", Title: "Diwali Celebration", Message: "Sweets at 7 PM".
  - Expected: Notice created; delivers to all active tenants.

### L. Settings (`/owner/settings`)
- [ ] **TC-OWN-27: Update PG Configuration**
  - Action: Update UPI ID to `skyheight@bank` and Electricity Rate to `₹12/unit`. Tap "Save".
  - Expected: Settings saved; reflected across future bills and UPI payment modal.

---

## 3. TENANT MANUAL TESTING CHECKLIST

### A. Prospective Registration & Guards
- [ ] **TC-TEN-01: Tenant Registration**
  - Action: On login screen, tap "Register". Enter Name, Phone, Email, Password. Submit.
  - Expected: Registration submitted with "Pending Approval" message.
- [ ] **TC-TEN-02: Pending Login Guard**
  - Action: Attempt login with newly registered pending email.
  - Expected: Blocked with message: "Your registration is pending owner approval".

### B. Tenant Dashboard (`/tenant`)
- [ ] **TC-TEN-03: Room & Tariff Display**
  - Action: Log in as `aman@skyheightpg.com`. Inspect Home tab.
  - Expected: Room 101, Monthly Rent ₹8,000, Security Deposit ₹8,000 displayed.
- [ ] **TC-TEN-04: Multi-Month Arrears Card (BUG-03 Fix)**
  - Action: When multiple monthly bills are unpaid/partial, inspect "Total Outstanding Dues".
  - Expected: Displays sum of ALL outstanding balances, not just the latest month.
- [ ] **TC-TEN-05: Sub-Meter Usage Widget**
  - Action: Inspect electricity card on dashboard.
  - Expected: Displays latest reading, units consumed, and cost calculation.

### C. Invoices & UPI Payment
- [ ] **TC-TEN-06: View Itemized Invoices**
  - Action: Tap "Bills" tab. Tap on an unpaid invoice card.
  - Expected: Bottom sheet shows Rent + Electricity - Concession = Total Due.
- [ ] **TC-TEN-07: Submit UPI Payment with UTR**
  - Action: Tap "Pay via UPI", copy PG UPI ID, enter 12-digit UTR, tap "Submit Payment".
  - Expected: Payment recorded with "Pending Verification" status; Owner alerted.
- [ ] **TC-TEN-08: Duplicate UTR Prevention**
  - Action: Attempt submitting payment with identical UTR.
  - Expected: Rejection SnackBar indicates UTR already used.

### D. Complaints & Helpdesk
- [ ] **TC-TEN-09: Raise Maintenance Complaint**
  - Action: Tap "Complaints" tab -> (+) button. Enter Title: "Fan Regulator Not Working", Category: "Electrical".
  - Expected: Ticket submitted; appears in tenant ticket list with "Pending" status chip.
- [ ] **TC-TEN-10: Receive Resolution Alert**
  - Action: After owner marks complaint resolved, check tenant notification bell.
  - Expected: In-app notification received with owner's technician notes.

### E. Profile & Occupancy History
- [ ] **TC-TEN-11: View Occupancy Timeline**
  - Action: Go to Profile -> tap "Occupancy History".
  - Expected: Chronological timeline displays each room lived in, joining dates, leaving dates, and reasons.

---

## 4. SIGN-OFF SHEET

| Role | Tester Name | Date | Devices Tested | Overall Result (PASS/FAIL) | Signature |
|---|---|---|---|---|---|
| **Lead QA Engineer** | | | Android Emulator / Physical Device | | |
| **Product Owner** | | | Android Physical Device | | |
