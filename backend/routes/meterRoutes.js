const express = require("express");
const router = express.Router();

const {
  addMeterReading,
  getRoomMeterHistory,
  getMyMeterDetails,
  getMonthlyUsageReport
} = require("../controllers/meterController");

const { protect, authorize } = require("../middleware/authMiddleware");

// All meter routes require authentication
router.use(protect);

// Current tenant's meter info
router.get("/my-meter", authorize("tenant"), getMyMeterDetails);

// Monthly usage summary across PG (Owner only)
router.get("/monthly-usage", authorize("owner"), getMonthlyUsageReport);

// Record meter reading (Owner only)
router.post("/", authorize("owner"), addMeterReading);

// Room meter history (Owner, or Tenant residing in this room)
router.get("/room/:roomId", getRoomMeterHistory);

module.exports = router;
