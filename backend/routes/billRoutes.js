const express = require("express");
const router = express.Router();

const {
  generateBills,
  getAllBills,
  getMyBills,
  getPendingBills,
  getBillById,
  updateBillAdjustments
} = require("../controllers/billController");

const { protect, authorize } = require("../middleware/authMiddleware");

// All bill routes require authentication
router.use(protect);

// Current tenant's bills
router.get("/my-bills", authorize("tenant"), getMyBills);

// Pending & overdue bills (Owner only)
router.get("/pending", authorize("owner"), getPendingBills);

// Generate monthly bills (Owner only)
router.post("/generate", authorize("owner"), generateBills);

// List all bills (Owner only)
router.get("/", authorize("owner"), getAllBills);

// Single bill details (Owner or Bill Owner)
router.get("/:id", getBillById);

// Update bill adjustments (Owner only)
router.put("/:id/adjustments", authorize("owner"), updateBillAdjustments);

module.exports = router;
