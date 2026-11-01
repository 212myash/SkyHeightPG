const express = require("express");
const router = express.Router();

const {
  registerUser,
  loginUser,
  getProfile,
  changePassword,
  getOwnerStatus
} = require("../controllers/authController");

const { protect, authorize, optionalAuth } = require("../middleware/authMiddleware");

// Public/Bootstrap: Check if owner account already exists
router.get("/owner-status", getOwnerStatus);

// Register API (supports initial owner bootstrap, tenant public signup, or owner-created accounts)
router.post("/register", optionalAuth, registerUser);

// Login API
router.post("/login", loginUser);

// Profile API (Protected)
router.get("/profile", protect, getProfile);

// Change Password API (Protected)
router.put("/change-password", protect, changePassword);

// Role verification endpoints (Used for role checks and authorization testing)
router.get("/owner-check", protect, authorize("owner"), (req, res) => {
  res.json({
    success: true,
    message: "Owner role access verified.",
    user: req.user
  });
});

router.get("/tenant-check", protect, authorize("tenant"), (req, res) => {
  res.json({
    success: true,
    message: "Tenant role access verified.",
    user: req.user
  });
});

module.exports = router;
