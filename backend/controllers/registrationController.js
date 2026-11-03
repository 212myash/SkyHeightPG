const User = require("../models/User");
const Tenant = require("../models/Tenant");
const Room = require("../models/Room");
const Notification = require("../models/Notification");
const Conversation = require("../models/Conversation");
const OccupancyHistory = require("../models/OccupancyHistory");
const { isValidObjectId } = require("../utils/validateObjectId");
const pushService = require("../services/pushNotificationService");

/**
 * @desc    Get all pending or filtered registrations
 * @route   GET /api/owner/registrations
 * @access  Private (Owner only)
 */
const getRegistrations = async (req, res) => {
  try {
    const status = req.query.status || "pending";
    const userQuery = { role: "tenant" };
    if (status !== "all") {
      userQuery.approvalStatus = status;
    }

    const users = await User.find(userQuery).sort({ createdAt: -1 });

    // Attach tenant profiles
    const registrations = await Promise.all(
      users.map(async (user) => {
        const tenant = await Tenant.findOne({ user: user._id }).populate("room", "roomNumber floor");
        return {
          _id: user._id,
          name: user.name,
          email: user.email,
          phone: user.phone,
          role: user.role,
          approvalStatus: user.approvalStatus,
          rejectionReason: user.rejectionReason,
          approvedAt: user.approvedAt,
          createdAt: user.createdAt,
          tenant: tenant
            ? {
                _id: tenant._id,
                room: tenant.room,
                monthlyRent: tenant.monthlyRent,
                securityDeposit: tenant.securityDeposit,
                status: tenant.status
              }
            : null
        };
      })
    );

    return res.status(200).json({
      success: true,
      count: registrations.length,
      data: registrations
    });
  } catch (error) {
    console.error("Get Registrations Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching registrations.",
      error: error.message
    });
  }
};

/**
 * @desc    Approve a tenant registration
 * @route   PUT /api/owner/registrations/:id/approve
 * @access  Private (Owner only)
 */
const approveRegistration = async (req, res) => {
  try {
    const { id } = req.params;
    const { roomId, monthlyRent, securityDeposit } = req.body;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid ID format."
      });
    }

    // Try finding by user ID, or fallback to tenant ID
    let user = await User.findById(id);
    let tenant = null;

    if (user) {
      tenant = await Tenant.findOne({ user: user._id });
    } else {
      tenant = await Tenant.findById(id);
      if (tenant) {
        user = await User.findById(tenant.user);
      }
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User registration not found."
      });
    }

    // Assign room if provided
    let assignedRoom = null;
    if (roomId) {
      if (!isValidObjectId(roomId)) {
        return res.status(400).json({
          success: false,
          message: "Invalid roomId format."
        });
      }

      assignedRoom = await Room.findById(roomId);
      if (!assignedRoom) {
        return res.status(404).json({
          success: false,
          message: "Room to assign not found."
        });
      }

      if (!assignedRoom.isActive) {
        return res.status(400).json({
          success: false,
          message: "Cannot assign to an inactive room."
        });
      }

      const roomCap = assignedRoom.maxOccupancy || assignedRoom.capacity || 2;
      if (assignedRoom.occupiedBeds >= roomCap) {
        return res.status(400).json({
          success: false,
          message: `Room ${assignedRoom.roomNumber} is full. Max occupancy is ${roomCap}.`
        });
      }

      assignedRoom.occupiedBeds += 1;
      await assignedRoom.save();
    }

    // Update user approval
    user.approvalStatus = "approved";
    user.approvedBy = req.user._id;
    user.approvedAt = new Date();
    user.rejectionReason = "";
    await user.save();

    // Update or create tenant profile
    if (!tenant) {
      tenant = new Tenant({
        user: user._id,
        fullName: user.name,
        email: user.email,
        phone: user.phone || "0000000000"
      });
    }

    tenant.approvalStatus = "approved";
    if (assignedRoom) {
      tenant.room = assignedRoom._id;
      tenant.status = "active";
      tenant.monthlyRent = monthlyRent !== undefined ? Number(monthlyRent) : assignedRoom.monthlyRent;
      tenant.securityDeposit = securityDeposit !== undefined ? Number(securityDeposit) : 0;
    } else {
      tenant.status = "pending_allocation";
    }
    await tenant.save();

    // Add user to room conversation if assigned
    if (assignedRoom) {
      try {
        let roomConv = await Conversation.findOne({ type: "room", room: assignedRoom._id });
        if (!roomConv) {
          roomConv = await Conversation.create({
            type: "room",
            name: `Room ${assignedRoom.roomNumber} Group`,
            room: assignedRoom._id,
            participants: [user._id]
          });
        } else if (!roomConv.participants.some((p) => String(p) === String(user._id))) {
          roomConv.participants.push(user._id);
          await roomConv.save();
        }
      } catch (chatErr) {
        console.error("Failed to add approved tenant to room conversation:", chatErr);
      }

      // Record Occupancy History
      try {
        await OccupancyHistory.create({
          tenant: tenant._id,
          room: assignedRoom._id,
          roomNumber: assignedRoom.roomNumber,
          joiningDate: tenant.joiningDate || new Date(),
          occupancyStatus: "active",
          monthlyRentSnapshot: tenant.monthlyRent,
          reason: "Approved registration and initial room assignment",
          recordedBy: req.user._id
        });
      } catch (histErr) {
        console.error("Failed to create occupancy history on approval:", histErr);
      }
    }

    // Add user to community conversation
    try {
      let commConv = await Conversation.findOne({ type: "community" });
      if (!commConv) {
        commConv = await Conversation.create({
          type: "community",
          name: "Sky Height Apartment — Community",
          participants: [req.user._id, user._id]
        });
      } else if (!commConv.participants.some((p) => String(p) === String(user._id))) {
        commConv.participants.push(user._id);
        await commConv.save();
      }
    } catch (commErr) {
      console.error("Failed to add approved tenant to community conversation:", commErr);
    }

    // Notify approved tenant
    try {
      await Notification.create({
        recipient: user._id,
        sender: req.user._id,
        title: "Registration Approved!",
        message: assignedRoom
          ? `Welcome to Sky Height Apartment! Your registration has been approved and you are assigned to Room ${assignedRoom.roomNumber}.`
          : "Welcome to Sky Height Apartment! Your registration has been approved. You can now log in.",
        category: "registration_update",
        audience: "tenant",
        targetRoom: assignedRoom ? assignedRoom._id : null,
        targetTenant: tenant._id
      });

      // Dispatch push notification to tenant
      pushService.sendPushToUser(user._id, {
        title: "Registration Approved!",
        body: assignedRoom
          ? `Welcome to Sky Height Apartment! You are assigned to Room ${assignedRoom.roomNumber}.`
          : "Welcome to Sky Height Apartment! Your registration has been approved.",
        data: {
          category: "registration_update",
          screen: "/tenant/dashboard"
        },
        channelId: "alerts"
      }).catch((err) => console.error("Approval push error:", err.message));
    } catch (notifErr) {
      console.error("Failed to send approval notification:", notifErr);
    }

    return res.status(200).json({
      success: true,
      message: `Tenant '${user.name}' approved successfully.${assignedRoom ? ` Assigned to Room ${assignedRoom.roomNumber}.` : ""}`,
      data: {
        user: {
          _id: user._id,
          name: user.name,
          email: user.email,
          approvalStatus: user.approvalStatus,
          approvedAt: user.approvedAt
        },
        tenant
      }
    });
  } catch (error) {
    console.error("Approve Registration Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error approving registration.",
      error: error.message
    });
  }
};

/**
 * @desc    Reject a tenant registration
 * @route   PUT /api/owner/registrations/:id/reject
 * @access  Private (Owner only)
 */
const rejectRegistration = async (req, res) => {
  try {
    const { id } = req.params;
    const { reason } = req.body;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid ID format."
      });
    }

    let user = await User.findById(id);
    let tenant = null;

    if (user) {
      tenant = await Tenant.findOne({ user: user._id });
    } else {
      tenant = await Tenant.findById(id);
      if (tenant) {
        user = await User.findById(tenant.user);
      }
    }

    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User registration not found."
      });
    }

    const rejectionReason = reason ? reason.trim() : "Application requirements not met.";

    user.approvalStatus = "rejected";
    user.rejectionReason = rejectionReason;
    await user.save();

    if (tenant) {
      tenant.approvalStatus = "rejected";
      await tenant.save();
    }

    // Attempt to notify user
    try {
      await Notification.create({
        recipient: user._id,
        sender: req.user._id,
        title: "Registration Rejected",
        message: `Your registration for Sky Height Apartment was not approved: ${rejectionReason}`,
        category: "registration_update",
        audience: "tenant"
      });

      // Dispatch push notification to user
      pushService.sendPushToUser(user._id, {
        title: "Registration Rejected",
        body: `Your registration for Sky Height Apartment was not approved: ${rejectionReason}`,
        data: {
          category: "registration_update",
          screen: "/login"
        },
        channelId: "alerts"
      }).catch((err) => console.error("Rejection push error:", err.message));
    } catch (notifErr) {
      console.error("Failed to send rejection notification:", notifErr);
    }

    return res.status(200).json({
      success: true,
      message: `Registration for '${user.name}' has been rejected.`,
      data: {
        _id: user._id,
        name: user.name,
        email: user.email,
        approvalStatus: user.approvalStatus,
        rejectionReason: user.rejectionReason
      }
    });
  } catch (error) {
    console.error("Reject Registration Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error rejecting registration.",
      error: error.message
    });
  }
};

module.exports = {
  getRegistrations,
  approveRegistration,
  rejectRegistration
};
