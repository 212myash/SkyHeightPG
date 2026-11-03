const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const Tenant = require("../models/Tenant");
const Room = require("../models/Room");
const User = require("../models/User");
const { isValidObjectId } = require("../utils/validateObjectId");

/**
 * Helper: ensure community conversation exists
 */
const ensureCommunityConversation = async () => {
  let community = await Conversation.findOne({ type: "community" });
  if (!community) {
    community = await Conversation.create({
      type: "community",
      name: "Sky Height Apartment — Community",
      participants: []
    });
  }
  return community;
};

/**
 * Helper: verify user has permission to access a conversation
 */
const checkConversationAccess = async (conversation, user) => {
  if (user.role === "owner") {
    return { allowed: true };
  }

  // Tenant checks
  if (conversation.type === "community") {
    // Active or pending tenants can view community
    const tenant = await Tenant.findOne({ user: user._id });
    if (!tenant || tenant.status === "vacated" || tenant.approvalStatus !== "approved") {
      return { allowed: false, message: "Only active apartment members can access the Community chat." };
    }
    return { allowed: true };
  }

  if (conversation.type === "room") {
    // Only tenants currently active in that specific room
    const tenant = await Tenant.findOne({ user: user._id, status: "active" });
    if (!tenant || !tenant.room || String(tenant.room) !== String(conversation.room)) {
      return { allowed: false, message: "Access denied. You are not an active occupant of this room." };
    }
    return { allowed: true };
  }

  if (conversation.type === "private") {
    const isParticipant = conversation.participants.some((p) => String(p) === String(user._id));
    if (!isParticipant) {
      return { allowed: false, message: "Forbidden: You are not a participant in this conversation." };
    }
    return { allowed: true };
  }

  return { allowed: false, message: "Unauthorized." };
};

/**
 * @desc    Get all conversations accessible to the current user
 * @route   GET /api/conversations
 * @access  Private (Owner / Tenant)
 */
const getConversations = async (req, res) => {
  try {
    await ensureCommunityConversation();

    const accessibleConversations = [];

    // 1. Community Conversation
    const community = await Conversation.findOne({ type: "community" });
    if (community) {
      accessibleConversations.push(community);
    }

    if (req.user.role === "owner") {
      // Owner can see all active room conversations and all their private chats
      const roomConversations = await Conversation.find({ type: "room" }).populate("room", "roomNumber floor");
      accessibleConversations.push(...roomConversations);

      const privateConversations = await Conversation.find({
        type: "private",
        participants: req.user._id
      }).populate("participants", "name email role");
      accessibleConversations.push(...privateConversations);
    } else {
      // Tenant: check assigned room
      const tenant = await Tenant.findOne({ user: req.user._id, status: "active" }).populate("room", "roomNumber floor");
      if (tenant && tenant.room) {
        let roomConv = await Conversation.findOne({ type: "room", room: tenant.room._id }).populate("room", "roomNumber floor");
        if (!roomConv) {
          roomConv = await Conversation.create({
            type: "room",
            name: `Room ${tenant.room.roomNumber} Group`,
            room: tenant.room._id,
            participants: [req.user._id]
          });
        }
        accessibleConversations.push(roomConv);
      }

      // Tenant's private chats (e.g. with Owner)
      const privateConversations = await Conversation.find({
        type: "private",
        participants: req.user._id
      }).populate("participants", "name email role");
      accessibleConversations.push(...privateConversations);
    }

    // Compute unread count for each conversation
    const enriched = await Promise.all(
      accessibleConversations.map(async (conv) => {
        const unreadCount = await Message.countDocuments({
          conversation: conv._id,
          sender: { $ne: req.user._id },
          readBy: { $ne: req.user._id }
        });

        const obj = conv.toObject();
        obj.unreadCount = unreadCount;

        // Custom name display for private chats
        if (conv.type === "private") {
          const otherParticipant = conv.participants.find((p) => String(p._id || p) !== String(req.user._id));
          if (otherParticipant && otherParticipant.name) {
            obj.displayName = `Chat with ${otherParticipant.name}`;
          } else {
            obj.displayName = req.user.role === "owner" ? "Tenant Chat" : "Owner Support Chat";
          }
        } else {
          obj.displayName = conv.name;
        }

        return obj;
      })
    );

    // Sort by lastMessageAt descending
    enriched.sort((a, b) => new Date(b.lastMessageAt) - new Date(a.lastMessageAt));

    return res.status(200).json({
      success: true,
      count: enriched.length,
      data: enriched
    });
  } catch (error) {
    console.error("Get Conversations Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching conversations.",
      error: error.message
    });
  }
};

/**
 * @desc    Start or retrieve a private conversation with a user (e.g. Owner ↔ Tenant)
 * @route   POST /api/conversations/private
 * @access  Private (Owner / Tenant)
 */
const getOrCreatePrivateConversation = async (req, res) => {
  try {
    let { recipientId } = req.body;

    // If tenant didn't specify recipient, route to Owner
    if (!recipientId && req.user.role === "tenant") {
      const owner = await User.findOne({ role: "owner", isActive: true });
      if (owner) {
        recipientId = owner._id;
      }
    }

    if (!recipientId || !isValidObjectId(recipientId)) {
      return res.status(400).json({
        success: false,
        message: "Please provide a valid recipientId."
      });
    }

    const recipient = await User.findById(recipientId);
    if (!recipient) {
      return res.status(404).json({
        success: false,
        message: "Recipient user account not found."
      });
    }

    // Look for existing conversation between these two
    let conversation = await Conversation.findOne({
      type: "private",
      participants: { $all: [req.user._id, recipient._id] }
    }).populate("participants", "name email role");

    if (!conversation) {
      conversation = await Conversation.create({
        type: "private",
        name: `Chat between ${req.user.name} and ${recipient.name}`,
        participants: [req.user._id, recipient._id],
        lastMessage: {
          text: "Conversation started",
          sender: req.user._id,
          sentAt: new Date()
        },
        lastMessageAt: new Date()
      });

      conversation = await Conversation.findById(conversation._id).populate("participants", "name email role");
    }

    return res.status(200).json({
      success: true,
      data: conversation
    });
  } catch (error) {
    console.error("Get or Create Private Conversation Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error creating conversation.",
      error: error.message
    });
  }
};

/**
 * @desc    Get messages for a conversation
 * @route   GET /api/conversations/:id/messages
 * @access  Private (Authorized participants only)
 */
const getConversationMessages = async (req, res) => {
  try {
    const { id } = req.params;
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.max(1, Math.min(100, parseInt(req.query.limit) || 50));
    const skip = (page - 1) * limit;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid conversation ID format."
      });
    }

    const conversation = await Conversation.findById(id).populate("room", "roomNumber floor");
    if (!conversation) {
      return res.status(404).json({
        success: false,
        message: "Conversation not found."
      });
    }

    const access = await checkConversationAccess(conversation, req.user);
    if (!access.allowed) {
      return res.status(403).json({
        success: false,
        message: access.message
      });
    }

    const total = await Message.countDocuments({ conversation: conversation._id });

    // Fetch messages (chronological order)
    const messages = await Message.find({ conversation: conversation._id })
      .populate("sender", "name email role")
      .sort({ createdAt: 1 })
      .skip(skip)
      .limit(limit);

    // Auto mark retrieved messages as read by current user
    await Message.updateMany(
      { conversation: conversation._id, readBy: { $ne: req.user._id } },
      { $addToSet: { readBy: req.user._id } }
    );

    return res.status(200).json({
      success: true,
      count: messages.length,
      conversation: {
        _id: conversation._id,
        name: conversation.name,
        type: conversation.type,
        room: conversation.room
      },
      pagination: {
        total,
        page,
        pages: Math.ceil(total / limit),
        limit
      },
      data: messages
    });
  } catch (error) {
    console.error("Get Conversation Messages Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error retrieving messages.",
      error: error.message
    });
  }
};

/**
 * @desc    Send a message in a conversation
 * @route   POST /api/conversations/:id/messages
 * @access  Private (Authorized participants only)
 */
const sendMessage = async (req, res) => {
  try {
    const { id } = req.params;
    const { content } = req.body;

    if (!content || !content.trim()) {
      return res.status(400).json({
        success: false,
        message: "Message content cannot be empty."
      });
    }

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid conversation ID format."
      });
    }

    const conversation = await Conversation.findById(id);
    if (!conversation) {
      return res.status(404).json({
        success: false,
        message: "Conversation not found."
      });
    }

    const access = await checkConversationAccess(conversation, req.user);
    if (!access.allowed) {
      return res.status(403).json({
        success: false,
        message: access.message
      });
    }

    const trimmedContent = content.trim();

    // Create Message
    const message = await Message.create({
      conversation: conversation._id,
      sender: req.user._id,
      content: trimmedContent,
      readBy: [req.user._id]
    });

    // Update Conversation last message
    conversation.lastMessage = {
      text: trimmedContent,
      sender: req.user._id,
      sentAt: new Date()
    };
    conversation.lastMessageAt = new Date();
    await conversation.save();

    const populatedMessage = await Message.findById(message._id).populate("sender", "name email role");

    return res.status(201).json({
      success: true,
      message: "Message sent successfully.",
      data: populatedMessage
    });
  } catch (error) {
    console.error("Send Message Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error sending message.",
      error: error.message
    });
  }
};

/**
 * @desc    Mark conversation messages as read
 * @route   PUT /api/conversations/:id/read
 * @access  Private
 */
const markConversationAsRead = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid conversation ID format."
      });
    }

    await Message.updateMany(
      { conversation: id, readBy: { $ne: req.user._id } },
      { $addToSet: { readBy: req.user._id } }
    );

    return res.status(200).json({
      success: true,
      message: "Messages marked as read."
    });
  } catch (error) {
    console.error("Mark Read Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error marking messages read.",
      error: error.message
    });
  }
};

module.exports = {
  getConversations,
  getOrCreatePrivateConversation,
  getConversationMessages,
  sendMessage,
  markConversationAsRead
};
