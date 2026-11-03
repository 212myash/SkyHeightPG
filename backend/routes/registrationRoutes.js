const express = require("express");
const router = express.Router();
const {
  getRegistrations,
  approveRegistration,
  rejectRegistration
} = require("../controllers/registrationController");
const { protect, authorize } = require("../middleware/authMiddleware");

// All registration management endpoints require owner role
router.use(protect);
router.use(authorize("owner"));

router.get("/", getRegistrations);
router.put("/:id/approve", approveRegistration);
router.put("/:id/reject", rejectRegistration);

module.exports = router;
