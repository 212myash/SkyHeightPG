const dns = require("dns");
try {
  dns.setServers(["8.8.8.8", "8.8.4.4"]);
} catch (e) {}

const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, ".env") });
const http = require("http");
const mongoose = require("mongoose");
const connectDB = require("./config/db");

// Models
const User = require("./models/User");
const Tenant = require("./models/Tenant");
const Room = require("./models/Room");
const OccupancyHistory = require("./models/OccupancyHistory");
const Bill = require("./models/Bill");
const Payment = require("./models/Payment");

// Utils
const generateToken = require("./utils/generateToken");

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(description, condition, details = "") {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`[PASS] ${totalTests}. ${description}`);
  } else {
    failedTests++;
    console.error(`[FAIL] ${totalTests}. ${description} ${details ? "- " + details : ""}`);
  }
}

async function runPhaseATests() {
  console.log("====================================================");
  console.log("   SKY HEIGHT APARTMENT — PHASE A AUTOMATED TESTS  ");
  console.log("       (Occupancy History & Leaving Audit)         ");
  console.log("====================================================\n");

  await connectDB();

  // Load express app
  const express = require("express");
  const cors = require("cors");
  const authRoutes = require("./routes/authRoutes");
  const roomRoutes = require("./routes/roomRoutes");
  const tenantRoutes = require("./routes/tenantRoutes");
  const registrationRoutes = require("./routes/registrationRoutes");

  const app = express();
  app.use(cors());
  app.use(express.json());

  app.use("/api/auth", authRoutes);
  app.use("/api/rooms", roomRoutes);
  app.use("/api/tenants", tenantRoutes);
  app.use("/api/owner/registrations", registrationRoutes);

  const PORT = 5057;
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(PORT, resolve));
  const BASE_URL = `http://localhost:${PORT}`;

  async function api(method, routePath, body = null, token = null) {
    const headers = { "Content-Type": "application/json" };
    if (token) headers["Authorization"] = `Bearer ${token}`;
    const options = { method, headers };
    if (body) options.body = JSON.stringify(body);
    const res = await fetch(`${BASE_URL}${routePath}`, options);
    let data = null;
    try {
      data = await res.json();
    } catch (e) {}
    return { status: res.status, ok: res.ok, data };
  }

  const testSuffix = Date.now().toString().slice(-6);

  let ownerUser = null;
  let ownerToken = null;
  let tenantUserA = null;
  let tenantTokenA = null;
  let tenantUserB = null;
  let tenantTokenB = null;

  let testRoom1 = null;
  let testRoom2 = null;
  let testTenant = null;

  try {
    // 0. Setup test users and rooms
    ownerUser = await User.create({
      name: `Test Owner ${testSuffix}`,
      email: `test_owner_${testSuffix}@skyheight.test`,
      password: "Password123!",
      role: "owner",
      approvalStatus: "approved",
      isActive: true
    });
    ownerToken = generateToken(ownerUser._id, "owner");

    testRoom1 = await Room.create({
      roomNumber: `TEST-A${testSuffix}`,
      floor: 1,
      roomType: "double",
      monthlyRent: 8000,
      maxOccupancy: 2,
      occupiedBeds: 0,
      status: "available",
      isActive: true
    });

    testRoom2 = await Room.create({
      roomNumber: `TEST-B${testSuffix}`,
      floor: 2,
      roomType: "single",
      monthlyRent: 9500,
      maxOccupancy: 1,
      occupiedBeds: 0,
      status: "available",
      isActive: true
    });

    // ----------------------------------------------------
    // TEST 1: Initial occupancy creation on tenant registration
    // ----------------------------------------------------
    const regRes = await api(
      "POST",
      "/api/tenants",
      {
        name: `Tenant Alpha ${testSuffix}`,
        email: `tenant_a_${testSuffix}@skyheight.test`,
        password: "TenantPassword123!",
        phone: "9876500001",
        roomId: testRoom1._id.toString(),
        monthlyRent: 8000,
        securityDeposit: 16000
      },
      ownerToken
    );

    assert(
      "Owner successfully registers tenant with room allocation",
      regRes.status === 201 && regRes.data?.success === true
    );

    testTenant = await Tenant.findById(regRes.data.data.tenant._id);
    tenantUserA = await User.findById(testTenant.user);
    tenantTokenA = generateToken(tenantUserA._id, "tenant");

    const initialHistory = await OccupancyHistory.findOne({
      tenant: testTenant._id,
      room: testRoom1._id
    });

    assert(
      "Active OccupancyHistory record automatically created on registration",
      initialHistory !== null &&
      initialHistory.occupancyStatus === "active" &&
      initialHistory.roomNumber === testRoom1.roomNumber &&
      initialHistory.leavingDate === null
    );

    // ----------------------------------------------------
    // TEST 2: Capacity Validation on Transfer
    // ----------------------------------------------------
    testRoom2.occupiedBeds = testRoom2.maxOccupancy;
    await testRoom2.save();

    const fullTransferRes = await api(
      "PUT",
      `/api/tenants/${testTenant._id}/change-room`,
      {
        newRoomId: testRoom2._id.toString(),
        reason: "Transfer attempt to full room"
      },
      ownerToken
    );

    assert(
      "Transfer rejects allocation to full room (HTTP 400 Capacity Validation)",
      fullTransferRes.status === 400 && fullTransferRes.data?.success === false
    );

    // Free testRoom2 for valid transfer
    testRoom2.occupiedBeds = 0;
    await testRoom2.save();

    // ----------------------------------------------------
    // TEST 3: Room Transfer - Close old and open new history
    // ----------------------------------------------------
    const transferDate = new Date();
    const transferRes = await api(
      "PUT",
      `/api/tenants/${testTenant._id}/change-room`,
      {
        newRoomId: testRoom2._id.toString(),
        monthlyRent: 9500,
        reason: "Upgraded to 2nd floor room",
        transferDate: transferDate.toISOString()
      },
      ownerToken
    );

    assert(
      "Owner successfully transfers tenant to new room",
      transferRes.status === 200 && transferRes.data?.success === true
    );

    // Verify old history is marked 'transferred' with leavingDate
    const oldHistory = await OccupancyHistory.findOne({
      tenant: testTenant._id,
      room: testRoom1._id
    });

    assert(
      "Previous occupancy record is closed with 'transferred' status, leavingDate, and reason",
      oldHistory !== null &&
      oldHistory.occupancyStatus === "transferred" &&
      oldHistory.leavingDate !== null &&
      oldHistory.reason.includes("Upgraded to 2nd floor")
    );

    // Verify new history is marked 'active' for testRoom2
    const newHistory = await OccupancyHistory.findOne({
      tenant: testTenant._id,
      room: testRoom2._id
    });

    assert(
      "New active OccupancyHistory record opened for destination room",
      newHistory !== null &&
      newHistory.occupancyStatus === "active" &&
      newHistory.roomNumber === testRoom2.roomNumber &&
      newHistory.monthlyRentSnapshot === 9500 &&
      newHistory.leavingDate === null
    );

    // Verify room counts: Room 1 decremented, Room 2 incremented
    const room1Updated = await Room.findById(testRoom1._id);
    const room2Updated = await Room.findById(testRoom2._id);
    assert(
      "Room occupancies correctly synchronized upon transfer",
      room1Updated.occupiedBeds === 0 && room2Updated.occupiedBeds === 1
    );

    // ----------------------------------------------------
    // TEST 4: Historical record preservation (No overwrite)
    // ----------------------------------------------------
    const allRecordsForTenant = await OccupancyHistory.find({ tenant: testTenant._id });
    assert(
      "Both previous and current occupancy records exist (historical preservation, zero overwrite)",
      allRecordsForTenant.length === 2
    );

    // ----------------------------------------------------
    // TEST 5: Owner views tenant occupancy history
    // ----------------------------------------------------
    const historyRes = await api(
      "GET",
      `/api/tenants/${testTenant._id}/occupancy-history`,
      null,
      ownerToken
    );

    assert(
      "Owner can query chronological occupancy history for tenant",
      historyRes.status === 200 &&
      historyRes.data?.data?.history?.length === 2 &&
      historyRes.data?.data?.history[0]?.occupancyStatus === "active"
    );

    // ----------------------------------------------------
    // TEST 6: Tenant views own occupancy history
    // ----------------------------------------------------
    const myHistoryRes = await api(
      "GET",
      "/api/tenants/me/occupancy-history",
      null,
      tenantTokenA
    );

    assert(
      "Tenant can view their own occupancy history via /api/tenants/me/occupancy-history",
      myHistoryRes.status === 200 &&
      myHistoryRes.data?.data?.history?.length === 2
    );

    // ----------------------------------------------------
    // TEST 7: Security & Data Isolation (Tenant B blocked)
    // ----------------------------------------------------
    tenantUserB = await User.create({
      name: `Tenant Beta ${testSuffix}`,
      email: `tenant_b_${testSuffix}@skyheight.test`,
      password: "TenantPassword123!",
      phone: "9876500002",
      role: "tenant",
      approvalStatus: "approved",
      isActive: true
    });
    tenantTokenB = generateToken(tenantUserB._id, "tenant");

    const unauthorizedHistoryRes = await api(
      "GET",
      `/api/tenants/${testTenant._id}/occupancy-history`,
      null,
      tenantTokenB
    );

    assert(
      "Tenant cannot access another tenant's occupancy history (HTTP 403 Forbidden)",
      unauthorizedHistoryRes.status === 403
    );

    // ----------------------------------------------------
    // TEST 8: Room Occupancy History (Historical occupants of room)
    // ----------------------------------------------------
    const roomHistoryRes = await api(
      "GET",
      `/api/rooms/${testRoom1._id}/occupancy-history`,
      null,
      ownerToken
    );

    assert(
      "Owner can query room occupancy history to see all past occupants",
      roomHistoryRes.status === 200 &&
      roomHistoryRes.data?.data?.history?.length === 1 &&
      roomHistoryRes.data?.data?.history[0]?.tenant?.fullName?.includes("Tenant Alpha")
    );

    // ----------------------------------------------------
    // TEST 9: Tenant Vacating & Leaving Audit
    // ----------------------------------------------------
    const vacateDate = new Date();
    const vacateRes = await api(
      "PUT",
      `/api/tenants/${testTenant._id}/vacate`,
      {
        reason: "Tenant moving out of city",
        leavingDate: vacateDate.toISOString()
      },
      ownerToken
    );

    assert(
      "Owner successfully marks tenant as vacated",
      vacateRes.status === 200 && vacateRes.data?.success === true
    );

    const refreshedTenant = await Tenant.findById(testTenant._id);
    assert(
      "Tenant model updated with status: 'vacated' and vacatedAt timestamp",
      refreshedTenant.status === "vacated" &&
      refreshedTenant.vacatedAt !== null
    );

    const vacatedHistory = await OccupancyHistory.findOne({
      tenant: testTenant._id,
      room: testRoom2._id
    });

    assert(
      "Active occupancy record closed with status: 'vacated', leavingDate, and reason",
      vacatedHistory !== null &&
      vacatedHistory.occupancyStatus === "vacated" &&
      vacatedHistory.leavingDate !== null &&
      vacatedHistory.reason.includes("moving out of city")
    );

    const room2AfterVacate = await Room.findById(testRoom2._id);
    assert(
      "Vacated room occupancy decremented and room marked available",
      room2AfterVacate.occupiedBeds === 0 && room2AfterVacate.status === "available"
    );

    // ----------------------------------------------------
    // TEST 10: Date Validation (leavingDate >= joiningDate)
    // ----------------------------------------------------
    let dateValFailed = false;
    try {
      const invalidHistory = new OccupancyHistory({
        tenant: testTenant._id,
        room: testRoom1._id,
        roomNumber: "TEST-INV",
        joiningDate: new Date("2026-10-01"),
        leavingDate: new Date("2026-09-01"),
        occupancyStatus: "vacated"
      });
      await invalidHistory.save();
    } catch (valErr) {
      dateValFailed = true;
    }

    assert(
      "Pre-save validation rejects leavingDate earlier than joiningDate",
      dateValFailed === true
    );

    // ----------------------------------------------------
    // TEST 11: Production Database Integrity Check
    // ----------------------------------------------------
    const genuineOwner = await User.findOne({ email: "212myashraj@gmail.com" });
    const genuineRooms = await Room.countDocuments({
      roomNumber: { $in: ["G101", "G102", "G103", "G104"] }
    });
    const genuineBills = await Bill.countDocuments();
    const genuinePayments = await Payment.countDocuments();

    assert(
      "Genuine production records (Owner, rooms G101-G104, bills, payments) 100% intact",
      genuineOwner !== null &&
      genuineRooms === 4 &&
      genuineBills >= 14 &&
      genuinePayments >= 16
    );

  } catch (error) {
    console.error("Test execution encountered an error:", error);
    failedTests++;
  } finally {
    // Clean up test records
    if (testTenant) {
      await OccupancyHistory.deleteMany({ tenant: testTenant._id });
      await Tenant.deleteOne({ _id: testTenant._id });
    }
    if (ownerUser) await User.deleteOne({ _id: ownerUser._id });
    if (tenantUserA) await User.deleteOne({ _id: tenantUserA._id });
    if (tenantUserB) await User.deleteOne({ _id: tenantUserB._id });
    if (testRoom1) await Room.deleteOne({ _id: testRoom1._id });
    if (testRoom2) await Room.deleteOne({ _id: testRoom2._id });

    server.close();
    await mongoose.disconnect();
    console.log("\n====================================================");
    console.log(`TEST SUMMARY: Total: ${totalTests} | Passed: ${passedTests} | Failed: ${failedTests}`);
    console.log("====================================================");
    process.exit(failedTests > 0 ? 1 : 0);
  }
}

runPhaseATests();
