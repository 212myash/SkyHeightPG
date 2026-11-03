const dns = require('dns');
dns.setServers(['8.8.8.8', '8.8.4.4']);

const mongoose = require('mongoose');
const dotenv = require('dotenv');
const path = require('path');
const fs = require('fs');

dotenv.config({ path: path.join(__dirname, '../.env') });

async function executeCleanup() {
  console.log("=== EXECUTE APPROVED PRODUCTION CLEANUP ===");

  const manifestPath = path.join(__dirname, '../../docs/DELETION_MANIFEST.json');
  if (!fs.existsSync(manifestPath)) {
    throw new Error("Deletion manifest not found at " + manifestPath);
  }

  const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

  // Ensure backup file exists and is readable
  if (!fs.existsSync(manifest.backupFile)) {
    throw new Error("FATAL: Required backup file does not exist: " + manifest.backupFile);
  }
  const backupCheck = JSON.parse(fs.readFileSync(manifest.backupFile, 'utf8'));
  console.log(`Verified backup file exists and is valid JSON (${Object.keys(backupCheck).length} collections).`);

  const uri = process.env.MONGODB_URI;
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 20000 });
  const db = mongoose.connection.db;
  console.log(`Connected to: [${db.databaseName}]`);

  if (db.databaseName !== 'test') {
    throw new Error("SAFETY ABORT: Database name is not 'test'. Aborting.");
  }

  // Group IDs by collection
  const deletionsByColl = {};
  for (const item of manifest.proposedDeletions) {
    if (!deletionsByColl[item.collection]) {
      deletionsByColl[item.collection] = [];
    }
    deletionsByColl[item.collection].push(new mongoose.Types.ObjectId(item.documentId));
  }

  console.log("\nDocument IDs to delete by collection:");
  for (const [coll, ids] of Object.entries(deletionsByColl)) {
    console.log(`  - ${coll}: ${ids.length} documents`);
  }

  // Safe ordered deletion
  const executionResults = {};
  for (const [collName, ids] of Object.entries(deletionsByColl)) {
    console.log(`Deleting ${ids.length} approved documents from collection: [${collName}]...`);
    const res = await db.collection(collName).deleteMany({ _id: { $in: ids } });
    executionResults[collName] = {
      requested: ids.length,
      deletedCount: res.deletedCount
    };
    console.log(`  -> Deleted: ${res.deletedCount} documents`);
  }

  console.log("\n=== VERIFYING PRESERVED GENUINE RECORDS ===");
  const users = await db.collection('users').find({}).toArray();
  const pgsettings = await db.collection('pgsettings').find({}).toArray();

  console.log(`Remaining Users (${users.length}):`);
  users.forEach(u => console.log(`  - [${u.role.toUpperCase()}] ${u.name} <${u.email}> (ID: ${u._id})`));

  console.log(`Remaining PG Settings (${pgsettings.length}):`);
  pgsettings.forEach(s => console.log(`  - ${s.pgName} | UPI: ${s.upiId} | Rate: ₹${s.electricityRatePerUnit}/unit`));

  console.log("\n=== POST-CLEANUP COLLECTION RECORD COUNTS ===");
  const collections = await db.listCollections().toArray();
  const afterCounts = {};
  for (const coll of collections) {
    afterCounts[coll.name] = await db.collection(coll.name).countDocuments({});
  }
  console.table(afterCounts);

  await mongoose.disconnect();
  console.log("Disconnected from MongoDB. Cleanup execution complete.");
}

// Only run if called directly with --execute flag
if (process.argv.includes('--execute')) {
  executeCleanup().catch(err => {
    console.error("CLEANUP EXECUTION FAILED:", err);
    process.exit(1);
  });
} else {
  console.log("Dry run only. Pass '--execute' to perform the approved deletion.");
}
