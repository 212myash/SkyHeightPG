# Registration & Owner Approval Architecture
**Project:** Sky Height Apartment  
**Document Version:** 1.0.0  
**Status:** Implemented & Verified  

---

## 1. Security Architecture & Threat Model
To prevent unauthorized users from creating administrative Owner accounts or accessing protected tenant records, the application enforces strict registration boundaries:

1. **Owner Registration Removed from Public Surface:**
   - Any public registration request specifying `role: "owner"` is blocked with HTTP `403 Forbidden` (`"Public registration as Owner is not permitted."`).
   - Only existing authenticated owners can provision additional owner accounts.
2. **Tenant Self-Registration Defaults to Pending:**
   - Every public tenant registration unconditionally sets `role: "tenant"` and `approvalStatus: "pending"`.
   - Initial unallocated tenant profile is created with `status: "pending_allocation"` and `room: null`.
3. **Automated Owner Notification:**
   - On registration, all active Owner accounts receive an in-app notice (`category: "registration_update"`) alerting them to review the applicant.
4. **Data Isolation & 403 Enforcement:**
   - Both `loginUser` and `protect` middleware intercept requests from users with `approvalStatus === 'pending'` or `'rejected'`, returning HTTP `403 Forbidden`.
   - Pending tenants cannot obtain active tokens or access protected bills, meter readings, or apartment data.

---

## 2. Sequence Diagram

```
Tenant Applicant              Backend API              MongoDB Atlas              Apartment Owner
     |                             |                         |                           |
     | 1. POST /api/auth/register  |                         |                           |
     |---------------------------->|                         |                           |
     |                             | 2. Create User(pending) |                           |
     |                             |    Create Tenant(unalloc)                           |
     |                             |------------------------>|                           |
     |                             | 3. Create Notification  |                           |
     |                             |------------------------>|                           |
     | 4. HTTP 201 (PendingNotice) |                         |                           |
     |<----------------------------|                         |                           |
     |                             |                         | 5. GET /api/owner/notifs  |
     |                             |                         |<--------------------------|
     |                             |                         | 6. Review Applicant       |
     |                             |                         |    GET /api/owner/regis   |
     |                             |                         |<--------------------------|
     |                             | 7. PUT /api/owner/regis/:id/approve (Assign Room)   |
     |                             |<----------------------------------------------------|
     |                             | 8. Update User(approved)|                           |
     |                             |    Update Tenant(active)|                           |
     |                             |    Room Occupancy + 1   |                           |
     |                             |    Add to Room/Comm Chat|                           |
     |                             |------------------------>|                           |
     | 9. POST /api/auth/login     |                         |                           |
     |---------------------------->|                         |                           |
     | 10. HTTP 200 (Token Issued) |                         |                           |
     |<----------------------------|                         |                           |
```

---

## 3. Approval & Rejection APIs

### A. List Registration Requests
- **Route:** `GET /api/owner/registrations?status=pending|approved|all`
- **Access:** Owner only
- **Response:**
```json
{
  "success": true,
  "count": 1,
  "data": [
    {
      "_id": "6ae8...",
      "name": "Rahul Sharma",
      "email": "rahul@example.com",
      "phone": "9876543210",
      "role": "tenant",
      "approvalStatus": "pending",
      "createdAt": "2026-11-02T10:00:00.000Z",
      "tenant": {
        "_id": "6ae9...",
        "room": null,
        "monthlyRent": 0,
        "securityDeposit": 0,
        "status": "pending_allocation"
      }
    }
  ]
}
```

### B. Approve Tenant
- **Route:** `PUT /api/owner/registrations/:id/approve`
- **Access:** Owner only
- **Payload (Optional Room Allocation):**
```json
{
  "roomId": "6ae8b...",
  "monthlyRent": 8000,
  "securityDeposit": 10000
}
```
- **Operations Performed:**
  1. Sets `User.approvalStatus = 'approved'`, `User.approvedBy = ownerId`, `User.approvedAt = now`.
  2. Sets `Tenant.approvalStatus = 'approved'`.
  3. If `roomId` is provided:
     - Validates room vacancy against `maxOccupancy`.
     - Assigns `tenant.room = roomId`, `tenant.status = 'active'`.
     - Increments room occupancy.
     - Adds tenant to Room Group Conversation and Community Group Conversation.
  4. Dispatches approval notification to tenant.

### C. Reject Tenant
- **Route:** `PUT /api/owner/registrations/:id/reject`
- **Access:** Owner only
- **Payload:** `{ "reason": "Application criteria not met." }`
- **Operations Performed:**
  1. Sets `User.approvalStatus = 'rejected'`, `User.rejectionReason = reason`.
  2. Sets `Tenant.approvalStatus = 'rejected'`.
  3. Subsequent login attempts return HTTP `403` with rejection explanation.

---

## 4. Mobile UI Implementation
- **`register_screen.dart`:**
  - Removed Owner toggle chip.
  - Submits registration with `role: "TENANT"`.
  - Shows branded success dialog: *"Application Submitted! Your registration is pending approval by the owner."*
- **`login_screen.dart`:**
  - Detects HTTP 403 `approvalStatus === 'pending'` or `'rejected'`.
  - Displays modal dialog explaining account status with *"I Understand"* confirmation.
- **`owner_registrations_screen.dart`:**
  - Filter tabs: Pending, Approved, All.
  - Approve action opens modal with room vacancy selector (e.g. `Room G101 (1/2 occupants) - Rs. 8,000/mo`).
  - Reject action prompts for optional reason before rejecting.
