const Payment = require("../models/Payment");
const Bill = require("../models/Bill");
const Tenant = require("../models/Tenant");
const { isValidObjectId } = require("../utils/validateObjectId");

/**
 * @desc    Record a cash payment directly by Owner
 * @route   POST /api/payments/cash
 * @access  Private (Owner only)
 */
const recordCashPayment = async (req, res) => {
  try {
    const { billId, amount, notes, transactionReference } = req.body;

    if (!billId || amount === undefined) {
      return res.status(400).json({
        success: false,
        message: "Please provide billId and payment amount."
      });
    }

    if (!isValidObjectId(billId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid billId format."
      });
    }

    const payAmount = Number(amount);
    if (payAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Payment amount must be greater than zero."
      });
    }

    const bill = await Bill.findById(billId).populate("tenant", "fullName");
    if (!bill) {
      return res.status(404).json({
        success: false,
        message: "Bill not found."
      });
    }

    const remainingBalance = Math.max(0, Math.round((bill.totalAmount - bill.paidAmount) * 100) / 100);
    if (payAmount > remainingBalance) {
      return res.status(400).json({
        success: false,
        message: `Payment amount of ₹${payAmount} exceeds the remaining balance of ₹${remainingBalance}.`
      });
    }

    // 1. Create verified payment record
    const payment = await Payment.create({
      tenant: bill.tenant._id,
      bill: bill._id,
      amount: payAmount,
      paymentMethod: "cash",
      transactionReference: transactionReference ? transactionReference.trim() : `CASH-${Date.now()}`,
      verificationStatus: "verified",
      verifiedBy: req.user._id,
      verifiedAt: new Date(),
      notes: notes ? notes.trim() : "Cash payment received by owner"
    });

    // 2. Update Bill paid amount
    bill.paidAmount = Math.round((bill.paidAmount + payAmount) * 100) / 100;
    await bill.save(); // pre-save updates paymentStatus ('paid' or 'partially_paid')

    return res.status(201).json({
      success: true,
      message: `Cash payment of ₹${payAmount} recorded and credited to Bill ${bill.billingMonth}.`,
      data: {
        payment,
        bill: {
          _id: bill._id,
          billingMonth: bill.billingMonth,
          totalAmount: bill.totalAmount,
          paidAmount: bill.paidAmount,
          paymentStatus: bill.paymentStatus,
          remainingBalance: Math.max(0, Math.round((bill.totalAmount - bill.paidAmount) * 100) / 100)
        }
      }
    });
  } catch (error) {
    console.error("Record Cash Payment Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error recording cash payment.",
      error: error.message
    });
  }
};

/**
 * @desc    Submit UPI payment reference by Tenant
 * @route   POST /api/payments/upi/submit
 * @access  Private (Tenant only)
 */
const submitUpiPayment = async (req, res) => {
  try {
    const { billId, amount, transactionReference, notes } = req.body;

    if (!billId || amount === undefined || !transactionReference) {
      return res.status(400).json({
        success: false,
        message: "Please provide billId, amount, and UPI transactionReference (UTR number)."
      });
    }

    if (!isValidObjectId(billId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid billId format."
      });
    }

    const payAmount = Number(amount);
    if (payAmount <= 0) {
      return res.status(400).json({
        success: false,
        message: "Payment amount must be greater than zero."
      });
    }

    const tenant = await Tenant.findOne({ user: req.user._id });
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "No tenant profile associated with your account."
      });
    }

    const bill = await Bill.findById(billId);
    if (!bill) {
      return res.status(404).json({
        success: false,
        message: "Bill not found."
      });
    }

    // Verify bill belongs to this tenant
    if (String(bill.tenant) !== String(tenant._id)) {
      return res.status(403).json({
        success: false,
        message: "Forbidden: You can only submit payments for your own bills."
      });
    }

    const cleanRef = transactionReference.trim();

    // Check duplicate UTR reference
    const duplicateRef = await Payment.findOne({
      transactionReference: cleanRef,
      verificationStatus: { $ne: "rejected" }
    });
    if (duplicateRef) {
      return res.status(400).json({
        success: false,
        message: `Transaction reference '${cleanRef}' has already been submitted.`
      });
    }

    const remainingBalance = Math.max(0, Math.round((bill.totalAmount - bill.paidAmount) * 100) / 100);
    if (payAmount > remainingBalance) {
      return res.status(400).json({
        success: false,
        message: `Payment amount of ₹${payAmount} exceeds your remaining balance of ₹${remainingBalance}.`
      });
    }

    // Create Payment with PENDING verification status
    // STRICT RULE: Never mark UPI payment verified upon tenant submission
    const payment = await Payment.create({
      tenant: tenant._id,
      bill: bill._id,
      amount: payAmount,
      paymentMethod: "upi",
      transactionReference: cleanRef,
      verificationStatus: "pending",
      notes: notes ? notes.trim() : "UPI payment submitted by tenant"
    });

    return res.status(201).json({
      success: true,
      message: "UPI payment reference submitted successfully. Status is PENDING verification by owner.",
      data: payment
    });
  } catch (error) {
    console.error("Submit UPI Payment Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error submitting UPI payment.",
      error: error.message
    });
  }
};

/**
 * @desc    Verify or reject a pending UPI payment
 * @route   PUT /api/payments/:id/verify
 * @access  Private (Owner only)
 */
const verifyUpiPayment = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, notes } = req.body;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Payment ID format."
      });
    }

    if (!status || !["verified", "rejected"].includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Please specify status as either 'verified' or 'rejected'."
      });
    }

    const payment = await Payment.findById(id).populate("bill").populate("tenant", "fullName");
    if (!payment) {
      return res.status(404).json({
        success: false,
        message: "Payment record not found."
      });
    }

    if (payment.verificationStatus !== "pending") {
      return res.status(400).json({
        success: false,
        message: `This payment has already been marked as '${payment.verificationStatus}'.`
      });
    }

    if (status === "verified") {
      // Find and validate bill before verification
      const bill = await Bill.findById(payment.bill._id);
      if (!bill) {
        return res.status(404).json({
          success: false,
          message: "Associated bill not found."
        });
      }

      // Overpayment prevention check at time of verification
      const remainingBalance = Math.max(0, Math.round((bill.totalAmount - bill.paidAmount) * 100) / 100);
      if (payment.amount > remainingBalance) {
        return res.status(400).json({
          success: false,
          message: `Cannot verify payment of ₹${payment.amount} because remaining bill balance is only ₹${remainingBalance}. Please reject or adjust the payment.`
        });
      }

      payment.verificationStatus = "verified";
      payment.verifiedBy = req.user._id;
      payment.verifiedAt = new Date();
      if (notes) payment.notes = notes.trim();

      // Credit the bill
      bill.paidAmount = Math.round((bill.paidAmount + payment.amount) * 100) / 100;
      await bill.save();

      await payment.save();

      return res.status(200).json({
        success: true,
        message: `Payment of ₹${payment.amount} for ${payment.tenant.fullName} verified successfully.`,
        data: {
          payment,
          billPaidAmount: bill.paidAmount,
          billStatus: bill.paymentStatus
        }
      });
    } else {
      // Rejected
      payment.verificationStatus = "rejected";
      payment.verifiedBy = req.user._id;
      payment.verifiedAt = new Date();
      if (notes) payment.notes = notes.trim();
      await payment.save();

      return res.status(200).json({
        success: true,
        message: `Payment of ₹${payment.amount} has been rejected.`,
        data: payment
      });
    }
  } catch (error) {
    console.error("Verify UPI Payment Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error verifying payment.",
      error: error.message
    });
  }
};

/**
 * @desc    Get all payments (Owner only)
 * @route   GET /api/payments
 * @access  Private (Owner only)
 */
const getAllPayments = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.max(1, Math.min(100, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const query = {};

    if (req.query.verificationStatus) {
      query.verificationStatus = req.query.verificationStatus;
    }
    if (req.query.paymentMethod) {
      query.paymentMethod = req.query.paymentMethod;
    }
    if (req.query.tenantId && isValidObjectId(req.query.tenantId)) {
      query.tenant = req.query.tenantId;
    }
    if (req.query.billId && isValidObjectId(req.query.billId)) {
      query.bill = req.query.billId;
    }

    const totalPayments = await Payment.countDocuments(query);
    const payments = await Payment.find(query)
      .populate("tenant", "fullName phone email")
      .populate("bill", "billingMonth totalAmount paymentStatus")
      .populate("verifiedBy", "name")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    return res.status(200).json({
      success: true,
      count: payments.length,
      pagination: {
        total: totalPayments,
        page,
        pages: Math.ceil(totalPayments / limit),
        limit
      },
      data: payments
    });
  } catch (error) {
    console.error("Get All Payments Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching payments.",
      error: error.message
    });
  }
};

/**
 * @desc    Get payment history for authenticated tenant
 * @route   GET /api/payments/my-payments
 * @access  Private (Tenant only)
 */
const getMyPayments = async (req, res) => {
  try {
    const tenant = await Tenant.findOne({ user: req.user._id });
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "No tenant profile found."
      });
    }

    const payments = await Payment.find({ tenant: tenant._id })
      .populate("bill", "billingMonth totalAmount")
      .sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: payments.length,
      data: payments
    });
  } catch (error) {
    console.error("Get My Payments Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching your payments.",
      error: error.message
    });
  }
};

/**
 * @desc    Calculate outstanding balance for a tenant
 * @route   GET /api/payments/balance/:tenantId
 * @access  Private (Owner or Self)
 */
const getTenantBalance = async (req, res) => {
  try {
    const { tenantId } = req.params;

    if (!isValidObjectId(tenantId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Tenant ID format."
      });
    }

    const tenant = await Tenant.findById(tenantId);
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "Tenant not found."
      });
    }

    // Role check
    if (req.user.role === "tenant" && String(tenant.user) !== String(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: "Forbidden: You are not authorized to view another tenant's balance."
      });
    }

    // Aggregate bills
    const bills = await Bill.find({ tenant: tenant._id });
    const totalBilled = bills.reduce((acc, b) => acc + (b.totalAmount || 0), 0);
    const totalPaid = bills.reduce((acc, b) => acc + (b.paidAmount || 0), 0);
    const outstandingBalance = Math.max(0, Math.round((totalBilled - totalPaid) * 100) / 100);

    // Count pending unverified UPI submissions
    const pendingUpiSubmissions = await Payment.find({
      tenant: tenant._id,
      verificationStatus: "pending"
    });
    const pendingUpiAmount = pendingUpiSubmissions.reduce((acc, p) => acc + (p.amount || 0), 0);

    return res.status(200).json({
      success: true,
      data: {
        tenantId: tenant._id,
        tenantName: tenant.fullName,
        totalBilled: Math.round(totalBilled * 100) / 100,
        totalPaid: Math.round(totalPaid * 100) / 100,
        outstandingBalance,
        pendingUpiVerification: {
          count: pendingUpiSubmissions.length,
          amount: Math.round(pendingUpiAmount * 100) / 100
        }
      }
    });
  } catch (error) {
    console.error("Get Tenant Balance Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error calculating balance.",
      error: error.message
    });
  }
};

module.exports = {
  recordCashPayment,
  submitUpiPayment,
  verifyUpiPayment,
  getAllPayments,
  getMyPayments,
  getTenantBalance
};
