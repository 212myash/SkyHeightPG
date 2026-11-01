const dns = require("dns");
dns.setServers(["8.8.8.8", "8.8.4.4"]);
require("dotenv").config({ path: __dirname + "/.env" });
const mongoose = require("mongoose");

const User = require("./models/User");
const Room = require("./models/Room");
const Tenant = require("./models/Tenant");
const MeterReading = require("./models/MeterReading");
const Bill = require("./models/Bill");
const Payment = require("./models/Payment");
const Expense = require("./models/Expense");
const Complaint = require("./models/Complaint");
const PGSettings = require("./models/PGSettings");

const runTests = async () => {
  console.log("==================================================");
  console.log("   SKY HEIGHT PG — PHASE 2 DATABASE ARCHITECTURE  ");
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
    console.log("Connecting to MongoDB Atlas...");
    await mongoose.connect(process.env.MONGODB_URI);
    console.log("Connected to MongoDB Atlas successfully.\n");

    // Ensure all model indexes are created in MongoDB Atlas
    await Room.syncIndexes();
    await Tenant.syncIndexes();
    await MeterReading.syncIndexes();
    await Bill.syncIndexes();
    await Payment.syncIndexes();
    await Expense.syncIndexes();
    await Complaint.syncIndexes();
    await PGSettings.syncIndexes();

    const timestamp = Date.now();

    // ----------------------------------------------------
    // TEST 1: User Model (Preserved)
    // ----------------------------------------------------
    const testOwner = await User.create({
      name: "Phase 2 Test Owner",
      email: `owner_${timestamp}@p2test.com`,
      password: "TestPassword123!",
      role: "owner"
    });
    assert(
      "1. User model creates and preserves authentication & role",
      testOwner && testOwner.role === "owner" && !testOwner.toJSON().password
    );

    const testTenantUser = await User.create({
      name: "Phase 2 Test Tenant",
      email: `tenant_${timestamp}@p2test.com`,
      password: "TestPassword123!",
      role: "tenant"
    });
    assert(
      "2. User model creates tenant account successfully",
      testTenantUser && testTenantUser.role === "tenant"
    );

    // ----------------------------------------------------
    // TEST 2: Room Model & Validation
    // ----------------------------------------------------
    const roomNum1 = `RM-${timestamp % 100000}`;
    const room1 = await Room.create({
      roomNumber: roomNum1,
      floor: 1,
      roomType: "double",
      monthlyRent: 8500,
      capacity: 2,
      amenities: ["AC", "Geyser", "WiFi"]
    });
    assert(
      "3. Room model creates valid room with default available status",
      room1 && room1.roomNumber === roomNum1 && room1.status === "available"
    );

    // Test Room required fields
    let roomMissingError = false;
    try {
      await Room.create({ floor: 1 });
    } catch {
      roomMissingError = true;
    }
    assert("4. Room validates required fields (roomNumber, monthlyRent, capacity)", roomMissingError);

    // Test Room invalid enum
    let invalidRoomTypeError = false;
    try {
      await Room.create({
        roomNumber: `INV-${timestamp}`,
        floor: 1,
        monthlyRent: 5000,
        roomType: "palace" // Invalid enum
      });
    } catch {
      invalidRoomTypeError = true;
    }
    assert("5. Room rejects invalid roomType enum", invalidRoomTypeError);

    // Test Room negative floor / rent
    let negativeFloorError = false;
    try {
      await Room.create({
        roomNumber: `NEG-${timestamp}`,
        floor: -2,
        monthlyRent: 5000
      });
    } catch {
      negativeFloorError = true;
    }
    assert("6. Room rejects negative floor", negativeFloorError);

    // Test Duplicate Room Number
    let duplicateRoomError = false;
    try {
      await Room.create({
        roomNumber: roomNum1,
        floor: 2,
        monthlyRent: 9000
      });
    } catch (err) {
      duplicateRoomError = err.code === 11000 || /duplicate/i.test(err.message);
    }
    assert("7. Duplicate room number is rejected by unique index (code 11000)", duplicateRoomError);

    // ----------------------------------------------------
    // TEST 3: Tenant Model & Relationships
    // ----------------------------------------------------
    const tenant1 = await Tenant.create({
      user: testTenantUser._id,
      room: room1._id,
      fullName: "Phase 2 Tenant Name",
      phone: "+919876543210",
      email: testTenantUser.email,
      monthlyRent: 8500,
      securityDeposit: 10000,
      assignedBed: "Bed 1",
      emergencyContact: {
        name: "Father Name",
        phone: "+919811122233",
        relation: "Father"
      }
    });
    assert(
      "8. Tenant model creates valid tenant linked to User and Room",
      tenant1 && tenant1.fullName === "Phase 2 Tenant Name" && tenant1.room.equals(room1._id)
    );

    // Test Tenant invalid email
    let tenantInvalidEmail = false;
    try {
      await Tenant.create({
        user: testTenantUser._id,
        room: room1._id,
        fullName: "Bad Email Tenant",
        phone: "+919876543210",
        email: "not-an-email",
        monthlyRent: 8000
      });
    } catch {
      tenantInvalidEmail = true;
    }
    assert("9. Tenant validates valid email format", tenantInvalidEmail);

    // Test Tenant Population (Relationship Verification)
    const populatedTenant = await Tenant.findById(tenant1._id)
      .populate("user", "name email role")
      .populate("room", "roomNumber floor roomType monthlyRent");
    assert(
      "10. Tenant population verifies User and Room foreign relationships",
      populatedTenant &&
        populatedTenant.user &&
        populatedTenant.user.name === "Phase 2 Test Tenant" &&
        populatedTenant.room &&
        populatedTenant.room.roomNumber === roomNum1
    );

    // ----------------------------------------------------
    // TEST 4: MeterReading Model & Calculations
    // ----------------------------------------------------
    const readingMonth = "2026-11";
    const meter1 = await MeterReading.create({
      room: room1._id,
      previousReading: 1250,
      currentReading: 1400,
      ratePerUnit: 12,
      readingMonth: readingMonth,
      recordedBy: testOwner._id,
      remarks: "November reading"
    });

    assert(
      "11. MeterReading calculates unitsConsumed (1400 - 1250 = 150)",
      meter1 && meter1.unitsConsumed === 150
    );
    assert(
      "12. MeterReading calculates electricityAmount (150 * 12 = 1800)",
      meter1 && meter1.electricityAmount === 1800
    );

    // Test Current Reading Lower than Previous Reading
    let meterLowerError = false;
    try {
      await MeterReading.create({
        room: room1._id,
        previousReading: 1500,
        currentReading: 1200, // Invalid: lower than previous
        ratePerUnit: 12,
        readingMonth: "2026-12",
        recordedBy: testOwner._id
      });
    } catch (err) {
      meterLowerError = /lower than previous/i.test(err.message);
    }
    assert("13. MeterReading rejects current reading lower than previous reading", meterLowerError);

    // Test Duplicate Meter Reading for same room and month
    let duplicateMeterError = false;
    try {
      await MeterReading.create({
        room: room1._id,
        previousReading: 1400,
        currentReading: 1500,
        ratePerUnit: 12,
        readingMonth: readingMonth, // Duplicate room + month
        recordedBy: testOwner._id
      });
    } catch (err) {
      duplicateMeterError = err.code === 11000 || /duplicate/i.test(err.message);
    }
    assert(
      "14. Duplicate meter reading for same room and month is rejected (unique index)",
      duplicateMeterError
    );

    // ----------------------------------------------------
    // TEST 5: Bill Model & Calculations
    // ----------------------------------------------------
    const dueDate = new Date();
    dueDate.setDate(dueDate.getDate() + 5);

    const bill1 = await Bill.create({
      tenant: tenant1._id,
      room: room1._id,
      billingMonth: readingMonth,
      monthlyRent: 8500,
      electricityAmount: 1800,
      otherCharges: 200,
      adjustments: 500,
      dueDate: dueDate,
      previousReading: 1250,
      currentReading: 1400,
      unitsConsumed: 150,
      meterReading: meter1._id
    });

    // Calculation: 8500 + 1800 + 200 - 500 = 10000
    assert(
      "15. Bill automatically computes totalAmount (8500 + 1800 + 200 - 500 = 10000)",
      bill1 && bill1.totalAmount === 10000
    );

    // Test Duplicate Bill for same tenant and month
    let duplicateBillError = false;
    try {
      await Bill.create({
        tenant: tenant1._id,
        room: room1._id,
        billingMonth: readingMonth, // Duplicate tenant + month
        monthlyRent: 8500,
        dueDate: dueDate
      });
    } catch (err) {
      duplicateBillError = err.code === 11000 || /duplicate/i.test(err.message);
    }
    assert(
      "16. Duplicate bill for same tenant and billing month is rejected (unique index)",
      duplicateBillError
    );

    // Test Bill Population
    const populatedBill = await Bill.findById(bill1._id)
      .populate("tenant", "fullName phone email")
      .populate("room", "roomNumber floor")
      .populate("meterReading");
    assert(
      "17. Bill population verifies relationships to Tenant, Room, and MeterReading",
      populatedBill &&
        populatedBill.tenant.fullName === "Phase 2 Tenant Name" &&
        populatedBill.room.roomNumber === roomNum1 &&
        populatedBill.meterReading.unitsConsumed === 150
    );

    // ----------------------------------------------------
    // TEST 6: Payment Model & Relationships
    // ----------------------------------------------------
    const payment1 = await Payment.create({
      tenant: tenant1._id,
      bill: bill1._id,
      amount: 10000,
      paymentMethod: "upi",
      transactionReference: "UPI-TXN-123456789",
      verificationStatus: "verified",
      verifiedBy: testOwner._id,
      verifiedAt: new Date(),
      notes: "Google Pay payment verified"
    });

    assert(
      "18. Payment model records payment linked to Tenant and Bill",
      payment1 && payment1.amount === 10000 && payment1.paymentMethod === "upi"
    );

    const populatedPayment = await Payment.findById(payment1._id)
      .populate("tenant", "fullName phone")
      .populate("bill", "billingMonth totalAmount paymentStatus")
      .populate("verifiedBy", "name email");
    assert(
      "19. Payment population verifies Tenant, Bill, and Owner verifiedBy relationships",
      populatedPayment &&
        populatedPayment.tenant.fullName === "Phase 2 Tenant Name" &&
        populatedPayment.bill.totalAmount === 10000 &&
        populatedPayment.verifiedBy.name === "Phase 2 Test Owner"
    );

    // ----------------------------------------------------
    // TEST 7: Expense Model
    // ----------------------------------------------------
    const expense1 = await Expense.create({
      title: "Plumbing repair on 1st Floor",
      category: "repairs",
      amount: 750,
      recordedBy: testOwner._id,
      description: "Fixed leaking tap in common washroom"
    });
    assert(
      "20. Expense model creates valid expense linked to owner",
      expense1 && expense1.amount === 750 && expense1.category === "repairs"
    );

    let invalidExpenseCategory = false;
    try {
      await Expense.create({
        title: "Test",
        category: "cryptocurrency", // Invalid category
        amount: 500,
        recordedBy: testOwner._id
      });
    } catch {
      invalidExpenseCategory = true;
    }
    assert("21. Expense validates category enum", invalidExpenseCategory);

    // ----------------------------------------------------
    // TEST 8: Complaint Model & Workflow
    // ----------------------------------------------------
    const complaint1 = await Complaint.create({
      tenant: tenant1._id,
      room: room1._id,
      title: "WiFi speed is slow in Room",
      description: "Getting disconnected during work calls",
      category: "wifi",
      priority: "high"
    });
    assert(
      "22. Complaint model creates open complaint linked to Tenant and Room",
      complaint1 && complaint1.status === "open" && complaint1.priority === "high"
    );

    complaint1.status = "resolved";
    complaint1.resolution = "Replaced router in corridor";
    complaint1.resolvedBy = testOwner._id;
    complaint1.resolvedAt = new Date();
    await complaint1.save();

    const populatedComplaint = await Complaint.findById(complaint1._id)
      .populate("tenant", "fullName phone")
      .populate("room", "roomNumber")
      .populate("resolvedBy", "name");
    assert(
      "23. Complaint resolution updates and verifies resolvedBy relationship",
      populatedComplaint &&
        populatedComplaint.status === "resolved" &&
        populatedComplaint.resolvedBy.name === "Phase 2 Test Owner"
    );

    // ----------------------------------------------------
    // TEST 9: PGSettings Model (Singleton)
    // ----------------------------------------------------
    const settings = await PGSettings.getSettings();
    assert(
      "24. PGSettings singleton helper returns initialized configuration",
      settings && settings.pgName === "Sky Height PG" && settings.electricityRatePerUnit >= 0
    );

    settings.electricityRatePerUnit = 11.5;
    settings.upiId = "skyheight@icici";
    await settings.save();

    const updatedSettings = await PGSettings.getSettings();
    assert(
      "25. PGSettings persists configurable electricity rate and UPI ID",
      updatedSettings.electricityRatePerUnit === 11.5 && updatedSettings.upiId === "skyheight@icici"
    );

    // Clean up test records
    await Payment.findByIdAndDelete(payment1._id);
    await Bill.findByIdAndDelete(bill1._id);
    await MeterReading.findByIdAndDelete(meter1._id);
    await Complaint.findByIdAndDelete(complaint1._id);
    await Expense.findByIdAndDelete(expense1._id);
    await Tenant.findByIdAndDelete(tenant1._id);
    await Room.findByIdAndDelete(room1._id);
    await User.findByIdAndDelete(testOwner._id);
    await User.findByIdAndDelete(testTenantUser._id);
    console.log("\nCleaned up all Phase 2 test documents successfully.");

    console.log("\n--------------------------------------------------");
    console.log(`TOTAL PHASE 2 TESTS: ${passed + failed}`);
    console.log(`PASSED:              ${passed}`);
    console.log(`FAILED:              ${failed}`);
    console.log("--------------------------------------------------");

    await mongoose.disconnect();

    if (failed === 0) {
      console.log("\nALL 25 PHASE 2 DATABASE ARCHITECTURE TESTS PASSED PERFECTLY!\n");
      process.exit(0);
    } else {
      console.error(`\n${failed} TEST(S) FAILED.\n`);
      process.exit(1);
    }
  } catch (error) {
    console.error("Test execution failed:", error);
    await mongoose.disconnect();
    process.exit(1);
  }
};

runTests();
