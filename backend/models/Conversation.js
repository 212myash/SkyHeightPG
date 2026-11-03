const mongoose = require("mongoose");

const conversationSchema = new mongoose.Schema(
  {
    type: {
      type: String,
      enum: {
        values: ["private", "room", "community"],
        message: "Conversation type must be private, room, or community"
      },
      required: [true, "Conversation type is required"],
      index: true
    },

    name: {
      type: String,
      trim: true,
      default: ""
    },

    room: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "Room",
      default: null,
      index: true
    },

    participants: [
      {
        type: mongoose.Schema.Types.ObjectId,
        ref: "User",
        index: true
      }
    ],

    lastMessage: {
      text: { type: String, default: "" },
      sender: { type: mongoose.Schema.Types.ObjectId, ref: "User", default: null },
      sentAt: { type: Date, default: Date.now }
    },

    lastMessageAt: {
      type: Date,
      default: Date.now,
      index: true
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

conversationSchema.index({ type: 1, room: 1 });
conversationSchema.index({ participants: 1, lastMessageAt: -1 });

module.exports = mongoose.model("Conversation", conversationSchema);
