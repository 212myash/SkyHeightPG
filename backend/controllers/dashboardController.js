const Room = require("../models/Room");
const Tenant = require("../models/Tenant");
const Bill = require("../models/Bill");
const Payment = require("../models/Payment");
const Expense = require("../models/Expense");
const Complaint = require("../models/Complaint");
const MeterReading = require("../models/MeterReading");

/**
 * Helper to get current YYYY-MM
 */
const getCurrentMonthString = () => {
  const now = new Date();
  const year = now.getFullYear();
  const month = String(now.getMonth() + 1).padStart(2, "0");
  return `${year}-${month}`;
};

/**
 * @desc    Get comprehensive Owner Dashboard summary
 * @route   GET /api/dashboard/summary
 * @access  Private (Owner only)
 */
const getDashboardSummary = async (req, res) => {
  try {
    const currentMonth = req.query.month || getCurrentMonthString();
    const [year, month] = currentMonth.split("-").map(Number);
    const startOfMonth = new Date(year, month - 1, 1);
    const endOfMonth = new Date(year, month, 0, 23, 59, 59);

    // 1. Room Metrics
    const totalRooms = await Room.countDocuments({ isActive: true });
    const occupiedRooms = await Room.countDocuments({ isActive: true, status: "occupied" });
    const vacantRooms = await Room.countDocuments({ isActive: true, status: "available" });

    const capacityAgg = await Room.aggregate([
      { $match: { isActive: true } },
      {
        $group: {
          _id: null,
          totalCapacity: { $sum: "$capacity" },
          occupiedBeds: { $sum: "$occupiedBeds" }
        }
      }
    ]);
    const totalCapacity = capacityAgg[0]?.totalCapacity || 0;
    const occupiedBeds = capacityAgg[0]?.occupiedBeds || 0;
    const availableBeds = Math.max(0, totalCapacity - occupiedBeds);

    // 2. Tenant Metrics
    const totalTenants = await Tenant.countDocuments({ status: "active" });

    // 3. Financial Metrics (Current Month)
    // Total Rent Collected from Verified Payments in this month
    const paymentsAgg = await Payment.aggregate([
      {
        $match: {
          verificationStatus: "verified",
          paymentDate: { $gte: startOfMonth, $lte: endOfMonth }
        }
      },
      {
        $group: {
          _id: null,
          totalCollected: { $sum: "$amount" }
        }
      }
    ]);
    const monthlyRentCollection = paymentsAgg[0]?.totalCollected || 0;

    // Pending Payments from All Unpaid Bills
    const pendingBillsAgg = await Bill.aggregate([
      {
        $match: {
          paymentStatus: { $in: ["pending", "partially_paid", "overdue"] }
        }
      },
      {
        $group: {
          _id: null,
          totalBilled: { $sum: "$totalAmount" },
          totalPaid: { $sum: "$paidAmount" }
        }
      }
    ]);
    const totalBilled = pendingBillsAgg[0]?.totalBilled || 0;
    const totalPaid = pendingBillsAgg[0]?.totalPaid || 0;
    const pendingPayments = Math.max(0, Math.round((totalBilled - totalPaid) * 100) / 100);

    // Electricity Consumption for this month
    const readingsAgg = await MeterReading.aggregate([
      { $match: { readingMonth: currentMonth } },
      {
        $group: {
          _id: null,
          totalUnits: { $sum: "$unitsConsumed" },
          totalAmount: { $sum: "$electricityAmount" }
        }
      }
    ]);
    const electricityUnits = readingsAgg[0]?.totalUnits || 0;
    const electricityAmount = readingsAgg[0]?.totalAmount || 0;

    // Monthly Expenses
    const expensesAgg = await Expense.aggregate([
      {
        $match: {
          date: { $gte: startOfMonth, $lte: endOfMonth }
        }
      },
      {
        $group: {
          _id: null,
          totalExpenses: { $sum: "$amount" }
        }
      }
    ]);
    const monthlyExpenses = expensesAgg[0]?.totalExpenses || 0;

    // Net Income
    const netIncome = Math.round((monthlyRentCollection - monthlyExpenses) * 100) / 100;

    // 4. Complaints
    const openComplaints = await Complaint.countDocuments({ status: { $in: ["open", "in_progress"] } });

    // 5. Recent Transactions
    const recentTransactions = await Payment.find({ verificationStatus: "verified" })
      .populate("tenant", "fullName phone")
      .populate("bill", "billingMonth")
      .sort({ paymentDate: -1 })
      .limit(5);

    // 6. Recent Complaints
    const recentComplaints = await Complaint.find({ status: { $in: ["open", "in_progress"] } })
      .populate("tenant", "fullName")
      .populate("room", "roomNumber")
      .sort({ createdAt: -1 })
      .limit(5);

    return res.status(200).json({
      success: true,
      data: {
        month: currentMonth,
        rooms: {
          total: totalRooms,
          occupied: occupiedRooms,
          vacant: vacantRooms,
          totalCapacity,
          occupiedBeds,
          availableBeds
        },
        tenants: {
          active: totalTenants
        },
        financials: {
          monthlyRentCollection: Math.round(monthlyRentCollection * 100) / 100,
          pendingPayments,
          monthlyExpenses: Math.round(monthlyExpenses * 100) / 100,
          netIncome
        },
        electricity: {
          unitsConsumed: Math.round(electricityUnits * 100) / 100,
          totalAmount: Math.round(electricityAmount * 100) / 100
        },
        complaints: {
          open: openComplaints
        },
        recentTransactions,
        recentComplaints
      }
    });
  } catch (error) {
    console.error("Dashboard Summary Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error generating dashboard summary.",
      error: error.message
    });
  }
};

/**
 * @desc    Get detailed financial report for a specific month
 * @route   GET /api/dashboard/reports/financial
 * @access  Private (Owner only)
 */
const getFinancialReport = async (req, res) => {
  try {
    const month = req.query.month || getCurrentMonthString();
    const [year, m] = month.split("-").map(Number);
    const startOfMonth = new Date(year, m - 1, 1);
    const endOfMonth = new Date(year, m, 0, 23, 59, 59);

    // 1. Collections breakdown (Cash vs UPI)
    const collections = await Payment.aggregate([
      {
        $match: {
          verificationStatus: "verified",
          paymentDate: { $gte: startOfMonth, $lte: endOfMonth }
        }
      },
      {
        $group: {
          _id: "$paymentMethod",
          totalAmount: { $sum: "$amount" },
          count: { $sum: 1 }
        }
      }
    ]);

    const totalCollected = collections.reduce((acc, c) => acc + c.totalAmount, 0);

    // 2. Expenses breakdown by category
    const expenses = await Expense.aggregate([
      {
        $match: {
          date: { $gte: startOfMonth, $lte: endOfMonth }
        }
      },
      {
        $group: {
          _id: "$category",
          totalAmount: { $sum: "$amount" },
          count: { $sum: 1 }
        }
      },
      { $sort: { totalAmount: -1 } }
    ]);

    const totalExpenses = expenses.reduce((acc, e) => acc + e.totalAmount, 0);
    const netProfit = Math.round((totalCollected - totalExpenses) * 100) / 100;

    // 3. Billing Stats
    const bills = await Bill.find({ billingMonth: month });
    const totalBilled = bills.reduce((acc, b) => acc + b.totalAmount, 0);
    const totalPaidOnBills = bills.reduce((acc, b) => acc + b.paidAmount, 0);
    const collectionEfficiency = totalBilled > 0 ? Math.round((totalPaidOnBills / totalBilled) * 100) : 0;

    return res.status(200).json({
      success: true,
      data: {
        month,
        summary: {
          totalBilled: Math.round(totalBilled * 100) / 100,
          totalCollected: Math.round(totalCollected * 100) / 100,
          totalExpenses: Math.round(totalExpenses * 100) / 100,
          netProfit,
          collectionEfficiencyPercent: collectionEfficiency
        },
        collectionsByMethod: collections,
        expensesByCategory: expenses
      }
    });
  } catch (error) {
    console.error("Financial Report Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error generating financial report.",
      error: error.message
    });
  }
};

module.exports = {
  getDashboardSummary,
  getFinancialReport
};
