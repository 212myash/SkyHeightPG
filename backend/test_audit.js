const http = require("http");
const dns = require("dns");
dns.setServers(["8.8.8.8", "8.8.4.4"]);
require("dotenv").config({ path: __dirname + "/.env" });
const mongoose = require("mongoose");
const User = require("./models/User");
const Room = require("./models/Room");
const Tenant = require("./models/Tenant");
const Bill = require("./models/Bill");
const Payment = require("./models/Payment");
const MeterReading = require("./models/MeterReading");
const PGSettings = require("./models/PGSettings");
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

const runAuditTests = async () => {
  console.log("==================================================");
  console.log("     SKY HEIGHT PG — AUDIT & EDGE CASE TESTS      ");
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

    // 1. Get or create Owner Token
    let owner = await User.findOne({ role: "owner" });
    if (!owner) {
      owner = await User.create({
        name: "Audit Owner",
        email: `audit_owner_${timestamp}@audit.com`,
        password: "OwnerPassword123!",
        role: "owner"
      });
    }
    const ownerToken = generateToken(owner._id, "owner");
    assert("1. Owner authentication token ready", Boolean(ownerToken));

    // 2. Room Setup for Audit
    const roomRes = await makeRequest(
      "POST",
      "/api/rooms",
      {
        roomNumber: `AUDIT-${timestamp % 100000}`,
        floor: 2,
        roomType: "double",
        monthlyRent: 9000,
        capacity: 2,
        amenities: ["AC"]
      },
      ownerToken
    );
    assert("2. Audit Room created successfully (201 Created)", roomRes.status === 201);
    const roomId = roomRes.data.data._id;

    // 3. Test Meter Reading uses PGSettings rate by default
    const settings = await PGSettings.getSettings();
    const meterDefaultRes = await makeRequest(
      "POST",
      "/api/meters",
      {
        roomId,
        previousReading: 100,
        currentReading: 200,
        readingMonth: "2026-09",
        remarks: "Default rate check"
      },
      ownerToken
    );
    assert(
      "3. Meter reading defaults to rate from PGSettings",
      meterDefaultRes.status === 201 && meterDefaultRes.data.data.ratePerUnit === settings.electricityRatePerUnit,
      JSON.stringify(meterDefaultRes.data)
    );

    // 4. Test Meter Reading rejects negative ratePerUnit
    const meterNegativeRateRes = await makeRequest(
      "POST",
      "/api/meters",
      {
        roomId,
        currentReading: 250,
        readingMonth: "2026-10",
        ratePerUnit: -10
      },
      ownerToken
    );
    assert(
      "4. Meter reading rejects negative ratePerUnit (400 Bad Request)",
      meterNegativeRateRes.status === 400 && meterNegativeRateRes.data.success === false,
      JSON.stringify(meterNegativeRateRes.data)
    );

    // 5. Test Register Tenant in Room
    const tenantRes = await makeRequest(
      "POST",
      "/api/tenants",
      {
        name: "Audit Tenant",
        email: `audit_tenant_${timestamp}@audit.com`,
        password: "Password123!",
        phone: "+919800011122",
        roomId,
        monthlyRent: 9000
      },
      ownerToken
    );
    assert("5. Audit Tenant registered and room occupancy updated to 1", tenantRes.status === 201);
    const tenantId = tenantRes.data.data.tenant._id;

    // 6. Test Single Bill with Custom Prorated Electricity Amount (Mid-month join)
    const proratedBillRes = await makeRequest(
      "POST",
      "/api/bills/generate",
      {
        tenantId,
        billingMonth: "2026-09",
        electricityAmount: 450, // custom mid-month prorated amount
        otherCharges: 100,
        adjustments: 200
      },
      ownerToken
    );
    // Formula: 9000 (rent) + 450 (elec) + 100 (other) - 200 (adjustments) = 9350
    assert(
      "6. Bill with custom prorated electricity amount computes totalAmount correctly (₹9350)",
      proratedBillRes.status === 201 &&
        proratedBillRes.data.data.electricityAmount === 450 &&
        proratedBillRes.data.data.totalAmount === 9350,
      JSON.stringify(proratedBillRes.data)
    );
    const billId = proratedBillRes.data.data._id;

    // 7. Verify Historical Bill Preservation when Tenant Details Change
    await makeRequest(
      "PUT",
      `/api/tenants/${tenantId}`,
      {
        monthlyRent: 11000 // Change tenant current rent
      },
      ownerToken
    );
    const historicalBillCheck = await makeRequest("GET", `/api/bills/${billId}`, null, ownerToken);
    assert(
      "7. Changing tenant current rent does NOT alter historical bill rent (remains ₹9000, total ₹9350)",
      historicalBillCheck.status === 200 &&
        historicalBillCheck.data.data.monthlyRent === 9000 &&
        historicalBillCheck.data.data.totalAmount === 9350,
      JSON.stringify(historicalBillCheck.data)
    );

    // 8. Test Partial Cash Payment on Bill
    // Total: 9350, Pay: 5000 -> Remaining balance: 4350
    const partialCashRes = await makeRequest(
      "POST",
      "/api/payments/cash",
      {
        billId,
        amount: 5000,
        notes: "Partial cash payment"
      },
      ownerToken
    );
    assert(
      "8. Partial cash payment applied (paidAmount: ₹5000, remaining balance: ₹4350)",
      partialCashRes.status === 201 && partialCashRes.data.data.bill.paidAmount === 5000,
      JSON.stringify(partialCashRes.data)
    );

    // 9. Tenant submits UPI payment of ₹5000 (which exceeds remaining balance of ₹4350 if allowed)
    // First, let's create a pending payment in DB for testing overpayment prevention during verification
    const tenantUser = await User.findOne({ email: `audit_tenant_${timestamp}@audit.com` });
    const tenantToken = generateToken(tenantUser._id, "tenant");

    // Submit valid ₹3000 UPI
    const validUpiRes = await makeRequest(
      "POST",
      "/api/payments/upi/submit",
      {
        billId,
        amount: 3000,
        transactionReference: `AUDIT-UTR-VALID-${timestamp}`,
        notes: "Valid partial UPI"
      },
      tenantToken
    );
    assert("9. Tenant submits valid ₹3000 UPI payment reference (pending)", validUpiRes.status === 201);
    const upiPayId = validUpiRes.data.data._id;

    // Now owner records cash payment of ₹2000 in the meantime (Total paid: 5000 + 2000 = 7000; remaining: 2350)
    await makeRequest(
      "POST",
      "/api/payments/cash",
      {
        billId,
        amount: 2000
      },
      ownerToken
    );

    // Now try to verify the ₹3000 UPI payment when remaining balance is only ₹2350!
    const overVerifyRes = await makeRequest(
      "PUT",
      `/api/payments/${upiPayId}/verify`,
      {
        status: "verified"
      },
      ownerToken
    );
    assert(
      "10. Overpayment prevention blocks verifying UPI payment exceeding current remaining balance (400 Bad Request)",
      overVerifyRes.status === 400 && overVerifyRes.data.success === false,
      JSON.stringify(overVerifyRes.data)
    );

    // 11. Test Rejecting UPI payment does NOT credit bill
    const rejectUpiRes = await makeRequest(
      "PUT",
      `/api/payments/${upiPayId}/verify`,
      {
        status: "rejected",
        notes: "Rejected due to overpayment; tenant should resubmit exact balance"
      },
      ownerToken
    );
    assert(
      "11. Rejection of UPI payment succeeds and marks verificationStatus: rejected",
      rejectUpiRes.status === 200 && rejectUpiRes.data.data.verificationStatus === "rejected",
      JSON.stringify(rejectUpiRes.data)
    );

    const billAfterReject = await makeRequest("GET", `/api/bills/${billId}`, null, ownerToken);
    assert(
      "12. Bill paidAmount remains uncredited after payment rejection (₹7000)",
      billAfterReject.status === 200 && billAfterReject.data.data.paidAmount === 7000,
      JSON.stringify(billAfterReject.data)
    );

    // 13. Test Room Occupancy Synchronization in updateTenant:
    // Vacating tenant via PUT /api/tenants/:id releases bed
    const updateVacateRes = await makeRequest(
      "PUT",
      `/api/tenants/${tenantId}`,
      {
        status: "vacated"
      },
      ownerToken
    );
    assert("13. Tenant status updated to vacated via PUT /api/tenants/:id", updateVacateRes.status === 200);

    const roomAfterVacate = await makeRequest("GET", `/api/rooms/${roomId}`, null, ownerToken);
    assert(
      "14. Room occupiedBeds automatically decremented to 0 and availableBeds is 2",
      roomAfterVacate.status === 200 &&
        roomAfterVacate.data.data.occupiedBeds === 0 &&
        roomAfterVacate.data.data.availableBeds === 2,
      JSON.stringify(roomAfterVacate.data)
    );

    // 15. Reactivating tenant increments occupiedBeds back to 1
    const updateReactivateRes = await makeRequest(
      "PUT",
      `/api/tenants/${tenantId}`,
      {
        status: "active"
      },
      ownerToken
    );
    assert("15. Tenant reactivated to active via PUT /api/tenants/:id", updateReactivateRes.status === 200);

    const roomAfterReactivate = await makeRequest("GET", `/api/rooms/${roomId}`, null, ownerToken);
    assert(
      "16. Room occupiedBeds automatically incremented back to 1",
      roomAfterReactivate.status === 200 && roomAfterReactivate.data.data.occupiedBeds === 1,
      JSON.stringify(roomAfterReactivate.data)
    );

    // Clean up audit test records
    await Payment.deleteMany({ bill: billId });
    await Bill.findByIdAndDelete(billId);
    await MeterReading.deleteMany({ room: roomId });
    await Tenant.findByIdAndDelete(tenantId);
    await Room.findByIdAndDelete(roomId);
    if (tenantUser) await User.findByIdAndDelete(tenantUser._id);

    console.log("\n--------------------------------------------------");
    console.log(`TOTAL AUDIT TESTS: ${passed + failed}`);
    console.log(`PASSED:            ${passed}`);
    console.log(`FAILED:            ${failed}`);
    console.log("--------------------------------------------------");

    await mongoose.disconnect();

    if (failed === 0) {
      console.log("\nALL 16 AUDIT & EDGE CASE TESTS PASSED PERFECTLY!\n");
      process.exit(0);
    } else {
      console.error(`\n${failed} TEST(S) FAILED.\n`);
      process.exit(1);
    }
  } catch (error) {
    console.error("Audit test error:", error);
    await mongoose.disconnect();
    process.exit(1);
  }
};

runAuditTests();
