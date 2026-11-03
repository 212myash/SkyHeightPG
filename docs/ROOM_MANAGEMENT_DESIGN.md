# Room Management Architecture & Bedless Occupancy Design
**Project:** Sky Height Apartment  
**Document Version:** 1.0.0  
**Status:** Implemented & Verified  

---

## 1. Executive Summary & Design Rationale
Historically, hostel/PG applications frequently forced tenants into rigid "Bed 1", "Bed 2", "Bed 3" allocations. In **Sky Height Apartment**, real-world management requires managing occupancy strictly by **Room Number** (e.g. `Room G101`: Rahul Kumar, `Room G102`: Amit Kumar, Rohit Sharma).

This document outlines the architectural changes implemented across the Node.js/Express backend, MongoDB schemas, and Flutter mobile application to eliminate bed concepts while preserving backward compatibility and enabling dynamic room occupancy management.

---

## 2. Occupancy Model & Core Principles
1. **Room-Based Identification:** All tenant allocations, contracts, electricity meters, and sub-meters are keyed strictly to Room IDs and Room Numbers.
2. **Occupancy Capacity (`maxOccupancy`):**
   - Each room maintains `maxOccupancy` (Number, default `2`, minimum `1`).
   - `capacity` and `occupiedBeds` are synchronized transparently on the backend as backward-compatible aliases.
   - Status updates automatically: `"available"` when active occupants < `maxOccupancy`, and `"occupied"` when active occupants == `maxOccupancy`.
3. **Multiple Active Tenants per Room:**
   - A single room cleanly accommodates up to `maxOccupancy` tenants.
   - Rooms reject over-capacity allocation attempts with HTTP `400 Bad Request`.
4. **Individual Rent vs. Split Utilities:**
   - **Monthly Rent:** Maintained individually per tenant (`tenant.monthlyRent`).
   - **Electricity Bill Sharing:** Calculated directly from the room's sub-meter reading, divided equally among active roommates:
     $$\text{Tenant Electricity Share} = \text{round}\left(\frac{\text{Room Electricity Amount}}{\text{Active Occupants Count}}\right)$$

```
                                  +---------------------+
                                  |     Room G101       |
                                  | maxOccupancy: 2     |
                                  | currentOccupancy: 2 |
                                  | status: "occupied"  |
                                  +----------+----------+
                                             |
                      +----------------------+----------------------+
                      |                                             |
             +--------v--------+                           +--------v--------+
             |   Occupant 1    |                           |   Occupant 2    |
             |  Rahul Sharma   |                           |   Amit Kumar    |
             | Rent: Rs. 8,000 |                           | Rent: Rs. 8,000 |
             | Elec: 50% Share |                           | Elec: 50% Share |
             +-----------------+                           +-----------------+
```

---

## 3. Database Schema Changes

### A. Room Schema (`backend/models/Room.js`)
```javascript
{
  roomNumber: { type: String, required: true, unique: true, uppercase: true, trim: true },
  floor: { type: Number, required: true, min: 0 },
  roomType: { type: String, enum: ["single", "double", "triple", "four-sharing", "other"], default: "double" },
  monthlyRent: { type: Number, required: true, min: 0 },
  maxOccupancy: { type: Number, min: 1, default: 2 },
  capacity: { type: Number, min: 1, default: 2 }, // Backward-compatible alias
  occupiedBeds: { type: Number, default: 0, min: 0 }, // Synchronized counter
  amenities: { type: [String], default: [] },
  status: { type: String, enum: ["available", "occupied", "maintenance"], default: "available" },
  isActive: { type: Boolean, default: true }
}
```

### B. Tenant Schema (`backend/models/Tenant.js`)
```javascript
{
  user: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true, index: true },
  room: { type: mongoose.Schema.Types.ObjectId, ref: "Room", default: null, index: true }, // Optional for pending tenants
  fullName: { type: String, required: true, trim: true },
  phone: { type: String, required: true, trim: true },
  email: { type: String, required: true, lowercase: true, trim: true },
  monthlyRent: { type: Number, default: 0 },
  securityDeposit: { type: Number, default: 0 },
  assignedBed: { type: String, default: "" }, // Deprecated, preserved for legacy documents
  status: { type: String, enum: ["active", "vacated", "notice_period", "pending_allocation"], default: "pending_allocation" },
  approvalStatus: { type: String, enum: ["pending", "approved", "rejected"], default: "approved" }
}
```

---

## 4. REST API Endpoints & Workflows

| Method | Endpoint | Access | Purpose |
| :--- | :--- | :--- | :--- |
| `GET` | `/api/rooms` | Authenticated | Lists all rooms enriched with occupant names, current occupancy, and vacancies |
| `POST` | `/api/rooms` | Owner only | Creates a room with `maxOccupancy` (default 2) |
| `GET` | `/api/rooms/:id/tenants` | Authenticated | Lists active tenants currently assigned to that room |
| `PUT` | `/api/rooms/:id` | Owner only | Updates room details, rent, or occupancy limit |
| `PUT` | `/api/tenants/:id/assign-room` | Owner only | Allocates an unassigned tenant to an active room with vacancies |
| `PUT` | `/api/tenants/:id/change-room` | Owner only | Atomically transfers tenant to new room (old -1, new +1) |
| `PUT` | `/api/tenants/:id/vacate` | Owner only | Marks tenant as vacated, releases room vacancy, and revokes chat access |

---

## 5. Mobile Application Integration
1. **Owner Rooms Screen (`owner_rooms_screen.dart`):**
   - Completely eliminated bed chips and bed selector dropdowns.
   - Each card displays Room Number, Floor, Rent, Occupancy fraction (`occupied / capacity`), Vacancies count, and active occupant names badge:
     `Occupants: Rahul Sharma, Amit Kumar`
   - "Add Room" modal prompts for `Max Occupancy (Persons)` defaulting to 2.
2. **Owner Tenants Screen (`owner_tenants_screen.dart`):**
   - Removed `bedController` and `Assigned Bed` text input.
   - Room allocation dropdown displays: `Room G101 (1/2 occupants) - Rs. 8,000/mo`.
   - Vacation dialog: confirms release of room occupancy rather than bed release.
3. **Tenant Dashboard (`tenant_dashboard_screen.dart`):**
   - Displays clean `Room G101 • Floor 1` without arbitrary bed labels.
   - Quick action shortcuts directly access Same-Room Group Chat, Owner Chat, and Community Group.
