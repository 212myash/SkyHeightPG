const Tenant = require("../models/Tenant");
const User = require("../models/User");
const Room = require("../models/Room");
const Conversation = require("../models/Conversation");
const OccupancyHistory = require("../models/OccupancyHistory");
const { isValidObjectId } = require("../utils/validateObjectId");

/**
 * @desc    Register and onboard a tenant (Owner creates account & tenant profile)
 * @route   POST /api/tenants
 * @access  Private (Owner only)
 */
const registerTenant = async (req, res) => {
  try {
    const {
      name,
      email,
      password,
      phone,
      roomId,
      monthlyRent,
      securityDeposit,
      assignedBed,
      address,
      emergencyContact,
      joiningDate
    } = req.body;

    // Validate required fields
    if (!name || !email || !password || !phone || !roomId) {
      return res.status(400).json({
        success: false,
        message: "Please provide name, email, password, phone, and roomId."
      });
    }

    if (!isValidObjectId(roomId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid roomId format."
      });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Check user uniqueness
    const existingUser = await User.findOne({ email: normalizedEmail });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "A user account with this email already exists."
      });
    }

    // Check room validity and capacity
    const room = await Room.findById(roomId);
    if (!room) {
      return res.status(404).json({
        success: false,
        message: "Assigned room not found."
      });
    }

    if (!room.isActive) {
      return res.status(400).json({
        success: false,
        message: "Cannot assign tenant to an inactive room."
      });
    }

    if (room.occupiedBeds >= room.capacity) {
      return res.status(400).json({
        success: false,
        message: `Room ${room.roomNumber} is full. Capacity is ${room.capacity} beds.`
      });
    }

    // 1. Create User account
    const user = await User.create({
      name: name.trim(),
      email: normalizedEmail,
      password,
      phone: phone.trim(),
      role: "tenant",
      isActive: true
    });

    // 2. Create Tenant profile
    const rentAmount = monthlyRent !== undefined ? Number(monthlyRent) : room.monthlyRent;
    const depositAmount = securityDeposit !== undefined ? Number(securityDeposit) : 0;

    const tenant = await Tenant.create({
      user: user._id,
      room: room._id,
      fullName: name.trim(),
      phone: phone.trim(),
      email: normalizedEmail,
      monthlyRent: rentAmount,
      securityDeposit: depositAmount,
      assignedBed: assignedBed || `Bed ${room.occupiedBeds + 1}`,
      address: address || {},
      emergencyContact: emergencyContact || {},
      joiningDate: joiningDate || Date.now(),
      status: "active"
    });

    // 3. Increment Room Occupied Beds
    room.occupiedBeds += 1;
    await room.save();

    // 4. Create active OccupancyHistory record
    try {
      await OccupancyHistory.create({
        tenant: tenant._id,
        room: room._id,
        roomNumber: room.roomNumber,
        joiningDate: tenant.joiningDate || new Date(),
        occupancyStatus: "active",
        monthlyRentSnapshot: tenant.monthlyRent,
        reason: "Initial registration and room assignment",
        recordedBy: req.user ? req.user._id : null
      });
    } catch (histErr) {
      console.error("Failed to create occupancy history on registerTenant:", histErr);
    }

    return res.status(201).json({
      success: true,
      message: "Tenant registered and assigned to room successfully.",
      data: {
        tenant,
        user: {
          _id: user._id,
          name: user.name,
          email: user.email,
          role: user.role
        },
        room: {
          _id: room._id,
          roomNumber: room.roomNumber,
          occupiedBeds: room.occupiedBeds,
          capacity: room.capacity
        }
      }
    });
  } catch (error) {
    console.error("Register Tenant Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error registering tenant.",
      error: error.message
    });
  }
};

/**
 * @desc    Get all tenants with search and filter
 * @route   GET /api/tenants
 * @access  Private (Owner only)
 */
const getAllTenants = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.max(1, Math.min(100, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const query = {};

    if (req.query.status) {
      query.status = req.query.status;
    }
    if (req.query.roomId && isValidObjectId(req.query.roomId)) {
      query.room = req.query.roomId;
    }
    if (req.query.search) {
      const regex = new RegExp(req.query.search, "i");
      query.$or = [{ fullName: regex }, { phone: regex }, { email: regex }];
    }

    const totalTenants = await Tenant.countDocuments(query);
    const tenants = await Tenant.find(query)
      .populate("room", "roomNumber floor roomType monthlyRent")
      .populate("user", "name email isActive")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    return res.status(200).json({
      success: true,
      count: tenants.length,
      pagination: {
        total: totalTenants,
        page,
        pages: Math.ceil(totalTenants / limit),
        limit
      },
      data: tenants
    });
  } catch (error) {
    console.error("Get All Tenants Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching tenants.",
      error: error.message
    });
  }
};

/**
 * @desc    Get tenant profile for logged-in tenant
 * @route   GET /api/tenants/me
 * @access  Private (Tenant only)
 */
const getMyTenantProfile = async (req, res) => {
  try {
    const tenant = await Tenant.findOne({ user: req.user._id })
      .populate("room", "roomNumber floor roomType monthlyRent amenities")
      .populate("user", "name email phone");

    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "No tenant profile found for this account."
      });
    }

    return res.status(200).json({
      success: true,
      data: tenant
    });
  } catch (error) {
    console.error("Get My Tenant Profile Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error retrieving tenant profile.",
      error: error.message
    });
  }
};

/**
 * @desc    Get tenant by ID
 * @route   GET /api/tenants/:id
 * @access  Private (Owner or Self)
 */
const getTenantById = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Tenant ID format."
      });
    }

    const tenant = await Tenant.findById(id)
      .populate("room", "roomNumber floor roomType monthlyRent amenities")
      .populate("user", "name email phone isActive");

    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "Tenant not found."
      });
    }

    // Role verification: Tenant can only view their own record
    if (req.user.role === "tenant" && String(tenant.user._id) !== String(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: "Forbidden: You are not authorized to view another tenant's profile."
      });
    }

    return res.status(200).json({
      success: true,
      data: tenant
    });
  } catch (error) {
    console.error("Get Tenant By ID Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching tenant.",
      error: error.message
    });
  }
};

/**
 * @desc    Update tenant details
 * @route   PUT /api/tenants/:id
 * @access  Private (Owner or Self for contact info)
 */
const updateTenant = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Tenant ID format."
      });
    }

    const tenant = await Tenant.findById(id);
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "Tenant not found."
      });
    }

    // Authorization check
    if (req.user.role === "tenant" && String(tenant.user) !== String(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: "Forbidden: You can only update your own profile."
      });
    }

    // If tenant is updating, allow only contact and address updates
    if (req.user.role === "tenant") {
      const { phone, address, emergencyContact } = req.body;
      if (phone) tenant.phone = phone.trim();
      if (address) tenant.address = { ...tenant.address, ...address };
      if (emergencyContact) tenant.emergencyContact = { ...tenant.emergencyContact, ...emergencyContact };
    } else {
      // Owner can update all fields
      const { fullName, phone, monthlyRent, securityDeposit, assignedBed, address, emergencyContact, status } = req.body;
      if (fullName) tenant.fullName = fullName.trim();
      if (phone) tenant.phone = phone.trim();
      if (monthlyRent !== undefined) tenant.monthlyRent = Number(monthlyRent);
      if (securityDeposit !== undefined) tenant.securityDeposit = Number(securityDeposit);
      if (assignedBed) tenant.assignedBed = assignedBed.trim();
      if (address) tenant.address = address;
      if (emergencyContact) tenant.emergencyContact = emergencyContact;

      // Handle room bed occupancy sync if status changes
      if (status && status !== tenant.status) {
        const room = await Room.findById(tenant.room);
        if (status === "vacated" && tenant.status !== "vacated" && room && room.occupiedBeds > 0) {
          room.occupiedBeds = Math.max(0, room.occupiedBeds - 1);
          await room.save();
        } else if (tenant.status === "vacated" && status !== "vacated" && room) {
          if (room.occupiedBeds >= room.capacity) {
            return res.status(400).json({
              success: false,
              message: `Cannot reactivate tenant: Room ${room.roomNumber} is already at full capacity (${room.capacity}).`
            });
          }
          room.occupiedBeds += 1;
          await room.save();
        }
        tenant.status = status;
      }
    }

    await tenant.save();

    return res.status(200).json({
      success: true,
      message: "Tenant updated successfully.",
      data: tenant
    });
  } catch (error) {
    console.error("Update Tenant Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error updating tenant.",
      error: error.message
    });
  }
};

/**
 * @desc    Assign a room to a tenant (e.g. pending allocation or unassigned)
 * @route   PUT /api/tenants/:id/assign-room
 * @access  Private (Owner only)
 */
const assignRoom = async (req, res) => {
  try {
    const { id } = req.params;
    const { roomId, monthlyRent, securityDeposit } = req.body;

    if (!isValidObjectId(id) || !isValidObjectId(roomId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid tenant ID or roomId format."
      });
    }

    const tenant = await Tenant.findById(id);
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "Tenant not found."
      });
    }

    const room = await Room.findById(roomId);
    if (!room) {
      return res.status(404).json({
        success: false,
        message: "Room not found."
      });
    }

    if (!room.isActive) {
      return res.status(400).json({
        success: false,
        message: "Cannot assign to an inactive room."
      });
    }

    const maxOcc = room.maxOccupancy || room.capacity || 2;
    if (room.occupiedBeds >= maxOcc) {
      return res.status(400).json({
        success: false,
        message: `Room ${room.roomNumber} is full. Max occupancy is ${maxOcc}.`
      });
    }

    // If tenant was previously in another room, decrement old room
    if (tenant.room && String(tenant.room) !== String(roomId)) {
      const oldRoom = await Room.findById(tenant.room);
      if (oldRoom && oldRoom.occupiedBeds > 0) {
        oldRoom.occupiedBeds = Math.max(0, oldRoom.occupiedBeds - 1);
        await oldRoom.save();
      }
      // Remove from old room conversation
      try {
        await Conversation.updateOne(
          { type: "room", room: tenant.room },
          { $pull: { participants: tenant.user } }
        );
      } catch (convErr) {
        console.error("Error removing from old room conversation:", convErr);
      }
    }

    // Increment new room
    room.occupiedBeds += 1;
    await room.save();

    // Update tenant
    tenant.room = room._id;
    tenant.status = "active";
    if (monthlyRent !== undefined && Number(monthlyRent) >= 0) {
      tenant.monthlyRent = Number(monthlyRent);
    } else {
      tenant.monthlyRent = room.monthlyRent;
    }
    if (securityDeposit !== undefined && Number(securityDeposit) >= 0) {
      tenant.securityDeposit = Number(securityDeposit);
    }
    await tenant.save();

    // Add tenant user to new room conversation
    try {
      let roomConv = await Conversation.findOne({ type: "room", room: room._id });
      if (!roomConv) {
        roomConv = await Conversation.create({
          type: "room",
          name: `Room ${room.roomNumber} Group`,
          room: room._id,
          participants: [tenant.user]
        });
      } else if (!roomConv.participants.some((p) => String(p) === String(tenant.user))) {
        roomConv.participants.push(tenant.user);
        await roomConv.save();
      }
    } catch (convErr) {
      console.error("Error adding to room conversation:", convErr);
    }

    // Record Occupancy History
    try {
      // Close any existing active occupancy records
      await OccupancyHistory.updateMany(
        { tenant: tenant._id, occupancyStatus: "active" },
        {
          leavingDate: new Date(),
          occupancyStatus: "transferred",
          reason: `Reassigned to Room ${room.roomNumber}`
        }
      );

      // Create new active record
      await OccupancyHistory.create({
        tenant: tenant._id,
        room: room._id,
        roomNumber: room.roomNumber,
        joiningDate: new Date(),
        occupancyStatus: "active",
        monthlyRentSnapshot: tenant.monthlyRent,
        reason: req.body.reason ? req.body.reason.trim() : "Room allocation",
        recordedBy: req.user ? req.user._id : null
      });
    } catch (histErr) {
      console.error("Error updating occupancy history on assignRoom:", histErr);
    }

    return res.status(200).json({
      success: true,
      message: `Tenant assigned to Room ${room.roomNumber} successfully.`,
      data: {
        tenant,
        room: {
          _id: room._id,
          roomNumber: room.roomNumber,
          maxOccupancy: maxOcc,
          currentOccupancy: room.occupiedBeds
        }
      }
    });
  } catch (error) {
    console.error("Assign Room Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error assigning room.",
      error: error.message
    });
  }
};

/**
 * @desc    Change room assignment for tenant
 * @route   PUT /api/tenants/:id/change-room
 * @access  Private (Owner only)
 */
const changeRoomAssignment = async (req, res) => {
  try {
    const { id } = req.params;
    const { newRoomId, assignedBed, monthlyRent } = req.body;

    if (!isValidObjectId(id) || !isValidObjectId(newRoomId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid tenant ID or newRoomId format."
      });
    }

    const tenant = await Tenant.findById(id);
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "Tenant not found."
      });
    }

    if (String(tenant.room) === String(newRoomId)) {
      return res.status(400).json({
        success: false,
        message: "Tenant is already assigned to this room."
      });
    }

    const newRoom = await Room.findById(newRoomId);
    if (!newRoom) {
      return res.status(404).json({
        success: false,
        message: "New room not found."
      });
    }

    if (!newRoom.isActive) {
      return res.status(400).json({
        success: false,
        message: "New room is deactivated."
      });
    }

    const newCap = newRoom.maxOccupancy || newRoom.capacity || 2;
    if (newRoom.occupiedBeds >= newCap) {
      return res.status(400).json({
        success: false,
        message: `New room ${newRoom.roomNumber} is full. Max occupancy is ${newCap}.`
      });
    }

    // Decrement old room
    const oldRoom = await Room.findById(tenant.room);
    if (oldRoom && oldRoom.occupiedBeds > 0) {
      oldRoom.occupiedBeds = Math.max(0, oldRoom.occupiedBeds - 1);
      await oldRoom.save();
    }

    // Revoke old room conversation access
    if (tenant.room) {
      try {
        await Conversation.updateOne(
          { type: "room", room: tenant.room },
          { $pull: { participants: tenant.user } }
        );
      } catch (convErr) {
        console.error("Error revoking old room conversation access:", convErr);
      }
    }

    // Increment new room
    newRoom.occupiedBeds += 1;
    await newRoom.save();

    // Update tenant
    tenant.room = newRoom._id;
    if (assignedBed) tenant.assignedBed = assignedBed.trim();
    if (monthlyRent !== undefined && Number(monthlyRent) >= 0) {
      tenant.monthlyRent = Number(monthlyRent);
    }
    await tenant.save();

    // Grant new room conversation access
    try {
      let roomConv = await Conversation.findOne({ type: "room", room: newRoom._id });
      if (!roomConv) {
        roomConv = await Conversation.create({
          type: "room",
          name: `Room ${newRoom.roomNumber} Group`,
          room: newRoom._id,
          participants: [tenant.user]
        });
      } else if (!roomConv.participants.some((p) => String(p) === String(tenant.user))) {
        roomConv.participants.push(tenant.user);
        await roomConv.save();
      }
    } catch (convErr) {
      console.error("Error updating new room conversation:", convErr);
    }

    // Occupancy History Audit: Close previous active record and open new record
    const transferDate = req.body.transferDate ? new Date(req.body.transferDate) : new Date();
    const reasonText = req.body.reason && req.body.reason.trim()
      ? req.body.reason.trim()
      : `Transferred from Room ${oldRoom ? oldRoom.roomNumber : ""} to Room ${newRoom.roomNumber}`;

    try {
      await OccupancyHistory.updateMany(
        { tenant: tenant._id, occupancyStatus: "active" },
        {
          leavingDate: transferDate,
          occupancyStatus: "transferred",
          reason: reasonText
        }
      );

      await OccupancyHistory.create({
        tenant: tenant._id,
        room: newRoom._id,
        roomNumber: newRoom.roomNumber,
        joiningDate: transferDate,
        occupancyStatus: "active",
        monthlyRentSnapshot: tenant.monthlyRent,
        reason: reasonText,
        recordedBy: req.user ? req.user._id : null
      });
    } catch (histErr) {
      console.error("Error updating occupancy history on transfer:", histErr);
    }

    return res.status(200).json({
      success: true,
      message: `Tenant successfully transferred to Room ${newRoom.roomNumber}.`,
      data: {
        tenant,
        newRoom: {
          _id: newRoom._id,
          roomNumber: newRoom.roomNumber,
          occupiedBeds: newRoom.occupiedBeds,
          capacity: newRoom.capacity,
          maxOccupancy: newCap
        }
      }
    });
  } catch (error) {
    console.error("Change Room Assignment Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error changing room assignment.",
      error: error.message
    });
  }
};

/**
 * @desc    Deactivate or vacate tenant
 * @route   PUT /api/tenants/:id/vacate
 * @access  Private (Owner only)
 */
const vacateTenant = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Tenant ID format."
      });
    }

    const tenant = await Tenant.findById(id);
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "Tenant not found."
      });
    }

    if (tenant.status === "vacated") {
      return res.status(400).json({
        success: false,
        message: "Tenant is already marked as vacated."
      });
    }

    // Decrement room occupancy
    if (tenant.room) {
      const room = await Room.findById(tenant.room);
      if (room && room.occupiedBeds > 0) {
        room.occupiedBeds = Math.max(0, room.occupiedBeds - 1);
        await room.save();
      }

      // Revoke room chat access
      try {
        await Conversation.updateOne(
          { type: "room", room: tenant.room },
          { $pull: { participants: tenant.user } }
        );
      } catch (convErr) {
        console.error("Error revoking vacated tenant room chat access:", convErr);
      }
    }

    const vacateDate = req.body.leavingDate ? new Date(req.body.leavingDate) : new Date();
    const reasonText = req.body.reason && req.body.reason.trim()
      ? req.body.reason.trim()
      : "Vacated apartment";

    tenant.status = "vacated";
    tenant.vacatedAt = vacateDate;
    await tenant.save();

    // Close active occupancy history record
    try {
      await OccupancyHistory.updateMany(
        { tenant: tenant._id, occupancyStatus: "active" },
        {
          leavingDate: vacateDate,
          occupancyStatus: "vacated",
          reason: reasonText
        }
      );
    } catch (histErr) {
      console.error("Error closing occupancy history on vacate:", histErr);
    }

    return res.status(200).json({
      success: true,
      message: "Tenant marked as vacated and room released.",
      data: tenant
    });
  } catch (error) {
    console.error("Vacate Tenant Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error vacating tenant.",
      error: error.message
    });
  }
};

/**
 * @desc    Get occupancy history for a tenant
 * @route   GET /api/tenants/:id/occupancy-history
 * @access  Private (Owner or Self)
 */
const getTenantOccupancyHistory = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Tenant ID format."
      });
    }

    const tenant = await Tenant.findById(id).populate("room");
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "Tenant not found."
      });
    }

    // Security & Authorization: Owner or Self only
    if (req.user.role !== "owner" && String(req.user._id) !== String(tenant.user)) {
      return res.status(403).json({
        success: false,
        message: "You are not authorized to view this tenant's occupancy history."
      });
    }

    let history = await OccupancyHistory.find({ tenant: tenant._id })
      .populate("room", "roomNumber floor roomType monthlyRent")
      .populate("recordedBy", "name email role")
      .sort({ joiningDate: -1, createdAt: -1 });

    // On-the-fly backfill for legacy tenants with allocated room and no history
    if (history.length === 0 && tenant.room) {
      try {
        const initialRecord = await OccupancyHistory.create({
          tenant: tenant._id,
          room: tenant.room._id,
          roomNumber: tenant.room.roomNumber,
          joiningDate: tenant.joiningDate || tenant.createdAt || new Date(),
          leavingDate: tenant.status === "vacated" ? (tenant.vacatedAt || tenant.updatedAt) : null,
          occupancyStatus: tenant.status === "vacated" ? "vacated" : "active",
          monthlyRentSnapshot: tenant.monthlyRent,
          reason: "Initial room allocation",
          recordedBy: null
        });
        history = [await initialRecord.populate("room", "roomNumber floor roomType monthlyRent")];
      } catch (backfillErr) {
        console.error("Backfill OccupancyHistory error:", backfillErr);
      }
    }

    return res.status(200).json({
      success: true,
      count: history.length,
      data: {
        tenant: {
          _id: tenant._id,
          fullName: tenant.fullName,
          phone: tenant.phone,
          email: tenant.email,
          status: tenant.status,
          vacatedAt: tenant.vacatedAt,
          currentRoom: tenant.room
            ? {
                _id: tenant.room._id,
                roomNumber: tenant.room.roomNumber
              }
            : null
        },
        history
      }
    });
  } catch (error) {
    console.error("Get Tenant Occupancy History Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching tenant occupancy history.",
      error: error.message
    });
  }
};

/**
 * @desc    Get current logged-in tenant's own occupancy history
 * @route   GET /api/tenants/me/occupancy-history
 * @access  Private (Tenant only)
 */
const getMyOccupancyHistory = async (req, res) => {
  try {
    const tenant = await Tenant.findOne({ user: req.user._id }).populate("room");
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "Tenant profile not found for this user."
      });
    }

    req.params.id = tenant._id.toString();
    return getTenantOccupancyHistory(req, res);
  } catch (error) {
    console.error("Get My Occupancy History Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching your occupancy history.",
      error: error.message
    });
  }
};

module.exports = {
  registerTenant,
  getAllTenants,
  getMyTenantProfile,
  getTenantById,
  updateTenant,
  assignRoom,
  changeRoomAssignment,
  vacateTenant,
  getTenantOccupancyHistory,
  getMyOccupancyHistory
};
