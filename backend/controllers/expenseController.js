const Expense = require("../models/Expense");
const { isValidObjectId } = require("../utils/validateObjectId");

/**
 * @desc    Add a new PG operational expense
 * @route   POST /api/expenses
 * @access  Private (Owner only)
 */
const addExpense = async (req, res) => {
  try {
    const { title, category, amount, date, description, receiptUrl } = req.body;

    if (!title || !category || amount === undefined) {
      return res.status(400).json({
        success: false,
        message: "Please provide title, category, and amount."
      });
    }

    const expAmount = Number(amount);
    if (expAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Expense amount must be greater than zero."
      });
    }

    const validCategories = [
      "maintenance",
      "utilities",
      "cleaning",
      "repairs",
      "supplies",
      "wifi",
      "taxes",
      "salary",
      "other"
    ];

    if (!validCategories.includes(category)) {
      return res.status(400).json({
        success: false,
        message: `Invalid category. Must be one of: ${validCategories.join(", ")}`
      });
    }

    const expense = await Expense.create({
      title: title.trim(),
      category,
      amount: expAmount,
      date: date ? new Date(date) : new Date(),
      description: description ? description.trim() : "",
      recordedBy: req.user._id,
      receiptUrl: receiptUrl ? receiptUrl.trim() : ""
    });

    return res.status(201).json({
      success: true,
      message: "Expense recorded successfully.",
      data: expense
    });
  } catch (error) {
    console.error("Add Expense Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error recording expense.",
      error: error.message
    });
  }
};

/**
 * @desc    List expenses with filtering & pagination
 * @route   GET /api/expenses
 * @access  Private (Owner only)
 */
const getAllExpenses = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.max(1, Math.min(100, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const query = {};

    if (req.query.category) {
      query.category = req.query.category;
    }

    // Month filter (YYYY-MM)
    if (req.query.month) {
      const [year, month] = req.query.month.split("-").map(Number);
      const start = new Date(year, month - 1, 1);
      const end = new Date(year, month, 0, 23, 59, 59);
      query.date = { $gte: start, $lte: end };
    }

    const totalExpenses = await Expense.countDocuments(query);
    const expenses = await Expense.find(query)
      .populate("recordedBy", "name")
      .sort({ date: -1 })
      .skip(skip)
      .limit(limit);

    return res.status(200).json({
      success: true,
      count: expenses.length,
      pagination: {
        total: totalExpenses,
        page,
        pages: Math.ceil(totalExpenses / limit),
        limit
      },
      data: expenses
    });
  } catch (error) {
    console.error("Get All Expenses Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching expenses.",
      error: error.message
    });
  }
};

/**
 * @desc    Get expense summary by category for a month
 * @route   GET /api/expenses/summary
 * @access  Private (Owner only)
 */
const getExpenseSummary = async (req, res) => {
  try {
    const { month } = req.query; // YYYY-MM

    let matchStage = {};
    if (month) {
      const [year, m] = month.split("-").map(Number);
      const start = new Date(year, m - 1, 1);
      const end = new Date(year, m, 0, 23, 59, 59);
      matchStage = { date: { $gte: start, $lte: end } };
    }

    const categoryBreakdown = await Expense.aggregate([
      { $match: matchStage },
      {
        $group: {
          _id: "$category",
          totalAmount: { $sum: "$amount" },
          count: { $sum: 1 }
        }
      },
      { $sort: { totalAmount: -1 } }
    ]);

    const totalSpent = categoryBreakdown.reduce((acc, cat) => acc + cat.totalAmount, 0);

    return res.status(200).json({
      success: true,
      month: month || "all-time",
      totalSpent: Math.round(totalSpent * 100) / 100,
      breakdown: categoryBreakdown
    });
  } catch (error) {
    console.error("Get Expense Summary Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error calculating expense summary.",
      error: error.message
    });
  }
};

/**
 * @desc    Get single expense by ID
 * @route   GET /api/expenses/:id
 * @access  Private (Owner only)
 */
const getExpenseById = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Expense ID format."
      });
    }

    const expense = await Expense.findById(id).populate("recordedBy", "name email");
    if (!expense) {
      return res.status(404).json({
        success: false,
        message: "Expense not found."
      });
    }

    return res.status(200).json({
      success: true,
      data: expense
    });
  } catch (error) {
    console.error("Get Expense By ID Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching expense.",
      error: error.message
    });
  }
};

/**
 * @desc    Update an expense
 * @route   PUT /api/expenses/:id
 * @access  Private (Owner only)
 */
const updateExpense = async (req, res) => {
  try {
    const { id } = req.params;
    const { title, category, amount, date, description, receiptUrl } = req.body;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Expense ID format."
      });
    }

    const expense = await Expense.findById(id);
    if (!expense) {
      return res.status(404).json({
        success: false,
        message: "Expense not found."
      });
    }

    if (title) expense.title = title.trim();
    if (category) expense.category = category;
    if (amount !== undefined) {
      const expAmount = Number(amount);
      if (expAmount <= 0) {
        return res.status(400).json({ success: false, message: "Amount must be greater than zero." });
      }
      expense.amount = expAmount;
    }
    if (date) expense.date = new Date(date);
    if (description !== undefined) expense.description = description.trim();
    if (receiptUrl !== undefined) expense.receiptUrl = receiptUrl.trim();

    await expense.save();

    return res.status(200).json({
      success: true,
      message: "Expense updated successfully.",
      data: expense
    });
  } catch (error) {
    console.error("Update Expense Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error updating expense.",
      error: error.message
    });
  }
};

/**
 * @desc    Delete an expense
 * @route   DELETE /api/expenses/:id
 * @access  Private (Owner only)
 */
const deleteExpense = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Expense ID format."
      });
    }

    const expense = await Expense.findByIdAndDelete(id);
    if (!expense) {
      return res.status(404).json({
        success: false,
        message: "Expense not found."
      });
    }

    return res.status(200).json({
      success: true,
      message: "Expense deleted successfully."
    });
  } catch (error) {
    console.error("Delete Expense Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error deleting expense.",
      error: error.message
    });
  }
};

module.exports = {
  addExpense,
  getAllExpenses,
  getExpenseSummary,
  getExpenseById,
  updateExpense,
  deleteExpense
};
