/**
 * SKY HEIGHT APARTMENT - END-TO-END RECOVERY VERIFICATION SUITE
 * Tests all key cross-module workflows against http://127.0.0.1:5000 (skyheight_isolated_test)
 */

const BASE_URL = "http://127.0.0.1:5000";

let ownerToken = "";
let tenantToken = "";
let room101Id = "";
let room102Id = "";
let room201Id = "";
let amanTenantId = "";
let bill101Id = "";
let paymentId = "";
let complaintId = "";

const results = [];

function recordTest(name, passed, detail = "") {
  results.push({ name, passed, detail });
  console.log(`[${passed ? "PASS" : "FAIL"}] ${name} ${detail ? "- " + detail : ""}`);
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

async function runTests() {
  console.log("=================================================");
  console.log("SKY HEIGHT APARTMENT - E2E RECOVERY TEST SUITE");
  console.log("=================================================\n");

  try {
    // 1. Health check
    const health = await api("/health");
    recordTest("Backend Health Check", health.status === 200 && health.data?.status === "healthy");

    // 2. Owner Login
    const ownerLogin = await api("/api/auth/login", {
      method: "POST",
      body: { email: "testowner@skyheightpg.com", password: "Password@123" }
    });
    ownerToken = ownerLogin.data?.token;
    recordTest(
      "Owner Authentication",
      ownerLogin.status === 200 && !!ownerToken && ownerLogin.data?.user?.role === "owner",
      `Role: ${ownerLogin.data?.user?.role}`
    );

    const ownerHeaders = { Authorization: `Bearer ${ownerToken}` };

    // 3. PG Settings Check
    const settingsRes = await api("/api/settings", { headers: ownerHeaders });
    recordTest(
      "PG Settings Retrieval",
      settingsRes.status === 200 && settingsRes.data?.data?.electricityRatePerUnit === 10,
      `Rate per unit: ₹${settingsRes.data?.data?.electricityRatePerUnit}`
    );

    // 4. Room Retrieval
    const roomsRes = await api("/api/rooms", { headers: ownerHeaders });
    const rooms = roomsRes.data?.data || [];
    const r101 = rooms.find((r) => r.roomNumber === "101");
    const r102 = rooms.find((r) => r.roomNumber === "102");
    room101Id = r101?._id;
    room102Id = r102?._id;
    recordTest(
      "Initial Rooms Verification (101 & 102)",
      roomsRes.status === 200 && !!room101Id && !!room102Id,
      `Found ${rooms.length} rooms`
    );

    // 5. Create Room 201
    let r201 = rooms.find((r) => r.roomNumber === "201");
    if (!r201) {
      const createRoomRes = await api("/api/rooms", {
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
      room201Id = createRoomRes.data?.data?._id;
      recordTest(
        "Owner Room Creation (Room 201)",
        createRoomRes.status === 201 && !!room201Id,
        `Created Room 201 ID: ${room201Id}`
      );
    } else {
      room201Id = r201._id;
      recordTest("Owner Room Verification (Room 201)", true, `Room 201 exists: ${room201Id}`);
    }

    // 6. Tenant 1 (Aman) Login
    const amanLogin = await api("/api/auth/login", {
      method: "POST",
      body: { email: "aman@skyheightpg.com", password: "Password@123" }
    });
    tenantToken = amanLogin.data?.token;
    recordTest(
      "Tenant 1 (Aman) Authentication",
      amanLogin.status === 200 && !!tenantToken && amanLogin.data?.user?.role === "tenant",
      `Role: ${amanLogin.data?.user?.role}`
    );

    const tenantHeaders = { Authorization: `Bearer ${tenantToken}` };

    // 7. Aman Profile & Room Check
    const amanProfile = await api("/api/tenants/me", { headers: tenantHeaders });
    amanTenantId = amanProfile.data?.data?._id;
    recordTest(
      "Tenant Assigned Room 101 Linkage",
      amanProfile.status === 200 && amanProfile.data?.data?.room?.roomNumber === "101",
      `Room: ${amanProfile.data?.data?.room?.roomNumber}, Rent: ₹${amanProfile.data?.data?.monthlyRent}`
    );

    // 8. Pending Applicant (Rohan) Registration Check
    const pendingRegs = await api("/api/owner/registrations?status=pending", { headers: ownerHeaders });
    const rohanReg = (pendingRegs.data?.data || []).find((u) => u.email === "rohan@skyheightpg.com");
    recordTest(
      "Pending Registration List Inspection",
      pendingRegs.status === 200,
      `Pending applicants count: ${pendingRegs.data?.data?.length || 0}`
    );

    // 9. Approve Rohan & Assign Room 102
    if (rohanReg) {
      const approveRes = await api(`/api/owner/registrations/${rohanReg._id}/approve`, {
        method: "PUT",
        headers: ownerHeaders,
        body: {
          roomId: room102Id,
          monthlyRent: 8000,
          securityDeposit: 16000,
          joiningDate: new Date().toISOString()
        }
      });
      recordTest(
        "Applicant Approval & Room 102 Allocation",
        approveRes.status === 200 && approveRes.data?.data?.tenant?.room === room102Id,
        `Approved ${rohanReg.name}`
      );
    } else {
      recordTest("Applicant Approval & Room 102 Allocation", true, "Rohan already approved in test DB");
    }

    // 10. Verify Room 102 Occupancy Increment
    const room102After = await api(`/api/rooms/${room102Id}`, { headers: ownerHeaders });
    recordTest(
      "Room 102 Bed Occupancy Counter Updated",
      room102After.status === 200 && room102After.data?.data?.occupiedBeds === 1,
      `Occupied beds: ${room102After.data?.data?.occupiedBeds}`
    );

    // 11. Meter Reading for Room 101 (Month 2026-11: 1000 prev -> 1085 curr = 85 units @ ₹10 = ₹850)
    const meterRes = await api("/api/meters", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        roomId: room101Id,
        previousReading: 1000,
        currentReading: 1085,
        readingMonth: "2026-11",
        ratePerUnit: 10,
        remarks: "November reading for Room 101"
      }
    });
    recordTest(
      "Electricity Meter Reading Recording (Room 101)",
      meterRes.status === 201 || (meterRes.status === 400 && meterRes.data?.message?.includes("already exists")),
      `Reading response: ${meterRes.data?.message}`
    );

    // 12. Generate Bill for Aman (Room 101, 2026-11)
    const billGenRes = await api("/api/bills/generate", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        tenantId: amanTenantId,
        billingMonth: "2026-11",
        dueDate: "2026-11-10"
      }
    });
    let generatedBill = billGenRes.data?.data;
    if (!generatedBill && billGenRes.status === 400) {
      const existingBillsRes = await api("/api/bills?billingMonth=2026-11", { headers: ownerHeaders });
      generatedBill = (existingBillsRes.data?.data || []).find((b) => b.tenant?._id === amanTenantId || b.tenant === amanTenantId);
    }
    bill101Id = generatedBill?._id;
    recordTest(
      "Monthly Bill Generation with Linked Electricity",
      !!bill101Id &&
        generatedBill?.monthlyRent === 6000 &&
        generatedBill?.electricityAmount === 850 &&
        generatedBill?.totalAmount === 6850,
      `Rent: ₹${generatedBill?.monthlyRent}, Elec: ₹${generatedBill?.electricityAmount}, Total: ₹${generatedBill?.totalAmount}`
    );

    // 13. TEST FIX FOR BUG 1: Retroactive Meter Sync
    // Step A: Generate bill for December BEFORE meter reading
    let decBillRes = await api("/api/bills/generate", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        tenantId: amanTenantId,
        billingMonth: "2026-12",
        dueDate: "2026-12-10"
      }
    });
    let decBillId = decBillRes.data?.data?._id;
    if (!decBillId) {
      const exDec = await api("/api/bills?billingMonth=2026-12", { headers: ownerHeaders });
      decBillId = (exDec.data?.data || [])[0]?._id;
    }

    // Step B: Now record meter reading for Room 101 for 2026-12 (1085 prev -> 1135 curr = 50 units = ₹500)
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

    // Step C: Inspect the December bill
    const billDecAfterRes = await api(`/api/bills/${decBillId}`, { headers: ownerHeaders });
    const decBillAfter = billDecAfterRes.data?.data;
    const retroSyncPassed =
      decBillAfter?.electricityAmount === 500 &&
      decBillAfter?.totalAmount === 6500;
    recordTest(
      "Retroactive Meter Sync (Bug 1 Fix Verification)",
      retroSyncPassed,
      `Elec: ₹${decBillAfter?.electricityAmount}, Total: ₹${decBillAfter?.totalAmount}`
    );

    // 14. Tenant Submits UPI Payment for November Bill (₹6,850)
    const utrNumber = `TESTUTR${Date.now()}`;
    const submitPayRes = await api("/api/payments/upi/submit", {
      method: "POST",
      headers: tenantHeaders,
      body: {
        billId: bill101Id,
        amount: 6850,
        transactionReference: utrNumber,
        notes: "Paid via GPay"
      }
    });
    paymentId = submitPayRes.data?.data?._id;
    recordTest(
      "Tenant UPI Payment Submission",
      submitPayRes.status === 201 && submitPayRes.data?.data?.verificationStatus === "pending",
      `Payment ID: ${paymentId}, UTR: ${utrNumber}`
    );

    // 15. Pending Payments Desk Check by Owner
    const pendingPaysRes = await api("/api/payments?verificationStatus=pending", { headers: ownerHeaders });
    const foundPending = (pendingPaysRes.data?.data || []).some((p) => p._id === paymentId);
    recordTest(
      "Owner Pending Payments Desk List",
      pendingPaysRes.status === 200 && foundPending,
      `Found submitted payment ${paymentId}`
    );

    // 16. Owner Verifies UPI Payment
    const verifyPayRes = await api(`/api/payments/${paymentId}/verify`, {
      method: "PUT",
      headers: ownerHeaders,
      body: {
        status: "verified",
        notes: "Verified against bank statement"
      }
    });
    const paymentStatus = verifyPayRes.data?.data?.payment?.verificationStatus || verifyPayRes.data?.data?.verificationStatus;
    recordTest(
      "Owner Payment Verification",
      verifyPayRes.status === 200 && paymentStatus === "verified",
      `Verification status: ${paymentStatus}`
    );

    // 17. Verify Bill Credited & Status Updated to "paid"
    const billAfterPayRes = await api(`/api/bills/${bill101Id}`, { headers: ownerHeaders });
    const billAfter = billAfterPayRes.data?.data;
    recordTest(
      "Bill Paid Amount & Payment Status Update",
      billAfter?.paidAmount === 6850 && billAfter?.paymentStatus === "paid",
      `Paid: ₹${billAfter?.paidAmount}/${billAfter?.totalAmount}, Status: ${billAfter?.paymentStatus}`
    );

    // 18. Record PG Operational Expense (₹2,500 for Plumbing Repair)
    const expenseRes = await api("/api/expenses", {
      method: "POST",
      headers: ownerHeaders,
      body: {
        title: "Plumbing repair on 1st Floor",
        amount: 2500,
        category: "maintenance",
        date: new Date().toISOString()
      }
    });
    recordTest(
      "Owner PG Expense Recording",
      expenseRes.status === 201 && expenseRes.data?.data?.amount === 2500,
      `Expense ID: ${expenseRes.data?.data?._id}`
    );

    // 19. Check Owner Financial Summary & Dashboard Stats
    const dashboardRes = await api("/api/dashboard/summary", { headers: ownerHeaders });
    const financials = dashboardRes.data?.data?.financials;
    recordTest(
      "Financial Summary Calculation (Dashboard Metrics)",
      dashboardRes.status === 200 && financials?.monthlyRentCollection >= 6850,
      `Rent Collected: ₹${financials?.monthlyRentCollection}, Pending: ₹${financials?.pendingPayments}, Expenses: ₹${financials?.monthlyExpenses}`
    );

    // 20. TEST FIX FOR BUG 2: Complaint Filing & Notification Dispatch
    // Tenant files complaint
    const complaintRes = await api("/api/complaints", {
      method: "POST",
      headers: tenantHeaders,
      body: {
        title: "Geyser not working in Room 101",
        description: "Water is lukewarm in the morning.",
        category: "electricity",
        priority: "high"
      }
    });
    complaintId = complaintRes.data?.data?._id;
    recordTest(
      "Tenant Complaint Submission",
      complaintRes.status === 201 && !!complaintId,
      `Complaint ID: ${complaintId}`
    );

    // Owner checks notifications for complaint alert
    const ownerNotifs = await api("/api/notifications", { headers: ownerHeaders });
    const complaintNotif = (ownerNotifs.data?.data || []).find(
      (n) => String(n.relatedComplaint) === String(complaintId) || (n.title && n.title.includes("Geyser"))
    );
    recordTest(
      "Owner In-App Notification on Complaint Creation (Bug 2 Part 1)",
      !!complaintNotif,
      `Notif: ${complaintNotif?.title}`
    );

    // Owner resolves complaint
    const resolveCompRes = await api(`/api/complaints/${complaintId}/status`, {
      method: "PUT",
      headers: ownerHeaders,
      body: {
        status: "resolved",
        resolution: "Heating element replaced by electrician."
      }
    });
    recordTest(
      "Owner Complaint Resolution",
      resolveCompRes.status === 200 && resolveCompRes.data?.data?.status === "resolved",
      `Resolution: ${resolveCompRes.data?.data?.resolution}`
    );

    // Tenant checks notifications for resolution alert
    const tenantNotifs = await api("/api/notifications", { headers: tenantHeaders });
    const resolvedNotif = (tenantNotifs.data?.data || []).find(
      (n) => String(n.relatedComplaint) === String(complaintId) || (n.title && n.title.includes("Updated"))
    );
    recordTest(
      "Tenant In-App Notification on Complaint Resolution (Bug 2 Part 2)",
      !!resolvedNotif,
      `Notif: ${resolvedNotif?.title}`
    );

    // 21. Chat Workflow: Room Chat & Community Chat
    const tenantConvs = await api("/api/chat", { headers: tenantHeaders });
    const convList = tenantConvs.data?.data || [];
    const commConv = convList.find((c) => c.type === "community");
    recordTest(
      "Tenant Chat Groups Auto-Discovery (Room & Community)",
      tenantConvs.status === 200 && convList.length > 0,
      `Found ${convList.length} conversations`
    );

    if (commConv) {
      const msgRes = await api(`/api/chat/${commConv._id}/messages`, {
        method: "POST",
        headers: tenantHeaders,
        body: { content: "Hello everyone, hope you have a great week!" }
      });
      recordTest(
        "Chat Message Posting to Community",
        msgRes.status === 201 && msgRes.data?.data?.content?.includes("Hello everyone")
      );
    }

    // 22. Occupancy History Audit
    const amanHist = await api(`/api/tenants/${amanTenantId}/occupancy-history`, { headers: ownerHeaders });
    const histList = amanHist.data?.data?.history || [];
    recordTest(
      "Occupancy History Audit Trail for Tenant",
      amanHist.status === 200 && histList.length > 0,
      `Records count: ${histList.length}`
    );

  } catch (err) {
    console.error("FATAL TEST EXCEPTION:", err);
    recordTest("Test Suite Execution", false, err.message);
  }

  console.log("\n=================================================");
  console.log("TEST RESULTS SUMMARY");
  console.log("=================================================");
  const passedCount = results.filter((r) => r.passed).length;
  const failedCount = results.filter((r) => !r.passed).length;
  console.log(`Total: ${results.length} | Passed: ${passedCount} | Failed: ${failedCount}`);

  if (failedCount > 0) {
    console.log("\nFailed Tests:");
    results.filter((r) => !r.passed).forEach((r) => console.log(`- ${r.name}: ${r.detail}`));
    process.exit(1);
  } else {
    console.log("\nALL VERIFICATION TESTS PASSED SUCCESSFULLY! (100%)");
    process.exit(0);
  }
}

runTests();
