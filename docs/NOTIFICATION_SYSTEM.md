# In-App Notification Center Architecture
**Project:** Sky Height Apartment  
**Document Version:** 1.0.0  
**Status:** Implemented & Verified  

---

## 1. Overview & Objectives
The In-App Notification Center provides an operational communication backbone for **Sky Height Apartment**, enabling:
- Real-time broadcasting of apartment notices, maintenance schedules, and security alerts.
- Room-level announcements (e.g. room inspection or meter maintenance).
- Tenant-specific reminders (rent reminders, electricity bills, payment confirmations).
- Dynamic tenant replies that automatically route directly into a private conversation with the Owner.

---

## 2. Notification Categories & Taxonomy

The system defines 10 typed notification categories with specific visual icons and color tokens:

| Category Code | Display Name | Icon | Accent Color | Primary Use Case |
| :--- | :--- | :--- | :--- | :--- |
| `rent_reminder` | Rent Reminder | `currency_rupee` | Crimson Primary | Due date notifications for rent |
| `electricity_bill` | Electricity Bill | `bolt` | Crimson Primary | Monthly sub-meter bills generated |
| `payment_reminder`| Payment Follow-up | `receipt_long` | Primary Dark | Overdue bill notices |
| `payment_received`| Payment Confirmed | `check_circle` | Success Green | Instant receipt confirmation |
| `maintenance` | Maintenance | `build_circle` | Amber Warning | Water tank, elevator, plumbing |
| `complaint_update`| Complaint Status | `support_agent` | Blue Info | Updates on reported issues |
| `general_announcement`| Announcement | `campaign` | Blue Info | Apartment rules, events, notices |
| `security_alert` | Security Alert | `security` | Crimson Error | Gate timings, visitor guidelines |
| `registration_update`| Account Update | `person_add` | Success Green | Approval / rejection notices |
| `system` | System Notice | `info` | Slate Neutral | App updates and configurations |

---

## 3. Data Model & Indexing Strategy (`backend/models/Notification.js`)
```javascript
{
  recipient: { type: ObjectId, ref: "User", required: true, index: true },
  sender: { type: ObjectId, ref: "User", default: null },
  title: { type: String, required: true, trim: true },
  message: { type: String, required: true, trim: true },
  category: { type: String, enum: VALID_CATEGORIES, default: "general_announcement", index: true },
  audience: { type: String, enum: ["all", "room", "tenant"], default: "tenant" },
  targetRoom: { type: ObjectId, ref: "Room", default: null },
  targetTenant: { type: ObjectId, ref: "Tenant", default: null },
  dueDate: { type: Date, default: null },
  relatedBill: { type: ObjectId, ref: "Bill", default: null },
  relatedComplaint: { type: ObjectId, ref: "Complaint", default: null },
  isRead: { type: Boolean, default: false, index: true },
  readAt: { type: Date, default: null }
}
```

### High-Performance Compound Index:
```javascript
notificationSchema.index({ recipient: 1, isRead: 1, createdAt: -1 });
```
Enables instant badge resolution (`/unread-count`) and paginated timeline feeds with zero full-collection scans.

---

## 4. Audience Targeting Engine
When the Owner dispatches a notice (`POST /api/notifications`):
1. **Audience = `"all"`:**
   - Finds all active tenants (`Tenant.find({ status: "active" })`).
   - Generates an individual `Notification` document per tenant.
   - Ensures individual read/unread state tracking.
2. **Audience = `"room"`:**
   - Finds all active occupants in `targetRoom`.
   - Generates individual documents for occupants of that specific room only.
3. **Audience = `"tenant"`:**
   - Targets a specific tenant user account.

---

## 5. Tenant Reply Routing Workflow
When a tenant receives a notification (e.g. *Rent Reminder* or *Room Inspection Notice*) and clicks **"Reply"**:
1. Tenant inputs their response in the bottom sheet.
2. Flutter client calls `POST /api/notifications/:id/reply`.
3. Backend:
   - Resolves the Owner recipient.
   - Finds or auto-creates a private `Conversation` (`type: "private"`) between the Tenant and Owner.
   - Posts a `Message` formatted as: `[Re: Notice Title] Tenant message text`.
   - Updates conversation timestamp and dispatches an alert to the Owner.
   - Returns the `conversationId`.
4. Mobile app immediately navigates the tenant into the private chat screen (`/chat/:id`).
