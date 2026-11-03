# SKY HEIGHT APARTMENT — FCM REAL DEVICE TESTING GUIDE

**Application ID:** `com.skyheightpg.app`  
**Target Platform:** Physical Android Device (Android 8.0 to Android 15+)  
**Backend:** Render Production API (`https://skyheightpg.onrender.com`)  
**APK Location:** `mobile/build/app/outputs/flutter-apk/app-release.apk`  
**Date:** November 2026

---

## 1. Scope & Objective

This testing guide provides step-by-step instructions for testing **real-device Firebase Cloud Messaging (FCM) push notifications** on physical Android hardware or Google Play-enabled Android Virtual Devices.

> [!IMPORTANT]
> **Audit Status vs Physical Device Testing:**  
> All automated tests (unit, widget, backend API, responsive layouts) and Firebase configuration checks have passed 100%.  
> However, physical device push delivery (actual arrival of notifications on real handset hardware) must be performed by following the steps in this guide on your testing device.

---

## 2. Prerequisites & Device Setup

1. **Physical Android Handset:**
   - Any Android phone running Android 8.0 or newer (Android 13+ recommended to verify runtime permission).
   - Google Play Services must be updated and functioning.
   - Connected to active Wi-Fi or cellular internet.
2. **Install Release APK:**
   - Transfer `mobile/build/app/outputs/flutter-apk/app-release.apk` to your phone via USB cable, Google Drive, or ADB:
     ```bash
     adb install -r F:\SkyHeightPG\mobile\build\app\outputs\flutter-apk\app-release.apk
     ```

---

## 3. Step-by-Step Verification Procedures

### Step 1: Initial Launch & Notification Permission Prompt (Android 13+)
1. Open **Sky Height PG** on the physical device.
2. **Expected System Dialog:**
   - *"Allow Sky Height PG to send you notifications?"*
3. Tap **Allow**.
4. **Verification:**
   - Go to device **Settings** > **Apps** > **Sky Height PG** > **Notifications**.
   - Verify that all 5 channels are listed and toggled ON:
     1. `Announcements` (High importance)
     2. `Billing & Payments` (High importance)
     3. `Maintenance & Complaints` (Default importance)
     4. `Chat Messages` (High importance)
     5. `Security & System Alerts` (Max importance)

---

### Step 2: Login & Device Token Registration
1. On the login screen, enter valid credentials:
   - For Owner testing: Log in with Owner credentials.
   - For Tenant testing: Log in with Tenant credentials.
2. Upon successful authentication, the app automatically fetches the Firebase Cloud Messaging registration token and calls:
   `POST https://skyheightpg.onrender.com/api/notifications/device-token`
3. **Verification (via Device Logcat):**
   ```bash
   adb logcat -s FlutterPush
   ```
   Output:
   ```
   [PushNotificationService] Firebase Cloud Messaging initialized successfully.
   [PushNotificationService] Device token registered with backend.
   ```

---

### Step 3: Test Scenario A — Bill Generation (Owner $\rightarrow$ Tenant)
1. **Prepare Tenant Device:**
   - Log in as **Tenant** on the physical phone.
   - Press the **Home** button on the phone (app is in the **Background**).
2. **Trigger Action as Owner:**
   - On a second phone, PC browser, or Postman connected to `https://skyheightpg.onrender.com`:
   - Log in as Owner.
   - Generate a bill for the logged-in Tenant (e.g. November 2026 rent).
3. **Expected Physical Device Result:**
   - Phone vibrates and sounds notification chime.
   - System notification appears in the status bar:
     - **Title:** `New Bill Generated: 2026-11`
     - **Body:** `Your bill of ₹[Amount] for 2026-11 is ready. Due date: [Date].`
     - **Channel:** `Billing & Payments`
4. **Deep-Link Tap Test:**
   - Tap the notification banner on the physical phone.
   - **Expected Result:** The app opens directly to `TenantMainScreen` with the **Bills** tab active (`/tenant/bills`), displaying the newly generated invoice.

---

### Step 4: Test Scenario B — Payment Submission & Approval
1. **Submit Payment (Tenant):**
   - On the Tenant phone, go to **Bills** > select the unpaid bill > tap **Pay Online**.
   - Enter UTR number (e.g., `UTR987654321`) and submit.
2. **Owner Device Notification:**
   - The Owner device receives a push notification:
     - **Title:** `New UPI Payment: ₹[Amount]`
     - **Body:** `[Tenant Name] submitted UPI payment (Ref: UTR987654321). Please verify.`
   - Tapping the notification opens the **Owner Payments Screen** (`/owner/payments`).
3. **Approve Payment (Owner):**
   - Owner taps **Verify / Approve**.
4. **Tenant Device Notification:**
   - Tenant physical phone receives a push notification:
     - **Title:** `Payment Approved: ₹[Amount]`
     - **Body:** `Your UPI payment of ₹[Amount] has been verified and credited.`
   - Tapping the notification opens **Tenant Payments** (`/tenant/payments`), showing the confirmed payment.

---

### Step 5: Test Scenario C — Maintenance Complaint Ticket
1. **Lodge Complaint (Tenant):**
   - As Tenant, file a new complaint (e.g., `Geyser not working in Room 101`).
2. **Owner Device Notification:**
   - Push notification arrives:
     - **Title:** `New Complaint: Geyser not working in Room 101`
     - **Body:** `[Tenant Name] has filed a HIGH priority complaint (Plumbing).`
   - Tap $\rightarrow$ opens **Owner Complaints** (`/owner/complaints`).
3. **Resolve Complaint (Owner):**
   - Owner updates complaint status to `RESOLVED` with resolution notes: `Heating element replaced`.
4. **Tenant Device Notification:**
   - Tenant phone receives push notification:
     - **Title:** `Complaint Updated: Geyser not working in Room 101`
     - **Body:** `Status updated to 'RESOLVED'. Notes: Heating element replaced`
   - Tap $\rightarrow$ opens **Tenant Complaints** (`/tenant/complaints`).

---

### Step 6: Test Scenario D — Broadcast Notice / Announcement
1. Put Tenant device to sleep (Screen locked).
2. As Owner, create an announcement:
   - **Title:** `Diwali Celebration Dinner`
   - **Audience:** `All Tenants`
   - **Message:** `Join us at 8 PM in the common hall for Diwali dinner.`
3. **Physical Device Lock-Screen Result:**
   - Screen wakes up with notification sound/vibration.
   - Lock screen displays notification safely without privacy compromise.
   - Unlocking and tapping opens **Notifications** (`/notifications`).

---

### Step 7: Test Scenario E — Terminated / Killed App State
1. Open Sky Height PG on the physical phone.
2. Swipe the app away from Android's **Recent Apps / App Switcher** so the process is completely killed.
3. Send a message to that user via the Community Chat or trigger an announcement.
4. **Expected Physical Device Result:**
   - Android's FCM system daemon receives the high-priority packet and displays the notification in the status bar even though the app process was terminated.
   - Tapping the notification cold-launches the app and navigates to the target screen.

---

### Step 8: Logout Token Deregistration
1. In the app, navigate to **Profile / More** and tap **Logout**.
2. **Verification:**
   - App calls `DELETE https://skyheightpg.onrender.com/api/notifications/device-token`.
   - The device token is removed from MongoDB.
   - Triggering a new bill or message for that user no longer pushes to the logged-out device.

---

## 4. Diagnostic Commands

### View live FCM logs via ADB:
```bash
adb logcat -s FlutterPush PushService FirebaseMessaging flutter
```

### Inspect notification delivery dumpsys:
```bash
adb shell dumpsys notification --noredact | grep -i "skyheight"
```
