const express = require("express");
const router = express.Router();

const {
  createRoom,
  getAllRooms,
  getRoomById,
  updateRoom,
  deleteRoom,
  getOccupancyStats
} = require("../controllers/roomController");

const { protect, authorize } = require("../middleware/authMiddleware");

// All room routes require authentication
router.use(protect);

// Occupancy stats (Owner only)
router.get("/stats/occupancy", authorize("owner"), getOccupancyStats);

// List all rooms (Owner / Tenant)
router.get("/", getAllRooms);

// Create room (Owner only)
router.post("/", authorize("owner"), createRoom);

// Get single room details
router.get("/:id", getRoomById);

// Update room (Owner only)
router.put("/:id", authorize("owner"), updateRoom);

// Delete/deactivate room (Owner only)
router.delete("/:id", authorize("owner"), deleteRoom);

module.exports = router;
