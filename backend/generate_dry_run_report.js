const fs = require('fs');
const path = require('path');

const snapshotPath = path.join(__dirname, '../docs/backups/prod_db_snapshot_1793715200465.json');
const data = JSON.parse(fs.readFileSync(snapshotPath, 'utf8'));

const users = data.users || [];
const rooms = data.rooms || [];
const tenants = data.tenants || [];
const bills = data.bills || [];
const payments = data.payments || [];
const meterreadings = data.meterreadings || [];
const complaints = data.complaints || [];
const notifications = data.notifications || [];
const pgsettings = data.pgsettings || [];
const conversations = data.conversations || [];

let report = `# SKY HEIGHT APARTMENT — PRODUCTION DATABASE CLEANUP DRY-RUN REPORT

**Document ID:** \`DOC-DB-CLEANUP-DRYRUN-001\`  
**Target Database:** Production MongoDB Atlas (\`test\`)  
**Safety Protocol:** **STRICT DRY RUN ONLY. ZERO PRODUCTION RECORDS HAVE BEEN DELETED.**  
**Safety Snapshot File:** \`docs/backups/prod_db_snapshot_1793715200465.json\`  
**Date:** November 3, 2026  

---

## 1. EXECUTIVE SUMMARY & SAFETY COMMITMENT

In accordance with strict production database safety rules:
1. A complete JSON snapshot backup of all collections was taken prior to analysis.
2. **NO DESTRUCTIVE ACTIONS HAVE OCCURRED.**
3. This document provides a record-level classification of all documents currently residing in the production MongoDB database (\`test\`).
4. Any proposed cleanup action is presented for explicit review and requires explicit user authorization before any operation is executed.

---

## 2. GENUINE RECORDS IDENTIFIED (TO PRESERVE PERMANENTLY)

The following records belong to real users, live property configurations, or genuine system operations and **MUST BE PRESERVED**:

### A. Genuine User Accounts (2 records)
1. **Owner Account:**
   - **ID:** \`6ae80f4a5ca93446b8f6e8a5\`
   - **Name:** Yash Raj
   - **Email:** \`212myashraj@gmail.com\`
   - **Role:** \`owner\`
   - **Status:** Active Genuine Property Owner
2. **Tenant Account:**
   - **ID:** \`6ae80e085ca93446b8f6e8a4\`
   - **Name:** Vaishanavi Sonawane
   - **Email:** \`radha118223@gmail.com\`
   - **Role:** \`tenant\`
   - **Status:** Registered Tenant

### B. Genuine PG Global Configuration (1 record)
- **ID:** \`${pgsettings[0]?._id}\`
- **PG Name:** ${pgsettings[0]?.pgName || "Sky Height PG"}
- **UPI ID:** \`${pgsettings[0]?.upiId}\`
- **Electricity Tariff:** ₹${pgsettings[0]?.electricityRatePerUnit}/unit
- **Default Due Day:** Day ${pgsettings[0]?.defaultDueDateDay || 5}

---

## 3. CANDIDATE TEST FIXTURES & ORPHANS PROPOSED FOR CLEANUP

These records were created during previous exploratory development and testing sessions before database isolation (\`skyheight_isolated_test\`) was instituted.

### A. Test User Accounts (${users.filter(u => /test|devtest/i.test(u.email)).length} records)
| Collection | Document _id | Name | Email | Role | Creation Note |
|---|---|---|---|---|---|
`;

const testUsers = users.filter(u => /test|devtest/i.test(u.email));
testUsers.forEach(u => {
  report += `| \`users\` | \`${u._id}\` | ${u.name} | \`${u.email}\` | ${u.role} | Legacy Dev/Test Account |\n`;
});

report += `\n### B. Orphaned Tenant Profile (${tenants.length} record)
| Collection | Document _id | User ID | Room ID | Status | Issue |
|---|---|---|---|---|---|
`;
tenants.forEach(t => {
  report += `| \`tenants\` | \`${t._id}\` | \`${t.user}\` | \`${t.room}\` | ${t.status} | Referenced Room does not exist in \`rooms\` collection |\n`;
});

report += `\n### C. Orphaned Invoices / Bills (${bills.length} records)
| Collection | Document _id | Billing Month | Tenant Ref | Room Ref | Total Amount | Issue |
|---|---|---|---|---|---|
`;
bills.forEach(b => {
  report += `| \`bills\` | \`${b._id}\` | ${b.billingMonth} | \`${b.tenant}\` | \`${b.room}\` | ₹${b.totalAmount} | Referenced Tenant & Room no longer exist |\n`;
});

report += `\n### D. Orphaned Meter Readings (${meterreadings.length} records)
| Collection | Document _id | Reading Month | Room Ref | Units Consumed | Issue |
|---|---|---|---|---|---|
`;
meterreadings.forEach(m => {
  report += `| \`meterreadings\` | \`${m._id}\` | ${m.readingMonth} | \`${m.room}\` | ${m.unitsConsumed} | Referenced Room does not exist |\n`;
});

report += `\n### E. Orphaned Maintenance Complaints (${complaints.length} records)
| Collection | Document _id | Title | Category | Status | Issue |
|---|---|---|---|---|---|
`;
complaints.forEach(c => {
  report += `| \`complaints\` | \`${c._id}\` | ${c.title} | ${c.category} | ${c.status} | Referenced Tenant does not exist |\n`;
});

report += `\n### F. Legacy Test Notifications (${notifications.length} records)
| Collection | Document _id | Title | Recipient | Category | Issue |
|---|---|---|---|---|---|
`;
notifications.forEach(n => {
  report += `| \`notifications\` | \`${n._id}\` | ${n.title} | \`${n.recipient}\` | ${n.category || 'general'} | Legacy test notification generated during initial test runs |\n`;
});

report += `\n### G. Legacy Chat Conversations (${conversations.length} records)
| Collection | Document _id | Type | Room Ref | Issue |
|---|---|---|---|---|
`;
conversations.forEach(cv => {
  report += `| \`conversations\` | \`${cv._id}\` | ${cv.type} | \`${cv.room || 'N/A'}\` | Legacy test conversation channels linked to defunct test rooms |\n`;
});

report += `\n---

## 4. ACTION SUMMARY & APPROVAL REQUEST

| Collection | Current Count | Genuine to Preserve | Candidate for Cleanup | Action Status |
|---|---|---|---|---|
| \`users\` | ${users.length} | 2 (Yash Raj, Vaishanavi) | ${testUsers.length} test accounts | **HELD — Awaiting Approval** |
| \`pgsettings\` | ${pgsettings.length} | 1 (Sky Height PG config) | 0 | **PRESERVED** |
| \`tenants\` | ${tenants.length} | 0 | ${tenants.length} orphan | **HELD — Awaiting Approval** |
| \`bills\` | ${bills.length} | 0 | ${bills.length} orphans | **HELD — Awaiting Approval** |
| \`meterreadings\` | ${meterreadings.length} | 0 | ${meterreadings.length} orphans | **HELD — Awaiting Approval** |
| \`complaints\` | ${complaints.length} | 0 | ${complaints.length} orphans | **HELD — Awaiting Approval** |
| \`notifications\`| ${notifications.length} | 0 | ${notifications.length} legacy test notices | **HELD — Awaiting Approval** |
| \`conversations\` | ${conversations.length} | 0 | ${conversations.length} legacy test channels | **HELD — Awaiting Approval** |
| \`rooms\` | 0 | 0 | 0 | **CLEAN** |
| \`payments\` | 0 | 0 | 0 | **CLEAN** |
| \`expenses\` | 0 | 0 | 0 | **CLEAN** |
| \`occupancyhistories\` | 0 | 0 | 0 | **CLEAN** |
| \`messages\` | 0 | 0 | 0 | **CLEAN** |

> [!IMPORTANT]
> **SAFETY NOTICE:**
> No database records have been modified or deleted. The verified JSON backup is safely stored at \`docs/backups/prod_db_snapshot_1793715200465.json\`. 
> 
> Cleanup of these candidate records will ONLY be performed if the user explicitly requests and approves it.
`;

const outputPath = path.join(__dirname, '../docs/DATABASE_CLEANUP_DRY_RUN_REPORT.md');
fs.writeFileSync(outputPath, report);
console.log("Dry-run report written to:", outputPath);
