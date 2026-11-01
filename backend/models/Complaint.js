const mongoose = require("mongoose");

const complaintSchema = new mongoose.Schema(
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

    title: {
      type: String,
      required: [true, "Complaint title is required"],
      trim: true
    },

    description: {
      type: String,
      required: [true, "Complaint description is required"],
      trim: true
    },

    category: {
      type: String,
      enum: {
        values: [
          "electricity",
          "plumbing",
          "wifi",
          "cleaning",
          "furniture",
          "noise",
          "other"
        ],
        message: "Invalid complaint category"
      },
      default: "other"
    },

    priority: {
      type: String,
      enum: {
        values: ["low", "medium", "high", "urgent"],
        message: "Invalid priority level"
      },
      default: "medium",
      index: true
    },

    status: {
      type: String,
      enum: {
        values: ["open", "in_progress", "resolved", "rejected"],
        message: "Invalid complaint status"
      },
      default: "open",
      index: true
    },

    resolution: {
      type: String,
      trim: true,
      default: ""
    },

    resolvedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User"
    },

    resolvedAt: {
      type: Date
    }
  },
  {
    timestamps: true
  }
);

module.exports = mongoose.model("Complaint", complaintSchema);
