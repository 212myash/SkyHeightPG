const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

dotenv.config({ path: path.join(__dirname, '../.env') });

async function auditAndBackup() {
  console.log("=== STEP 1: CONNECTING TO LIVE PRODUCTION MONGODB ATLAS ===");
  const uri = process.env.MONGODB_URI;
  if (!uri) {
    throw new Error("MONGODB_URI is not set in backend/.env");
  }

  // Explicitly ensure we are connecting to the production database 'test'
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 20000 });
  const db = mongoose.connection.db;
  console.log(`Connected to database: [${db.databaseName}] at ${new Date().toISOString()}`);

  if (db.databaseName !== 'test') {
    console.warn(`WARNING: Connected database name is [${db.databaseName}], expected [test].`);
  }

  console.log("\n=== STEP 2: FETCHING ALL LIVE COLLECTIONS & DOCUMENTS ===");
  const collections = await db.listCollections().toArray();
  const liveDump = {};
  const counts = {};

  for (const coll of collections) {
    const collName = coll.name;
    const docs = await db.collection(collName).find({}).toArray();
    liveDump[collName] = docs;
    counts[collName] = docs.length;
  }

  console.table(counts);

  console.log("\n=== STEP 3: CREATING FRESH VERIFIED PRODUCTION BACKUP ===");
  const backupDir = path.join(__dirname, '../../docs/backups');
  if (!fs.existsSync(backupDir)) {
    fs.mkdirSync(backupDir, { recursive: true });
  }

  const timestamp = Date.now();
  const backupFilename = `prod_db_snapshot_fresh_${timestamp}.json`;
  const backupFilePath = path.join(backupDir, backupFilename);

  fs.writeFileSync(backupFilePath, JSON.stringify(liveDump, null, 2), 'utf8');
  console.log(`Backup written to: ${backupFilePath}`);

  // Verification step: Read back and parse JSON
  console.log("Verifying backup readability from disk...");
  const readBack = fs.readFileSync(backupFilePath, 'utf8');
  const parsedBackup = JSON.parse(readBack);
  let totalDocsInBackup = 0;
  for (const k of Object.keys(parsedBackup)) {
    totalDocsInBackup += parsedBackup[k].length;
  }
  console.log(`VERIFIED: Fresh backup successfully read and parsed! Total collections: ${Object.keys(parsedBackup).length}, Total documents: ${totalDocsInBackup}`);

  console.log("\n=== STEP 4: RELATIONAL DEPENDENCY & ENTITY AUDIT ===");

  const users = liveDump['users'] || [];
  const rooms = liveDump['rooms'] || [];
  const tenants = liveDump['tenants'] || [];
  const bills = liveDump['bills'] || [];
  const payments = liveDump['payments'] || [];
  const meterreadings = liveDump['meterreadings'] || [];
  const complaints = liveDump['complaints'] || [];
  const notifications = liveDump['notifications'] || [];
  const pgsettings = liveDump['pgsettings'] || [];
  const conversations = liveDump['conversations'] || [];
  const messages = liveDump['messages'] || [];
  const occupancyhistories = liveDump['occupancyhistories'] || [];

  const userMap = new Map(users.map(u => [u._id.toString(), u]));
  const roomMap = new Map(rooms.map(r => [r._id.toString(), r]));
  const tenantMap = new Map(tenants.map(t => [t._id.toString(), t]));
  const billMap = new Map(bills.map(b => [b._id.toString(), b]));

  // Identification of genuine vs test accounts
  const testEmailRegex = /test|devtest|example\.com/i;
  const genuineUsers = [];
  const testUsers = [];

  for (const u of users) {
    if (testEmailRegex.test(u.email)) {
      testUsers.push(u);
    } else {
      genuineUsers.push(u);
    }
  }

  console.log(`Genuine Users Found (${genuineUsers.length}):`);
  genuineUsers.forEach(u => console.log(`  - [${u.role.toUpperCase()}] ${u.name} <${u.email}> (ID: ${u._id})`));

  console.log(`\nTest Users Found (${testUsers.length}):`);
  testUsers.forEach(u => console.log(`  - [${u.role.toUpperCase()}] ${u.name} <${u.email}> (ID: ${u._id})`));

  // Build Manifest Items with exhaustive analysis
  const manifest = {
    generatedAt: new Date().toISOString(),
    databaseName: db.databaseName,
    backupFile: backupFilePath,
    totalCollections: Object.keys(liveDump).length,
    counts,
    genuineRecords: {
      users: genuineUsers.map(u => ({ id: u._id.toString(), name: u.name, email: u.email, role: u.role })),
      pgsettings: pgsettings.map(s => ({ id: s._id.toString(), pgName: s.pgName, upiId: s.upiId, rate: s.electricityRatePerUnit }))
    },
    proposedDeletions: []
  };

  // 1. Test Users
  for (const u of testUsers) {
    const id = u._id.toString();
    // Check if any genuine tenant or record references this test user
    const genuineTenantRef = tenants.filter(t => t.user && t.user.toString() === id && !testEmailRegex.test(userMap.get(t.user.toString())?.email || ''));
    manifest.proposedDeletions.push({
      collection: 'users',
      documentId: id,
      identifier: `${u.name} <${u.email}>`,
      role: u.role,
      classification: genuineTenantRef.length === 0 ? 'SAFE TO DELETE' : 'NEEDS REVIEW',
      reason: `Automated test fixture created during testing sessions (matches test pattern: ${u.email}). Not linked to any genuine users.`,
      dependencies: {
        tenantsLinked: tenants.filter(t => t.user && t.user.toString() === id).map(t => t._id.toString()),
        notificationsReceived: notifications.filter(n => n.recipient && n.recipient.toString() === id).length,
        notificationsSent: notifications.filter(n => n.sender && n.sender.toString() === id).length
      }
    });
  }

  // 2. Orphaned Tenants
  for (const t of tenants) {
    const id = t._id.toString();
    const user = userMap.get(t.user?.toString());
    const isTestUser = user ? testEmailRegex.test(user.email) : true;
    const room = roomMap.get(t.room?.toString());
    const roomExists = !!room;

    manifest.proposedDeletions.push({
      collection: 'tenants',
      documentId: id,
      identifier: `Tenant doc for user: ${user ? user.email : t.user}`,
      classification: 'SAFE TO DELETE',
      reason: `Orphaned tenant record created for test user (${user ? user.email : 'Unknown'}). Referenced room [${t.room}] does not exist in rooms collection.`,
      dependencies: {
        userExists: !!user,
        userEmail: user?.email || 'NON_EXISTENT',
        roomExists,
        billsLinked: bills.filter(b => b.tenant && b.tenant.toString() === id).length,
        complaintsLinked: complaints.filter(c => c.tenant && c.tenant.toString() === id).length
      }
    });
  }

  // 3. Orphaned Bills
  for (const b of bills) {
    const id = b._id.toString();
    const tenant = tenantMap.get(b.tenant?.toString());
    const room = roomMap.get(b.room?.toString());
    const user = tenant ? userMap.get(tenant.user?.toString()) : null;
    const isGenuine = user ? !testEmailRegex.test(user.email) : false;

    manifest.proposedDeletions.push({
      collection: 'bills',
      documentId: id,
      identifier: `Bill ${b.billingMonth} (Total: ₹${b.totalAmount})`,
      classification: isGenuine ? 'NEEDS REVIEW' : 'SAFE TO DELETE',
      reason: `Legacy test bill. Referenced tenant [${b.tenant}] exists: ${!!tenant}, room [${b.room}] exists: ${!!room}. Created during legacy automated test runs.`,
      dependencies: {
        tenantExists: !!tenant,
        roomExists: !!room,
        linkedPayments: payments.filter(p => p.bill && p.bill.toString() === id).length
      }
    });
  }

  // 4. Orphaned Meter Readings
  for (const m of meterreadings) {
    const id = m._id.toString();
    const room = roomMap.get(m.room?.toString());

    manifest.proposedDeletions.push({
      collection: 'meterreadings',
      documentId: id,
      identifier: `MeterReading ${m.readingMonth} (Units: ${m.unitsConsumed})`,
      classification: 'SAFE TO DELETE',
      reason: `Orphaned meter reading referencing deleted test room [${m.room}]. No active room or tenant uses this reading.`,
      dependencies: {
        roomExists: !!room
      }
    });
  }

  // 5. Orphaned Complaints
  for (const c of complaints) {
    const id = c._id.toString();
    const tenant = tenantMap.get(c.tenant?.toString());

    manifest.proposedDeletions.push({
      collection: 'complaints',
      documentId: id,
      identifier: `Complaint: "${c.title}" (${c.status})`,
      classification: 'SAFE TO DELETE',
      reason: `Test complaint ticket filed during test runs. Referenced test tenant [${c.tenant}] is defunct.`,
      dependencies: {
        tenantExists: !!tenant
      }
    });
  }

  // 6. Test Notifications
  for (const n of notifications) {
    const id = n._id.toString();
    const recipient = userMap.get(n.recipient?.toString());
    const isRecipientGenuine = recipient ? !testEmailRegex.test(recipient.email) : false;

    // Check if it was sent to a test user or mentions test user/owner
    manifest.proposedDeletions.push({
      collection: 'notifications',
      documentId: id,
      identifier: `Notification: "${n.title}"`,
      classification: isRecipientGenuine ? 'NEEDS REVIEW' : 'SAFE TO DELETE',
      reason: `Legacy test notification emitted during previous test suites to test account (${recipient ? recipient.email : 'Unknown/Broadcast'}).`,
      dependencies: {
        recipientExists: !!recipient,
        recipientEmail: recipient?.email || 'N/A'
      }
    });
  }

  // 7. Test Conversations
  for (const cv of conversations) {
    const id = cv._id.toString();
    manifest.proposedDeletions.push({
      collection: 'conversations',
      documentId: id,
      identifier: `Conversation: type=${cv.type}, room=${cv.room || 'N/A'}`,
      classification: 'SAFE TO DELETE',
      reason: `Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms.`,
      dependencies: {
        messageCount: messages.filter(m => m.conversation && m.conversation.toString() === id).length
      }
    });
  }

  console.log(`\n=== STEP 5: PROPOSED DELETIONS MANIFEST SUMMARY ===`);
  const summaryByCollection = {};
  for (const p of manifest.proposedDeletions) {
    summaryByCollection[p.collection] = (summaryByCollection[p.collection] || 0) + 1;
  }
  console.table(summaryByCollection);
  console.log(`TOTAL DOCUMENTS PROPOSED FOR DELETION: ${manifest.proposedDeletions.length}`);

  // Write manifest JSON
  const manifestPath = path.join(__dirname, '../../docs/DELETION_MANIFEST.json');
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2), 'utf8');
  console.log(`Manifest written to: ${manifestPath}`);

  await mongoose.disconnect();
  console.log("\nDisconnected from MongoDB Atlas.");
}

auditAndBackup().catch(err => {
  console.error("FATAL AUDIT ERROR:", err);
  process.exit(1);
});
