const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');

dotenv.config({ path: path.join(__dirname, '../backend/.env') });

const mongoUri = process.env.MONGODB_URI;

if (!mongoUri) {
  console.error('ERROR: MONGODB_URI not found in backend/.env');
  process.exit(1);
}

async function auditDatabase() {
  console.log('Connecting to MongoDB Atlas...');
  await mongoose.connect(mongoUri, { serverSelectionTimeoutMS: 15000 });
  console.log('Connected to database:', mongoose.connection.name);

  const collections = await mongoose.connection.db.listCollections().toArray();
  console.log('\n--- Collections Found ---');
  for (const c of collections) {
    const count = await mongoose.connection.db.collection(c.name).countDocuments();
    console.log(`- ${c.name}: ${count} document(s)`);
  }

  // Inspect Users
  console.log('\n--- Users Audit ---');
  const users = await mongoose.connection.db.collection('users').find({}).toArray();
  for (const u of users) {
    console.log(`User: ID=${u._id}, Name="${u.name}", Email="${u.email}", Role="${u.role}", Active=${u.isActive}, CreatedAt=${u.createdAt}`);
  }

  // Inspect Rooms
  console.log('\n--- Rooms Audit ---');
  const rooms = await mongoose.connection.db.collection('rooms').find({}).toArray();
  for (const r of rooms) {
    console.log(`Room: ID=${r._id}, Number="${r.roomNumber}", Floor=${r.floor}, Capacity=${r.capacity}, Occupied=${r.occupiedBeds}, Status="${r.status}", Rent=${r.rentPerBed}`);
  }

  // Inspect Tenants
  console.log('\n--- Tenants Audit ---');
  const tenants = await mongoose.connection.db.collection('tenants').find({}).toArray();
  for (const t of tenants) {
    console.log(`Tenant: ID=${t._id}, UserID=${t.user}, RoomID=${t.room}, Bed=${t.bedNumber}, Status="${t.status}", Name="${t.name || t.fullName}"`);
  }

  // Inspect Bills
  console.log('\n--- Bills Audit ---');
  const bills = await mongoose.connection.db.collection('bills').find({}).toArray();
  for (const b of bills) {
    console.log(`Bill: ID=${b._id}, TenantID=${b.tenant}, RoomID=${b.room}, Month="${b.month}", TotalAmount=${b.totalAmount}, Status="${b.status}"`);
  }

  // Inspect Payments
  console.log('\n--- Payments Audit ---');
  const payments = await mongoose.connection.db.collection('payments').find({}).toArray();
  for (const p of payments) {
    console.log(`Payment: ID=${p._id}, BillID=${p.bill}, TenantID=${p.tenant}, Amount=${p.amount}, Status="${p.status}", Method="${p.method || p.paymentMethod}", Ref="${p.transactionRef || p.referenceId}"`);
  }

  // Inspect Meter Readings
  console.log('\n--- Meter Readings Audit ---');
  const meters = await mongoose.connection.db.collection('meterreadings').find({}).toArray();
  for (const m of meters) {
    console.log(`MeterReading: ID=${m._id}, RoomID=${m.room}, Month="${m.month}", Units=${m.unitsConsumed}, Status="${m.status}"`);
  }

  // Inspect Complaints
  console.log('\n--- Complaints Audit ---');
  const complaints = await mongoose.connection.db.collection('complaints').find({}).toArray();
  for (const c of complaints) {
    console.log(`Complaint: ID=${c._id}, TenantID=${c.tenant}, Title="${c.title}", Status="${c.status}", Category="${c.category}"`);
  }

  // Inspect Expenses
  console.log('\n--- Expenses Audit ---');
  const expenses = await mongoose.connection.db.collection('expenses').find({}).toArray();
  for (const e of expenses) {
    console.log(`Expense: ID=${e._id}, Title="${e.title}", Amount=${e.amount}, Date=${e.date}`);
  }

  // Inspect Settings
  console.log('\n--- Settings Audit ---');
  const settings = await mongoose.connection.db.collection('pgsettings').find({}).toArray();
  for (const s of settings) {
    console.log(`PGSettings: PGName="${s.pgName}", ElectricityRate=${s.electricityRatePerUnit}`);
  }

  await mongoose.disconnect();
  console.log('\nAudit complete and disconnected.');
}

auditDatabase().catch(err => {
  console.error('Audit failed:', err);
  process.exit(1);
});
