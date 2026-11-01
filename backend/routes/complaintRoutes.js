const express = require("express");
const router = express.Router();

const {
  createComplaint,
  getMyComplaints,
  getAllComplaints,
  getComplaintById,
  updateComplaintStatus
} = require("../controllers/complaintController");

const { protect, authorize } = require("../middleware/authMiddleware");

// All complaint routes require authentication
router.use(protect);

// Current tenant's complaints
router.get("/my-complaints", authorize("tenant"), getMyComplaints);

// Register a new complaint (Tenant only)
router.post("/", authorize("tenant"), createComplaint);

// List all complaints (Owner only)
router.get("/", authorize("owner"), getAllComplaints);

// Single complaint details (Owner or Complaint owner)
router.get("/:id", getComplaintById);

// Update complaint status / resolution (Owner only)
router.put("/:id/status", authorize("owner"), updateComplaintStatus);

module.exports = router;
