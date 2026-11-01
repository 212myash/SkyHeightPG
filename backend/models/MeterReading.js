const mongoose = require("mongoose");

const meterReadingSchema = new mongoose.Schema(
  {
    room: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Room",
      required: [true, "Room reference is required"],
      index: true
    },

    previousReading: {
      type: Number,
      required: [true, "Previous reading is required"],
      min: [0, "Previous reading cannot be negative"]
    },

    currentReading: {
      type: Number,
      required: [true, "Current reading is required"],
      min: [0, "Current reading cannot be negative"]
    },

    unitsConsumed: {
      type: Number,
      min: [0, "Units consumed cannot be negative"]
    },

    ratePerUnit: {
      type: Number,
      required: [true, "Rate per unit is required"],
      min: [0, "Rate per unit cannot be negative"],
      set: (v) => Math.round(v * 100) / 100
    },

    electricityAmount: {
      type: Number,
      min: [0, "Electricity amount cannot be negative"],
      set: (v) => Math.round(v * 100) / 100
    },

    readingMonth: {
      type: String,
      required: [true, "Reading month is required (YYYY-MM)"],
      trim: true,
      match: [/^\d{4}-(0[1-9]|1[0-2])$/, "Reading month must be in YYYY-MM format"]
    },

    readingDate: {
      type: Date,
      default: Date.now
    },

    recordedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "Owner reference (recordedBy) is required"]
    },

    remarks: {
      type: String,
      trim: true,
      default: ""
    }
  },
  {
    timestamps: true
  }
);

// Prevent duplicate meter reading for the same room and month
meterReadingSchema.index({ room: 1, readingMonth: 1 }, { unique: true });

// Pre-save validation and calculation
meterReadingSchema.pre("save", async function () {
  if (this.currentReading < this.previousReading) {
    throw new Error("Current reading cannot be lower than previous reading");
  }

  this.unitsConsumed = Math.round((this.currentReading - this.previousReading) * 100) / 100;
  this.electricityAmount = Math.round(this.unitsConsumed * this.ratePerUnit * 100) / 100;
});

module.exports = mongoose.model("MeterReading", meterReadingSchema);
