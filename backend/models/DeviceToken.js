const mongoose = require("mongoose");

const deviceTokenSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: [true, "User reference is required"],
      index: true
    },
    token: {
      type: String,
      required: [true, "Device token is required"],
      unique: true,
      trim: true
    },
    platform: {
      type: String,
      enum: ["android", "ios", "web"],
      default: "android"
    },
    deviceId: {
      type: String,
      trim: true,
      default: null
    },
    lastUsedAt: {
      type: Date,
      default: Date.now
    }
  },
  {
    timestamps: true
  }
);

// Query optimization for finding tokens of a specific user
deviceTokenSchema.index({ user: 1, lastUsedAt: -1 });

module.exports = mongoose.model("DeviceToken", deviceTokenSchema);
