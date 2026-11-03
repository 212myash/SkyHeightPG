const dns = require("dns");
dns.setServers(["8.8.8.8", "8.8.4.4"]);
require("dotenv").config();

const mongoose = require("mongoose");
const User = require("./models/User");
const Room = require("./models/Room");
const Tenant = require("./models/Tenant");
const PGSettings = require("./models/PGSettings");
const OccupancyHistory = require("./models/OccupancyHistory");

async function seed() {
  const baseUri = process.env.MONGODB_URI;
  const isolatedUri = baseUri.endsWith("/")
    ? baseUri + "skyheight_isolated_test"
    : baseUri + "/skyheight_isolated_test";

  console.log("Connecting to isolated test database...");
  await mongoose.connect(isolatedUri, { serverSelectionTimeoutMS: 5000 });
  console.log("Connected to:", mongoose.connection.name);

  // Clean all collections in the isolated test DB
  console.log("Clearing isolated test database collections...");
  const collections = await mongoose.connection.db.listCollections().toArray();
  for (const c of collections) {
    await mongoose.connection.db.dropCollection(c.name);
    console.log(`Dropped collection: ${c.name}`);
  }

  // 1. Settings
  console.log("Seeding default PG settings...");
  await PGSettings.create({
    pgName: "Sky Height PG (Isolated Test)",
    electricityRatePerUnit: 10,
    defaultDueDateDay: 5,
    upiId: "testowner@upi"
  });

  // 2. Owner
  console.log("Creating Test Owner account...");
  const owner = await User.create({
    name: "Test Owner",
    email: "testowner@skyheightpg.com",
    password: "Password@123",
    phone: "9876543210",
    role: "owner",
    approvalStatus: "approved",
    isActive: true
  });

  // 3. Rooms
  console.log("Creating Rooms (101, 102)...");
  const room101 = await Room.create({
    roomNumber: "101",
    floor: 1,
    roomType: "double",
    monthlyRent: 6000,
    capacity: 2,
    maxOccupancy: 2,
    occupiedBeds: 0,
    status: "available",
    isActive: true
  });

  const room102 = await Room.create({
    roomNumber: "102",
    floor: 1,
    roomType: "single",
    monthlyRent: 8000,
    capacity: 1,
    maxOccupancy: 1,
    occupiedBeds: 0,
    status: "available",
    isActive: true
  });

  // 4. Test Tenant 1 (Active in Room 101)
  console.log("Creating Test Tenant 1 (Active in Room 101)...");
  const tenantUser1 = await User.create({
    name: "Aman Sharma",
    email: "aman@skyheightpg.com",
    password: "Password@123",
    phone: "9876543211",
    role: "tenant",
    approvalStatus: "approved",
    approvedBy: owner._id,
    approvedAt: new Date(),
    isActive: true
  });

  const tenant1 = await Tenant.create({
    user: tenantUser1._id,
    room: room101._id,
    fullName: "Aman Sharma",
    phone: "9876543211",
    email: "aman@skyheightpg.com",
    monthlyRent: 6000,
    securityDeposit: 6000,
    assignedBed: "Bed 1",
    joiningDate: new Date(),
    status: "active",
    approvalStatus: "approved"
  });

  room101.occupiedBeds = 1;
  await room101.save();

  await OccupancyHistory.create({
    tenant: tenant1._id,
    room: room101._id,
    roomNumber: "101",
    joiningDate: tenant1.joiningDate,
    occupancyStatus: "active",
    monthlyRentSnapshot: 6000,
    reason: "Initial assignment",
    recordedBy: owner._id
  });

  // 5. Pending Applicant (Awaiting approval)
  console.log("Creating Pending Registration Applicant...");
  const applicantUser = await User.create({
    name: "Rohan Verma",
    email: "rohan@skyheightpg.com",
    password: "Password@123",
    phone: "9876543212",
    role: "tenant",
    approvalStatus: "pending",
    isActive: true
  });

  await Tenant.create({
    user: applicantUser._id,
    room: null,
    fullName: "Rohan Verma",
    phone: "9876543212",
    email: "rohan@skyheightpg.com",
    monthlyRent: 0,
    securityDeposit: 0,
    status: "pending_allocation",
    approvalStatus: "pending"
  });

  console.log("\nIsolated test database seeded successfully!");
  console.log("------------------------------------------");
  console.log("Owner Login:      testowner@skyheightpg.com / Password@123");
  console.log("Tenant 1 Login:   aman@skyheightpg.com / Password@123 (Room 101)");
  console.log("Applicant Login:  rohan@skyheightpg.com / Password@123 (Pending)");
  console.log("------------------------------------------\n");

  await mongoose.disconnect();
}

seed().catch(err => {
  console.error("Seed error:", err);
  process.exit(1);
});
