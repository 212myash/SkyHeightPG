const mongoose = require("mongoose");

const pgSettingsSchema = new mongoose.Schema(
  {
    pgName: {
      type: String,
      required: [true, "PG name is required"],
      trim: true,
      default: "Sky Height PG"
    },

    address: {
      street: { type: String, trim: true, default: "123 Sky Height Avenue" },
      city: { type: String, trim: true, default: "Jaipur" },
      state: { type: String, trim: true, default: "Rajasthan" },
      pincode: { type: String, trim: true, default: "302001" }
    },

    contactNumber: {
      type: String,
      trim: true,
      default: "+91 98765 43210"
    },

    email: {
      type: String,
      trim: true,
      default: "contact@skyheightpg.com"
    },

    electricityRatePerUnit: {
      type: Number,
      required: [true, "Electricity rate per unit is required"],
      min: [0, "Electricity rate cannot be negative"],
      default: 10,
      set: (v) => Math.round(v * 100) / 100
    },

    defaultDueDateDay: {
      type: Number,
      required: [true, "Default due date day is required"],
      min: [1, "Due date day must be between 1 and 28"],
      max: [28, "Due date day must be between 1 and 28"],
      default: 5
    },

    upiId: {
      type: String,
      trim: true,
      default: "skyheight@upi"
    },

    upiQrImageUrl: {
      type: String,
      trim: true,
      default: ""
    },

    noticePeriodDays: {
      type: Number,
      default: 30,
      min: 0
    },

    rulesAndRegulations: {
      type: [String],
      default: [
        "Gate closes at 11:00 PM.",
        "Quiet hours from 11:00 PM to 6:00 AM.",
        "No smoking or alcohol on the premises.",
        "Guests allowed only in common areas until 8:00 PM."
      ]
    }
  },
  {
    timestamps: true
  }
);

// Helper static method to get or initialize the singleton PGSettings document
pgSettingsSchema.statics.getSettings = async function () {
  let settings = await this.findOne();
  if (!settings) {
    settings = await this.create({});
  }
  return settings;
};

module.exports = mongoose.model("PGSettings", pgSettingsSchema);
