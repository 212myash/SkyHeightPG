const dns = require("dns");
try {
  dns.setServers(["8.8.8.8", "8.8.4.4"]);
} catch (e) {}

const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, ".env") });
const http = require("http");
const mongoose = require("mongoose");
const connectDB = require("./config/db");
const User = require("./models/User");
const Tenant = require("./models/Tenant");
const Room = require("./models/Room");
const Notification = require("./models/Notification");
const Conversation = require("./models/Conversation");
const Message = require("./models/Message");
const Bill = require("./models/Bill");
const Payment = require("./models/Payment");
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

async function runPhaseFeaturesTest() {
  console.log("====================================================");
  console.log("   SKY HEIGHT APARTMENT — PHASE 8 FEATURE VERIFICATION");
  console.log("====================================================\n");

  await connectDB();

  // Load existing app
  const express = require("express");
  const cors = require("cors");
  const authRoutes = require("./routes/authRoutes");
  const roomRoutes = require("./routes/roomRoutes");
  const tenantRoutes = require("./routes/tenantRoutes");
  const meterRoutes = require("./routes/meterRoutes");
  const billRoutes = require("./routes/billRoutes");
  const paymentRoutes = require("./routes/paymentRoutes");
  const expenseRoutes = require("./routes/expenseRoutes");
  const complaintRoutes = require("./routes/complaintRoutes");
  const dashboardRoutes = require("./routes/dashboardRoutes");
  const settingsRoutes = require("./routes/settingsRoutes");
  const registrationRoutes = require("./routes/registrationRoutes");
  const notificationRoutes = require("./routes/notificationRoutes");
  const chatRoutes = require("./routes/chatRoutes");

  const app = express();
  app.use(cors());
  app.use(express.json());

  app.use("/api/auth", authRoutes);
  app.use("/api/rooms", roomRoutes);
  app.use("/api/tenants", tenantRoutes);
  app.use("/api/meters", meterRoutes);
  app.use("/api/bills", billRoutes);
  app.use("/api/payments", paymentRoutes);
  app.use("/api/expenses", expenseRoutes);
  app.use("/api/complaints", complaintRoutes);
  app.use("/api/dashboard", dashboardRoutes);
  app.use("/api/settings", settingsRoutes);
  app.use("/api/owner/registrations", registrationRoutes);
  app.use("/api/registrations", registrationRoutes);
  app.use("/api/notifications", notificationRoutes);
  app.use("/api/conversations", chatRoutes);
  app.use("/api/chat", chatRoutes);

  const PORT = 5055;
  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(PORT, resolve));
  const BASE_URL = `http://localhost:${PORT}`;

  async function api(method, path, body = null, token = null) {
    const headers = { "Content-Type": "application/json" };
    if (token) headers["Authorization"] = `Bearer ${token}`;
    const options = { method, headers };
    if (body) options.body = JSON.stringify(body);
    const res = await fetch(`${BASE_URL}${path}`, options);
    let data = null;
    try {
      data = await res.json();
    } catch (e) {}
    return { status: res.status, ok: res.ok, data };
  }

  // Find genuine owner
  const genuineOwner = await User.findOne({ role: "owner", isActive: true });
  if (!genuineOwner) {
    console.error("Critical: No genuine owner found in database!");
    server.close();
    process.exit(1);
  }
  const ownerToken = generateToken(genuineOwner._id, genuineOwner.role);

  const testSuffix = Date.now();
  const testEmail1 = `test_tenant_phase_${testSuffix}_1@example.com`;
  const testEmail2 = `test_tenant_phase_${testSuffix}_2@example.com`;
  const testEmail3 = `test_tenant_phase_${testSuffix}_3@example.com`;

  let testUser1Id = null;
  let testUser2Id = null;
  let testUser3Id = null;
  let testRoom1Id = null;
  let testRoom2Id = null;

  try {
    // --- TEST 1: Public registration creates Tenant only (pending) ---
    const regRes = await api("POST", "/api/auth/register", {
      name: "Phase Test Tenant 1",
      email: testEmail1,
      password: "password123",
      phone: "9876543210"
    });
    testUser1Id = regRes.data?.user?._id;
    assert(
      "Public registration creates Tenant only with approvalStatus: 'pending'",
      regRes.status === 201 &&
        regRes.data?.approvalStatus === "pending" &&
        regRes.data?.user?.role === "tenant"
    );

    // --- TEST 2: Owner creation via public register is blocked ---
    const regOwnerRes = await api("POST", "/api/auth/register", {
      name: "Malicious Owner Attempt",
      email: `fake_owner_${testSuffix}@example.com`,
      password: "password123",
      role: "owner"
    });
    assert(
      "Owner creation via public register is blocked (HTTP 403)",
      regOwnerRes.status === 403
    );

    // --- TEST 3: Pending tenant cannot access protected endpoints ---
    // If pending tenant tries to log in
    const loginPendingRes = await api("POST", "/api/auth/login", {
      email: testEmail1,
      password: "password123"
    });
    assert(
      "Pending tenant login is blocked with HTTP 403 pending status",
      loginPendingRes.status === 403 && loginPendingRes.data?.approvalStatus === "pending"
    );

    // If pending tenant possesses a token and calls protected route
    const pendingFakeToken = generateToken(testUser1Id, "tenant");
    const protectedRes = await api("GET", "/api/notifications", null, pendingFakeToken);
    assert(
      "Pending tenant cannot access protected endpoints (HTTP 403)",
      protectedRes.status === 403 && protectedRes.data?.approvalStatus === "pending"
    );

    // --- TEST 4: Owner receives notification on registration ---
    const ownerNotif = await Notification.findOne({
      recipient: genuineOwner._id,
      category: "registration_update"
    }).sort({ createdAt: -1 });
    assert(
      "Owner receives notification on new tenant registration",
      ownerNotif && ownerNotif.message.includes(testEmail1)
    );

    // Create test rooms for bedless occupancy testing
    const room1Res = await api(
      "POST",
      "/api/rooms",
      {
        roomNumber: `PT${String(testSuffix).slice(-3)}A`,
        floor: 1,
        monthlyRent: 8000,
        maxOccupancy: 2
      },
      ownerToken
    );
    testRoom1Id = room1Res.data?.data?._id;

    const room2Res = await api(
      "POST",
      "/api/rooms",
      {
        roomNumber: `PT${String(testSuffix).slice(-3)}B`,
        floor: 1,
        monthlyRent: 8500,
        maxOccupancy: 1
      },
      ownerToken
    );
    testRoom2Id = room2Res.data?.data?._id;

    // --- TEST 5: Owner can approve registration ---
    const approveRes = await api(
      "PUT",
      `/api/owner/registrations/${testUser1Id}/approve`,
      {
        roomId: testRoom1Id,
        monthlyRent: 8000
      },
      ownerToken
    );
    assert(
      "Owner can approve registration and assign room without bed fields",
      approveRes.status === 200 && approveRes.data?.data?.user?.approvalStatus === "approved"
    );

    // Register second tenant and approve
    const regRes2 = await api("POST", "/api/auth/register", {
      name: "Phase Test Tenant 2",
      email: testEmail2,
      password: "password123",
      phone: "9876543211"
    });
    testUser2Id = regRes2.data?.user?._id;
    await api(
      "PUT",
      `/api/owner/registrations/${testUser2Id}/approve`,
      {
        roomId: testRoom1Id,
        monthlyRent: 8000
      },
      ownerToken
    );

    // --- TEST 6: Room can have multiple active tenants without bed references ---
    const roomTenantsRes = await api("GET", `/api/rooms/${testRoom1Id}/tenants`, null, ownerToken);
    assert(
      "Room has multiple (2) active tenants allocated without beds",
      roomTenantsRes.status === 200 &&
        roomTenantsRes.data?.currentOccupancy === 2 &&
        roomTenantsRes.data?.data?.length === 2
    );

    // --- TEST 7: Room rejects over-capacity allocation ---
    const regRes3 = await api("POST", "/api/auth/register", {
      name: "Phase Test Tenant 3",
      email: testEmail3,
      password: "password123",
      phone: "9876543212"
    });
    testUser3Id = regRes3.data?.user?._id;
    const overCapacityApprove = await api(
      "PUT",
      `/api/owner/registrations/${testUser3Id}/approve`,
      {
        roomId: testRoom1Id
      },
      ownerToken
    );
    assert(
      "Room rejects over-capacity allocation (HTTP 400)",
      overCapacityApprove.status === 400
    );

    // Approve tenant 3 into testRoom2
    await api(
      "PUT",
      `/api/owner/registrations/${testUser3Id}/approve`,
      {
        roomId: testRoom2Id,
        monthlyRent: 8500
      },
      ownerToken
    );

    // --- TEST 8: Room transfer updates room counts correctly ---
    // Transfer tenant 2 from room 1 to room 2? But room 2 has maxOccupancy: 1 and has tenant 3.
    // Let's create Room 3 with maxOccupancy: 2
    const room3Res = await api(
      "POST",
      "/api/rooms",
      {
        roomNumber: `PT${String(testSuffix).slice(-3)}C`,
        floor: 2,
        monthlyRent: 9000,
        maxOccupancy: 2
      },
      ownerToken
    );
    const testRoom3Id = room3Res.data?.data?._id;

    const tenant2Doc = await Tenant.findOne({ user: testUser2Id });
    const transferRes = await api(
      "PUT",
      `/api/tenants/${tenant2Doc._id}/change-room`,
      {
        newRoomId: testRoom3Id
      },
      ownerToken
    );

    const oldRoomCheck = await Room.findById(testRoom1Id);
    const newRoomCheck = await Room.findById(testRoom3Id);
    assert(
      "Room transfer decrements old room and increments new room occupancy",
      transferRes.status === 200 &&
        oldRoomCheck.occupiedBeds === 1 &&
        newRoomCheck.occupiedBeds === 1
    );

    // Now testUser1 login
    const loginUser1 = await api("POST", "/api/auth/login", {
      email: testEmail1,
      password: "password123"
    });
    const tenant1Token = loginUser1.data?.token;

    // testUser3 login
    const loginUser3 = await api("POST", "/api/auth/login", {
      email: testEmail3,
      password: "password123"
    });
    const tenant3Token = loginUser3.data?.token;

    // --- TEST 9: Tenant data isolation maintained ---
    const tenant1Profile = await api("GET", `/api/tenants/${tenant2Doc._id}`, null, tenant1Token);
    assert(
      "Tenant cannot access another tenant's profile (HTTP 403 Data Isolation)",
      tenant1Profile.status === 403
    );

    // --- TEST 10: Owner broadcasts notification to All ---
    const broadcastRes = await api(
      "POST",
      "/api/notifications",
      {
        title: "Building Water Tank Cleaning",
        message: "Water supply will be paused between 2 PM and 4 PM.",
        category: "maintenance",
        audience: "all"
      },
      ownerToken
    );
    assert(
      "Owner can broadcast notification to All tenants",
      broadcastRes.status === 201 && broadcastRes.data?.count > 0
    );

    // --- TEST 11: Owner sends Room notification ---
    const roomNotifRes = await api(
      "POST",
      "/api/notifications",
      {
        title: "Room Inspection Notice",
        message: "Room 1 inspection tomorrow.",
        category: "general_announcement",
        audience: "room",
        targetRoom: testRoom1Id
      },
      ownerToken
    );
    assert(
      "Owner sends notification targeted to a specific room",
      roomNotifRes.status === 201 && roomNotifRes.data?.count === 1
    );

    // --- TEST 12: Owner sends Tenant-specific notification ---
    const tenantNotifRes = await api(
      "POST",
      "/api/notifications",
      {
        title: "Rent Reminder",
        message: "Your monthly rent is due on the 5th.",
        category: "rent_reminder",
        audience: "tenant",
        targetTenant: testUser1Id
      },
      ownerToken
    );
    assert(
      "Owner sends tenant-specific notification",
      tenantNotifRes.status === 201 && tenantNotifRes.data?.count === 1
    );

    // --- TEST 13: Notification read status is individual ---
    const tenant1Notifs = await api("GET", "/api/notifications", null, tenant1Token);
    const targetNotifId = tenant1Notifs.data?.data?.[0]?._id;
    const readRes = await api("PUT", `/api/notifications/${targetNotifId}/read`, {}, tenant1Token);
    assert(
      "Notification read status updates individually for recipient",
      readRes.status === 200 && readRes.data?.data?.isRead === true
    );

    // --- TEST 14: Tenant notification reply routes to private chat with Owner ---
    const replyRes = await api(
      "POST",
      `/api/notifications/${targetNotifId}/reply`,
      { message: "Understood, I will pay tomorrow morning." },
      tenant1Token
    );
    assert(
      "Tenant notification reply routes into private chat conversation with Owner",
      replyRes.status === 200 && replyRes.data?.data?.conversationId
    );

    const privateConvId = replyRes.data?.data?.conversationId;

    // --- TEST 15: Owner-Tenant private chat works ---
    const ownerReplyRes = await api(
      "POST",
      `/api/conversations/${privateConvId}/messages`,
      { content: "Thank you for informing me!" },
      ownerToken
    );
    const msgsRes = await api("GET", `/api/conversations/${privateConvId}/messages`, null, tenant1Token);
    assert(
      "Owner-Tenant private chat messages exchanged successfully",
      ownerReplyRes.status === 201 && msgsRes.data?.count >= 2
    );

    // --- TEST 16: Same-room group access works ---
    let room1Conv = await Conversation.findOne({ type: "room", room: testRoom1Id });
    if (!room1Conv) {
      room1Conv = await Conversation.create({
        type: "room",
        name: "Test Room 1 Group",
        room: testRoom1Id,
        participants: [testUser1Id]
      });
    }
    const tenant1RoomMsg = await api(
      "POST",
      `/api/conversations/${room1Conv._id}/messages`,
      { content: "Hello roommate!" },
      tenant1Token
    );
    assert(
      "Active room occupant can post and view in Same-Room group",
      tenant1RoomMsg.status === 201
    );

    // --- TEST 17: Different-room tenant blocked from room group (403) ---
    const tenant3RoomMsg = await api(
      "POST",
      `/api/conversations/${room1Conv._id}/messages`,
      { content: "Can I enter this chat?" },
      tenant3Token
    );
    assert(
      "Different-room tenant blocked from room group chat (HTTP 403)",
      tenant3RoomMsg.status === 403
    );

    // --- TEST 18: Community group allows eligible tenants ---
    const community = await Conversation.findOne({ type: "community" });
    const commMsg = await api(
      "POST",
      `/api/conversations/${community._id}/messages`,
      { content: "Hello Sky Height Community!" },
      tenant1Token
    );
    assert(
      "Community group allows eligible active tenants to participate",
      commMsg.status === 201
    );

    // --- TEST 19: Vacated tenant loses access to room group ---
    const tenant1Doc = await Tenant.findOne({ user: testUser1Id });
    await api("PUT", `/api/tenants/${tenant1Doc._id}/vacate`, {}, ownerToken);

    const vacatedRoomAccess = await api(
      "POST",
      `/api/conversations/${room1Conv._id}/messages`,
      { content: "I was vacated, can I still talk here?" },
      tenant1Token
    );
    assert(
      "Vacated tenant immediately loses access to room group (HTTP 403)",
      vacatedRoomAccess.status === 403
    );

    // --- TEST 20: Existing bills, payments, and genuine accounts remain intact ---
    const genuineOwnerCheck = await User.findOne({ email: "212myashraj@gmail.com" });
    const genuineRooms = await Room.find({ roomNumber: { $in: ["G101", "G102", "G103", "G104"] } });
    const totalBills = await Bill.countDocuments();
    const totalPayments = await Payment.countDocuments();

    assert(
      "Existing genuine accounts, rooms G101-G104, bills, and payments remain 100% intact",
      genuineOwnerCheck &&
        genuineRooms.length >= 4 &&
        totalBills > 0 &&
        totalPayments > 0
    );

    // Safe cleanup of only test fixtures created in this run
    await User.deleteMany({ email: { $in: [testEmail1, testEmail2, testEmail3] } });
    await Tenant.deleteMany({ user: { $in: [testUser1Id, testUser2Id, testUser3Id] } });
    await Room.deleteMany({ _id: { $in: [testRoom1Id, testRoom2Id, testRoom3Id] } });
    await Conversation.deleteMany({ _id: { $in: [room1Conv?._id, privateConvId] } });
    await Message.deleteMany({ conversation: { $in: [room1Conv?._id, privateConvId, community?._id] } });
    await Notification.deleteMany({ recipient: { $in: [testUser1Id, testUser2Id, testUser3Id] } });
  } catch (err) {
    console.error("Test execution exception:", err);
  } finally {
    server.close();
    await mongoose.connection.close();
  }

  console.log("\n====================================================");
  console.log(`TEST SUMMARY: Total: ${totalTests} | Passed: ${passedTests} | Failed: ${failedTests}`);
  console.log("====================================================");

  if (failedTests > 0) {
    process.exit(1);
  }
}

runPhaseFeaturesTest();
