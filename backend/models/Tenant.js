const mongoose = require("mongoose");

const tenantSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Associated user account is required"],
      index: true
    },

    room: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Room",
      required: [true, "Assigned room is required"],
      index: true
    },

    fullName: {
      type: String,
      required: [true, "Full name is required"],
      trim: true
    },

    phone: {
      type: String,
      required: [true, "Phone number is required"],
      trim: true,
      index: true
    },

    email: {
      type: String,
      required: [true, "Email address is required"],
      lowercase: true,
      trim: true,
      match: [/^\S+@\S+\.\S+$/, "Please provide a valid email address"]
    },

    address: {
      street: { type: String, trim: true, default: "" },
      city: { type: String, trim: true, default: "" },
      state: { type: String, trim: true, default: "" },
      pincode: { type: String, trim: true, default: "" }
    },

    joiningDate: {
      type: Date,
      required: [true, "Joining date is required"],
      default: Date.now
    },

    securityDeposit: {
      type: Number,
      required: [true, "Security deposit amount is required"],
      min: [0, "Security deposit cannot be negative"],
      default: 0,
      set: (v) => Math.round(v * 100) / 100
    },

    monthlyRent: {
      type: Number,
      required: [true, "Monthly rent is required"],
      min: [0, "Monthly rent cannot be negative"],
      set: (v) => Math.round(v * 100) / 100
    },

    assignedBed: {
      type: String,
      trim: true,
      default: "Bed 1"
    },

    emergencyContact: {
      name: { type: String, trim: true, default: "" },
      phone: { type: String, trim: true, default: "" },
      relation: { type: String, trim: true, default: "" }
    },

    status: {
      type: String,
      enum: {
        values: ["active", "vacated", "notice_period"],
        message: "Status must be active, vacated, or notice_period"
      },
      default: "active",
      index: true
    }
  },
  {
    timestamps: true
  }
);

module.exports = mongoose.model("Tenant", tenantSchema);
