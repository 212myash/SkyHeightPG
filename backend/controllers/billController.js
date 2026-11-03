const Bill = require("../models/Bill");
const Tenant = require("../models/Tenant");
const Room = require("../models/Room");
const MeterReading = require("../models/MeterReading");
const Payment = require("../models/Payment");
const PGSettings = require("../models/PGSettings");
const { isValidObjectId } = require("../utils/validateObjectId");
const pushService = require("../services/pushNotificationService");

/**
 * Helper to compute default due date from settings
 * @param {string} billingMonth YYYY-MM
 * @param {number} dueDay Default due day of month (e.g. 5)
 * @returns {Date}
 */
const computeDueDate = (billingMonth, dueDay = 5) => {
  const [year, month] = billingMonth.split("-").map(Number);
  // Default due date: e.g. 5th of that month or 5th of following month
  const date = new Date(year, month - 1, dueDay, 23, 59, 59);
  return date;
};

/**
 * @desc    Generate a bill for a tenant or bulk generate for all active tenants
 * @route   POST /api/bills/generate
 * @access  Private (Owner only)
 */
const generateBills = async (req, res) => {
  try {
    const {
      tenantId,
      billingMonth,
      dueDate,
      electricityAmount: customElecAmount,
      otherCharges,
      adjustments,
      notes,
      bulk
    } = req.body;

    if (!billingMonth) {
      return res.status(400).json({
        success: false,
        message: "Please provide billingMonth (YYYY-MM)."
      });
    }

    const monthRegex = /^\d{4}-(0[1-9]|1[0-2])$/;
    if (!monthRegex.test(billingMonth)) {
      return res.status(400).json({
        success: false,
        message: "billingMonth must be in YYYY-MM format."
      });
    }

    const settings = await PGSettings.getSettings();
    const resolvedDueDate = dueDate ? new Date(dueDate) : computeDueDate(billingMonth, settings.defaultDueDateDay);

    // 1. Single Tenant Bill Generation
    if (tenantId && !bulk) {
      if (!isValidObjectId(tenantId)) {
        return res.status(400).json({
          success: false,
          message: "Invalid tenantId format."
        });
      }

      const tenant = await Tenant.findById(tenantId).populate("room");
      if (!tenant) {
        return res.status(404).json({
          success: false,
          message: "Tenant not found."
        });
      }

      // Check duplicate bill for tenant + month
      const existingBill = await Bill.findOne({ tenant: tenant._id, billingMonth });
      if (existingBill) {
        return res.status(400).json({
          success: false,
          message: `Bill for tenant '${tenant.fullName}' for month ${billingMonth} already exists.`
        });
      }

      // Check meter reading for this room and month
      const meterReading = await MeterReading.findOne({ room: tenant.room._id, readingMonth: billingMonth });

      let elecAmount = 0;
      let prevReading = 0;
      let currReading = 0;
      let units = 0;

      if (customElecAmount !== undefined && !isNaN(Number(customElecAmount))) {
        // Owner explicitly provided a custom/prorated electricity amount (e.g. mid-month join/transfer)
        elecAmount = Math.max(0, Math.round(Number(customElecAmount) * 100) / 100);
        if (meterReading) {
          prevReading = meterReading.previousReading;
          currReading = meterReading.currentReading;
          units = meterReading.unitsConsumed;
        }
      } else if (meterReading) {
        // Divide electricity cost equally among active tenants in the room
        const activeRoommatesCount = await Tenant.countDocuments({ room: tenant.room._id, status: "active" });
        const divisor = Math.max(1, activeRoommatesCount);

        elecAmount = Math.round((meterReading.electricityAmount / divisor) * 100) / 100;
        units = Math.round((meterReading.unitsConsumed / divisor) * 100) / 100;
        prevReading = meterReading.previousReading;
        currReading = meterReading.currentReading;
      }

      const bill = await Bill.create({
        tenant: tenant._id,
        room: tenant.room._id,
        billingMonth,
        monthlyRent: tenant.monthlyRent,
        electricityAmount: elecAmount,
        otherCharges: otherCharges ? Number(otherCharges) : 0,
        adjustments: adjustments ? Number(adjustments) : 0,
        dueDate: resolvedDueDate,
        paymentStatus: "pending",
        paidAmount: 0,
        previousReading: prevReading,
        currentReading: currReading,
        unitsConsumed: units,
        meterReading: meterReading ? meterReading._id : undefined,
        notes: notes ? notes.trim() : ""
      });

      // Dispatch in-app and push notification to tenant asynchronously
      if (tenant.user) {
        pushService.dispatchNotificationAndPush({
          recipientId: tenant.user._id || tenant.user,
          senderId: req.user._id,
          title: `New Bill Generated: ${billingMonth}`,
          message: `Your bill of ₹${bill.totalAmount} for ${billingMonth} is ready. Due date: ${bill.dueDate ? new Date(bill.dueDate).toLocaleDateString("en-IN") : "N/A"}.`,
          category: "rent_reminder",
          relatedBill: bill._id,
          data: {
            screen: "/tenant/bills",
            billId: bill._id.toString(),
            billingMonth: bill.billingMonth
          },
          channelId: "billing"
        }).catch((err) => console.error("Bill push dispatch error:", err.message));
      }

      return res.status(201).json({
        success: true,
        message: `Bill generated successfully for tenant '${tenant.fullName}'.`,
        data: bill
      });
    }

    // 2. Bulk Generation for All Active Tenants
    const activeTenants = await Tenant.find({ status: "active" }).populate("room");
    if (activeTenants.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No active tenants found to generate bills for."
      });
    }

    const createdBills = [];
    const skippedTenants = [];

    for (const tenant of activeTenants) {
      const existingBill = await Bill.findOne({ tenant: tenant._id, billingMonth });
      if (existingBill) {
        skippedTenants.push({ tenant: tenant.fullName, reason: "Bill already exists" });
        continue;
      }

      const meterReading = await MeterReading.findOne({ room: tenant.room._id, readingMonth: billingMonth });

      let elecAmount = 0;
      let prevReading = 0;
      let currReading = 0;
      let units = 0;

      if (meterReading) {
        const activeRoommatesCount = await Tenant.countDocuments({ room: tenant.room._id, status: "active" });
        const divisor = Math.max(1, activeRoommatesCount);
        elecAmount = Math.round((meterReading.electricityAmount / divisor) * 100) / 100;
        units = Math.round((meterReading.unitsConsumed / divisor) * 100) / 100;
        prevReading = meterReading.previousReading;
        currReading = meterReading.currentReading;
      }

      const bill = await Bill.create({
        tenant: tenant._id,
        room: tenant.room._id,
        billingMonth,
        monthlyRent: tenant.monthlyRent,
        electricityAmount: elecAmount,
        otherCharges: 0,
        adjustments: 0,
        dueDate: resolvedDueDate,
        paymentStatus: "pending",
        paidAmount: 0,
        previousReading: prevReading,
        currentReading: currReading,
        unitsConsumed: units,
        meterReading: meterReading ? meterReading._id : undefined,
        notes: "Monthly auto-generated bill"
      });

      createdBills.push(bill);
    }

    // Dispatch notifications asynchronously for all created bills
    if (createdBills.length > 0) {
      (async () => {
        for (const b of createdBills) {
          const t = activeTenants.find((item) => item._id.toString() === b.tenant.toString());
          if (t && t.user) {
            await pushService.dispatchNotificationAndPush({
              recipientId: t.user._id || t.user,
              senderId: req.user._id,
              title: `New Bill Generated: ${billingMonth}`,
              message: `Your bill of ₹${b.totalAmount} for ${billingMonth} is ready.`,
              category: "rent_reminder",
              relatedBill: b._id,
              data: {
                screen: "/tenant/bills",
                billId: b._id.toString(),
                billingMonth: b.billingMonth
              },
              channelId: "billing"
            }).catch(() => {});
          }
        }
      })().catch((err) => console.error("Bulk push dispatch error:", err.message));
    }

    return res.status(201).json({
      success: true,
      message: `Bulk bill generation complete. Created: ${createdBills.length}, Skipped: ${skippedTenants.length}`,
      data: {
        createdCount: createdBills.length,
        skippedCount: skippedTenants.length,
        createdBills,
        skippedTenants
      }
    });
  } catch (error) {
    console.error("Generate Bills Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error generating bills.",
      error: error.message
    });
  }
};

/**
 * @desc    Get all bills (Owner only)
 * @route   GET /api/bills
 * @access  Private (Owner only)
 */
const getAllBills = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.max(1, Math.min(100, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const query = {};

    if (req.query.billingMonth) {
      query.billingMonth = req.query.billingMonth;
    }
    if (req.query.paymentStatus) {
      query.paymentStatus = req.query.paymentStatus;
    }
    if (req.query.roomId && isValidObjectId(req.query.roomId)) {
      query.room = req.query.roomId;
    }
    if (req.query.tenantId && isValidObjectId(req.query.tenantId)) {
      query.tenant = req.query.tenantId;
    }

    const totalBills = await Bill.countDocuments(query);
    const bills = await Bill.find(query)
      .populate("tenant", "fullName phone email")
      .populate("room", "roomNumber floor")
      .sort({ billingMonth: -1, createdAt: -1 })
      .skip(skip)
      .limit(limit);

    return res.status(200).json({
      success: true,
      count: bills.length,
      pagination: {
        total: totalBills,
        page,
        pages: Math.ceil(totalBills / limit),
        limit
      },
      data: bills
    });
  } catch (error) {
    console.error("Get All Bills Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching bills.",
      error: error.message
    });
  }
};

/**
 * @desc    Get bills for authenticated tenant
 * @route   GET /api/bills/my-bills
 * @access  Private (Tenant only)
 */
const getMyBills = async (req, res) => {
  try {
    const tenant = await Tenant.findOne({ user: req.user._id });
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "No tenant profile associated with your account."
      });
    }

    const bills = await Bill.find({ tenant: tenant._id })
      .populate("room", "roomNumber floor")
      .sort({ billingMonth: -1 });

    return res.status(200).json({
      success: true,
      count: bills.length,
      data: bills
    });
  } catch (error) {
    console.error("Get My Bills Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching your bills.",
      error: error.message
    });
  }
};

/**
 * @desc    Get pending / overdue bills (Owner only)
 * @route   GET /api/bills/pending
 * @access  Private (Owner only)
 */
const getPendingBills = async (req, res) => {
  try {
    const bills = await Bill.find({
      paymentStatus: { $in: ["pending", "partially_paid", "overdue"] }
    })
      .populate("tenant", "fullName phone email")
      .populate("room", "roomNumber floor")
      .sort({ dueDate: 1 });

    const totalPendingAmount = bills.reduce(
      (acc, b) => acc + Math.max(0, b.totalAmount - (b.paidAmount || 0)),
      0
    );

    return res.status(200).json({
      success: true,
      count: bills.length,
      totalPendingAmount: Math.round(totalPendingAmount * 100) / 100,
      data: bills
    });
  } catch (error) {
    console.error("Get Pending Bills Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching pending bills.",
      error: error.message
    });
  }
};

/**
 * @desc    Get single bill by ID
 * @route   GET /api/bills/:id
 * @access  Private (Owner or Bill Owner)
 */
const getBillById = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Bill ID format."
      });
    }

    const bill = await Bill.findById(id)
      .populate("tenant", "fullName phone email user")
      .populate("room", "roomNumber floor roomType")
      .populate("meterReading");

    if (!bill) {
      return res.status(404).json({
        success: false,
        message: "Bill not found."
      });
    }

    // Role authorization: Tenant can only view their own bill
    if (req.user.role === "tenant" && String(bill.tenant.user) !== String(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: "Forbidden: You are not authorized to view this bill."
      });
    }

    // Fetch payments associated with this bill
    const payments = await Payment.find({ bill: bill._id }).sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      data: {
        ...bill.toObject(),
        remainingBalance: Math.max(0, Math.round((bill.totalAmount - bill.paidAmount) * 100) / 100),
        payments
      }
    });
  } catch (error) {
    console.error("Get Bill By ID Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching bill.",
      error: error.message
    });
  }
};

/**
 * @desc    Update bill adjustments / other charges
 * @route   PUT /api/bills/:id/adjustments
 * @access  Private (Owner only)
 */
const updateBillAdjustments = async (req, res) => {
  try {
    const { id } = req.params;
    const { adjustments, otherCharges, electricityAmount, notes } = req.body;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Bill ID format."
      });
    }

    const bill = await Bill.findById(id);
    if (!bill) {
      return res.status(404).json({
        success: false,
        message: "Bill not found."
      });
    }

    if (adjustments !== undefined) {
      bill.adjustments = Number(adjustments);
    }
    if (electricityAmount !== undefined) {
      const elec = Number(electricityAmount);
      if (elec < 0) {
        return res.status(400).json({
          success: false,
          message: "Electricity amount cannot be negative."
        });
      }
      bill.electricityAmount = Math.round(elec * 100) / 100;
    }
    if (otherCharges !== undefined) {
      if (Number(otherCharges) < 0) {
        return res.status(400).json({
          success: false,
          message: "Other charges cannot be negative."
        });
      }
      bill.otherCharges = Number(otherCharges);
    }
    if (notes) {
      bill.notes = notes.trim();
    }

    await bill.save(); // triggers pre-save recalculation of totalAmount and paymentStatus

    return res.status(200).json({
      success: true,
      message: "Bill adjustments updated successfully.",
      data: bill
    });
  } catch (error) {
    console.error("Update Bill Adjustments Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error updating adjustments.",
      error: error.message
    });
  }
};

module.exports = {
  generateBills,
  getAllBills,
  getMyBills,
  getPendingBills,
  getBillById,
  updateBillAdjustments
};
