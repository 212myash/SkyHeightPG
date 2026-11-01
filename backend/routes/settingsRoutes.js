const express = require("express");
const router = express.Router();

const {
  getSettings,
  updateSettings
} = require("../controllers/settingsController");

const { protect, authorize } = require("../middleware/authMiddleware");

// All settings routes require authentication
router.use(protect);

// Get PG settings (Owner / Tenant)
router.get("/", getSettings);

// Update PG settings (Owner only)
router.put("/", authorize("owner"), updateSettings);

module.exports = router;
