const express = require("express");
const router = express.Router();

const {
  getDashboardSummary,
  getFinancialReport
} = require("../controllers/dashboardController");

const { protect, authorize } = require("../middleware/authMiddleware");

// All dashboard routes are restricted to Owner
router.use(protect, authorize("owner"));

// Dashboard summary
router.get("/summary", getDashboardSummary);

// Financial reports
router.get("/reports/financial", getFinancialReport);

module.exports = router;
