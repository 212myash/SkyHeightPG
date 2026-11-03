# SKY HEIGHT APARTMENT — PRODUCTION DATABASE CLEANUP EXECUTION REPORT

**Document ID:** `DOC-DB-EXECUTION-001`  
**Target Database:** Production MongoDB Atlas (`test`)  
**Authorization:** Explicit User Approval Received  
**Execution Timestamp:** 2026-11-03T18:43:54.597Z to 2026-11-03T18:44:11.464Z  
**Total Documents Deleted:** **70 (Exact Match with Approved Manifest)**  
**Genuine Records Preserved:** **100% (Yash Raj, Vaishanavi Sonawane, PG Settings)**  
**Zero-Risk Isolation:** Clean, ordered foreign-key deletion completed.  
**Fresh Backup Reference:** `docs/backups/prod_db_snapshot_fresh_1793730958547.json`  

---

## 1. EXECUTIVE SUMMARY & VERIFICATION

On 4/11/2026, the approved production cleanup was executed against the production MongoDB Atlas database (`test`). 

All pre-deletion integrity checks passed:
1. Fresh production backup verified readable from disk prior to execution.
2. Every one of the 70 approved document IDs was re-verified against live MongoDB documents and confirmed to be legacy test fixtures.
3. Preserved genuine records were confirmed present prior to deletion and re-verified intact post-deletion.
4. Exactly 70 documents were deleted using strict document ID filters (`_id: { $in: exactApprovedIds }`).
5. No collection-wide or blind wildcard operations were executed.

---

## 2. BEFORE AND AFTER COLLECTION AUDIT

| Collection Name | Pre-Cleanup Count | Deleted Count | Post-Cleanup Count | Preserved Status |
|---|---|---|---|---|
| `users` | 15 | **13** | **2** | Preserved Owner Yash Raj & Tenant Vaishanavi |
| `pgsettings` | 1 | **0** | **1** | Preserved Sky Height PG settings & UPI |
| `tenants` | 1 | **1** | **0** | Orphan test tenant removed |
| `bills` | 14 | **14** | **0** | Orphan test bills removed |
| `meterreadings` | 8 | **8** | **0** | Orphan test meter readings removed |
| `complaints` | 7 | **7** | **0** | Orphan test complaints removed |
| `notifications` | 16 | **16** | **0** | Legacy test notifications removed |
| `conversations` | 11 | **11** | **0** | Legacy test chat channels removed |
| `rooms` | 0 | 0 | 0 | Clean |
| `payments` | 0 | 0 | 0 | Clean |
| `expenses` | 0 | 0 | 0 | Clean |
| `messages` | 0 | 0 | 0 | Clean |
| `occupancyhistories` | 0 | 0 | 0 | Clean |
| **TOTALS** | **73** | **70** | **3** | **100% Genuine Production State** |

---

## 3. PRESERVED GENUINE PRODUCTION RECORDS

| Collection | Document ID | Account / Identifier | Role / Details | Status |
|---|---|---|---|---|
| `users` | `6ae80f4a5ca93446b8f6e8a5` | **Yash Raj** (`212myashraj@gmail.com`) | Property Owner | **VERIFIED INTACT** |
| `users` | `6ae80e085ca93446b8f6e8a4` | **Vaishanavi Sonawane** (`radha118223@gmail.com`) | Registered Tenant | **VERIFIED INTACT** |
| `pgsettings` | `6ae6c7720d213bb788527a31` | **Sky Height PG** | UPI: `6206825865@oksbi`, Rate: ₹13/unit | **VERIFIED INTACT** |

---

## 4. ITEMIZED RECORD DELETION LOG (ALL 70 DOCUMENTS)

### Collection: `conversations` (11 documents deleted)
| # | Document ID | Identifier | Status | Matched | Deleted |
|---|---|---|---|---|---|
| 1 | `6ae826dce12b3b0207357abe` | Conversation: type=community, room=N/A | **DELETED** | 1 | 1 |
| 2 | `6ae826e9e12b3b0207357ac7` | Conversation: type=room, room=6ae826d9e12b3b0207357abc | **DELETED** | 1 | 1 |
| 3 | `6ae826f0e12b3b0207357aca` | Conversation: type=room, room=6ae826eae12b3b0207357ac9 | **DELETED** | 1 | 1 |
| 4 | `6ae8279127ed99e6bd22fdb6` | Conversation: type=room, room=6ae8277d27ed99e6bd22fdac | **DELETED** | 1 | 1 |
| 5 | `6ae8279727ed99e6bd22fdb9` | Conversation: type=room, room=6ae8279227ed99e6bd22fdb8 | **DELETED** | 1 | 1 |
| 6 | `6ae8310f8c447b559fe245bf` | Conversation: type=room, room=6ae831028c447b559fe245b5 | **DELETED** | 1 | 1 |
| 7 | `6ae831168c447b559fe245c2` | Conversation: type=room, room=6ae831108c447b559fe245c1 | **DELETED** | 1 | 1 |
| 8 | `6ae83a7e01037968bd9466c2` | Conversation: type=room, room=6ae83a7801037968bd9466be | **DELETED** | 1 | 1 |
| 9 | `6ae83a9e5e85e78779982b5a` | Conversation: type=room, room=6ae83a995e85e78779982b56 | **DELETED** | 1 | 1 |
| 10 | `6ae83ac32f539c15ae672bb6` | Conversation: type=room, room=6ae83ab92f539c15ae672baa | **DELETED** | 1 | 1 |
| 11 | `6ae83ac82f539c15ae672bba` | Conversation: type=room, room=6ae83ac42f539c15ae672bb9 | **DELETED** | 1 | 1 |

### Collection: `notifications` (16 documents deleted)
| # | Document ID | Identifier | Status | Matched | Deleted |
|---|---|---|---|---|---|
| 12 | `6ae826d7e12b3b0207357aba` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 13 | `6ae826dee12b3b0207357ac2` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 14 | `6ae826e7e12b3b0207357ac6` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 15 | `6ae826fde12b3b0207357ad2` | Notification: "Reply from Phase Test Tenant 1" | **DELETED** | 1 | 1 |
| 16 | `6ae8277a27ed99e6bd22fdaa` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 17 | `6ae8278427ed99e6bd22fdb1` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 18 | `6ae8278927ed99e6bd22fdb5` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 19 | `6ae827a127ed99e6bd22fdc1` | Notification: "Reply from Phase Test Tenant 1" | **DELETED** | 1 | 1 |
| 20 | `6ae830ff8c447b559fe245b3` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 21 | `6ae831068c447b559fe245ba` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 22 | `6ae8310a8c447b559fe245be` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 23 | `6ae831298c447b559fe245ca` | Notification: "Reply from Phase Test Tenant 1" | **DELETED** | 1 | 1 |
| 24 | `6ae83ab72f539c15ae672ba8` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 25 | `6ae83abc2f539c15ae672bb0` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 26 | `6ae83ac12f539c15ae672bb5` | Notification: "New Registration Request" | **DELETED** | 1 | 1 |
| 27 | `6ae83ace2f539c15ae672bc3` | Notification: "Reply from Phase Test Tenant 1" | **DELETED** | 1 | 1 |

### Collection: `complaints` (7 documents deleted)
| # | Document ID | Identifier | Status | Matched | Deleted |
|---|---|---|---|---|---|
| 28 | `6ae6cb513c12a54fa65c680f` | Complaint: "Bathroom Tap Leaking" (resolved) | **DELETED** | 1 | 1 |
| 29 | `6ae6ce9e3e6af1ca39c45bd5` | Complaint: "Bathroom Tap Leaking" (resolved) | **DELETED** | 1 | 1 |
| 30 | `6ae70ccf0eaa37ed6cbea6f4` | Complaint: "Bathroom Tap Leaking" (resolved) | **DELETED** | 1 | 1 |
| 31 | `6ae70eee0eaa37ed6cbea709` | Complaint: "Bathroom Tap Leaking" (resolved) | **DELETED** | 1 | 1 |
| 32 | `6ae71190c242281fec839223` | Complaint: "Bathroom Tap Leaking" (resolved) | **DELETED** | 1 | 1 |
| 33 | `6ae72272482d8e2df83cebf6` | Complaint: "Bathroom Tap Leaking" (resolved) | **DELETED** | 1 | 1 |
| 34 | `6ae724ce60dd360913145000` | Complaint: "Bathroom Tap Leaking" (open) | **DELETED** | 1 | 1 |

### Collection: `meterreadings` (8 documents deleted)
| # | Document ID | Identifier | Status | Matched | Deleted |
|---|---|---|---|---|---|
| 35 | `6ae6cb473c12a54fa65c6809` | MeterReading 2026-11 (Units: 150) | **DELETED** | 1 | 1 |
| 36 | `6ae6ce963e6af1ca39c45bcf` | MeterReading 2026-11 (Units: 150) | **DELETED** | 1 | 1 |
| 37 | `6ae70cbf0eaa37ed6cbea6ee` | MeterReading 2026-11 (Units: 150) | **DELETED** | 1 | 1 |
| 38 | `6ae70ee40eaa37ed6cbea703` | MeterReading 2026-11 (Units: 150) | **DELETED** | 1 | 1 |
| 39 | `6ae71184c242281fec83921d` | MeterReading 2026-11 (Units: 150) | **DELETED** | 1 | 1 |
| 40 | `6ae72269482d8e2df83cebf0` | MeterReading 2026-11 (Units: 150) | **DELETED** | 1 | 1 |
| 41 | `6ae724c460dd360913144ffa` | MeterReading 2026-11 (Units: 150) | **DELETED** | 1 | 1 |
| 42 | `6ae785f642d7bc444f40c07f` | MeterReading 2026-11 (Units: 50) | **DELETED** | 1 | 1 |

### Collection: `bills` (14 documents deleted)
| # | Document ID | Identifier | Status | Matched | Deleted |
|---|---|---|---|---|---|
| 43 | `6ae6cb4a3c12a54fa65c680a` | Bill 2026-11 (Total: ₹9500) | **DELETED** | 1 | 1 |
| 44 | `6ae6cb4b3c12a54fa65c680b` | Bill 2026-11 (Total: ₹8500) | **DELETED** | 1 | 1 |
| 45 | `6ae6ce983e6af1ca39c45bd0` | Bill 2026-11 (Total: ₹9500) | **DELETED** | 1 | 1 |
| 46 | `6ae6ce993e6af1ca39c45bd1` | Bill 2026-11 (Total: ₹8500) | **DELETED** | 1 | 1 |
| 47 | `6ae70cc40eaa37ed6cbea6ef` | Bill 2026-11 (Total: ₹9500) | **DELETED** | 1 | 1 |
| 48 | `6ae70cc50eaa37ed6cbea6f0` | Bill 2026-11 (Total: ₹8500) | **DELETED** | 1 | 1 |
| 49 | `6ae70ee60eaa37ed6cbea704` | Bill 2026-11 (Total: ₹9500) | **DELETED** | 1 | 1 |
| 50 | `6ae70ee80eaa37ed6cbea705` | Bill 2026-11 (Total: ₹8500) | **DELETED** | 1 | 1 |
| 51 | `6ae71187c242281fec83921e` | Bill 2026-11 (Total: ₹9500) | **DELETED** | 1 | 1 |
| 52 | `6ae71189c242281fec83921f` | Bill 2026-11 (Total: ₹8500) | **DELETED** | 1 | 1 |
| 53 | `6ae7226b482d8e2df83cebf1` | Bill 2026-11 (Total: ₹9500) | **DELETED** | 1 | 1 |
| 54 | `6ae7226d482d8e2df83cebf2` | Bill 2026-11 (Total: ₹8500) | **DELETED** | 1 | 1 |
| 55 | `6ae724c660dd360913144ffb` | Bill 2026-11 (Total: ₹9500) | **DELETED** | 1 | 1 |
| 56 | `6ae724c860dd360913144ffc` | Bill 2026-11 (Total: ₹26708500) | **DELETED** | 1 | 1 |

### Collection: `tenants` (1 documents deleted)
| # | Document ID | Identifier | Status | Matched | Deleted |
|---|---|---|---|---|---|
| 57 | `6ae724c160dd360913144ff9` | Tenant doc for user: tenantb_1793533117859@skyheight-test.com | **DELETED** | 1 | 1 |

### Collection: `users` (13 documents deleted)
| # | Document ID | Identifier | Status | Matched | Deleted |
|---|---|---|---|---|---|
| 58 | `6ae6ee2b0eaa37ed6cbea6db` | DevTest Tenant <devtest_tenant@skyheight.in> | **DELETED** | 1 | 1 |
| 59 | `6ae70c9e0eaa37ed6cbea6e6` | Rahul Sharma <tenant_1793526942475@skyheight-test.com> | **DELETED** | 1 | 1 |
| 60 | `6ae70ca10eaa37ed6cbea6e7` | Tenant Added By Owner <tenant_by_owner_1793526945177@skyheight-test.com> | **DELETED** | 1 | 1 |
| 61 | `6ae70cba0eaa37ed6cbea6ea` | Rahul Tenant A <tenanta_1793526965606@skyheight-test.com> | **DELETED** | 1 | 1 |
| 62 | `6ae70cbb0eaa37ed6cbea6ec` | Amit Tenant B <tenantb_1793526965606@skyheight-test.com> | **DELETED** | 1 | 1 |
| 63 | `6ae70ee10eaa37ed6cbea6ff` | Rahul Tenant A <tenanta_1793527518463@skyheight-test.com> | **DELETED** | 1 | 1 |
| 64 | `6ae70ee20eaa37ed6cbea701` | Amit Tenant B <tenantb_1793527518463@skyheight-test.com> | **DELETED** | 1 | 1 |
| 65 | `6ae71181c242281fec839219` | Rahul Tenant A <tenanta_1793528189409@skyheight-test.com> | **DELETED** | 1 | 1 |
| 66 | `6ae71182c242281fec83921b` | Amit Tenant B <tenantb_1793528189409@skyheight-test.com> | **DELETED** | 1 | 1 |
| 67 | `6ae72264482d8e2df83cebec` | Rahul Tenant A <tenanta_1793532513201@skyheight-test.com> | **DELETED** | 1 | 1 |
| 68 | `6ae72265482d8e2df83cebee` | Amit Tenant B <tenantb_1793532513201@skyheight-test.com> | **DELETED** | 1 | 1 |
| 69 | `6ae724c060dd360913144ff6` | Rahul Tenant A <tenanta_1793533117859@skyheight-test.com> | **DELETED** | 1 | 1 |
| 70 | `6ae724c160dd360913144ff8` | Amit Tenant B <tenantb_1793533117859@skyheight-test.com> | **DELETED** | 1 | 1 |

---

## 5. POST-CLEANUP REFERENTIAL INTEGRITY VERIFICATION

1. **Foreign Key Integrity:**
   - No orphaned references remain in the production database.
   - All dangling test bills, meter readings, and complaints referencing defunct test rooms/tenants have been completely eliminated.
2. **Account Safety:**
   - The genuine owner account (`212myashraj@gmail.com`) and tenant account (`radha118223@gmail.com`) have zero dependencies on any deleted records.
   - The PG settings configuration remains active with genuine UPI payment endpoints.
3. **Application Health:**
   - The database is in an authentic, production-clean state, ready for live property management.

---

## 6. BACKUP AVAILABILITY NOTICE

The pre-cleanup snapshot remains permanently available for audit and recovery at:
`docs/backups/prod_db_snapshot_fresh_1793730958547.json`
