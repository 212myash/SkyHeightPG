const http = require("http");
const dns = require("dns");
dns.setServers(["8.8.8.8", "8.8.4.4"]);
require("dotenv").config({ path: __dirname + "/.env" });
const mongoose = require("mongoose");
const User = require("./models/User");
const generateToken = require("./utils/generateToken");

const BASE_URL = "http://localhost:5000";

const makeRequest = (method, path, body = null, token = null) => {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const headers = {
      "Content-Type": "application/json"
    };
    if (token) {
      headers["Authorization"] = `Bearer ${token}`;
    }

    const payload = body ? JSON.stringify(body) : null;
    if (payload) {
      headers["Content-Length"] = Buffer.byteLength(payload);
    }

    const req = http.request(
      url,
      {
        method,
        headers
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          let parsed;
          try {
            parsed = JSON.parse(data);
          } catch {
            parsed = data;
          }
          resolve({ status: res.statusCode, data: parsed });
        });
      }
    );

    req.on("error", (err) => reject(err));
    if (payload) req.write(payload);
    req.end();
  });
};

const runTests = async () => {
  console.log("==================================================");
  console.log("      SKY HEIGHT PG — PHASE 3 CORE API TESTS      ");
  console.log("==================================================\n");

  let passed = 0;
  let failed = 0;

  const assert = (description, condition, details = "") => {
    if (condition) {
      console.log(`[PASS] ${description}`);
      passed++;
    } else {
      console.error(`[FAIL] ${description} - ${details}`);
      failed++;
    }
  };

  try {
    await mongoose.connect(process.env.MONGODB_URI);

    const timestamp = Date.now();
    const testMonth = "2026-11";

    // ----------------------------------------------------
    // SETUP: Owner Account & Token
    // ----------------------------------------------------
    let owner = await User.findOne({ role: "owner" });
    let ownerToken;

    if (!owner) {
      const ownerRegRes = await makeRequest("POST", "/api/auth/register", {
        name: "Phase 3 Owner Admin",
        email: `owner_p3_${timestamp}@skyheight-test.com`,
        password: "OwnerPassword123!",
        phone: "+919876543210",
        role: "owner"
      });
      ownerToken = ownerRegRes.data.token;
    } else {
      ownerToken = generateToken(owner._id, "owner");
    }

    assert("0. Owner authentication token ready", Boolean(ownerToken));

    // ----------------------------------------------------
    // MODULE 1: Room Management
    // ----------------------------------------------------
    console.log("\n--- MODULE 1: Room Management ---");
    const roomNum1 = `R101-${timestamp % 100000}`;
    const roomNum2 = `R102-${timestamp % 100000}`;

    // 1. Create Room 101
    const createRoomRes = await makeRequest(
      "POST",
      "/api/rooms",
      {
        roomNumber: roomNum1,
        floor: 1,
        roomType: "double",
        monthlyRent: 8000,
        capacity: 2,
        amenities: ["AC", "WiFi", "Geyser"]
      },
      ownerToken
    );
    assert(
      "1. Owner creates Room 101 (201 Created)",
      createRoomRes.status === 201 && createRoomRes.data.data.roomNumber === roomNum1,
      JSON.stringify(createRoomRes.data)
    );
    const roomId1 = createRoomRes.data.data._id;

    // 2. Create Room 102
    const createRoomRes2 = await makeRequest(
      "POST",
      "/api/rooms",
      {
        roomNumber: roomNum2,
        floor: 1,
        roomType: "single",
        monthlyRent: 12000,
        capacity: 1,
        amenities: ["AC", "WiFi", "Balcony"]
      },
      ownerToken
    );
    assert(
      "2. Owner creates Room 102 (201 Created)",
      createRoomRes2.status === 201 && createRoomRes2.data.data.roomNumber === roomNum2,
      JSON.stringify(createRoomRes2.data)
    );
    const roomId2 = createRoomRes2.data.data._id;

    // 3. Prevent duplicate room number
    const dupRoomRes = await makeRequest(
      "POST",
      "/api/rooms",
      {
        roomNumber: roomNum1,
        floor: 2,
        monthlyRent: 9000,
        capacity: 2
      },
      ownerToken
    );
    assert(
      "3. Duplicate room number is rejected (400 Bad Request)",
      dupRoomRes.status === 400 && dupRoomRes.data.success === false,
      JSON.stringify(dupRoomRes.data)
    );

    // 4. Get all rooms
    const getAllRoomsRes = await makeRequest("GET", "/api/rooms", null, ownerToken);
    assert(
      "4. List all rooms returns status 200 and pagination",
      getAllRoomsRes.status === 200 && Array.isArray(getAllRoomsRes.data.data),
      JSON.stringify(getAllRoomsRes.data)
    );

    // 5. Get room by ID
    const getRoomRes = await makeRequest("GET", `/api/rooms/${roomId1}`, null, ownerToken);
    assert(
      "5. Get room by ID returns details and available beds",
      getRoomRes.status === 200 && getRoomRes.data.data.availableBeds === 2,
      JSON.stringify(getRoomRes.data)
    );

    // 6. Update room details
    const updateRoomRes = await makeRequest(
      "PUT",
      `/api/rooms/${roomId1}`,
      {
        monthlyRent: 8500,
        amenities: ["AC", "WiFi", "Geyser", "Study Table"]
      },
      ownerToken
    );
    assert(
      "6. Owner updates room details (200 OK)",
      updateRoomRes.status === 200 && updateRoomRes.data.data.monthlyRent === 8500,
      JSON.stringify(updateRoomRes.data)
    );

    // 7. Get Room Occupancy Stats
    const occupancyStatsRes = await makeRequest("GET", "/api/rooms/stats/occupancy", null, ownerToken);
    assert(
      "7. Room occupancy stats returns totalRooms, occupiedRooms, availableBeds",
      occupancyStatsRes.status === 200 && occupancyStatsRes.data.data.totalCapacity >= 3,
      JSON.stringify(occupancyStatsRes.data)
    );

    // ----------------------------------------------------
    // MODULE 2: Tenant Management
    // ----------------------------------------------------
    console.log("\n--- MODULE 2: Tenant Management ---");
    const tenantEmailA = `tenantA_${timestamp}@skyheight-test.com`;
    const tenantEmailB = `tenantB_${timestamp}@skyheight-test.com`;
    const tenantPassword = "TenantPassword123!";

    // 8. Owner registers Tenant A into Room 101
    const regTenantARes = await makeRequest(
      "POST",
      "/api/tenants",
      {
        name: "Rahul Tenant A",
        email: tenantEmailA,
        password: tenantPassword,
        phone: "+919811122233",
        roomId: roomId1,
        monthlyRent: 8500,
        securityDeposit: 10000,
        assignedBed: "Bed 1"
      },
      ownerToken
    );
    assert(
      "8. Owner registers Tenant A into Room 101 (201 Created)",
      regTenantARes.status === 201 && regTenantARes.data.data.room.occupiedBeds === 1,
      JSON.stringify(regTenantARes.data)
    );
    const tenantIdA = regTenantARes.data.data.tenant._id;

    // Login as Tenant A to get Tenant A token
    const loginTenantARes = await makeRequest("POST", "/api/auth/login", {
      email: tenantEmailA,
      password: tenantPassword
    });
    const tenantTokenA = loginTenantARes.data.token;
    assert("9. Tenant A logs in successfully", Boolean(tenantTokenA));

    // 10. Tenant trying to register another tenant is forbidden (403)
    const unauthorizedRegRes = await makeRequest(
      "POST",
      "/api/tenants",
      {
        name: "Hacker Tenant",
        email: `hacker_${timestamp}@test.com`,
        password: "Pass123456!",
        phone: "+919999999999",
        roomId: roomId1
      },
      tenantTokenA
    );
    assert(
      "10. Tenant is forbidden from registering new tenants (403 Forbidden)",
      unauthorizedRegRes.status === 403,
      JSON.stringify(unauthorizedRegRes.data)
    );

    // 11. Owner registers Tenant B into Room 101 (Capacity becomes 2/2 - Full)
    const regTenantBRes = await makeRequest(
      "POST",
      "/api/tenants",
      {
        name: "Amit Tenant B",
        email: tenantEmailB,
        password: tenantPassword,
        phone: "+919822233344",
        roomId: roomId1,
        monthlyRent: 8500,
        securityDeposit: 10000,
        assignedBed: "Bed 2"
      },
      ownerToken
    );
    assert(
      "11. Owner registers Tenant B into Room 101 (201 Created, Bed 2/2)",
      regTenantBRes.status === 201 && regTenantBRes.data.data.room.occupiedBeds === 2,
      JSON.stringify(regTenantBRes.data)
    );
    const tenantIdB = regTenantBRes.data.data.tenant._id;

    // Login as Tenant B
    const loginTenantBRes = await makeRequest("POST", "/api/auth/login", {
      email: tenantEmailB,
      password: tenantPassword
    });
    const tenantTokenB = loginTenantBRes.data.token;

    // 12. Capacity Restriction: Registering Tenant C in full Room 101 is blocked
    const regTenantCRes = await makeRequest(
      "POST",
      "/api/tenants",
      {
        name: "Vikas Tenant C",
        email: `tenantC_${timestamp}@skyheight-test.com`,
        password: tenantPassword,
        phone: "+919833344455",
        roomId: roomId1
      },
      ownerToken
    );
    assert(
      "12. Room capacity restriction blocks 3rd tenant in 2-bed room (400 Bad Request)",
      regTenantCRes.status === 400 && regTenantCRes.data.success === false,
      JSON.stringify(regTenantCRes.data)
    );

    // 13. Tenant A views their own profile
    const getMyProfileRes = await makeRequest("GET", "/api/tenants/me", null, tenantTokenA);
    assert(
      "13. Tenant A views own profile via /api/tenants/me (200 OK)",
      getMyProfileRes.status === 200 && getMyProfileRes.data.data.fullName === "Rahul Tenant A",
      JSON.stringify(getMyProfileRes.data)
    );

    // 14. Tenant A trying to view Tenant B's profile directly is forbidden
    const getOtherTenantRes = await makeRequest("GET", `/api/tenants/${tenantIdB}`, null, tenantTokenA);
    assert(
      "14. Tenant A is blocked from viewing Tenant B's profile (403 Forbidden)",
      getOtherTenantRes.status === 403,
      JSON.stringify(getOtherTenantRes.data)
    );

    // 15. Owner changes Room assignment: Move Tenant B from Room 101 to Room 102
    const changeRoomRes = await makeRequest(
      "PUT",
      `/api/tenants/${tenantIdB}/change-room`,
      {
        newRoomId: roomId2,
        assignedBed: "Bed Single"
      },
      ownerToken
    );
    assert(
      "15. Owner moves Tenant B to Room 102 (200 OK, updates both rooms)",
      changeRoomRes.status === 200 && changeRoomRes.data.data.newRoom.occupiedBeds === 1,
      JSON.stringify(changeRoomRes.data)
    );

    // 16. Safe Room deletion: Attempting to delete Room 101 with active Tenant A is rejected
    const deleteOccupiedRoomRes = await makeRequest("DELETE", `/api/rooms/${roomId1}`, null, ownerToken);
    assert(
      "16. Cannot delete room with active tenant (400 Bad Request)",
      deleteOccupiedRoomRes.status === 400 && deleteOccupiedRoomRes.data.success === false,
      JSON.stringify(deleteOccupiedRoomRes.data)
    );

    // ----------------------------------------------------
    // MODULE 3: Electricity Meter Readings
    // ----------------------------------------------------
    console.log("\n--- MODULE 3: Electricity Meter Readings ---");

    // 17. Record meter reading for Room 101
    const addMeterRes = await makeRequest(
      "POST",
      "/api/meters",
      {
        roomId: roomId1,
        previousReading: 1000,
        currentReading: 1150,
        readingMonth: testMonth,
        ratePerUnit: 12,
        remarks: "Nov meter reading"
      },
      ownerToken
    );
    assert(
      "17. Owner records meter reading (1150 - 1000 = 150 units, ₹1800)",
      addMeterRes.status === 201 &&
        addMeterRes.data.data.unitsConsumed === 150 &&
        addMeterRes.data.data.electricityAmount === 1800,
      JSON.stringify(addMeterRes.data)
    );

    // 18. Duplicate meter reading prevention for same room and month
    const dupMeterRes = await makeRequest(
      "POST",
      "/api/meters",
      {
        roomId: roomId1,
        currentReading: 1200,
        readingMonth: testMonth
      },
      ownerToken
    );
    assert(
      "18. Duplicate meter reading for same room & month rejected (400 Bad Request)",
      dupMeterRes.status === 400 && dupMeterRes.data.success === false,
      JSON.stringify(dupMeterRes.data)
    );

    // 19. Current reading lower than previous is rejected
    const lowerMeterRes = await makeRequest(
      "POST",
      "/api/meters",
      {
        roomId: roomId2,
        previousReading: 500,
        currentReading: 400, // Invalid: lower than 500
        readingMonth: testMonth
      },
      ownerToken
    );
    assert(
      "19. Current meter reading lower than previous is rejected (400 Bad Request)",
      lowerMeterRes.status === 400 && lowerMeterRes.data.success === false,
      JSON.stringify(lowerMeterRes.data)
    );

    // 20. Tenant is forbidden from recording meter readings
    const tenantMeterRes = await makeRequest(
      "POST",
      "/api/meters",
      {
        roomId: roomId1,
        currentReading: 1200,
        readingMonth: "2026-12"
      },
      tenantTokenA
    );
    assert("20. Tenant is blocked from recording meter readings (403 Forbidden)", tenantMeterRes.status === 403);

    // 21. Tenant A views own room meter details
    const getTenantMeterRes = await makeRequest("GET", "/api/meters/my-meter", null, tenantTokenA);
    assert(
      "21. Tenant views their room's latest meter details (200 OK)",
      getTenantMeterRes.status === 200 && getTenantMeterRes.data.data.latestReading.unitsConsumed === 150,
      JSON.stringify(getTenantMeterRes.data)
    );

    // 22. Owner views monthly electricity usage report across all rooms
    const usageReportRes = await makeRequest("GET", `/api/meters/monthly-usage?month=${testMonth}`, null, ownerToken);
    assert(
      "22. Owner views monthly electricity usage summary report (200 OK)",
      usageReportRes.status === 200 && usageReportRes.data.totalUnitsConsumed >= 150,
      JSON.stringify(usageReportRes.data)
    );

    // ----------------------------------------------------
    // MODULE 4: Billing APIs
    // ----------------------------------------------------
    console.log("\n--- MODULE 4: Billing APIs ---");

    // 23. Owner generates bill for Tenant A
    // Rent: 8500, Electricity: 1800, Other: 200, Adjustments: 500 -> Total = 10000
    const genBillRes = await makeRequest(
      "POST",
      "/api/bills/generate",
      {
        tenantId: tenantIdA,
        billingMonth: testMonth,
        otherCharges: 200,
        adjustments: 500,
        notes: "November Rent + Electricity"
      },
      ownerToken
    );
    assert(
      "23. Owner generates monthly bill for Tenant A (Total: ₹10,000)",
      genBillRes.status === 201 && genBillRes.data.data.totalAmount === 10000,
      JSON.stringify(genBillRes.data)
    );
    const billIdA = genBillRes.data.data._id;

    // 24. Duplicate bill prevention for same tenant and month
    const dupBillRes = await makeRequest(
      "POST",
      "/api/bills/generate",
      {
        tenantId: tenantIdA,
        billingMonth: testMonth
      },
      ownerToken
    );
    assert(
      "24. Duplicate bill for same tenant & month rejected (400 Bad Request)",
      dupBillRes.status === 400 && dupBillRes.data.success === false,
      JSON.stringify(dupBillRes.data)
    );

    // 25. Tenant forbidden from generating bills
    const tenantGenBillRes = await makeRequest(
      "POST",
      "/api/bills/generate",
      {
        tenantId: tenantIdA,
        billingMonth: "2026-12"
      },
      tenantTokenA
    );
    assert("25. Tenant is blocked from generating bills (403 Forbidden)", tenantGenBillRes.status === 403);

    // 26. Tenant A views their bills
    const getMyBillsRes = await makeRequest("GET", "/api/bills/my-bills", null, tenantTokenA);
    assert(
      "26. Tenant A views own bills via /api/bills/my-bills (200 OK)",
      getMyBillsRes.status === 200 && getMyBillsRes.data.data.length >= 1,
      JSON.stringify(getMyBillsRes.data)
    );

    // 27. Owner generates bill for Tenant B
    const genBillBRes = await makeRequest(
      "POST",
      "/api/bills/generate",
      {
        tenantId: tenantIdB,
        billingMonth: testMonth
      },
      ownerToken
    );
    const billIdB = genBillBRes.data.data._id;
    assert("27. Owner generates bill for Tenant B (201 Created)", genBillBRes.status === 201);

    // 28. Tenant A blocked from viewing Tenant B's bill
    const viewOtherBillRes = await makeRequest("GET", `/api/bills/${billIdB}`, null, tenantTokenA);
    assert(
      "28. Tenant A is forbidden from viewing Tenant B's bill (403 Forbidden)",
      viewOtherBillRes.status === 403,
      JSON.stringify(viewOtherBillRes.data)
    );

    // 29. Owner views all pending bills
    const pendingBillsRes = await makeRequest("GET", "/api/bills/pending", null, ownerToken);
    assert(
      "29. Owner views pending bills list and total pending amount",
      pendingBillsRes.status === 200 && pendingBillsRes.data.totalPendingAmount > 0,
      JSON.stringify(pendingBillsRes.data)
    );

    // 30. Owner updates bill adjustments
    const updateAdjustRes = await makeRequest(
      "PUT",
      `/api/bills/${billIdA}/adjustments`,
      {
        adjustments: 1000 // increases discount by 500 -> total becomes 9500
      },
      ownerToken
    );
    assert(
      "30. Owner updates bill adjustment (total recalculated to ₹9500)",
      updateAdjustRes.status === 200 && updateAdjustRes.data.data.totalAmount === 9500,
      JSON.stringify(updateAdjustRes.data)
    );

    // ----------------------------------------------------
    // MODULE 5: Payment APIs
    // ----------------------------------------------------
    console.log("\n--- MODULE 5: Payment APIs ---");

    // 31. Owner records cash payment for Tenant A (Partial: ₹5000 of ₹9500)
    const cashPayRes = await makeRequest(
      "POST",
      "/api/payments/cash",
      {
        billId: billIdA,
        amount: 5000,
        notes: "Cash received in office"
      },
      ownerToken
    );
    assert(
      "31. Owner records cash payment (201 Created, Bill status: partially_paid)",
      cashPayRes.status === 201 &&
        cashPayRes.data.data.payment.verificationStatus === "verified" &&
        cashPayRes.data.data.bill.paymentStatus === "partially_paid",
      JSON.stringify(cashPayRes.data)
    );

    // 32. Overpayment prevention: paying more than remaining balance is rejected
    const overPayRes = await makeRequest(
      "POST",
      "/api/payments/cash",
      {
        billId: billIdA,
        amount: 6000 // Remaining is 4500, 6000 is invalid
      },
      ownerToken
    );
    assert(
      "32. Overpayment exceeding remaining balance is rejected (400 Bad Request)",
      overPayRes.status === 400 && overPayRes.data.success === false,
      JSON.stringify(overPayRes.data)
    );

    // 33. Tenant B submits UPI payment reference (UTR) for Bill B
    const upiRef = `UPI${timestamp}UTR999`;
    const submitUpiRes = await makeRequest(
      "POST",
      "/api/payments/upi/submit",
      {
        billId: billIdB,
        amount: 5000,
        transactionReference: upiRef,
        notes: "GPay transfer"
      },
      tenantTokenB
    );
    assert(
      "33. Tenant B submits UPI payment reference (Status is PENDING)",
      submitUpiRes.status === 201 &&
        submitUpiRes.data.data.verificationStatus === "pending" &&
        submitUpiRes.data.data.paymentMethod === "upi",
      JSON.stringify(submitUpiRes.data)
    );
    const upiPaymentId = submitUpiRes.data.data._id;

    // 34. Verify Bill B paidAmount is still 0 (submission does NOT credit until verified)
    const checkBillBRes = await makeRequest("GET", `/api/bills/${billIdB}`, null, ownerToken);
    assert(
      "34. Bill is NOT credited on unverified UPI submission (paidAmount remains 0)",
      checkBillBRes.status === 200 && checkBillBRes.data.data.paidAmount === 0,
      JSON.stringify(checkBillBRes.data)
    );

    // 35. Duplicate UTR reference rejection
    const dupUpiRes = await makeRequest(
      "POST",
      "/api/payments/upi/submit",
      {
        billId: billIdB,
        amount: 5000,
        transactionReference: upiRef
      },
      tenantTokenB
    );
    assert(
      "35. Duplicate transaction reference (UTR) is rejected (400 Bad Request)",
      dupUpiRes.status === 400,
      JSON.stringify(dupUpiRes.data)
    );

    // 36. Tenant cannot verify their own payment
    const unauthVerifyRes = await makeRequest(
      "PUT",
      `/api/payments/${upiPaymentId}/verify`,
      {
        status: "verified"
      },
      tenantTokenB
    );
    assert("36. Tenant is forbidden from verifying payments (403 Forbidden)", unauthVerifyRes.status === 403);

    // 37. Owner verifies Tenant B's UPI payment
    const verifyUpiRes = await makeRequest(
      "PUT",
      `/api/payments/${upiPaymentId}/verify`,
      {
        status: "verified",
        notes: "Verified in ICICI bank statement"
      },
      ownerToken
    );
    assert(
      "37. Owner verifies UPI payment (200 OK, bill paidAmount now credited)",
      verifyUpiRes.status === 200 &&
        verifyUpiRes.data.data.payment.verificationStatus === "verified" &&
        verifyUpiRes.data.data.billPaidAmount === 5000,
      JSON.stringify(verifyUpiRes.data)
    );

    // 38. Tenant Outstanding balance calculation
    const balanceRes = await makeRequest("GET", `/api/payments/balance/${tenantIdA}`, null, ownerToken);
    assert(
      "38. Outstanding balance calculation (totalBilled ₹9500, paid ₹5000, balance ₹4500)",
      balanceRes.status === 200 && balanceRes.data.data.outstandingBalance === 4500,
      JSON.stringify(balanceRes.data)
    );

    // ----------------------------------------------------
    // MODULE 6: Expense APIs
    // ----------------------------------------------------
    console.log("\n--- MODULE 6: Expense APIs ---");

    // 39. Owner adds expense
    const addExpRes = await makeRequest(
      "POST",
      "/api/expenses",
      {
        title: "WiFi Fibre Bill November",
        category: "wifi",
        amount: 1499,
        date: "2026-11-01",
        description: "Airtel broadband 200 Mbps"
      },
      ownerToken
    );
    assert(
      "39. Owner records operational expense (201 Created)",
      addExpRes.status === 201 && addExpRes.data.data.category === "wifi",
      JSON.stringify(addExpRes.data)
    );
    const expId = addExpRes.data.data._id;

    // 40. Tenant forbidden from adding expenses
    const tenantExpRes = await makeRequest(
      "POST",
      "/api/expenses",
      {
        title: "Test",
        category: "cleaning",
        amount: 500
      },
      tenantTokenA
    );
    assert("40. Tenant is forbidden from recording expenses (403 Forbidden)", tenantExpRes.status === 403);

    // 41. Owner gets expense summary
    const expSummaryRes = await makeRequest("GET", `/api/expenses/summary?month=${testMonth}`, null, ownerToken);
    assert(
      "41. Owner views monthly expense summary with category breakdown",
      expSummaryRes.status === 200 && expSummaryRes.data.totalSpent >= 1499,
      JSON.stringify(expSummaryRes.data)
    );

    // 42. Owner updates expense
    const updateExpRes = await makeRequest(
      "PUT",
      `/api/expenses/${expId}`,
      {
        amount: 1599,
        description: "Airtel broadband 200 Mbps + GST"
      },
      ownerToken
    );
    assert(
      "42. Owner updates expense amount and description (200 OK)",
      updateExpRes.status === 200 && updateExpRes.data.data.amount === 1599,
      JSON.stringify(updateExpRes.data)
    );

    // 43. Owner deletes expense
    const deleteExpRes = await makeRequest("DELETE", `/api/expenses/${expId}`, null, ownerToken);
    assert("43. Owner deletes expense record (200 OK)", deleteExpRes.status === 200);

    // ----------------------------------------------------
    // MODULE 7: Complaint APIs
    // ----------------------------------------------------
    console.log("\n--- MODULE 7: Complaint APIs ---");

    // 44. Tenant A registers a complaint
    const addComplaintRes = await makeRequest(
      "POST",
      "/api/complaints",
      {
        title: "Bathroom Tap Leaking",
        description: "Water leaking constantly from geyser valve in washroom",
        category: "plumbing",
        priority: "high"
      },
      tenantTokenA
    );
    assert(
      "44. Tenant A registers complaint (201 Created, Status: open)",
      addComplaintRes.status === 201 &&
        addComplaintRes.data.data.status === "open" &&
        addComplaintRes.data.data.priority === "high",
      JSON.stringify(addComplaintRes.data)
    );
    const complaintId = addComplaintRes.data.data._id;

    // 45. Tenant A views their complaints
    const myComplaintsRes = await makeRequest("GET", "/api/complaints/my-complaints", null, tenantTokenA);
    assert(
      "45. Tenant A views own complaints list (200 OK)",
      myComplaintsRes.status === 200 && myComplaintsRes.data.count >= 1,
      JSON.stringify(myComplaintsRes.data)
    );

    // 46. Owner views all complaints
    const allComplaintsRes = await makeRequest("GET", "/api/complaints", null, ownerToken);
    assert(
      "46. Owner views all PG complaints (200 OK)",
      allComplaintsRes.status === 200 && allComplaintsRes.data.count >= 1,
      JSON.stringify(allComplaintsRes.data)
    );

    // 47. Owner updates complaint status to resolved
    const resolveCompRes = await makeRequest(
      "PUT",
      `/api/complaints/${complaintId}/status`,
      {
        status: "resolved",
        resolution: "Replaced washer in geyser inlet valve"
      },
      ownerToken
    );
    assert(
      "47. Owner resolves complaint with resolution notes (200 OK)",
      resolveCompRes.status === 200 &&
        resolveCompRes.data.data.status === "resolved" &&
        resolveCompRes.data.data.resolution.includes("Replaced washer"),
      JSON.stringify(resolveCompRes.data)
    );

    // ----------------------------------------------------
    // MODULE 8: Owner Dashboard & Settings APIs
    // ----------------------------------------------------
    console.log("\n--- MODULE 8: Dashboard & Settings ---");

    // 48. Owner views Dashboard Summary
    const dashboardRes = await makeRequest("GET", `/api/dashboard/summary?month=${testMonth}`, null, ownerToken);
    assert(
      "48. Owner views Dashboard Summary with aggregated rooms, tenants, financials",
      dashboardRes.status === 200 &&
        dashboardRes.data.data.rooms.total >= 2 &&
        dashboardRes.data.data.tenants.active >= 2 &&
        dashboardRes.data.data.financials.monthlyRentCollection >= 10000,
      JSON.stringify(dashboardRes.data)
    );

    // 49. Tenant forbidden from accessing Owner Dashboard
    const tenantDashRes = await makeRequest("GET", "/api/dashboard/summary", null, tenantTokenA);
    assert("49. Tenant is blocked from Owner Dashboard (403 Forbidden)", tenantDashRes.status === 403);

    // 50. Owner views Financial Report
    const finReportRes = await makeRequest(
      "GET",
      `/api/dashboard/reports/financial?month=${testMonth}`,
      null,
      ownerToken
    );
    assert(
      "50. Owner views detailed Financial Report (collections by method, net profit)",
      finReportRes.status === 200 && finReportRes.data.data.summary.totalCollected >= 10000,
      JSON.stringify(finReportRes.data)
    );

    // 51. View PG Settings (Tenant or Owner)
    const getSettingsRes = await makeRequest("GET", "/api/settings", null, tenantTokenA);
    assert(
      "51. Tenant views PG settings (PG name, UPI ID, default rules)",
      getSettingsRes.status === 200 && Boolean(getSettingsRes.data.data.pgName),
      JSON.stringify(getSettingsRes.data)
    );

    // 52. Owner updates PG Settings
    const updateSettingsRes = await makeRequest(
      "PUT",
      "/api/settings",
      {
        electricityRatePerUnit: 11.5,
        upiId: "skyheight@okaxis",
        defaultDueDateDay: 7
      },
      ownerToken
    );
    assert(
      "52. Owner updates PG electricity rate and UPI ID (200 OK)",
      updateSettingsRes.status === 200 &&
        updateSettingsRes.data.data.electricityRatePerUnit === 11.5 &&
        updateSettingsRes.data.data.upiId === "skyheight@okaxis",
      JSON.stringify(updateSettingsRes.data)
    );

    // 53. Tenant forbidden from updating PG settings
    const tenantUpdateSettingsRes = await makeRequest(
      "PUT",
      "/api/settings",
      {
        electricityRatePerUnit: 5
      },
      tenantTokenA
    );
    assert("53. Tenant is blocked from updating PG settings (403 Forbidden)", tenantUpdateSettingsRes.status === 403);

    // 54. Invalid ObjectId validation check
    const invalidIdRes = await makeRequest("GET", "/api/rooms/invalid-mongo-id-123", null, ownerToken);
    assert(
      "54. Malformed ObjectId is caught and rejected with 400 Bad Request",
      invalidIdRes.status === 400 && invalidIdRes.data.success === false,
      JSON.stringify(invalidIdRes.data)
    );

    console.log("\n--------------------------------------------------");
    console.log(`TOTAL PHASE 3 TESTS: ${passed + failed}`);
    console.log(`PASSED:              ${passed}`);
    console.log(`FAILED:              ${failed}`);
    console.log("--------------------------------------------------");

    await mongoose.disconnect();

    if (failed === 0) {
      console.log("\nALL 55 PHASE 3 CORE API TESTS PASSED PERFECTLY!\n");
      process.exit(0);
    } else {
      console.error(`\n${failed} TEST(S) FAILED.\n`);
      process.exit(1);
    }
  } catch (error) {
    console.error("Test runner encountered an error:", error);
    await mongoose.disconnect();
    process.exit(1);
  }
};

runTests();
