# Messaging & Chat System Architecture
**Project:** Sky Height Apartment  
**Document Version:** 1.0.0  
**Status:** Implemented & Verified  

---

## 1. Architectural Channels & Scope
The Messaging & Chat system in **Sky Height Apartment** provides three distinct, secure communication channels without third-party external dependencies:

```
+-----------------------------------------------------------------------------------------+
|                                3 COMMUNICATION CHANNELS                                 |
+-----------------------------------------------------------------------------------------+
|  1. PRIVATE DIRECT CHAT       |  2. SAME-ROOM GROUP CHAT      |  3. COMMUNITY GROUP     |
|  - Owner <-> Tenant (1-on-1)  |  - Active occupants of room   |  - All active residents |
|  - Rent queries & payment     |  - Split chores, groceries    |  - Apartment notices    |
|  - Confidential support       |  - Strict room isolation      |  - Owner moderation     |
|  - Retained across rooms      |  - Revoked on vacate/transfer |  - Safe broadcasting    |
+-----------------------------------------------------------------------------------------+
```

---

## 2. Dynamic Authorization & Room Access Governance
1. **Private Chats (`type: "private"`):**
   - Participants strictly restricted to the two authenticated user IDs (`$all: [req.user._id, otherUserId]`).
   - Unauthorized users receive HTTP `403 Forbidden`.
2. **Same-Room Group Chat (`type: "room"`):**
   - Tied directly to a physical `Room` (`room: roomId`).
   - Access is checked dynamically on every read (`GET /messages`) and write (`POST /messages`):
     ```javascript
     const tenant = await Tenant.findOne({ user: user._id, status: "active" });
     if (!tenant || !tenant.room || String(tenant.room) !== String(conversation.room)) {
       return { allowed: false, message: "Access denied. You are not an active occupant of this room." };
     }
     ```
   - **Automatic Revocation on Vacation/Transfer:** When an Owner transfers a tenant (`/change-room`) or vacates a tenant (`/vacate`), their access to the old room's group is revoked immediately. Attempting to post or read from the old room returns HTTP `403`.
3. **Community Group (`type: "community"`):**
   - Global channel titled `Sky Height Apartment — Community`.
   - Accessible to all currently active residents and the Owner.
   - Vacated or deactivated accounts are automatically denied access.

---

## 3. Database Models

### A. Conversation Model (`backend/models/Conversation.js`)
```javascript
{
  type: { type: String, enum: ["private", "room", "community"], required: true, index: true },
  name: { type: String, trim: true, default: "" },
  room: { type: ObjectId, ref: "Room", default: null, index: true },
  participants: [{ type: ObjectId, ref: "User", index: true }],
  lastMessage: {
    text: { type: String, default: "" },
    sender: { type: ObjectId, ref: "User", default: null },
    sentAt: { type: Date, default: Date.now }
  },
  lastMessageAt: { type: Date, default: Date.now, index: true },
  isActive: { type: Boolean, default: true }
}
```

### B. Message Model (`backend/models/Message.js`)
```javascript
{
  conversation: { type: ObjectId, ref: "Conversation", required: true, index: true },
  sender: { type: ObjectId, ref: "User", required: true, index: true },
  content: { type: String, required: true, trim: true },
  readBy: [{ type: ObjectId, ref: "User" }]
}
```

---

## 4. Real-Time Synchronization Protocol
To guarantee 100% operational reliability on Render, mobile background execution, and local development environments without requiring complex WebSocket reconnection logic:
- The Flutter `ConversationScreen` employs an active lightweight sync timer (3 seconds) while the chat view is active.
- Unread messages are marked read automatically as the user scrolls.
- Timers are safely cancelled in `dispose()` to prevent memory leaks and background battery drain.
