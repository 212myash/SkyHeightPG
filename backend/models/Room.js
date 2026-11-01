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

    capacity: {
      type: Number,
      required: [true, "Room capacity is required"],
      min: [1, "Room capacity must be at least 1 bed"],
      default: 2
    },

    occupiedBeds: {
      type: Number,
      default: 0,
      min: [0, "Occupied beds cannot be negative"],
      validate: {
        validator: function (v) {
          return v <= this.capacity;
        },
        message: "Occupied beds cannot exceed total capacity"
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

// Auto-update status based on occupied beds unless marked maintenance
roomSchema.pre("save", async function () {
  if (this.status !== "maintenance") {
    if (this.occupiedBeds >= this.capacity) {
      this.status = "occupied";
    } else {
      this.status = "available";
    }
  }
});

module.exports = mongoose.model("Room", roomSchema);
