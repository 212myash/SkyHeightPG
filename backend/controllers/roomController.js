const Room = require("../models/Room");
const Tenant = require("../models/Tenant");
const Bill = require("../models/Bill");
const MeterReading = require("../models/MeterReading");
const { isValidObjectId } = require("../utils/validateObjectId");

/**
 * @desc    Create a new room
 * @route   POST /api/rooms
 * @access  Private (Owner only)
 */
const createRoom = async (req, res) => {
  try {
    const { roomNumber, floor, roomType, monthlyRent, capacity, amenities } = req.body;

    if (!roomNumber || floor === undefined || monthlyRent === undefined || capacity === undefined) {
      return res.status(400).json({
        success: false,
        message: "Please provide roomNumber, floor, monthlyRent, and capacity."
      });
    }

    const normalizedRoomNumber = String(roomNumber).trim().toUpperCase();

    // Check duplicate room number
    const existingRoom = await Room.findOne({ roomNumber: normalizedRoomNumber });
    if (existingRoom) {
      return res.status(400).json({
        success: false,
        message: `Room with number '${normalizedRoomNumber}' already exists.`
      });
    }

    if (Number(capacity) < 1) {
      return res.status(400).json({
        success: false,
        message: "Room capacity must be at least 1 bed."
      });
    }

    if (Number(monthlyRent) < 0) {
      return res.status(400).json({
        success: false,
        message: "Monthly rent cannot be negative."
      });
    }

    if (Number(floor) < 0) {
      return res.status(400).json({
        success: false,
        message: "Floor number cannot be negative."
      });
    }

    const room = await Room.create({
      roomNumber: normalizedRoomNumber,
      floor: Number(floor),
      roomType: roomType || "double",
      monthlyRent: Number(monthlyRent),
      capacity: Number(capacity),
      occupiedBeds: 0,
      amenities: Array.isArray(amenities) ? amenities : [],
      status: "available",
      isActive: true
    });

    return res.status(201).json({
      success: true,
      message: "Room created successfully.",
      data: room
    });
  } catch (error) {
    console.error("Create Room Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error creating room.",
      error: error.message
    });
  }
};

/**
 * @desc    Get all rooms with filtering and pagination
 * @route   GET /api/rooms
 * @access  Private (Owner / Tenant)
 */
const getAllRooms = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.max(1, Math.min(100, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const query = { isActive: true };

    // Filters
    if (req.query.floor !== undefined) {
      query.floor = Number(req.query.floor);
    }
    if (req.query.roomType) {
      query.roomType = req.query.roomType;
    }
    if (req.query.status) {
      query.status = req.query.status;
    }
    if (req.query.includeInactive === "true" && req.user.role === "owner") {
      delete query.isActive;
    }

    const totalRooms = await Room.countDocuments(query);
    const rooms = await Room.find(query)
      .sort({ roomNumber: 1 })
      .skip(skip)
      .limit(limit);

    return res.status(200).json({
      success: true,
      count: rooms.length,
      pagination: {
        total: totalRooms,
        page,
        pages: Math.ceil(totalRooms / limit),
        limit
      },
      data: rooms
    });
  } catch (error) {
    console.error("Get All Rooms Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching rooms.",
      error: error.message
    });
  }
};

/**
 * @desc    Get room by ID with occupant details
 * @route   GET /api/rooms/:id
 * @access  Private (Owner / Tenant)
 */
const getRoomById = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Room ID format."
      });
    }

    const room = await Room.findById(id);
    if (!room) {
      return res.status(404).json({
        success: false,
        message: "Room not found."
      });
    }

    // Fetch active tenants in this room
    const tenants = await Tenant.find({ room: room._id, status: "active" })
      .select("fullName phone email assignedBed joiningDate")
      .populate("user", "name email");

    return res.status(200).json({
      success: true,
      data: {
        ...room.toObject(),
        availableBeds: Math.max(0, room.capacity - room.occupiedBeds),
        tenants
      }
    });
  } catch (error) {
    console.error("Get Room By ID Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching room details.",
      error: error.message
    });
  }
};

/**
 * @desc    Update room details
 * @route   PUT /api/rooms/:id
 * @access  Private (Owner only)
 */
const updateRoom = async (req, res) => {
  try {
    const { id } = req.params;
    const { roomNumber, floor, roomType, monthlyRent, capacity, amenities, status, isActive } = req.body;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Room ID format."
      });
    }

    const room = await Room.findById(id);
    if (!room) {
      return res.status(404).json({
        success: false,
        message: "Room not found."
      });
    }

    // Check duplicate room number if changed
    if (roomNumber) {
      const normalizedRoomNumber = String(roomNumber).trim().toUpperCase();
      if (normalizedRoomNumber !== room.roomNumber) {
        const duplicate = await Room.findOne({ roomNumber: normalizedRoomNumber });
        if (duplicate) {
          return res.status(400).json({
            success: false,
            message: `Room with number '${normalizedRoomNumber}' already exists.`
          });
        }
        room.roomNumber = normalizedRoomNumber;
      }
    }

    // Validate new capacity against current occupants
    if (capacity !== undefined) {
      const newCapacity = Number(capacity);
      if (newCapacity < 1) {
        return res.status(400).json({
          success: false,
          message: "Room capacity must be at least 1."
        });
      }
      if (newCapacity < room.occupiedBeds) {
        return res.status(400).json({
          success: false,
          message: `Cannot reduce capacity to ${newCapacity} because ${room.occupiedBeds} beds are currently occupied.`
        });
      }
      room.capacity = newCapacity;
    }

    if (floor !== undefined) {
      if (Number(floor) < 0) {
        return res.status(400).json({ success: false, message: "Floor cannot be negative." });
      }
      room.floor = Number(floor);
    }

    if (monthlyRent !== undefined) {
      if (Number(monthlyRent) < 0) {
        return res.status(400).json({ success: false, message: "Monthly rent cannot be negative." });
      }
      room.monthlyRent = Number(monthlyRent);
    }

    if (roomType) room.roomType = roomType;
    if (Array.isArray(amenities)) room.amenities = amenities;
    if (status) room.status = status;
    if (isActive !== undefined) room.isActive = Boolean(isActive);

    await room.save();

    return res.status(200).json({
      success: true,
      message: "Room updated successfully.",
      data: room
    });
  } catch (error) {
    console.error("Update Room Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error updating room.",
      error: error.message
    });
  }
};

/**
 * @desc    Deactivate or safe delete room
 * @route   DELETE /api/rooms/:id
 * @access  Private (Owner only)
 */
const deleteRoom = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Room ID format."
      });
    }

    const room = await Room.findById(id);
    if (!room) {
      return res.status(404).json({
        success: false,
        message: "Room not found."
      });
    }

    // Check active tenants
    const activeTenantsCount = await Tenant.countDocuments({ room: room._id, status: "active" });
    if (activeTenantsCount > 0) {
      return res.status(400).json({
        success: false,
        message: `Cannot delete room with ${activeTenantsCount} active tenant(s). Please reassign or vacate tenants first.`
      });
    }

    // Check financial history
    const billsCount = await Bill.countDocuments({ room: room._id });
    const readingsCount = await MeterReading.countDocuments({ room: room._id });

    if (billsCount > 0 || readingsCount > 0) {
      // Safe deactivation
      room.isActive = false;
      room.status = "maintenance";
      await room.save();
      return res.status(200).json({
        success: true,
        message: "Room has historical bills or readings. It has been deactivated rather than hard-deleted.",
        deactivated: true
      });
    }

    // No history -> safe hard delete
    await Room.findByIdAndDelete(room._id);
    return res.status(200).json({
      success: true,
      message: "Room deleted successfully."
    });
  } catch (error) {
    console.error("Delete Room Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error deleting room.",
      error: error.message
    });
  }
};

/**
 * @desc    Get room occupancy summary stats
 * @route   GET /api/rooms/stats/occupancy
 * @access  Private (Owner only)
 */
const getOccupancyStats = async (req, res) => {
  try {
    const totalRooms = await Room.countDocuments({ isActive: true });
    const occupiedRooms = await Room.countDocuments({ isActive: true, status: "occupied" });
    const availableRooms = await Room.countDocuments({ isActive: true, status: "available" });
    const maintenanceRooms = await Room.countDocuments({ isActive: true, status: "maintenance" });

    const capacityAggregation = await Room.aggregate([
      { $match: { isActive: true } },
      {
        $group: {
          _id: null,
          totalCapacity: { $sum: "$capacity" },
          occupiedBeds: { $sum: "$occupiedBeds" }
        }
      }
    ]);

    const totalCapacity = capacityAggregation[0]?.totalCapacity || 0;
    const occupiedBeds = capacityAggregation[0]?.occupiedBeds || 0;
    const availableBeds = Math.max(0, totalCapacity - occupiedBeds);

    return res.status(200).json({
      success: true,
      data: {
        totalRooms,
        occupiedRooms,
        availableRooms,
        maintenanceRooms,
        totalCapacity,
        occupiedBeds,
        availableBeds
      }
    });
  } catch (error) {
    console.error("Get Occupancy Stats Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error retrieving occupancy stats.",
      error: error.message
    });
  }
};

module.exports = {
  createRoom,
  getAllRooms,
  getRoomById,
  updateRoom,
  deleteRoom,
  getOccupancyStats
};
