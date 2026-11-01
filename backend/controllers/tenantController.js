const Tenant = require("../models/Tenant");
const User = require("../models/User");
const Room = require("../models/Room");
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
      if (status) tenant.status = status;
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
 * @desc    Change room assignment for tenant
 * @route   PUT /api/tenants/:id/change-room
 * @access  Private (Owner only)
 */
const changeRoomAssignment = async (req, res) => {
  try {
    const { id } = req.params;
    const { newRoomId, assignedBed } = req.body;

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

    if (newRoom.occupiedBeds >= newRoom.capacity) {
      return res.status(400).json({
        success: false,
        message: `New room ${newRoom.roomNumber} is full. Capacity is ${newRoom.capacity}.`
      });
    }

    // Decrement old room
    const oldRoom = await Room.findById(tenant.room);
    if (oldRoom && oldRoom.occupiedBeds > 0) {
      oldRoom.occupiedBeds = Math.max(0, oldRoom.occupiedBeds - 1);
      await oldRoom.save();
    }

    // Increment new room
    newRoom.occupiedBeds += 1;
    await newRoom.save();

    // Update tenant
    tenant.room = newRoom._id;
    if (assignedBed) tenant.assignedBed = assignedBed.trim();
    await tenant.save();

    return res.status(200).json({
      success: true,
      message: `Tenant successfully transferred to Room ${newRoom.roomNumber}.`,
      data: {
        tenant,
        newRoom: {
          _id: newRoom._id,
          roomNumber: newRoom.roomNumber,
          occupiedBeds: newRoom.occupiedBeds,
          capacity: newRoom.capacity
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
    const room = await Room.findById(tenant.room);
    if (room && room.occupiedBeds > 0) {
      room.occupiedBeds = Math.max(0, room.occupiedBeds - 1);
      await room.save();
    }

    tenant.status = "vacated";
    await tenant.save();

    return res.status(200).json({
      success: true,
      message: "Tenant marked as vacated and room bed released.",
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

module.exports = {
  registerTenant,
  getAllTenants,
  getMyTenantProfile,
  getTenantById,
  updateTenant,
  changeRoomAssignment,
  vacateTenant
};
