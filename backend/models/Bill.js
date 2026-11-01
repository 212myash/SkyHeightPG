const mongoose = require("mongoose");

const billSchema = new mongoose.Schema(
  {
    tenant: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Tenant",
      required: [true, "Tenant reference is required"],
      index: true
    },

    room: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Room",
      required: [true, "Room reference is required"],
      index: true
    },

    billingMonth: {
      type: String,
      required: [true, "Billing month is required (YYYY-MM)"],
      trim: true,
      match: [/^\d{4}-(0[1-9]|1[0-2])$/, "Billing month must be in YYYY-MM format"]
    },

    monthlyRent: {
      type: Number,
      required: [true, "Monthly rent is required"],
      min: [0, "Monthly rent cannot be negative"],
      set: (v) => Math.round(v * 100) / 100
    },

    electricityAmount: {
      type: Number,
      default: 0,
      min: [0, "Electricity amount cannot be negative"],
      set: (v) => Math.round(v * 100) / 100
    },

    otherCharges: {
      type: Number,
      default: 0,
      min: [0, "Other charges cannot be negative"],
      set: (v) => Math.round(v * 100) / 100
    },

    // Adjustments: Concession/discount subtracted from bill (Formula: Rent + Electricity + OtherCharges - Adjustments)
    adjustments: {
      type: Number,
      default: 0,
      set: (v) => Math.round(v * 100) / 100
    },

    totalAmount: {
      type: Number,
      min: [0, "Total amount cannot be negative"],
      set: (v) => Math.round(v * 100) / 100
    },

    dueDate: {
      type: Date,
      required: [true, "Bill due date is required"]
    },

    paymentStatus: {
      type: String,
      enum: {
        values: ["pending", "partially_paid", "paid", "overdue"],
        message: "Invalid payment status"
      },
      default: "pending",
      index: true
    },

    paidAmount: {
      type: Number,
      default: 0,
      min: [0, "Paid amount cannot be negative"],
      set: (v) => Math.round(v * 100) / 100
    },

    previousReading: {
      type: Number,
      default: 0,
      min: [0, "Previous reading cannot be negative"]
    },

    currentReading: {
      type: Number,
      default: 0,
      min: [0, "Current reading cannot be negative"]
    },

    unitsConsumed: {
      type: Number,
      default: 0,
      min: [0, "Units consumed cannot be negative"]
    },

    meterReading: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MeterReading"
    },

    notes: {
      type: String,
      trim: true,
      default: ""
    }
  },
  {
    timestamps: true
  }
);

// Prevent duplicate monthly bill for the same tenant and month
billSchema.index({ tenant: 1, billingMonth: 1 }, { unique: true });

// Pre-save calculation of total bill amount
billSchema.pre("save", async function () {
  const calculatedTotal =
    (this.monthlyRent || 0) +
    (this.electricityAmount || 0) +
    (this.otherCharges || 0) -
    (this.adjustments || 0);

  this.totalAmount = Math.max(0, Math.round(calculatedTotal * 100) / 100);

  // Auto-update status if fully paid
  if (this.totalAmount > 0 && this.paidAmount >= this.totalAmount) {
    this.paymentStatus = "paid";
  } else if (this.paidAmount > 0 && this.paidAmount < this.totalAmount) {
    this.paymentStatus = "partially_paid";
  } else if (this.paidAmount === 0 && this.dueDate && new Date() > this.dueDate) {
    this.paymentStatus = "overdue";
  }
});

module.exports = mongoose.model("Bill", billSchema);
