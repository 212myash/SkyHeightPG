const express = require("express");
const router = express.Router();

const {
  recordCashPayment,
  submitUpiPayment,
  verifyUpiPayment,
  getAllPayments,
  getMyPayments,
  getTenantBalance
} = require("../controllers/paymentController");

const { protect, authorize } = require("../middleware/authMiddleware");
const { paymentLimiter } = require("../middleware/rateLimiter");

// All payment routes require authentication
router.use(protect);

// Tenant routes
router.get("/my-payments", authorize("tenant"), getMyPayments);
router.post(["/upi/submit", "/upi"], authorize("tenant"), paymentLimiter, submitUpiPayment);

// Owner routes
router.post("/cash", authorize("owner"), recordCashPayment);
router.put("/:id/verify", authorize("owner"), verifyUpiPayment);
router.get("/", authorize("owner"), getAllPayments);

// Balance calculation (Owner or Self)
router.get("/balance/:tenantId", getTenantBalance);

module.exports = router;
