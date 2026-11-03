const mongoose = require("mongoose");

const occupancyHistorySchema = new mongoose.Schema(
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

    roomNumber: {
      type: String,
      required: [true, "Room number snapshot is required"],
      trim: true,
      uppercase: true
    },

    joiningDate: {
      type: Date,
      required: [true, "Joining date is required"],
      default: Date.now,
      index: true
    },

    leavingDate: {
      type: Date,
      default: null,
      index: true
    },

    occupancyStatus: {
      type: String,
      enum: {
        values: ["active", "transferred", "vacated"],
        message: "Occupancy status must be active, transferred, or vacated"
      },
      default: "active",
      index: true
    },

    monthlyRentSnapshot: {
      type: Number,
      default: 0,
      min: [0, "Rent snapshot cannot be negative"]
    },

    reason: {
      type: String,
      trim: true,
      default: ""
    },

    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      default: null
    }
  },
  {
    timestamps: true
  }
);

// Compound indexes for rapid lookups
occupancyHistorySchema.index({ tenant: 1, occupancyStatus: 1 });
occupancyHistorySchema.index({ room: 1, occupancyStatus: 1 });
occupancyHistorySchema.index({ tenant: 1, joiningDate: -1 });

// Date validation: leavingDate must be >= joiningDate
occupancyHistorySchema.pre("save", async function () {
  if (this.leavingDate && this.joiningDate && this.leavingDate < this.joiningDate) {
    throw new Error("Leaving date cannot be earlier than joining date.");
  }
});

module.exports = mongoose.model("OccupancyHistory", occupancyHistorySchema);
