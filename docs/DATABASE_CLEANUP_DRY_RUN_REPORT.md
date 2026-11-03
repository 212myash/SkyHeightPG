# SKY HEIGHT APARTMENT — PRODUCTION DATABASE CLEANUP DRY-RUN REPORT

**Document ID:** `DOC-DB-CLEANUP-DRYRUN-001`  
**Target Database:** Production MongoDB Atlas (`test`)  
**Safety Protocol:** **STRICT DRY RUN ONLY. ZERO PRODUCTION RECORDS HAVE BEEN DELETED.**  
**Safety Snapshot File:** `docs/backups/prod_db_snapshot_1793715200465.json`  
**Date:** November 3, 2026  

---

## 1. EXECUTIVE SUMMARY & SAFETY COMMITMENT

In accordance with strict production database safety rules:
1. A complete JSON snapshot backup of all collections was taken prior to analysis.
2. **NO DESTRUCTIVE ACTIONS HAVE OCCURRED.**
3. This document provides a record-level classification of all documents currently residing in the production MongoDB database (`test`).
4. Any proposed cleanup action is presented for explicit review and requires explicit user authorization before any operation is executed.

---

## 2. GENUINE RECORDS IDENTIFIED (TO PRESERVE PERMANENTLY)

The following records belong to real users, live property configurations, or genuine system operations and **MUST BE PRESERVED**:

### A. Genuine User Accounts (2 records)
1. **Owner Account:**
   - **ID:** `6ae80f4a5ca93446b8f6e8a5`
   - **Name:** Yash Raj
   - **Email:** `212myashraj@gmail.com`
   - **Role:** `owner`
   - **Status:** Active Genuine Property Owner
2. **Tenant Account:**
   - **ID:** `6ae80e085ca93446b8f6e8a4`
   - **Name:** Vaishanavi Sonawane
   - **Email:** `radha118223@gmail.com`
   - **Role:** `tenant`
   - **Status:** Registered Tenant

### B. Genuine PG Global Configuration (1 record)
- **ID:** `6ae6c7720d213bb788527a31`
- **PG Name:** Sky Height PG
- **UPI ID:** `6206825865@oksbi`
- **Electricity Tariff:** ₹13/unit
- **Default Due Day:** Day 5

---

## 3. CANDIDATE TEST FIXTURES & ORPHANS PROPOSED FOR CLEANUP

These records were created during previous exploratory development and testing sessions before database isolation (`skyheight_isolated_test`) was instituted.

### A. Test User Accounts (13 records)
| Collection | Document _id | Name | Email | Role | Creation Note |
|---|---|---|---|---|---|
| `users` | `6ae6ee2b0eaa37ed6cbea6db` | DevTest Tenant | `devtest_tenant@skyheight.in` | tenant | Legacy Dev/Test Account |
| `users` | `6ae70c9e0eaa37ed6cbea6e6` | Rahul Sharma | `tenant_1793526942475@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae70ca10eaa37ed6cbea6e7` | Tenant Added By Owner | `tenant_by_owner_1793526945177@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae70cba0eaa37ed6cbea6ea` | Rahul Tenant A | `tenanta_1793526965606@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae70cbb0eaa37ed6cbea6ec` | Amit Tenant B | `tenantb_1793526965606@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae70ee10eaa37ed6cbea6ff` | Rahul Tenant A | `tenanta_1793527518463@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae70ee20eaa37ed6cbea701` | Amit Tenant B | `tenantb_1793527518463@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae71181c242281fec839219` | Rahul Tenant A | `tenanta_1793528189409@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae71182c242281fec83921b` | Amit Tenant B | `tenantb_1793528189409@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae72264482d8e2df83cebec` | Rahul Tenant A | `tenanta_1793532513201@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae72265482d8e2df83cebee` | Amit Tenant B | `tenantb_1793532513201@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae724c060dd360913144ff6` | Rahul Tenant A | `tenanta_1793533117859@skyheight-test.com` | tenant | Legacy Dev/Test Account |
| `users` | `6ae724c160dd360913144ff8` | Amit Tenant B | `tenantb_1793533117859@skyheight-test.com` | tenant | Legacy Dev/Test Account |

### B. Orphaned Tenant Profile (1 record)
| Collection | Document _id | User ID | Room ID | Status | Issue |
|---|---|---|---|---|---|
| `tenants` | `6ae724c160dd360913144ff9` | `6ae724c160dd360913144ff8` | `6ae724be60dd360913144ff5` | vacated | Referenced Room does not exist in `rooms` collection |

### C. Orphaned Invoices / Bills (14 records)
| Collection | Document _id | Billing Month | Tenant Ref | Room Ref | Total Amount | Issue |
|---|---|---|---|---|---|
| `bills` | `6ae6cb4a3c12a54fa65c680a` | 2026-11 | `6ae6cb433c12a54fa65c6806` | `6ae6cb413c12a54fa65c6803` | ₹9500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae6cb4b3c12a54fa65c680b` | 2026-11 | `6ae6cb443c12a54fa65c6808` | `6ae6cb413c12a54fa65c6804` | ₹8500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae6ce983e6af1ca39c45bd0` | 2026-11 | `6ae6ce923e6af1ca39c45bcc` | `6ae6ce903e6af1ca39c45bc9` | ₹9500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae6ce993e6af1ca39c45bd1` | 2026-11 | `6ae6ce933e6af1ca39c45bce` | `6ae6ce903e6af1ca39c45bca` | ₹8500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae70cc40eaa37ed6cbea6ef` | 2026-11 | `6ae70cba0eaa37ed6cbea6eb` | `6ae70cb80eaa37ed6cbea6e8` | ₹9500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae70cc50eaa37ed6cbea6f0` | 2026-11 | `6ae70cbc0eaa37ed6cbea6ed` | `6ae70cb80eaa37ed6cbea6e9` | ₹8500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae70ee60eaa37ed6cbea704` | 2026-11 | `6ae70ee10eaa37ed6cbea700` | `6ae70edf0eaa37ed6cbea6fd` | ₹9500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae70ee80eaa37ed6cbea705` | 2026-11 | `6ae70ee20eaa37ed6cbea702` | `6ae70edf0eaa37ed6cbea6fe` | ₹8500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae71187c242281fec83921e` | 2026-11 | `6ae71181c242281fec83921a` | `6ae7117fc242281fec839217` | ₹9500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae71189c242281fec83921f` | 2026-11 | `6ae71182c242281fec83921c` | `6ae7117fc242281fec839218` | ₹8500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae7226b482d8e2df83cebf1` | 2026-11 | `6ae72265482d8e2df83cebed` | `6ae72262482d8e2df83cebea` | ₹9500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae7226d482d8e2df83cebf2` | 2026-11 | `6ae72266482d8e2df83cebef` | `6ae72262482d8e2df83cebeb` | ₹8500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae724c660dd360913144ffb` | 2026-11 | `6ae724c060dd360913144ff7` | `6ae724be60dd360913144ff4` | ₹9500 | Referenced Tenant & Room no longer exist |
| `bills` | `6ae724c860dd360913144ffc` | 2026-11 | `6ae724c160dd360913144ff9` | `6ae724be60dd360913144ff5` | ₹31700 | Referenced Tenant & Room no longer exist |

### D. Orphaned Meter Readings (8 records)
| Collection | Document _id | Reading Month | Room Ref | Units Consumed | Issue |
|---|---|---|---|---|---|
| `meterreadings` | `6ae6cb473c12a54fa65c6809` | 2026-11 | `6ae6cb413c12a54fa65c6803` | 150 | Referenced Room does not exist |
| `meterreadings` | `6ae6ce963e6af1ca39c45bcf` | 2026-11 | `6ae6ce903e6af1ca39c45bc9` | 150 | Referenced Room does not exist |
| `meterreadings` | `6ae70cbf0eaa37ed6cbea6ee` | 2026-11 | `6ae70cb80eaa37ed6cbea6e8` | 150 | Referenced Room does not exist |
| `meterreadings` | `6ae70ee40eaa37ed6cbea703` | 2026-11 | `6ae70edf0eaa37ed6cbea6fd` | 150 | Referenced Room does not exist |
| `meterreadings` | `6ae71184c242281fec83921d` | 2026-11 | `6ae7117fc242281fec839217` | 150 | Referenced Room does not exist |
| `meterreadings` | `6ae72269482d8e2df83cebf0` | 2026-11 | `6ae72262482d8e2df83cebea` | 150 | Referenced Room does not exist |
| `meterreadings` | `6ae724c460dd360913144ffa` | 2026-11 | `6ae724be60dd360913144ff4` | 150 | Referenced Room does not exist |
| `meterreadings` | `6ae785f642d7bc444f40c07f` | 2026-11 | `6ae6cb413c12a54fa65c6804` | 50 | Referenced Room does not exist |

### E. Orphaned Maintenance Complaints (7 records)
| Collection | Document _id | Title | Category | Status | Issue |
|---|---|---|---|---|---|
| `complaints` | `6ae6cb513c12a54fa65c680f` | Bathroom Tap Leaking | plumbing | resolved | Referenced Tenant does not exist |
| `complaints` | `6ae6ce9e3e6af1ca39c45bd5` | Bathroom Tap Leaking | plumbing | resolved | Referenced Tenant does not exist |
| `complaints` | `6ae70ccf0eaa37ed6cbea6f4` | Bathroom Tap Leaking | plumbing | resolved | Referenced Tenant does not exist |
| `complaints` | `6ae70eee0eaa37ed6cbea709` | Bathroom Tap Leaking | plumbing | resolved | Referenced Tenant does not exist |
| `complaints` | `6ae71190c242281fec839223` | Bathroom Tap Leaking | plumbing | resolved | Referenced Tenant does not exist |
| `complaints` | `6ae72272482d8e2df83cebf6` | Bathroom Tap Leaking | plumbing | resolved | Referenced Tenant does not exist |
| `complaints` | `6ae724ce60dd360913145000` | Bathroom Tap Leaking | plumbing | open | Referenced Tenant does not exist |

### F. Legacy Test Notifications (16 records)
| Collection | Document _id | Title | Recipient | Category | Issue |
|---|---|---|---|---|---|
| `notifications` | `6ae826d7e12b3b0207357aba` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae826dee12b3b0207357ac2` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae826e7e12b3b0207357ac6` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae826fde12b3b0207357ad2` | Reply from Phase Test Tenant 1 | `6ae80f4a5ca93446b8f6e8a5` | general_announcement | Legacy test notification generated during initial test runs |
| `notifications` | `6ae8277a27ed99e6bd22fdaa` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae8278427ed99e6bd22fdb1` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae8278927ed99e6bd22fdb5` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae827a127ed99e6bd22fdc1` | Reply from Phase Test Tenant 1 | `6ae80f4a5ca93446b8f6e8a5` | general_announcement | Legacy test notification generated during initial test runs |
| `notifications` | `6ae830ff8c447b559fe245b3` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae831068c447b559fe245ba` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae8310a8c447b559fe245be` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae831298c447b559fe245ca` | Reply from Phase Test Tenant 1 | `6ae80f4a5ca93446b8f6e8a5` | general_announcement | Legacy test notification generated during initial test runs |
| `notifications` | `6ae83ab72f539c15ae672ba8` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae83abc2f539c15ae672bb0` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae83ac12f539c15ae672bb5` | New Registration Request | `6ae80f4a5ca93446b8f6e8a5` | registration_update | Legacy test notification generated during initial test runs |
| `notifications` | `6ae83ace2f539c15ae672bc3` | Reply from Phase Test Tenant 1 | `6ae80f4a5ca93446b8f6e8a5` | general_announcement | Legacy test notification generated during initial test runs |

### G. Legacy Chat Conversations (11 records)
| Collection | Document _id | Type | Room Ref | Issue |
|---|---|---|---|---|
| `conversations` | `6ae826dce12b3b0207357abe` | community | `N/A` | Legacy test conversation channels linked to defunct test rooms |
| `conversations` | `6ae826e9e12b3b0207357ac7` | room | `6ae826d9e12b3b0207357abc` | Legacy test conversation channels linked to defunct test rooms |
| `conversations` | `6ae826f0e12b3b0207357aca` | room | `6ae826eae12b3b0207357ac9` | Legacy test conversation channels linked to defunct test rooms |
| `conversations` | `6ae8279127ed99e6bd22fdb6` | room | `6ae8277d27ed99e6bd22fdac` | Legacy test conversation channels linked to defunct test rooms |
| `conversations` | `6ae8279727ed99e6bd22fdb9` | room | `6ae8279227ed99e6bd22fdb8` | Legacy test conversation channels linked to defunct test rooms |
| `conversations` | `6ae8310f8c447b559fe245bf` | room | `6ae831028c447b559fe245b5` | Legacy test conversation channels linked to defunct test rooms |
| `conversations` | `6ae831168c447b559fe245c2` | room | `6ae831108c447b559fe245c1` | Legacy test conversation channels linked to defunct test rooms |
| `conversations` | `6ae83a7e01037968bd9466c2` | room | `6ae83a7801037968bd9466be` | Legacy test conversation channels linked to defunct test rooms |
| `conversations` | `6ae83a9e5e85e78779982b5a` | room | `6ae83a995e85e78779982b56` | Legacy test conversation channels linked to defunct test rooms |
| `conversations` | `6ae83ac32f539c15ae672bb6` | room | `6ae83ab92f539c15ae672baa` | Legacy test conversation channels linked to defunct test rooms |
| `conversations` | `6ae83ac82f539c15ae672bba` | room | `6ae83ac42f539c15ae672bb9` | Legacy test conversation channels linked to defunct test rooms |

---

## 4. ACTION SUMMARY & APPROVAL REQUEST

| Collection | Current Count | Genuine to Preserve | Candidate for Cleanup | Action Status |
|---|---|---|---|---|
| `users` | 15 | 2 (Yash Raj, Vaishanavi) | 13 test accounts | **HELD — Awaiting Approval** |
| `pgsettings` | 1 | 1 (Sky Height PG config) | 0 | **PRESERVED** |
| `tenants` | 1 | 0 | 1 orphan | **HELD — Awaiting Approval** |
| `bills` | 14 | 0 | 14 orphans | **HELD — Awaiting Approval** |
| `meterreadings` | 8 | 0 | 8 orphans | **HELD — Awaiting Approval** |
| `complaints` | 7 | 0 | 7 orphans | **HELD — Awaiting Approval** |
| `notifications`| 16 | 0 | 16 legacy test notices | **HELD — Awaiting Approval** |
| `conversations` | 11 | 0 | 11 legacy test channels | **HELD — Awaiting Approval** |
| `rooms` | 0 | 0 | 0 | **CLEAN** |
| `payments` | 0 | 0 | 0 | **CLEAN** |
| `expenses` | 0 | 0 | 0 | **CLEAN** |
| `occupancyhistories` | 0 | 0 | 0 | **CLEAN** |
| `messages` | 0 | 0 | 0 | **CLEAN** |

> [!IMPORTANT]
> **SAFETY NOTICE:**
> No database records have been modified or deleted. The verified JSON backup is safely stored at `docs/backups/prod_db_snapshot_1793715200465.json`. 
> 
> Cleanup of these candidate records will ONLY be performed if the user explicitly requests and approves it.
