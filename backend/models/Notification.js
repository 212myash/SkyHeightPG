const mongoose = require("mongoose");

const notificationSchema = new mongoose.Schema(
  {
    recipient: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Recipient is required"],
      index: true
    },

    sender: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null
    },

    title: {
      type: String,
      required: [true, "Title is required"],
      trim: true
    },

    message: {
      type: String,
      required: [true, "Message is required"],
      trim: true
    },

    category: {
      type: String,
      enum: {
        values: [
          "rent_reminder",
          "electricity_bill",
          "payment_reminder",
          "payment_received",
          "maintenance",
          "complaint_update",
          "general_announcement",
          "security_alert",
          "registration_update",
          "system"
        ],
        message: "Invalid notification category"
      },
      default: "general_announcement",
      index: true
    },

    audience: {
      type: String,
      enum: ["all", "room", "tenant"],
      default: "tenant"
    },

    targetRoom: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Room",
      default: null
    },

    targetTenant: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Tenant",
      default: null
    },

    dueDate: {
      type: Date,
      default: null
    },

    relatedBill: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Bill",
      default: null
    },

    relatedComplaint: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Complaint",
      default: null
    },

    isRead: {
      type: Boolean,
      default: false,
      index: true
    },

    readAt: {
      type: Date,
      default: null
    }
  },
  {
    timestamps: true
  }
);

// Compound index for fast queries: user's unread / read notifications by recency
notificationSchema.index({ recipient: 1, isRead: 1, createdAt: -1 });

module.exports = mongoose.model("Notification", notificationSchema);
