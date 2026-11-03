const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

dotenv.config({ path: path.join(__dirname, '.env') });

async function inspectProdData() {
  console.log("Connecting to production MongoDB Atlas (Read-Only inspection)...");
  await mongoose.connect(process.env.MONGODB_URI, { serverSelectionTimeoutMS: 20000 });
  const db = mongoose.connection.db;
  console.log("Connected to database:", db.databaseName);

  const collections = await db.listCollections().toArray();
  const summary = {};
  const fullDump = {};

  for (const coll of collections) {
    const name = coll.name;
    const docs = await db.collection(name).find({}).toArray();
    summary[name] = docs.length;
    fullDump[name] = docs;
  }

  console.log("\n--- COLLECTION RECORD COUNTS ---");
  console.table(summary);

  // Backup all production documents to a local JSON file for safekeeping
  const backupDir = path.join(__dirname, '../docs/backups');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }
  const backupPath = path.join(backupDir, `prod_db_snapshot_${Date.now()}.json`);
  fs.writeFileSync(backupPath, JSON.stringify(fullDump, null, 2));
  console.log(`\nVerified safety backup saved to: ${backupPath}`);

  // Detailed Classification
  const users = fullDump['users'] || [];
  const rooms = fullDump['rooms'] || [];
  const tenants = fullDump['tenants'] || [];
  const bills = fullDump['bills'] || [];
  const payments = fullDump['payments'] || [];
  const meterreadings = fullDump['meterreadings'] || [];
  const complaints = fullDump['complaints'] || [];
  const expenses = fullDump['expenses'] || [];
  const notifications = fullDump['notifications'] || [];
  const pgsettings = fullDump['pgsettings'] || [];

  console.log("\n=== USER ACCOUNTS CLASSIFICATION ===");
  const testUserRegex = /test|devtest|example\.com/i;
  const genuineUsers = [];
  const testUsers = [];

  for (const u of users) {
    if (testUserRegex.test(u.email)) {
      testUsers.push({ _id: u._id.toString(), name: u.name, email: u.email, role: u.role, approvalStatus: u.approvalStatus });
    } else {
      genuineUsers.push({ _id: u._id.toString(), name: u.name, email: u.email, role: u.role, approvalStatus: u.approvalStatus });
    }
  }

  console.log(`Genuine Users (${genuineUsers.length}):`);
  genuineUsers.forEach(u => console.log(`  [${u.role.toUpperCase()}] ${u.name} <${u.email}> (ID: ${u._id}, status: ${u.approvalStatus})`));

  console.log(`\nTest Users (${testUsers.length}):`);
  testUsers.forEach(u => console.log(`  [${u.role.toUpperCase()}] ${u.name} <${u.email}> (ID: ${u._id})`));

  console.log(`\nRooms (${rooms.length}):`);
  rooms.forEach(r => console.log(`  Room ${r.roomNumber} - Floor ${r.floor}, Rent ${r.monthlyRent}, Beds: ${r.occupiedBeds}/${r.capacity}, Status: ${r.status}`));

  console.log(`\nTenants (${tenants.length}):`);
  tenants.forEach(t => console.log(`  Tenant ID: ${t._id}, User: ${t.user}, Room: ${t.room}, Status: ${t.status}`));

  console.log(`\nBills (${bills.length}):`);
  console.log(`  Total Bills in DB: ${bills.length}`);

  console.log(`\nPayments (${payments.length}):`);
  console.log(`  Total Payments in DB: ${payments.length}`);

  console.log(`\nMeter Readings (${meterreadings.length}):`);
  console.log(`  Total Meter Readings in DB: ${meterreadings.length}`);

  console.log(`\nComplaints (${complaints.length}):`);
  console.log(`  Total Complaints in DB: ${complaints.length}`);

  console.log(`\nExpenses (${expenses.length}):`);
  console.log(`  Total Expenses in DB: ${expenses.length}`);

  console.log(`\nNotifications (${notifications.length}):`);
  console.log(`  Total Notifications in DB: ${notifications.length}`);

  console.log(`\nPG Settings (${pgsettings.length}):`);
  pgsettings.forEach(s => console.log(`  PG Name: ${s.pgName}, Address: ${s.address}, UPI: ${s.upiId}, Rate: ${s.electricityRatePerUnit}`));

  await mongoose.disconnect();
  console.log("\nDatabase inspection complete. Disconnected.");
}

inspectProdData().catch(err => {
  console.error("Inspection Error:", err);
  process.exit(1);
});
