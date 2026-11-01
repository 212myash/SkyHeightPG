const mongoose = require("mongoose");

const paymentSchema = new mongoose.Schema(
  {
    tenant: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Tenant",
      required: [true, "Tenant reference is required"],
      index: true
    },

    bill: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Bill",
      required: [true, "Bill reference is required"],
      index: true
    },

    amount: {
      type: Number,
      required: [true, "Payment amount is required"],
      min: [0.01, "Payment amount must be greater than zero"],
      set: (v) => Math.round(v * 100) / 100
    },

    paymentMethod: {
      type: String,
      enum: {
        values: ["cash", "upi"],
        message: "Payment method must be cash or upi"
      },
      required: [true, "Payment method is required"]
    },

    transactionReference: {
      type: String,
      trim: true,
      default: ""
    },

    paymentDate: {
      type: Date,
      default: Date.now,
      index: true
    },

    verificationStatus: {
      type: String,
      enum: {
        values: ["pending", "verified", "rejected"],
        message: "Invalid verification status"
      },
      default: "pending",
      index: true
    },

    verifiedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User"
    },

    verifiedAt: {
      type: Date
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

module.exports = mongoose.model("Payment", paymentSchema);
