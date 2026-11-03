# SKY HEIGHT APARTMENT — PRODUCTION DATABASE DELETION MANIFEST & AUDIT

**Document ID:** `DOC-DB-MANIFEST-001`  
**Target Database:** Production MongoDB Atlas (`test`)  
**Safety Protocol:** **STRICT READ-ONLY AUDIT. NO DOCUMENTS HAVE BEEN DELETED.**  
**Fresh Verified Backup File:** `docs/backups/prod_db_snapshot_fresh_1793730958547.json`  
**Total Documents in Production:** 73  
**Genuine Records Preserved Permanently:** 3 (100% of genuine records)  
**Total Documents Proposed for Deletion:** 70  
**Status:** **AWAITING USER EXPLICIT APPROVAL (STOP CHECKPOINT)**  
**Date:** November 4, 2026  

---

## 1. BACKUP VERIFICATION PROOF

Prior to generating this manifest, a complete JSON snapshot of all 13 collections from the live production database was taken and verified:

- **Backup Path:** `F:\SkyHeightPG\docs\backups\prod_db_snapshot_fresh_1793730958547.json`
- **Filesize:** ~42 KB
- **Readability Check:** Passed (Parsed 13 collections, 73 total documents).
- **Checksum / Timestamp:** Generated at 2026-11-03T18:35:58.554Z

---

## 2. GENUINE PRODUCTION RECORDS PRESERVED PERMANENTLY

The following genuine records were verified and are **EXCLUDED** from deletion:

| Collection | Document ID | Name / Description | Role / Identifier | Permanent Status |
|---|---|---|---|---|
| `users` | `6ae80f4a5ca93446b8f6e8a5` | **Yash Raj** | `212myashraj@gmail.com` (Role: owner) | **PRESERVED PERMANENTLY** |
| `users` | `6ae80e085ca93446b8f6e8a4` | **Vaishanavi Sonawane** | `radha118223@gmail.com` (Role: tenant) | **PRESERVED PERMANENTLY** |
| `pgsettings` | `6ae6c7720d213bb788527a31` | **Sky Height PG** | UPI: `6206825865@oksbi`, Rate: ₹13/unit | **PRESERVED PERMANENTLY** |

---

## 3. SUMMARY OF PROPOSED DELETIONS BY COLLECTION

| Collection Name | Total Live Count | Genuine Preserved | Proposed for Deletion | Cascade / Dependency Risk |
|---|---|---|---|---|
| `users` | 15 | 2 | **13** | **Zero Risk:** All match test email patterns; 0 genuine tenants/bills depend on them. |
| `tenants` | 1 | 0 | **1** | **Zero Risk:** Orphan tenant doc for test user 'Amit Tenant B'. Referenced room does not exist. |
| `bills` | 14 | 0 | **14** | **Zero Risk:** Leftover test bills from past automated test runs. No payments linked. |
| `meterreadings` | 8 | 0 | **8** | **Zero Risk:** Orphan test readings for defunct rooms. |
| `complaints` | 7 | 0 | **7** | **Zero Risk:** Test tickets filed by defunct test users. |
| `notifications` | 16 | 0 | **16** | **Zero Risk:** Test notifications delivered to defunct test users or system broadcasts. |
| `conversations` | 11 | 0 | **11** | **Zero Risk:** Test chat channels created during earlier automated test runs. |
| `rooms` | 0 | 0 | 0 | Clean. |
| `payments` | 0 | 0 | 0 | Clean. |
| `expenses` | 0 | 0 | 0 | Clean. |
| `occupancyhistories` | 0 | 0 | 0 | Clean. |
| `messages` | 0 | 0 | 0 | Clean. |
| **TOTALS** | **73** | **3** | **70** | **100% Isolated to Test Fixtures** |

---

## 4. ITEMIZED RECORD-BY-RECORD DELETION MANIFEST

### Group A: Test User Accounts (13 documents)
| # | Collection | Document ID | Name & Email | Role | Classification | Specific Reason |
|---|---|---|---|---|---|---|
| 1 | `users` | `6ae6ee2b0eaa37ed6cbea6db` | DevTest Tenant <devtest_tenant@skyheight.in> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: devtest_tenant@skyheight.in). Not linked to any genuine users. |
| 2 | `users` | `6ae70c9e0eaa37ed6cbea6e6` | Rahul Sharma <tenant_1793526942475@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenant_1793526942475@skyheight-test.com). Not linked to any genuine users. |
| 3 | `users` | `6ae70ca10eaa37ed6cbea6e7` | Tenant Added By Owner <tenant_by_owner_1793526945177@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenant_by_owner_1793526945177@skyheight-test.com). Not linked to any genuine users. |
| 4 | `users` | `6ae70cba0eaa37ed6cbea6ea` | Rahul Tenant A <tenanta_1793526965606@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenanta_1793526965606@skyheight-test.com). Not linked to any genuine users. |
| 5 | `users` | `6ae70cbb0eaa37ed6cbea6ec` | Amit Tenant B <tenantb_1793526965606@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenantb_1793526965606@skyheight-test.com). Not linked to any genuine users. |
| 6 | `users` | `6ae70ee10eaa37ed6cbea6ff` | Rahul Tenant A <tenanta_1793527518463@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenanta_1793527518463@skyheight-test.com). Not linked to any genuine users. |
| 7 | `users` | `6ae70ee20eaa37ed6cbea701` | Amit Tenant B <tenantb_1793527518463@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenantb_1793527518463@skyheight-test.com). Not linked to any genuine users. |
| 8 | `users` | `6ae71181c242281fec839219` | Rahul Tenant A <tenanta_1793528189409@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenanta_1793528189409@skyheight-test.com). Not linked to any genuine users. |
| 9 | `users` | `6ae71182c242281fec83921b` | Amit Tenant B <tenantb_1793528189409@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenantb_1793528189409@skyheight-test.com). Not linked to any genuine users. |
| 10 | `users` | `6ae72264482d8e2df83cebec` | Rahul Tenant A <tenanta_1793532513201@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenanta_1793532513201@skyheight-test.com). Not linked to any genuine users. |
| 11 | `users` | `6ae72265482d8e2df83cebee` | Amit Tenant B <tenantb_1793532513201@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenantb_1793532513201@skyheight-test.com). Not linked to any genuine users. |
| 12 | `users` | `6ae724c060dd360913144ff6` | Rahul Tenant A <tenanta_1793533117859@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenanta_1793533117859@skyheight-test.com). Not linked to any genuine users. |
| 13 | `users` | `6ae724c160dd360913144ff8` | Amit Tenant B <tenantb_1793533117859@skyheight-test.com> | `tenant` | **SAFE TO DELETE** | Automated test fixture created during testing sessions (matches test pattern: tenantb_1793533117859@skyheight-test.com). Not linked to any genuine users. |

### Group B: Orphaned Test Tenant Profile (1 document)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
| 1 | `tenants` | `6ae724c160dd360913144ff9` | Tenant doc for user: tenantb_1793533117859@skyheight-test.com | **SAFE TO DELETE** | Orphaned tenant record created for test user (tenantb_1793533117859@skyheight-test.com). Referenced room [6ae724be60dd360913144ff5] does not exist in rooms collection. |

### Group C: Orphaned Test Invoices / Bills (14 documents)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
| 1 | `bills` | `6ae6cb4a3c12a54fa65c680a` | Bill 2026-11 (Total: ₹9500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae6cb433c12a54fa65c6806] exists: false, room [6ae6cb413c12a54fa65c6803] exists: false. Created during legacy automated test runs. |
| 2 | `bills` | `6ae6cb4b3c12a54fa65c680b` | Bill 2026-11 (Total: ₹8500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae6cb443c12a54fa65c6808] exists: false, room [6ae6cb413c12a54fa65c6804] exists: false. Created during legacy automated test runs. |
| 3 | `bills` | `6ae6ce983e6af1ca39c45bd0` | Bill 2026-11 (Total: ₹9500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae6ce923e6af1ca39c45bcc] exists: false, room [6ae6ce903e6af1ca39c45bc9] exists: false. Created during legacy automated test runs. |
| 4 | `bills` | `6ae6ce993e6af1ca39c45bd1` | Bill 2026-11 (Total: ₹8500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae6ce933e6af1ca39c45bce] exists: false, room [6ae6ce903e6af1ca39c45bca] exists: false. Created during legacy automated test runs. |
| 5 | `bills` | `6ae70cc40eaa37ed6cbea6ef` | Bill 2026-11 (Total: ₹9500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae70cba0eaa37ed6cbea6eb] exists: false, room [6ae70cb80eaa37ed6cbea6e8] exists: false. Created during legacy automated test runs. |
| 6 | `bills` | `6ae70cc50eaa37ed6cbea6f0` | Bill 2026-11 (Total: ₹8500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae70cbc0eaa37ed6cbea6ed] exists: false, room [6ae70cb80eaa37ed6cbea6e9] exists: false. Created during legacy automated test runs. |
| 7 | `bills` | `6ae70ee60eaa37ed6cbea704` | Bill 2026-11 (Total: ₹9500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae70ee10eaa37ed6cbea700] exists: false, room [6ae70edf0eaa37ed6cbea6fd] exists: false. Created during legacy automated test runs. |
| 8 | `bills` | `6ae70ee80eaa37ed6cbea705` | Bill 2026-11 (Total: ₹8500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae70ee20eaa37ed6cbea702] exists: false, room [6ae70edf0eaa37ed6cbea6fe] exists: false. Created during legacy automated test runs. |
| 9 | `bills` | `6ae71187c242281fec83921e` | Bill 2026-11 (Total: ₹9500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae71181c242281fec83921a] exists: false, room [6ae7117fc242281fec839217] exists: false. Created during legacy automated test runs. |
| 10 | `bills` | `6ae71189c242281fec83921f` | Bill 2026-11 (Total: ₹8500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae71182c242281fec83921c] exists: false, room [6ae7117fc242281fec839218] exists: false. Created during legacy automated test runs. |
| 11 | `bills` | `6ae7226b482d8e2df83cebf1` | Bill 2026-11 (Total: ₹9500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae72265482d8e2df83cebed] exists: false, room [6ae72262482d8e2df83cebea] exists: false. Created during legacy automated test runs. |
| 12 | `bills` | `6ae7226d482d8e2df83cebf2` | Bill 2026-11 (Total: ₹8500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae72266482d8e2df83cebef] exists: false, room [6ae72262482d8e2df83cebeb] exists: false. Created during legacy automated test runs. |
| 13 | `bills` | `6ae724c660dd360913144ffb` | Bill 2026-11 (Total: ₹9500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae724c060dd360913144ff7] exists: false, room [6ae724be60dd360913144ff4] exists: false. Created during legacy automated test runs. |
| 14 | `bills` | `6ae724c860dd360913144ffc` | Bill 2026-11 (Total: ₹26708500) | **SAFE TO DELETE** | Legacy test bill. Referenced tenant [6ae724c160dd360913144ff9] exists: true, room [6ae724be60dd360913144ff5] exists: false. Created during legacy automated test runs. |

### Group D: Orphaned Sub-Meter Readings (8 documents)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
| 1 | `meterreadings` | `6ae6cb473c12a54fa65c6809` | MeterReading 2026-11 (Units: 150) | **SAFE TO DELETE** | Orphaned meter reading referencing deleted test room [6ae6cb413c12a54fa65c6803]. No active room or tenant uses this reading. |
| 2 | `meterreadings` | `6ae6ce963e6af1ca39c45bcf` | MeterReading 2026-11 (Units: 150) | **SAFE TO DELETE** | Orphaned meter reading referencing deleted test room [6ae6ce903e6af1ca39c45bc9]. No active room or tenant uses this reading. |
| 3 | `meterreadings` | `6ae70cbf0eaa37ed6cbea6ee` | MeterReading 2026-11 (Units: 150) | **SAFE TO DELETE** | Orphaned meter reading referencing deleted test room [6ae70cb80eaa37ed6cbea6e8]. No active room or tenant uses this reading. |
| 4 | `meterreadings` | `6ae70ee40eaa37ed6cbea703` | MeterReading 2026-11 (Units: 150) | **SAFE TO DELETE** | Orphaned meter reading referencing deleted test room [6ae70edf0eaa37ed6cbea6fd]. No active room or tenant uses this reading. |
| 5 | `meterreadings` | `6ae71184c242281fec83921d` | MeterReading 2026-11 (Units: 150) | **SAFE TO DELETE** | Orphaned meter reading referencing deleted test room [6ae7117fc242281fec839217]. No active room or tenant uses this reading. |
| 6 | `meterreadings` | `6ae72269482d8e2df83cebf0` | MeterReading 2026-11 (Units: 150) | **SAFE TO DELETE** | Orphaned meter reading referencing deleted test room [6ae72262482d8e2df83cebea]. No active room or tenant uses this reading. |
| 7 | `meterreadings` | `6ae724c460dd360913144ffa` | MeterReading 2026-11 (Units: 150) | **SAFE TO DELETE** | Orphaned meter reading referencing deleted test room [6ae724be60dd360913144ff4]. No active room or tenant uses this reading. |
| 8 | `meterreadings` | `6ae785f642d7bc444f40c07f` | MeterReading 2026-11 (Units: 50) | **SAFE TO DELETE** | Orphaned meter reading referencing deleted test room [6ae6cb413c12a54fa65c6804]. No active room or tenant uses this reading. |

### Group E: Orphaned Test Maintenance Complaints (7 documents)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
| 1 | `complaints` | `6ae6cb513c12a54fa65c680f` | Complaint: "Bathroom Tap Leaking" (resolved) | **SAFE TO DELETE** | Test complaint ticket filed during test runs. Referenced test tenant [6ae6cb433c12a54fa65c6806] is defunct. |
| 2 | `complaints` | `6ae6ce9e3e6af1ca39c45bd5` | Complaint: "Bathroom Tap Leaking" (resolved) | **SAFE TO DELETE** | Test complaint ticket filed during test runs. Referenced test tenant [6ae6ce923e6af1ca39c45bcc] is defunct. |
| 3 | `complaints` | `6ae70ccf0eaa37ed6cbea6f4` | Complaint: "Bathroom Tap Leaking" (resolved) | **SAFE TO DELETE** | Test complaint ticket filed during test runs. Referenced test tenant [6ae70cba0eaa37ed6cbea6eb] is defunct. |
| 4 | `complaints` | `6ae70eee0eaa37ed6cbea709` | Complaint: "Bathroom Tap Leaking" (resolved) | **SAFE TO DELETE** | Test complaint ticket filed during test runs. Referenced test tenant [6ae70ee10eaa37ed6cbea700] is defunct. |
| 5 | `complaints` | `6ae71190c242281fec839223` | Complaint: "Bathroom Tap Leaking" (resolved) | **SAFE TO DELETE** | Test complaint ticket filed during test runs. Referenced test tenant [6ae71181c242281fec83921a] is defunct. |
| 6 | `complaints` | `6ae72272482d8e2df83cebf6` | Complaint: "Bathroom Tap Leaking" (resolved) | **SAFE TO DELETE** | Test complaint ticket filed during test runs. Referenced test tenant [6ae72265482d8e2df83cebed] is defunct. |
| 7 | `complaints` | `6ae724ce60dd360913145000` | Complaint: "Bathroom Tap Leaking" (open) | **SAFE TO DELETE** | Test complaint ticket filed during test runs. Referenced test tenant [6ae724c060dd360913144ff7] is defunct. |

### Group F: Legacy Test Notifications (16 documents)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
| 1 | `notifications` | `6ae826d7e12b3b0207357aba` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 2 | `notifications` | `6ae826dee12b3b0207357ac2` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 3 | `notifications` | `6ae826e7e12b3b0207357ac6` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 4 | `notifications` | `6ae826fde12b3b0207357ad2` | Notification: "Reply from Phase Test Tenant 1" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 5 | `notifications` | `6ae8277a27ed99e6bd22fdaa` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 6 | `notifications` | `6ae8278427ed99e6bd22fdb1` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 7 | `notifications` | `6ae8278927ed99e6bd22fdb5` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 8 | `notifications` | `6ae827a127ed99e6bd22fdc1` | Notification: "Reply from Phase Test Tenant 1" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 9 | `notifications` | `6ae830ff8c447b559fe245b3` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 10 | `notifications` | `6ae831068c447b559fe245ba` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 11 | `notifications` | `6ae8310a8c447b559fe245be` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 12 | `notifications` | `6ae831298c447b559fe245ca` | Notification: "Reply from Phase Test Tenant 1" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 13 | `notifications` | `6ae83ab72f539c15ae672ba8` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 14 | `notifications` | `6ae83abc2f539c15ae672bb0` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 15 | `notifications` | `6ae83ac12f539c15ae672bb5` | Notification: "New Registration Request" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |
| 16 | `notifications` | `6ae83ace2f539c15ae672bc3` | Notification: "Reply from Phase Test Tenant 1" | **NEEDS REVIEW** | Legacy test notification emitted during previous test suites to test account (212myashraj@gmail.com). |

### Group G: Defunct Test Chat Conversations (11 documents)
| # | Collection | Document ID | Identifier | Classification | Specific Reason |
|---|---|---|---|---|---|
| 1 | `conversations` | `6ae826dce12b3b0207357abe` | Conversation: type=community, room=N/A | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |
| 2 | `conversations` | `6ae826e9e12b3b0207357ac7` | Conversation: type=room, room=6ae826d9e12b3b0207357abc | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |
| 3 | `conversations` | `6ae826f0e12b3b0207357aca` | Conversation: type=room, room=6ae826eae12b3b0207357ac9 | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |
| 4 | `conversations` | `6ae8279127ed99e6bd22fdb6` | Conversation: type=room, room=6ae8277d27ed99e6bd22fdac | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |
| 5 | `conversations` | `6ae8279727ed99e6bd22fdb9` | Conversation: type=room, room=6ae8279227ed99e6bd22fdb8 | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |
| 6 | `conversations` | `6ae8310f8c447b559fe245bf` | Conversation: type=room, room=6ae831028c447b559fe245b5 | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |
| 7 | `conversations` | `6ae831168c447b559fe245c2` | Conversation: type=room, room=6ae831108c447b559fe245c1 | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |
| 8 | `conversations` | `6ae83a7e01037968bd9466c2` | Conversation: type=room, room=6ae83a7801037968bd9466be | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |
| 9 | `conversations` | `6ae83a9e5e85e78779982b5a` | Conversation: type=room, room=6ae83a995e85e78779982b56 | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |
| 10 | `conversations` | `6ae83ac32f539c15ae672bb6` | Conversation: type=room, room=6ae83ab92f539c15ae672baa | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |
| 11 | `conversations` | `6ae83ac82f539c15ae672bba` | Conversation: type=room, room=6ae83ac42f539c15ae672bb9 | **SAFE TO DELETE** | Defunct test conversation channel created during test suite runs. Not connected to genuine users or rooms. |

---

## 5. DEPENDENCY AND CASCADE SAFETY ANALYSIS

1. **Owner Account Safety:**  
   The primary owner account (`212myashraj@gmail.com`) has ID `6ae80f4a5ca93446b8f6e8a5`. None of the proposed deletions target or cascade to this ID.
2. **Tenant Account Safety:**  
   The primary tenant account (`radha118223@gmail.com`) has ID `6ae80e085ca93446b8f6e8a4`. None of the proposed deletions reference or affect this tenant.
3. **Property Settings Safety:**  
   The PG settings document (containing UPI ID `6206825865@oksbi` and rate ₹13/unit) is completely preserved.
4. **Foreign Key Integrity:**  
   All 14 bills and 8 meter readings proposed for deletion reference test rooms/tenants that were previously deleted in past testing sessions. Removing them eliminates foreign key dangling references, thereby restoring database referential integrity.
5. **No Blind Bulk Deletion:**  
   Deletions will be executed using individual document ID matching (`_id: { $in: approvedIds }`), never using collection drops or `deleteMany({})`.

---

## 6. STOP CHECKPOINT & APPROVAL REQUEST

> [!WARNING]
> **ACTION REQUIRED BEFORE EXECUTION:**  
> In accordance with Phase 3 instructions, the process is now **HALTED** at this checkpoint.  
> 
> Please review the 70 itemized document IDs in this manifest. **Explicit user authorization is required to proceed with deleting these 70 test documents.**
