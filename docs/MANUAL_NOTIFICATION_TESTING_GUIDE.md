# SKY HEIGHT APARTMENT — MANUAL PUSH NOTIFICATION TESTING GUIDE

**Application ID:** `com.skyheightpg.app`  
**Workspace:** `F:\SkyHeightPG`  
**Platform:** Android (Flutter Mobile + Node.js Backend)  
**Date:** November 2026

---

## 1. Overview & Objectives

This guide provides end-to-end instructions for manually verifying real-device push notifications and in-app alert flows across both **Owner** and **Tenant** roles.

It covers:
- Firebase Console credentials configuration.
- Device token lifecycle verification.
- Testing in all 3 app states: **Foreground**, **Background**, and **Terminated (Killed)**.
- Event-driven push notifications across all business modules.
- Deep-link navigation verification on notification click.
- Graceful degradation verification (when running without Firebase credentials).

---

## 2. Prerequisites & Firebase Setup

### 2.1 Android Device Configuration
- Physical Android device or Android Emulator running API 33+ (Android 13+).
- Google Play Services must be installed and active on the device.
- Grant Notification Permission when the system prompt appears on first launch.

### 2.2 Firebase Console Configuration (When Connecting Live FCM)
1. Open the [Firebase Console](https://console.firebase.google.com/).
2. Create or select your project: `Sky Height PG`.
3. Add an Android App with package name: `com.skyheightpg.app`.
4. Download the generated `google-services.json` and place it in:
   `F:\SkyHeightPG\mobile\android\app\google-services.json`
5. Go to **Project Settings** > **Service Accounts** > **Generate New Private Key**.
6. Save the JSON key file, and on your backend server set the environment variable:
   ```env
   FIREBASE_SERVICE_ACCOUNT_KEY={"type":"service_account","project_id":"...","private_key":"...","client_email":"..."}
   ```
   *(Or place `serviceAccountKey.json` directly in `F:\SkyHeightPG\backend\config\serviceAccountKey.json`).*

---

## 3. Step-by-Step Test Scenarios

### Scenario 1: Device Token Registration & Deregistration

#### Steps:
1. Launch the app and log in as Owner (`owner@skyheightpg.com`).
2. Verify token registration:
   - Check device Logcat (`adb logcat -s FlutterPush`):
     ```
     [PushNotification] Device token registered with backend successfully
     ```
3. Open a terminal and query MongoDB to verify the token record:
   ```bash
   node -e "const mongoose=require('mongoose'); mongoose.connect(process.env.MONGODB_URI).then(async ()=>{ const t=await mongoose.connection.collection('devicetokens').find({}).toArray(); console.log(t); process.exit(0); });"
   ```
4. In the app, navigate to **Profile / More** and tap **Logout**.
5. Check Logcat and MongoDB:
   - The device token is removed from MongoDB, preventing notifications to logged-out users.

---

### Scenario 2: Bill Generation $\rightarrow$ Tenant Push Notification

#### Target:
- Recipient: **Tenant**
- Channel: `billing` (`Rent & Bills`)
- Deep Link: `/tenant/bills`

#### Steps:
1. Log in as **Tenant** on Device A. Send app to background (press Home button).
2. On Device B or Web/Postman, log in as **Owner**.
3. Go to **Bills** > **Generate Bill** > Select the tenant from Device A, set amount (e.g. ₹8,500), and tap **Generate**.
4. **Expected Result on Device A (Background):**
   - High-priority system tray notification appears:
     - **Title:** `New Bill Generated`
     - **Body:** `Your bill for [Month] has been generated: ₹8,500. Due: [Date].`
5. Tap the notification on Device A.
   - **Expected Result:** App opens directly to the **Tenant Bills Screen** (`/tenant/bills`), displaying the newly generated bill.

---

### Scenario 3: UPI Payment Submission $\rightarrow$ Owner Push Notification

#### Target:
- Recipient: **Owner**
- Channel: `billing` (`Rent & Bills`)
- Deep Link: `/owner/payments`

#### Steps:
1. Log in as **Owner** on Device A. Send app to background.
2. Log in as **Tenant** on Device B.
3. On Device B, go to **Bills** > select unpaid bill > tap **Pay Online**.
4. Enter UTR reference number (e.g., `UTR987654321`) and submit.
5. **Expected Result on Device A (Owner):**
   - Push notification arrives:
     - **Title:** `Payment Submitted`
     - **Body:** `[Tenant Name] submitted UPI payment of ₹8,500 (UTR: UTR987654321).`
6. Tap the notification:
   - App opens directly to **Owner Payments Screen** (`/owner/payments`), highlighting the pending approval.

---

### Scenario 4: Payment Approval $\rightarrow$ Tenant Push Notification

#### Target:
- Recipient: **Tenant**
- Channel: `billing`
- Deep Link: `/tenant/payments`

#### Steps:
1. On Owner device, tap **Approve** on the submitted payment.
2. **Expected Result on Tenant Device:**
   - Push notification arrives:
     - **Title:** `Payment Approved`
     - **Body:** `Your payment of ₹8,500 has been verified and approved.`
3. Tap notification $\rightarrow$ opens **Tenant Payment History** showing green `PAID` badge.

---

### Scenario 5: Complaint Raised $\rightarrow$ Owner Push Notification

#### Target:
- Recipient: **Owner**
- Channel: `maintenance` (`Maintenance & Complaints`)
- Deep Link: `/owner/complaints`

#### Steps:
1. As **Tenant**, open **Complaints** > tap **+ New Complaint**.
2. Title: `AC cooling issue`, Category: `Appliance`, Priority: `High`, Description: `AC is blowing warm air`. Tap **Submit**.
3. **Expected Result on Owner Device:**
   - Push notification arrives:
     - **Title:** `New Complaint Raised`
     - **Body:** `New complaint: AC cooling issue (Room 201, Priority: HIGH).`
4. Tap notification $\rightarrow$ opens **Owner Complaints Screen** with the complaint visible.

---

### Scenario 6: Complaint Resolved $\rightarrow$ Tenant Push Notification

#### Target:
- Recipient: **Tenant**
- Channel: `maintenance`
- Deep Link: `/tenant/complaints`

#### Steps:
1. As **Owner**, select `AC cooling issue` > tap **Update Status** > choose **RESOLVED** and enter note: `Technician fixed compressor`.
2. **Expected Result on Tenant Device:**
   - Push notification arrives:
     - **Title:** `Complaint Resolved`
     - **Body:** `Your complaint 'AC cooling issue' status updated to RESOLVED.`
3. Tap notification $\rightarrow$ opens **Tenant Complaints Screen** showing resolved badge.

---

### Scenario 7: Meter Reading Logged $\rightarrow$ Occupant Push Notification

#### Target:
- Recipient: **All Room Occupants**
- Channel: `billing`
- Deep Link: `/tenant/bills`

#### Steps:
1. As **Owner**, go to **More** > **Meter Readings** > select Room 201.
2. Enter current reading: `1450 units` (e.g. 50 units consumed @ ₹10/unit = ₹500 total). Save reading.
3. **Expected Result on Room 201 Occupant Device:**
   - Push notification arrives:
     - **Title:** `Meter Reading Logged`
     - **Body:** `Meter reading recorded for Room 201: 50 units (₹250/person).`
4. Tap notification $\rightarrow$ opens **Tenant Bills Screen**.

---

### Scenario 8: Broadcast Announcement $\rightarrow$ All Tenants

#### Target:
- Recipient: **All Active Tenants**
- Channel: `announcements` (`Announcements`)
- Deep Link: `/notifications`

#### Steps:
1. As **Owner**, go to **Notifications** > tap **+ Create Notice**.
2. Title: `Water Tank Cleaning Tomorrow`, Audience: `All Tenants`, Message: `Water supply will be suspended between 10 AM and 2 PM tomorrow.` Tap **Send Announcement**.
3. **Expected Result on All Tenant Devices:**
   - High-priority banner appears with custom sound and vibration:
     - **Title:** `Water Tank Cleaning Tomorrow`
     - **Body:** `Water supply will be suspended between 10 AM and 2 PM tomorrow.`
4. Tap notification $\rightarrow$ opens **Notifications Screen**.

---

### Scenario 9: Real-Time Chat Message $\rightarrow$ Recipient Push

#### Target:
- Recipient: **Chat Partner**
- Channel: `messages` (`Messages & Chat`)
- Deep Link: `/chat/:conversationId`

#### Steps:
1. Put Tenant app into background or lock screen.
2. From Owner app, go to **Community / Messages** > open chat with that Tenant > send: `Please collect your parcel from reception.`
3. **Expected Result on Tenant Device:**
   - Push notification arrives:
     - **Title:** `Sky Height Admin`
     - **Body:** `Please collect your parcel from reception.`
4. Tap notification $\rightarrow$ opens the active conversation screen directly.

---

### Scenario 10: Graceful Degradation Test (No Firebase Credentials)

#### Objective:
Verify that if Firebase is offline or not configured, the app and backend continue functioning cleanly without crashing.

#### Steps:
1. Ensure `FIREBASE_SERVICE_ACCOUNT_KEY` is not set on the backend.
2. Perform any of Scenarios 2–9 (e.g., generate bill, submit complaint, send message).
3. **Expected Result:**
   - HTTP response returns status `200 OK` or `201 Created` with full payload.
   - Backend terminal logs: `[PushNotification] Push service unavailable or token empty: skipping push dispatch`.
   - In-app notification appears in the recipient's in-app Notifications tab (`/notifications`).
   - Mobile app does not freeze, crash, or show an unhandled error dialog.

---

## 4. Useful ADB & Diagnostic Commands

### View live push notification logs on device:
```bash
adb logcat -s FlutterPush PushService FirebaseMessaging flutter
```

### Check active notification channels on device:
```bash
adb shell dumpsys notification --noredact | grep -E "announcements|billing|maintenance|messages|alerts"
```

### Clear app storage and restart fresh:
```bash
adb shell pm clear com.skyheightpg.app
```
