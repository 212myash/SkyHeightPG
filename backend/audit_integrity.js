const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../backend/.env') });

async function checkIntegrity() {
  await mongoose.connect(process.env.MONGODB_URI, { serverSelectionTimeoutMS: 15000 });
  const db = mongoose.connection.db;

  const users = await db.collection('users').find({}).toArray();
  const rooms = await db.collection('rooms').find({}).toArray();
  const tenants = await db.collection('tenants').find({}).toArray();
  const bills = await db.collection('bills').find({}).toArray();
  const payments = await db.collection('payments').find({}).toArray();
  const meterreadings = await db.collection('meterreadings').find({}).toArray();
  const complaints = await db.collection('complaints').find({}).toArray();

  const userMap = new Map(users.map(u => [u._id.toString(), u]));
  const roomMap = new Map(rooms.map(r => [r._id.toString(), r]));
  const tenantMap = new Map(tenants.map(t => [t._id.toString(), t]));
  const billMap = new Map(bills.map(b => [b._id.toString(), b]));

  console.log('=== DATA INTEGRITY ANALYSIS ===\n');

  // Check Tenants
  console.log('--- Tenant Integrity ---');
  let tenantOrphans = 0;
  for (const t of tenants) {
    const userExists = userMap.has(t.user?.toString());
    const roomExists = roomMap.has(t.room?.toString());
    if (!userExists || !roomExists) {
      tenantOrphans++;
      console.log(`[ORPHAN] Tenant ${t._id}: userExists=${userExists} (user=${t.user}), roomExists=${roomExists} (room=${t.room})`);
    }
  }
  console.log(`Total tenants: ${tenants.length}, Orphans: ${tenantOrphans}`);

  // Check Bills
  console.log('\n--- Bill Integrity ---');
  let billOrphans = 0;
  for (const b of bills) {
    const tenantExists = tenantMap.has(b.tenant?.toString());
    const roomExists = roomMap.has(b.room?.toString());
    if (!tenantExists || !roomExists) {
      billOrphans++;
      console.log(`[ORPHAN] Bill ${b._id}: tenantExists=${tenantExists} (tenant=${b.tenant}), roomExists=${roomExists} (room=${b.room})`);
    }
  }
  console.log(`Total bills: ${bills.length}, Orphans: ${billOrphans}`);

  // Check Payments
  console.log('\n--- Payment Integrity ---');
  let paymentOrphans = 0;
  for (const p of payments) {
    const billExists = billMap.has(p.bill?.toString());
    const tenantExists = tenantMap.has(p.tenant?.toString());
    if (!billExists || !tenantExists) {
      paymentOrphans++;
      console.log(`[ORPHAN] Payment ${p._id}: billExists=${billExists} (bill=${p.bill}), tenantExists=${tenantExists} (tenant=${p.tenant})`);
    }
  }
  console.log(`Total payments: ${payments.length}, Orphans: ${paymentOrphans}`);

  // Check Meter Readings
  console.log('\n--- Meter Reading Integrity ---');
  let meterOrphans = 0;
  for (const m of meterreadings) {
    const roomExists = roomMap.has(m.room?.toString());
    if (!roomExists) {
      meterOrphans++;
      console.log(`[ORPHAN] MeterReading ${m._id}: roomExists=${roomExists} (room=${m.room})`);
    }
  }
  console.log(`Total meter readings: ${meterreadings.length}, Orphans: ${meterOrphans}`);

  // Check Complaints
  console.log('\n--- Complaint Integrity ---');
  let complaintOrphans = 0;
  for (const c of complaints) {
    const tenantExists = tenantMap.has(c.tenant?.toString());
    if (!tenantExists) {
      complaintOrphans++;
      console.log(`[ORPHAN] Complaint ${c._id}: tenantExists=${tenantExists} (tenant=${c.tenant})`);
    }
  }
  console.log(`Total complaints: ${complaints.length}, Orphans: ${complaintOrphans}`);

  // Classify Genuine vs Test Records (Option B Dry Run)
  console.log('\n=== OPTION B CLEANUP DRY-RUN REPORT ===');
  const testUserRegex = /test|devtest/i;
  const testRoomRegex = /^R\d+-\d+/i;

  const genuineUsers = users.filter(u => !testUserRegex.test(u.email));
  const testUsers = users.filter(u => testUserRegex.test(u.email));

  const genuineRooms = rooms.filter(r => !testRoomRegex.test(r.roomNumber));
  const testRooms = rooms.filter(r => testRoomRegex.test(r.roomNumber));

  console.log(`\nGENUINE ACCOUNTS TO PRESERVE (${genuineUsers.length}):`);
  genuineUsers.forEach(u => console.log(`  - [${u.role.toUpperCase()}] ${u.name} <${u.email}> (ID: ${u._id})`));

  console.log(`\nGENUINE ROOMS TO PRESERVE (${genuineRooms.length}):`);
  genuineRooms.forEach(r => console.log(`  - Room ${r.roomNumber} (Floor ${r.floor}, Cap ${r.capacity}, Status: ${r.status})`));

  console.log(`\nTEST / DUMMY FIXTURES ELIGIBLE FOR REMOVAL (DRY RUN ONLY):`);
  console.log(`  - Test Users: ${testUsers.length}`);
  testUsers.forEach(u => console.log(`      * ${u.name} <${u.email}>`));
  console.log(`  - Test Rooms: ${testRooms.length}`);
  testRooms.forEach(r => console.log(`      * Room ${r.roomNumber}`));

  await mongoose.disconnect();
}

checkIntegrity().catch(err => {
  console.error(err);
  process.exit(1);
});
