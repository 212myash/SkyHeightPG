const mongoose = require("mongoose");

const expenseSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: [true, "Expense title is required"],
      trim: true
    },

    category: {
      type: String,
      enum: {
        values: [
          "maintenance",
          "utilities",
          "cleaning",
          "repairs",
          "supplies",
          "wifi",
          "taxes",
          "salary",
          "other"
        ],
        message: "Invalid expense category"
      },
      required: [true, "Expense category is required"],
      index: true
    },

    amount: {
      type: Number,
      required: [true, "Expense amount is required"],
      min: [0.01, "Expense amount must be greater than zero"],
      set: (v) => Math.round(v * 100) / 100
    },

    date: {
      type: Date,
      required: [true, "Expense date is required"],
      default: Date.now,
      index: true
    },

    description: {
      type: String,
      trim: true,
      default: ""
    },

    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "User reference (recordedBy) is required"]
    },

    receiptUrl: {
      type: String,
      trim: true,
      default: ""
    }
  },
  {
    timestamps: true
  }
);

module.exports = mongoose.model("Expense", expenseSchema);
