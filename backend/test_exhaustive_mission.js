/**
 * SKY HEIGHT APARTMENT — EXHAUSTIVE FUNCTION-BY-FUNCTION MISSION TEST SUITE
 * Tests every controller, route, permission check, boundary, and data cascade
 * strictly against http://127.0.0.1:5000 (skyheight_isolated_test)
 */

const BASE_URL = "http://127.0.0.1:5000";

let ownerToken = "";
let tenant1Token = "";
let tenant2Token = "";
let ownerHeaders = {};
let tenant1Headers = {};
let tenant2Headers = {};

let room101Id = "";
let room102Id = "";
let room201Id = "";
let tenant1Id = "";
let tenant1UserId = "";
let applicantUserId = "";
let bill1Id = "";
let payment1Id = "";
let expense1Id = "";
let complaint1Id = "";
let communityConvId = "";
let room101ConvId = "";

const testLogs = [];

function logTest(testId, name, passed, detail = "") {
  testLogs.push({ testId, name, passed, detail });
  const statusStr = passed ? "PASS" : "FAIL";
  console.log(`[${statusStr}] [${testId}] ${name}${detail ? " -> " + detail : ""}`);
}

async function api(path, options = {}) {
  const url = `${BASE_URL}${path}`;
  const headers = { ...options.headers };
  let body = undefined;

  if (options.body) {
    headers["Content-Type"] = "application/json";
    body = JSON.stringify(options.body);
  }

  const res = await fetch(url, {
    method: options.method || "GET",
    headers,
    body
  });

  let data = null;
  try {
    data = await res.json();
  } catch (e) {
    data = null;
  }

  return { status: res.status, data };
}

async function runExhaustiveTests() {
  console.log("================================================================================");
  console.log("SKY HEIGHT APARTMENT — EXHAUSTIVE FUNCTION-BY-FUNCTION TEST SUITE");
  console.log("================================================================================\n");

  try {
    // -------------------------------------------------------------------------
    // SECTION 1: HEALTH & INFRASTRUCTURE
    // -------------------------------------------------------------------------
    console.log(">>> SECTION 1: SYSTEM HEALTH & SERVER CONNECTIVITY");
    const healthRes = await api("/health");
    logTest(
      "INF-001",
      "Backend Health Endpoint",
      healthRes.status === 200 && healthRes.data?.status === "healthy",
      `Uptime: ${healthRes.data?.uptime}s`
    );

    // -------------------------------------------------------------------------
    // SECTION 2: AUTHENTICATION & SECURITY BOUNDARIES
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 2: AUTHENTICATION & ACCESS CONTROL");

    // Negative: Missing credentials
    const missingCreds = await api("/api/auth/login", {
      method: "POST",
      body: { email: "" }
    });
    logTest(
      "AUTH-NEG-001",
      "Login Missing Credentials Guard",
      missingCreds.status === 400 && missingCreds.data?.success === false,
      `HTTP ${missingCreds.status}: ${missingCreds.data?.message}`
    );

    // Negative: Invalid password
    const badPass = await api("/api/auth/login", {
      method: "POST",
      body: { email: "testowner@skyheightpg.com", password: "WrongPassword" }
    });
    logTest(
      "AUTH-NEG-002",
      "Login Invalid Password Guard",
      badPass.status === 401 && badPass.data?.success === false,
      `HTTP ${badPass.status}: ${badPass.data?.message}`
    );

    // Negative: Unregistered email
    const noUser = await api("/api/auth/login", {
      method: "POST",
      body: { email: "nonexistent@skyheightpg.com", password: "Password@123" }
    });
    logTest(
      "AUTH-NEG-003",
      "Login Non-existent User Guard",
      noUser.status === 401 && noUser.data?.success === false,
      `HTTP ${noUser.status}: ${noUser.data?.message}`
    );

    // Positive: Owner Login
    const ownerLogin = await api("/api/auth/login", {
      method: "POST",
      body: { email: "testowner@skyheightpg.com", password: "Password@123" }
    });
    ownerToken = ownerLogin.data?.token;
    ownerHeaders = { Authorization: `Bearer ${ownerToken}` };
    logTest(
      "AUTH-OWN-001",
      "Owner Login & Token Issuance",
      ownerLogin.status === 200 && !!ownerToken && ownerLogin.data?.user?.role === "owner",
      `Role: ${ownerLogin.data?.user?.role}`
    );

    // Positive: Tenant 1 Login
    const tenant1Login = await api("/api/auth/login", {
      method: "POST",
      body: { email: "aman@skyheightpg.com", password: "Password@123" }
    });
    tenant1Token = tenant1Login.data?.token;
    tenant1Headers = { Authorization: `Bearer ${tenant1Token}` };
    tenant1UserId = tenant1Login.data?.user?._id;
    logTest(
      "AUTH-TEN-001",
      "Tenant Login & Token Issuance",
      tenant1Login.status === 200 && !!tenant1Token && tenant1Login.data?.user?.role === "tenant",
      `Role: ${tenant1Login.data?.user?.role}`
    );

    // Positive: /api/auth/profile verification
    const meRes = await api("/api/auth/profile", { headers: ownerHeaders });
    logTest(
      "AUTH-OWN-002",
      "Token Verification via /api/auth/profile",
      meRes.status === 200 && meRes.data?.user?.role === "owner",
      `Verified: ${meRes.data?.user?.email}`
    );

    // Negative: Unauthenticated request to protected endpoint
    const unauthReq = await api("/api/rooms");
    logTest(
      "AUTH-NEG-004",
      "Protected Route Unauthenticated Guard",
      unauthReq.status === 401,
      `HTTP ${unauthReq.status}: ${unauthReq.data?.message}`
    );

    // Negative: Tenant attempting owner-restricted endpoint
    const wrongRole = await api("/api/rooms", {
      method: "POST",
      headers: tenant1Headers,
      body: { roomNumber: "999", roomType: "single", monthlyRent: 5000, maxOccupancy: 1 }
    });
    logTest(
      "AUTH-NEG-005",
      "Role-Based Access Control (Tenant -> Owner Endpoint)",
      wrongRole.status === 403,
      `HTTP ${wrongRole.status}: ${wrongRole.data?.message}`
    );

    // -------------------------------------------------------------------------
    // SECTION 3: PG GLOBAL SETTINGS
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 3: PG GLOBAL CONFIGURATION");
    const getSettingsRes = await api("/api/settings", { headers: ownerHeaders });
    logTest(
      "SET-OWN-001",
      "Retrieve PG Settings",
      getSettingsRes.status === 200 && getSettingsRes.data?.data?.electricityRatePerUnit === 10,
      `Rate: ₹${getSettingsRes.data?.data?.electricityRatePerUnit}/unit`
    );

    // Negative: Tenant cannot update settings
    const tenantSetUpdate = await api("/api/settings", {
      method: "PUT",
      headers: tenant1Headers,
      body: { electricityRatePerUnit: 12 }
    });
    logTest(
      "SET-NEG-001",
      "Tenant Settings Update Rejection",
      tenantSetUpdate.status === 403,
      `HTTP ${tenantSetUpdate.status}`
    );

    // Positive: Owner updates settings
    const ownerSetUpdate = await api("/api/settings", {
      method: "PUT",
      headers: ownerHeaders,
      body: { electricityRatePerUnit: 10, defaultDueDateDay: 5 }
    });
    logTest(
      "SET-OWN-002",
      "Owner Settings Update",
      ownerSetUpdate.status === 200 && ownerSetUpdate.data?.data?.defaultDueDateDay === 5,
      `Due day: ${ownerSetUpdate.data?.data?.defaultDueDateDay}`
    );

    // -------------------------------------------------------------------------
    // SECTION 4: ROOM MANAGEMENT & CAPACITY
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 4: ROOM MANAGEMENT");
    const roomsListRes = await api("/api/rooms", { headers: ownerHeaders });
    const rooms = roomsListRes.data?.data || [];
    const r101 = rooms.find((r) => r.roomNumber === "101");
    const r102 = rooms.find((r) => r.roomNumber === "102");
    room101Id = r101?._id;
    room102Id = r102?._id;
    logTest(
      "ROOM-OWN-001",
      "Enumerate Rooms & Active Occupancy",
      roomsListRes.status === 200 && !!room101Id && !!room102Id,
      `Total rooms: ${rooms.length}`
    );

    // Negative: Missing required fields when creating room
    const badRoomRes = await api("/api/rooms", {
      method: "POST",
      headers: ownerHeaders,
      body: { floor: 2 }
    });
    logTest(
      "ROOM-NEG-001",
      "Create Room Missing Fields Validation",
      badRoomRes.status === 400,
      `HTTP ${badRoomRes.status}: ${badRoomRes.data?.message}`
    );

    // Positive: Create Room 201
    const create201Res = await api("/api/rooms", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        roomNumber: "201",
        floor: 2,
        roomType: "single",
        monthlyRent: 7500,
        maxOccupancy: 1
      }
    });
    room201Id = create201Res.data?.data?._id;
    logTest(
      "ROOM-OWN-002",
      "Create New Room (Room 201)",
      create201Res.status === 201 && !!room201Id,
      `Created Room ID: ${room201Id}`
    );

    // Negative: Duplicate room creation rejection
    const dupRoomRes = await api("/api/rooms", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        roomNumber: "201",
        floor: 2,
        roomType: "single",
        monthlyRent: 7500,
        maxOccupancy: 1
      }
    });
    logTest(
      "ROOM-NEG-002",
      "Duplicate Room Number Rejection",
      dupRoomRes.status === 400 && dupRoomRes.data?.message?.includes("already exists"),
      `HTTP ${dupRoomRes.status}: ${dupRoomRes.data?.message}`
    );

    // Negative: Invalid ObjectId query
    const badIdRoom = await api("/api/rooms/invalid-object-id-123", { headers: ownerHeaders });
    logTest(
      "ROOM-NEG-003",
      "Get Room Invalid ObjectId Guard",
      badIdRoom.status === 400,
      `HTTP ${badIdRoom.status}: ${badIdRoom.data?.message}`
    );

    // -------------------------------------------------------------------------
    // SECTION 5: REGISTRATION & APPLICANT APPROVAL
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 5: REGISTRATION & APPROVAL WORKFLOW");

    // Positive: New tenant registers via public endpoint
    const newRegRes = await api("/api/auth/register", {
      method: "POST",
      body: {
        name: "Vikram Malhotra",
        email: "vikram@skyheightpg.com",
        password: "Password@123",
        phone: "9876543220",
        role: "tenant"
      }
    });
    applicantUserId = newRegRes.data?.user?._id;
    logTest(
      "REG-PUB-001",
      "Tenant Registration Submission",
      newRegRes.status === 201 && newRegRes.data?.user?.approvalStatus === "pending",
      `Applicant ID: ${applicantUserId}, Status: ${newRegRes.data?.user?.approvalStatus}`
    );

    // Negative: Pending applicant login attempt blocked
    const pendingLogin = await api("/api/auth/login", {
      method: "POST",
      body: { email: "vikram@skyheightpg.com", password: "Password@123" }
    });
    logTest(
      "REG-NEG-001",
      "Pending Applicant Login Blocked",
      pendingLogin.status === 403 && pendingLogin.data?.approvalStatus === "pending",
      `HTTP 403: ${pendingLogin.data?.message}`
    );

    // Owner checks pending registrations
    const pendingListRes = await api("/api/owner/registrations?status=pending", { headers: ownerHeaders });
    const foundVikram = (pendingListRes.data?.data || []).some((u) => u.email === "vikram@skyheightpg.com");
    logTest(
      "REG-OWN-001",
      "Owner Pending Registrations Inspection",
      pendingListRes.status === 200 && foundVikram,
      `Pending count: ${pendingListRes.data?.data?.length}`
    );

    // Positive: Approve Vikram and allocate Room 102
    const approveVikramRes = await api(`/api/owner/registrations/${applicantUserId}/approve`, {
      method: "PUT",
      headers: ownerHeaders,
      body: {
        roomId: room102Id,
        monthlyRent: 8000,
        securityDeposit: 16000,
        joiningDate: new Date().toISOString()
      }
    });
    logTest(
      "REG-OWN-002",
      "Approve Applicant & Allocate Bed",
      approveVikramRes.status === 200 && approveVikramRes.data?.data?.tenant?.room === room102Id,
      `Approved: ${approveVikramRes.data?.data?.user?.name}`
    );

    // Verify Room 102 occupied beds updated
    const room102Check = await api(`/api/rooms/${room102Id}`, { headers: ownerHeaders });
    logTest(
      "REG-OWN-003",
      "Room Occupied Bed Counter Increment",
      room102Check.status === 200 && room102Check.data?.data?.occupiedBeds === 1,
      `Occupied beds: ${room102Check.data?.data?.occupiedBeds}`
    );

    // -------------------------------------------------------------------------
    // SECTION 6: TENANT PROFILE & ROOM ASSIGNMENT
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 6: TENANT PROFILE & OCCUPANCY");
    const tenant1Profile = await api("/api/tenants/me", { headers: tenant1Headers });
    tenant1Id = tenant1Profile.data?.data?._id;
    logTest(
      "TEN-PRF-001",
      "Tenant Profile Retrieval & Room Association",
      tenant1Profile.status === 200 && tenant1Profile.data?.data?.room?.roomNumber === "101",
      `Tenant: ${tenant1Profile.data?.data?.fullName}, Room: ${tenant1Profile.data?.data?.room?.roomNumber}`
    );

    // Tenant Occupancy History
    const tenantHist = await api("/api/tenants/me/occupancy-history", { headers: tenant1Headers });
    logTest(
      "TEN-PRF-002",
      "Tenant Self Occupancy History",
      tenantHist.status === 200 && (tenantHist.data?.data?.history || []).length > 0,
      `Records: ${tenantHist.data?.data?.history?.length}`
    );

    // -------------------------------------------------------------------------
    // SECTION 7: ELECTRICITY SUB-METERING
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 7: ELECTRICITY SUB-METERING");

    // Negative: Lower meter reading rejection
    const lowerReading = await api("/api/meters", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        roomId: room101Id,
        previousReading: 1000,
        currentReading: 950,
        readingMonth: "2026-11",
        ratePerUnit: 10
      }
    });
    logTest(
      "MTR-NEG-001",
      "Lower Meter Reading Validation Rejection",
      lowerReading.status === 400 && lowerReading.data?.message?.includes("cannot be lower"),
      `HTTP ${lowerReading.status}: ${lowerReading.data?.message}`
    );

    // Positive: Record meter reading for Room 101 for 2026-11 (1000 -> 1085 = 85 units @ ₹10 = ₹850)
    const meter101Res = await api("/api/meters", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        roomId: room101Id,
        previousReading: 1000,
        currentReading: 1085,
        readingMonth: "2026-11",
        ratePerUnit: 10,
        remarks: "November verified reading"
      }
    });
    logTest(
      "MTR-OWN-001",
      "Record Room Meter Reading",
      meter101Res.status === 201 && meter101Res.data?.data?.unitsConsumed === 85,
      `Units: 85, Amount: ₹${meter101Res.data?.data?.electricityAmount}`
    );

    // Negative: Duplicate monthly reading rejection
    const dupMeter = await api("/api/meters", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        roomId: room101Id,
        previousReading: 1085,
        currentReading: 1100,
        readingMonth: "2026-11",
        ratePerUnit: 10
      }
    });
    logTest(
      "MTR-NEG-002",
      "Duplicate Monthly Meter Reading Rejection",
      dupMeter.status === 400 && dupMeter.data?.message?.includes("already exists"),
      `HTTP ${dupMeter.status}: ${dupMeter.data?.message}`
    );

    // Positive: Tenant queries my-meter
    const tenantMeterRes = await api("/api/meters/my-meter", { headers: tenant1Headers });
    logTest(
      "MTR-TEN-001",
      "Tenant Self Sub-meter Inspection",
      tenantMeterRes.status === 200 && tenantMeterRes.data?.data?.currentReading === 1085,
      `Current: ${tenantMeterRes.data?.data?.currentReading} kWh`
    );

    // -------------------------------------------------------------------------
    // SECTION 8: MONTHLY BILLING & INVOICES
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 8: MONTHLY BILLING & INVOICES");

    // Positive: Generate bill for Aman (Room 101, 2026-11)
    const billGenRes = await api("/api/bills/generate", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        tenantId: tenant1Id,
        billingMonth: "2026-11",
        dueDate: "2026-11-10"
      }
    });
    bill1Id = billGenRes.data?.data?._id;
    const bData = billGenRes.data?.data;
    logTest(
      "BILL-OWN-001",
      "Generate Monthly Bill with Linked Electricity",
      billGenRes.status === 201 && bData?.monthlyRent === 6000 && bData?.electricityAmount === 850 && bData?.totalAmount === 6850,
      `Rent ₹${bData?.monthlyRent} + Elec ₹${bData?.electricityAmount} = Total ₹${bData?.totalAmount}`
    );

    // Negative: Duplicate monthly bill generation rejection
    const dupBillRes = await api("/api/bills/generate", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        tenantId: tenant1Id,
        billingMonth: "2026-11",
        dueDate: "2026-11-10"
      }
    });
    logTest(
      "BILL-NEG-001",
      "Duplicate Monthly Bill Rejection",
      dupBillRes.status === 400 && dupBillRes.data?.message?.includes("already exists"),
      `HTTP ${dupBillRes.status}: ${dupBillRes.data?.message}`
    );

    // Positive: Retroactive Meter Sync (Generate December bill before meter reading, then log reading)
    const billDecGen = await api("/api/bills/generate", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        tenantId: tenant1Id,
        billingMonth: "2026-12",
        dueDate: "2026-12-10"
      }
    });
    const decBillId = billDecGen.data?.data?._id;
    const decBefore = billDecGen.data?.data;

    // Log December meter reading (1085 -> 1135 = 50 units = ₹500)
    await api("/api/meters", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        roomId: room101Id,
        previousReading: 1085,
        currentReading: 1135,
        readingMonth: "2026-12",
        ratePerUnit: 10
      }
    });

    const decAfterRes = await api(`/api/bills/${decBillId}`, { headers: ownerHeaders });
    const decAfter = decAfterRes.data?.data;
    logTest(
      "BILL-OWN-002",
      "Retroactive Bill Electricity Recalculation (BUG-01 Fix)",
      decBefore?.electricityAmount === 0 && decAfter?.electricityAmount === 500 && decAfter?.totalAmount === 6500,
      `Before: ₹${decBefore?.totalAmount} -> After: ₹${decAfter?.totalAmount}`
    );

    // Positive: Tenant fetches my-bills
    const myBillsRes = await api("/api/bills/my-bills", { headers: tenant1Headers });
    logTest(
      "BILL-TEN-001",
      "Tenant My-Bills Listing",
      myBillsRes.status === 200 && (myBillsRes.data?.data || []).length >= 2,
      `Bills count: ${myBillsRes.data?.data?.length}`
    );

    // -------------------------------------------------------------------------
    // SECTION 9: PAYMENTS & VERIFICATION LEDGER
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 9: PAYMENTS & VERIFICATION LEDGER");

    // Negative: Overpayment submission rejection
    const overpayRes = await api("/api/payments/upi/submit", {
      method: "POST",
      headers: tenant1Headers,
      body: {
        billId: bill1Id,
        amount: 99999,
        transactionReference: "OVERPAY123456"
      }
    });
    logTest(
      "PAY-NEG-001",
      "Overpayment Submission Guard",
      overpayRes.status === 400 && overpayRes.data?.message?.includes("exceeds"),
      `HTTP ${overpayRes.status}: ${overpayRes.data?.message}`
    );

    // Positive: Tenant submits UPI payment for November bill (₹6,850)
    const utr = `UTR${Date.now()}`;
    const submitUpiRes = await api("/api/payments/upi/submit", {
      method: "POST",
      headers: tenant1Headers,
      body: {
        billId: bill1Id,
        amount: 6850,
        transactionReference: utr,
        notes: "Paid via GPay"
      }
    });
    payment1Id = submitUpiRes.data?.data?._id;
    logTest(
      "PAY-TEN-001",
      "Submit UPI Payment with UTR",
      submitUpiRes.status === 201 && submitUpiRes.data?.data?.verificationStatus === "pending",
      `Payment ID: ${payment1Id}, Status: PENDING`
    );

    // Negative: Duplicate UTR rejection
    const dupUtrRes = await api("/api/payments/upi/submit", {
      method: "POST",
      headers: tenant1Headers,
      body: {
        billId: decBillId,
        amount: 6500,
        transactionReference: utr
      }
    });
    logTest(
      "PAY-NEG-002",
      "Duplicate UTR Number Rejection",
      dupUtrRes.status === 400 && dupUtrRes.data?.message?.includes("already been submitted"),
      `HTTP ${dupUtrRes.status}: ${dupUtrRes.data?.message}`
    );

    // Negative: Tenant attempting to verify payment
    const tenantVerifyAttempt = await api(`/api/payments/${payment1Id}/verify`, {
      method: "PUT",
      headers: tenant1Headers,
      body: { status: "verified" }
    });
    logTest(
      "PAY-NEG-003",
      "Tenant Verify Attempt Guard (RBAC)",
      tenantVerifyAttempt.status === 403,
      `HTTP ${tenantVerifyAttempt.status}`
    );

    // Positive: Owner verifies payment and credits bill
    const verifyPayRes = await api(`/api/payments/${payment1Id}/verify`, {
      method: "PUT",
      headers: ownerHeaders,
      body: {
        status: "verified",
        notes: "Verified against HDFC bank statement"
      }
    });
    logTest(
      "PAY-OWN-001",
      "Owner Payment Verification & Credit",
      verifyPayRes.status === 200 && verifyPayRes.data?.data?.payment?.verificationStatus === "verified",
      `Status: ${verifyPayRes.data?.data?.payment?.verificationStatus}`
    );

    // Verify Bill #1 is now marked paid
    const bill1Check = await api(`/api/bills/${bill1Id}`, { headers: ownerHeaders });
    logTest(
      "PAY-OWN-002",
      "Bill Paid Amount & Status Update to 'paid'",
      bill1Check.status === 200 && bill1Check.data?.data?.paidAmount === 6850 && bill1Check.data?.data?.paymentStatus === "paid",
      `Paid: ₹${bill1Check.data?.data?.paidAmount}/${bill1Check.data?.data?.totalAmount}, Status: ${bill1Check.data?.data?.paymentStatus}`
    );

    // Positive: Record direct Cash payment for December bill (₹3,000 partial payment)
    const recordCashRes = await api("/api/payments/cash", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        billId: decBillId,
        amount: 3000,
        notes: "Handed cash at PG office"
      }
    });
    logTest(
      "PAY-OWN-003",
      "Owner Record Cash Partial Payment",
      recordCashRes.status === 201 && recordCashRes.data?.data?.payment?.paymentMethod === "cash",
      `Paid: ₹${recordCashRes.data?.data?.payment?.amount}`
    );

    // Verify December bill is now marked 'partially_paid'
    const decPartialCheck = await api(`/api/bills/${decBillId}`, { headers: ownerHeaders });
    logTest(
      "PAY-OWN-004",
      "Bill Status Update to 'partially_paid'",
      decPartialCheck.status === 200 && decPartialCheck.data?.data?.paidAmount === 3000 && decPartialCheck.data?.data?.paymentStatus === "partially_paid",
      `Paid: ₹${decPartialCheck.data?.data?.paidAmount}/₹${decPartialCheck.data?.data?.totalAmount}, Status: ${decPartialCheck.data?.data?.paymentStatus}`
    );

    // -------------------------------------------------------------------------
    // SECTION 10: PROPERTY EXPENSES
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 10: OPERATIONAL EXPENSES");

    // Positive: Add operational expense
    const addExpRes = await api("/api/expenses", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        title: "Main Water Tank Cleaning",
        amount: 1500,
        category: "cleaning",
        date: new Date().toISOString(),
        notes: "Bi-annual cleaning"
      }
    });
    expense1Id = addExpRes.data?.data?._id;
    logTest(
      "EXP-OWN-001",
      "Record Property Expense",
      addExpRes.status === 201 && !!expense1Id && addExpRes.data?.data?.amount === 1500,
      `Expense ID: ${expense1Id}`
    );

    // Positive: Get expense summary
    const expSummaryRes = await api("/api/expenses/summary", { headers: ownerHeaders });
    logTest(
      "EXP-OWN-002",
      "Expense Category Aggregation Summary",
      expSummaryRes.status === 200 && expSummaryRes.data?.totalSpent >= 1500,
      `Total Spent: ₹${expSummaryRes.data?.totalSpent}`
    );

    // -------------------------------------------------------------------------
    // SECTION 11: COMPLAINTS & IN-APP NOTIFICATIONS
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 11: COMPLAINTS & NOTIFICATION ALERTS");

    // Positive: Tenant files complaint
    const createCompRes = await api("/api/complaints", {
      method: "POST",
      headers: tenant1Headers,
      body: {
        title: "Ceiling fan speed regulator faulty",
        description: "Fan is running only at maximum speed.",
        category: "electricity",
        priority: "medium"
      }
    });
    complaint1Id = createCompRes.data?.data?._id;
    logTest(
      "CMP-TEN-001",
      "Tenant File Complaint",
      createCompRes.status === 201 && !!complaint1Id,
      `Complaint ID: ${complaint1Id}`
    );

    // Verify Owner received in-app alert for this complaint
    const ownerNotifs = await api("/api/notifications", { headers: ownerHeaders });
    const compAlert = (ownerNotifs.data?.data || []).find(
      (n) => String(n.relatedComplaint) === String(complaint1Id) || (n.title && n.title.includes("Ceiling fan"))
    );
    logTest(
      "CMP-OWN-001",
      "Owner In-App Notification on Complaint Creation (BUG-02)",
      !!compAlert,
      `Title: ${compAlert?.title}`
    );

    // Owner resolves complaint
    const resolveCompRes = await api(`/api/complaints/${complaint1Id}/status`, {
      method: "PUT",
      headers: ownerHeaders,
      body: {
        status: "resolved",
        resolution: "Capacitor and regulator replaced by electrician."
      }
    });
    logTest(
      "CMP-OWN-002",
      "Owner Resolve Complaint Ticket",
      resolveCompRes.status === 200 && resolveCompRes.data?.data?.status === "resolved",
      `Resolution: ${resolveCompRes.data?.data?.resolution}`
    );

    // Verify Tenant received in-app resolution alert
    const tenantNotifs = await api("/api/notifications", { headers: tenant1Headers });
    const resAlert = (tenantNotifs.data?.data || []).find(
      (n) => String(n.relatedComplaint) === String(complaint1Id) || (n.title && n.title.includes("Updated"))
    );
    logTest(
      "CMP-TEN-002",
      "Tenant In-App Notification on Complaint Resolution (BUG-02)",
      !!resAlert,
      `Title: ${resAlert?.title}`
    );

    // Tenant marks notification as read
    if (resAlert) {
      const markReadRes = await api(`/api/notifications/${resAlert._id}/read`, {
        method: "PUT",
        headers: tenant1Headers
      });
      logTest(
        "NTF-TEN-001",
        "Mark Notification as Read",
        markReadRes.status === 200 && markReadRes.data?.data?.isRead === true,
        `isRead: ${markReadRes.data?.data?.isRead}`
      );
    }

    // -------------------------------------------------------------------------
    // SECTION 12: CHAT & GROUP MESSAGING BOUNDARIES
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 12: CHAT & PRIVACY BOUNDARIES");

    const chatListRes = await api("/api/chat", { headers: tenant1Headers });
    const convs = chatListRes.data?.data || [];
    const commGroup = convs.find((c) => c.type === "community");
    const roomGroup = convs.find((c) => c.type === "room");
    communityConvId = commGroup?._id;
    room101ConvId = roomGroup?._id;
    logTest(
      "CHT-TEN-001",
      "Chat Group Auto-Discovery (Community & Room)",
      chatListRes.status === 200 && !!communityConvId && !!room101ConvId,
      `Found ${convs.length} conversation channels`
    );

    // Positive: Send message to Community
    const sendCommMsg = await api(`/api/chat/${communityConvId}/messages`, {
      method: "POST",
      headers: tenant1Headers,
      body: { content: "Good evening everyone!" }
    });
    logTest(
      "CHT-TEN-002",
      "Post Message to Community Chat",
      sendCommMsg.status === 201 && sendCommMsg.data?.data?.content === "Good evening everyone!",
      `Sender: ${sendCommMsg.data?.data?.sender?.name || "Aman"}`
    );

    // Positive: Send message to Room 101 Group
    const sendRoomMsg = await api(`/api/chat/${room101ConvId}/messages`, {
      method: "POST",
      headers: tenant1Headers,
      body: { content: "Room 101 cleaning completed today." }
    });
    logTest(
      "CHT-TEN-003",
      "Post Message to Assigned Room Chat",
      sendRoomMsg.status === 201 && sendRoomMsg.data?.data?.content?.includes("cleaning completed"),
      `Room msg ID: ${sendRoomMsg.data?.data?._id}`
    );

    // Negative: Empty message rejection
    const emptyMsgRes = await api(`/api/chat/${communityConvId}/messages`, {
      method: "POST",
      headers: tenant1Headers,
      body: { content: "   " }
    });
    logTest(
      "CHT-NEG-001",
      "Empty Chat Message Rejection",
      emptyMsgRes.status === 400,
      `HTTP ${emptyMsgRes.status}: ${emptyMsgRes.data?.message}`
    );

    // -------------------------------------------------------------------------
    // SECTION 13: DASHBOARD METRICS & REVENUE AUDIT
    // -------------------------------------------------------------------------
    console.log("\n>>> SECTION 13: OWNER DASHBOARD & FINANCIAL AUDIT");
    const dashRes = await api("/api/dashboard/summary", { headers: ownerHeaders });
    const financials = dashRes.data?.data?.financials;
    const roomsMetrics = dashRes.data?.data?.rooms;

    // We verified ₹6,850 UPI + ₹3,000 cash = ₹9,850 collections; ₹1,500 expenses; Net Profit = ₹8,350
    const mathConsistent =
      financials?.monthlyRentCollection >= 9850 &&
      financials?.monthlyExpenses >= 1500 &&
      Math.abs(financials?.netProfit - (financials?.monthlyRentCollection - financials?.monthlyExpenses)) < 0.01;

    logTest(
      "DAS-OWN-001",
      "Owner Dashboard Financial Formula Consistency",
      dashRes.status === 200 && mathConsistent,
      `Collected: ₹${financials?.monthlyRentCollection}, Expenses: ₹${financials?.monthlyExpenses}, Net: ₹${financials?.netProfit}`
    );

    logTest(
      "DAS-OWN-002",
      "Owner Dashboard Room Occupancy Metrics",
      dashRes.status === 200 && roomsMetrics?.total >= 3 && roomsMetrics?.occupiedBeds >= 2,
      `Total Rooms: ${roomsMetrics?.total}, Occupied Beds: ${roomsMetrics?.occupiedBeds}/${roomsMetrics?.totalCapacity}`
    );

  } catch (err) {
    console.error("FATAL RUNNER ERROR:", err);
    logTest("FATAL", "Test Runner Exception", false, err.message);
  }

  console.log("\n================================================================================");
  console.log("EXHAUSTIVE TEST SUITE SUMMARY");
  console.log("================================================================================");
  const total = testLogs.length;
  const passed = testLogs.filter((t) => t.passed).length;
  const failed = testLogs.filter((t) => !t.passed).length;

  console.log(`Total Scenarios Tested: ${total}`);
  console.log(`Passed:                 ${passed} (${Math.round((passed / total) * 100)}%)`);
  console.log(`Failed:                 ${failed}`);

  if (failed > 0) {
    console.log("\nFailed Test Cases:");
    testLogs.filter((t) => !t.passed).forEach((t) => console.log(`- [${t.testId}] ${t.name}: ${t.detail}`));
    process.exit(1);
  } else {
    console.log("\n>>> ALL EXHAUSTIVE FUNCTION TESTS PASSED WITH 100% SUCCESS RATE! <<<");
    process.exit(0);
  }
}

runExhaustiveTests();
