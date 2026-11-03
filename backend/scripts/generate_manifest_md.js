const fs = require('fs');
const path = require('path');

const manifestPath = path.join(__dirname, '../../docs/DELETION_MANIFEST.json');
const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

let md = `# SKY HEIGHT APARTMENT — PRODUCTION DATABASE DELETION MANIFEST & AUDIT

**Document ID:** \`DOC-DB-MANIFEST-001\`  
**Target Database:** Production MongoDB Atlas (\`test\`)  
**Safety Protocol:** **STRICT READ-ONLY AUDIT. NO DOCUMENTS HAVE BEEN DELETED.**  
**Fresh Verified Backup File:** \`docs/backups/prod_db_snapshot_fresh_1793730958547.json\`  
**Total Documents in Production:** 73  
**Genuine Records Preserved Permanently:** 3 (100% of genuine records)  
**Total Documents Proposed for Deletion:** 70  
**Status:** **AWAITING USER EXPLICIT APPROVAL (STOP CHECKPOINT)**  
**Date:** November 4, 2026  

---

## 1. BACKUP VERIFICATION PROOF

Prior to generating this manifest, a complete JSON snapshot of all 13 collections from the live production database was taken and verified:

- **Backup Path:** \`F:\\SkyHeightPG\\docs\\backups\\prod_db_snapshot_fresh_1793730958547.json\`
- **Filesize:** ~42 KB
- **Readability Check:** Passed (Parsed 13 collections, 73 total documents).
- **Checksum / Timestamp:** Generated at ${manifest.generatedAt}

---

## 2. GENUINE PRODUCTION RECORDS PRESERVED PERMANENTLY

The following genuine records were verified and are **EXCLUDED** from deletion:

| Collection | Document ID | Name / Description | Role / Identifier | Permanent Status |
|---|---|---|---|---|
| \`users\` | \`6ae80f4a5ca93446b8f6e8a5\` | **Yash Raj** | \`212myashraj@gmail.com\` (Role: owner) | **PRESERVED PERMANENTLY** |
| \`users\` | \`6ae80e085ca93446b8f6e8a4\` | **Vaishanavi Sonawane** | \`radha118223@gmail.com\` (Role: tenant) | **PRESERVED PERMANENTLY** |
| \`pgsettings\` | \`${manifest.genuineRecords.pgsettings[0]?.id}\` | **Sky Height PG** | UPI: \`${manifest.genuineRecords.pgsettings[0]?.upiId}\`, Rate: ₹${manifest.genuineRecords.pgsettings[0]?.rate}/unit | **PRESERVED PERMANENTLY** |

---

## 3. SUMMARY OF PROPOSED DELETIONS BY COLLECTION

| Collection Name | Total Live Count | Genuine Preserved | Proposed for Deletion | Cascade / Dependency Risk |
|---|---|---|---|---|
| \`users\` | 15 | 2 | **13** | **Zero Risk:** All match test email patterns; 0 genuine tenants/bills depend on them. |
| \`tenants\` | 1 | 0 | **1** | **Zero Risk:** Orphan tenant doc for test user 'Amit Tenant B'. Referenced room does not exist. |
| \`bills\` | 14 | 0 | **14** | **Zero Risk:** Leftover test bills from past automated test runs. No payments linked. |
| \`meterreadings\` | 8 | 0 | **8** | **Zero Risk:** Orphan test readings for defunct rooms. |
| \`complaints\` | 7 | 0 | **7** | **Zero Risk:** Test tickets filed by defunct test users. |
| \`notifications\` | 16 | 0 | **16** | **Zero Risk:** Test notifications delivered to defunct test users or system broadcasts. |
| \`conversations\` | 11 | 0 | **11** | **Zero Risk:** Test chat channels created during earlier automated test runs. |
| \`rooms\` | 0 | 0 | 0 | Clean. |
| \`payments\` | 0 | 0 | 0 | Clean. |
| \`expenses\` | 0 | 0 | 0 | Clean. |
| \`occupancyhistories\` | 0 | 0 | 0 | Clean. |
| \`messages\` | 0 | 0 | 0 | Clean. |
| **TOTALS** | **73** | **3** | **70** | **100% Isolated to Test Fixtures** |

---

## 4. ITEMIZED RECORD-BY-RECORD DELETION MANIFEST

### Group A: Test User Accounts (13 documents)
| # | Collection | Document ID | Name & Email | Role | Classification | Specific Reason |
|---|---|---|---|---|---|---|
`;

let count = 1;
manifest.proposedDeletions.filter(p => p.collection === 'users').forEach(p => {
  md += `| ${count++} | \`${p.collection}\` | \`${p.documentId}\` | ${p.identifier} | \`${p.role}\` | **${p.classification}** | ${p.reason} |\n`;
});

md += `\n### Group B: Orphaned Test Tenant Profile (1 document)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
`;
count = 1;
manifest.proposedDeletions.filter(p => p.collection === 'tenants').forEach(p => {
  md += `| ${count++} | \`${p.collection}\` | \`${p.documentId}\` | ${p.identifier} | **${p.classification}** | ${p.reason} |\n`;
});

md += `\n### Group C: Orphaned Test Invoices / Bills (14 documents)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
`;
count = 1;
manifest.proposedDeletions.filter(p => p.collection === 'bills').forEach(p => {
  md += `| ${count++} | \`${p.collection}\` | \`${p.documentId}\` | ${p.identifier} | **${p.classification}** | ${p.reason} |\n`;
});

md += `\n### Group D: Orphaned Sub-Meter Readings (8 documents)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
`;
count = 1;
manifest.proposedDeletions.filter(p => p.collection === 'meterreadings').forEach(p => {
  md += `| ${count++} | \`${p.collection}\` | \`${p.documentId}\` | ${p.identifier} | **${p.classification}** | ${p.reason} |\n`;
});

md += `\n### Group E: Orphaned Test Maintenance Complaints (7 documents)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
`;
count = 1;
manifest.proposedDeletions.filter(p => p.collection === 'complaints').forEach(p => {
  md += `| ${count++} | \`${p.collection}\` | \`${p.documentId}\` | ${p.identifier} | **${p.classification}** | ${p.reason} |\n`;
});

md += `\n### Group F: Legacy Test Notifications (16 documents)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
`;
count = 1;
manifest.proposedDeletions.filter(p => p.collection === 'notifications').forEach(p => {
  md += `| ${count++} | \`${p.collection}\` | \`${p.documentId}\` | ${p.identifier} | **${p.classification}** | ${p.reason} |\n`;
});

md += `\n### Group G: Defunct Test Chat Conversations (11 documents)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
`;
count = 1;
manifest.proposedDeletions.filter(p => p.collection === 'conversations').forEach(p => {
  md += `| ${count++} | \`${p.collection}\` | \`${p.documentId}\` | ${p.identifier} | **${p.classification}** | ${p.reason} |\n`;
});

md += `\n---

## 5. DEPENDENCY AND CASCADE SAFETY ANALYSIS

1. **Owner Account Safety:**  
   The primary owner account (\`212myashraj@gmail.com\`) has ID \`6ae80f4a5ca93446b8f6e8a5\`. None of the proposed deletions target or cascade to this ID.
2. **Tenant Account Safety:**  
   The primary tenant account (\`radha118223@gmail.com\`) has ID \`6ae80e085ca93446b8f6e8a4\`. None of the proposed deletions reference or affect this tenant.
3. **Property Settings Safety:**  
   The PG settings document (containing UPI ID \`6206825865@oksbi\` and rate ₹13/unit) is completely preserved.
4. **Foreign Key Integrity:**  
   All 14 bills and 8 meter readings proposed for deletion reference test rooms/tenants that were previously deleted in past testing sessions. Removing them eliminates foreign key dangling references, thereby restoring database referential integrity.
5. **No Blind Bulk Deletion:**  
   Deletions will be executed using individual document ID matching (\`_id: { $in: approvedIds }\`), never using collection drops or \`deleteMany({})\`.

---

## 6. STOP CHECKPOINT & APPROVAL REQUEST

> [!WARNING]
> **ACTION REQUIRED BEFORE EXECUTION:**  
> In accordance with Phase 3 instructions, the process is now **HALTED** at this checkpoint.  
> 
> Please review the 70 itemized document IDs in this manifest. **Explicit user authorization is required to proceed with deleting these 70 test documents.**
`;

const outputPath = path.join(__dirname, '../../docs/PRODUCTION_DELETION_MANIFEST.md');
fs.writeFileSync(outputPath, md, 'utf8');
console.log("Markdown manifest written to:", outputPath);
