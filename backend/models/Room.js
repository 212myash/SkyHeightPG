const mongoose = require("mongoose");

const roomSchema = new mongoose.Schema(
  {
    roomNumber: {
      type: String,
      required: [true, "Room number is required"],
      unique: true,
      trim: true,
      uppercase: true
    },

    floor: {
      type: Number,
      required: [true, "Floor number is required"],
      min: [0, "Floor cannot be negative"]
    },

    roomType: {
      type: String,
      enum: {
        values: ["single", "double", "triple", "four-sharing", "other"],
        message: "Invalid room type"
      },
      default: "double"
    },

    monthlyRent: {
      type: Number,
      required: [true, "Monthly rent is required"],
      min: [0, "Monthly rent cannot be negative"],
      set: (v) => Math.round(v * 100) / 100
    },

    maxOccupancy: {
      type: Number,
      min: [1, "Room occupancy must be at least 1 person"],
      default: 2
    },

    capacity: {
      type: Number,
      min: [1, "Room capacity must be at least 1"],
      default: 2
    },

    occupiedBeds: {
      type: Number,
      default: 0,
      min: [0, "Occupied count cannot be negative"],
      validate: {
        validator: function (v) {
          const cap = this.maxOccupancy || this.capacity || 2;
          return v <= cap;
        },
        message: "Occupied occupants cannot exceed maximum occupancy"
      }
    },

    amenities: {
      type: [String],
      default: []
    },

    status: {
      type: String,
      enum: {
        values: ["available", "occupied", "maintenance"],
        message: "Status must be available, occupied, or maintenance"
      },
      default: "available"
    },

    isActive: {
      type: Boolean,
      default: true
    }
  },
  {
    timestamps: true
  }
);

// Auto-sync capacity and maxOccupancy; update status based on occupancy
roomSchema.pre("save", async function () {
  if (this.maxOccupancy !== undefined) {
    this.capacity = this.maxOccupancy;
  } else if (this.capacity !== undefined) {
    this.maxOccupancy = this.capacity;
  }

  if (this.status !== "maintenance") {
    const current = this.occupiedBeds || 0;
    const limit = this.maxOccupancy || this.capacity || 2;
    if (current >= limit) {
      this.status = "occupied";
    } else {
      this.status = "available";
    }
  }
});

module.exports = mongoose.model("Room", roomSchema);
