const express = require("express");
const router = express.Router();

const {
  addExpense,
  getAllExpenses,
  getExpenseSummary,
  getExpenseById,
  updateExpense,
  deleteExpense
} = require("../controllers/expenseController");

const { protect, authorize } = require("../middleware/authMiddleware");

// All expense routes require Owner authentication
router.use(protect, authorize("owner"));

// Summary of expenses
router.get("/summary", getExpenseSummary);

// List all expenses
router.get("/", getAllExpenses);

// Add new expense
router.post("/", addExpense);

// Get single expense
router.get("/:id", getExpenseById);

// Update expense
router.put("/:id", updateExpense);

// Delete expense
router.delete("/:id", deleteExpense);

module.exports = router;
