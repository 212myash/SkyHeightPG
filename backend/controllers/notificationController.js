const Notification = require("../models/Notification");
const Tenant = require("../models/Tenant");
const Room = require("../models/Room");
const User = require("../models/User");
const Conversation = require("../models/Conversation");
const Message = require("../models/Message");
const { isValidObjectId } = require("../utils/validateObjectId");
const pushService = require("../services/pushNotificationService");

const VALID_CATEGORIES = [
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
];

/**
 * @desc    Create and dispatch notification(s)
 * @route   POST /api/notifications
 * @access  Private (Owner only)
 */
const createNotification = async (req, res) => {
  try {
    const {
      title,
      message,
      category = "general_announcement",
      audience = "all",
      targetRoom,
      targetTenant,
      dueDate,
      relatedBill,
      relatedComplaint
    } = req.body;

    if (!title || !message) {
      return res.status(400).json({
        success: false,
        message: "Please provide both title and message."
      });
    }

    if (!VALID_CATEGORIES.includes(category)) {
      return res.status(400).json({
        success: false,
        message: `Invalid category. Allowed: ${VALID_CATEGORIES.join(", ")}`
      });
    }

    const createdNotifications = [];

    if (audience === "all") {
      // Broadcast to all active tenants
      const activeTenants = await Tenant.find({ status: "active" }).populate("user");
      for (const t of activeTenants) {
        if (t.user && t.user._id) {
          const notif = await Notification.create({
            recipient: t.user._id,
            sender: req.user._id,
            title: title.trim(),
            message: message.trim(),
            category,
            audience: "all",
            dueDate: dueDate ? new Date(dueDate) : null,
            relatedBill: relatedBill && isValidObjectId(relatedBill) ? relatedBill : null,
            relatedComplaint: relatedComplaint && isValidObjectId(relatedComplaint) ? relatedComplaint : null
          });
          createdNotifications.push(notif);
        }
      }
    } else if (audience === "room") {
      if (!targetRoom || !isValidObjectId(targetRoom)) {
        return res.status(400).json({
          success: false,
          message: "Please provide a valid targetRoom ID for room audience."
        });
      }

      const roomTenants = await Tenant.find({ room: targetRoom, status: "active" }).populate("user");
      for (const t of roomTenants) {
        if (t.user && t.user._id) {
          const notif = await Notification.create({
            recipient: t.user._id,
            sender: req.user._id,
            title: title.trim(),
            message: message.trim(),
            category,
            audience: "room",
            targetRoom,
            dueDate: dueDate ? new Date(dueDate) : null,
            relatedBill: relatedBill && isValidObjectId(relatedBill) ? relatedBill : null,
            relatedComplaint: relatedComplaint && isValidObjectId(relatedComplaint) ? relatedComplaint : null
          });
          createdNotifications.push(notif);
        }
      }
    } else if (audience === "tenant") {
      if (!targetTenant || !isValidObjectId(targetTenant)) {
        return res.status(400).json({
          success: false,
          message: "Please provide a valid targetTenant ID for tenant audience."
        });
      }

      // Check whether targetTenant is Tenant ID or User ID
      let recipientUserId = null;
      let tenantRecord = await Tenant.findById(targetTenant);
      if (tenantRecord) {
        recipientUserId = tenantRecord.user;
      } else {
        const userRecord = await User.findById(targetTenant);
        if (userRecord) {
          recipientUserId = userRecord._id;
          tenantRecord = await Tenant.findOne({ user: userRecord._id });
        }
      }

      if (!recipientUserId) {
        return res.status(404).json({
          success: false,
          message: "Target tenant or user account not found."
        });
      }

      const notif = await Notification.create({
        recipient: recipientUserId,
        sender: req.user._id,
        title: title.trim(),
        message: message.trim(),
        category,
        audience: "tenant",
        targetTenant: tenantRecord ? tenantRecord._id : null,
        targetRoom: tenantRecord ? tenantRecord.room : null,
        dueDate: dueDate ? new Date(dueDate) : null,
        relatedBill: relatedBill && isValidObjectId(relatedBill) ? relatedBill : null,
        relatedComplaint: relatedComplaint && isValidObjectId(relatedComplaint) ? relatedComplaint : null
      });
      createdNotifications.push(notif);
    } else {
      return res.status(400).json({
        success: false,
        message: "Invalid audience. Must be 'all', 'room', or 'tenant'."
      });
    }

    if (createdNotifications.length > 0) {
      const recipientIds = [...new Set(createdNotifications.map((n) => n.recipient.toString()))];
      // Asynchronously trigger push notifications without blocking HTTP response
      pushService.sendPushToUsers(recipientIds, {
        title: title.trim(),
        body: message.trim(),
        data: {
          category,
          audience,
          screen: "/notifications",
          count: createdNotifications.length.toString()
        },
        channelId: pushService.CATEGORY_CHANNEL_MAP[category] || "announcements"
      }).catch((err) => {
        console.error("Async push dispatch error in createNotification:", err.message);
      });
    }

    return res.status(201).json({
      success: true,
      message: `Notification dispatched successfully to ${createdNotifications.length} recipient(s).`,
      count: createdNotifications.length,
      data: createdNotifications
    });
  } catch (error) {
    console.error("Create Notification Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error creating notification.",
      error: error.message
    });
  }
};

/**
 * @desc    Get current user's notifications
 * @route   GET /api/notifications
 * @access  Private (Owner / Tenant)
 */
const getMyNotifications = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.max(1, Math.min(100, parseInt(req.query.limit) || 30));
    const skip = (page - 1) * limit;

    const query = { recipient: req.user._id };

    if (req.query.isRead !== undefined) {
      query.isRead = req.query.isRead === "true";
    }

    if (req.query.category && VALID_CATEGORIES.includes(req.query.category)) {
      query.category = req.query.category;
    }

    const total = await Notification.countDocuments(query);
    const unreadCount = await Notification.countDocuments({ recipient: req.user._id, isRead: false });

    const notifications = await Notification.find(query)
      .populate("sender", "name email role")
      .populate("targetRoom", "roomNumber floor")
      .populate("relatedBill", "billingMonth totalAmount paymentStatus")
      .populate("relatedComplaint", "title status priority")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    return res.status(200).json({
      success: true,
      count: notifications.length,
      unreadCount,
      pagination: {
        total,
        page,
        pages: Math.ceil(total / limit),
        limit
      },
      data: notifications
    });
  } catch (error) {
    console.error("Get My Notifications Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching notifications.",
      error: error.message
    });
  }
};

/**
 * @desc    Get unread notifications count
 * @route   GET /api/notifications/unread-count
 * @access  Private (Owner / Tenant)
 */
const getUnreadCount = async (req, res) => {
  try {
    const count = await Notification.countDocuments({ recipient: req.user._id, isRead: false });
    return res.status(200).json({
      success: true,
      unreadCount: count
    });
  } catch (error) {
    console.error("Get Unread Count Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error retrieving unread count.",
      error: error.message
    });
  }
};

/**
 * @desc    Mark a notification as read
 * @route   PUT /api/notifications/:id/read
 * @access  Private (Recipient only)
 */
const markAsRead = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid notification ID format."
      });
    }

    const notification = await Notification.findById(id);
    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "Notification not found."
      });
    }

    // Recipient check (or owner)
    if (String(notification.recipient) !== String(req.user._id) && req.user.role !== "owner") {
      return res.status(403).json({
        success: false,
        message: "Forbidden: You cannot modify this notification."
      });
    }

    notification.isRead = true;
    notification.readAt = new Date();
    await notification.save();

    return res.status(200).json({
      success: true,
      message: "Notification marked as read.",
      data: notification
    });
  } catch (error) {
    console.error("Mark As Read Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error updating notification.",
      error: error.message
    });
  }
};

/**
 * @desc    Mark all user's notifications as read
 * @route   PUT /api/notifications/read-all
 * @access  Private (Owner / Tenant)
 */
const markAllAsRead = async (req, res) => {
  try {
    await Notification.updateMany(
      { recipient: req.user._id, isRead: false },
      { $set: { isRead: true, readAt: new Date() } }
    );

    return res.status(200).json({
      success: true,
      message: "All notifications marked as read."
    });
  } catch (error) {
    console.error("Mark All Read Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error marking notifications read.",
      error: error.message
    });
  }
};

/**
 * @desc    Tenant reply to notification (routes into private chat with Owner)
 * @route   POST /api/notifications/:id/reply
 * @access  Private (Tenant only)
 */
const replyToNotification = async (req, res) => {
  try {
    const { id } = req.params;
    const { message: replyText } = req.body;

    if (!replyText || !replyText.trim()) {
      return res.status(400).json({
        success: false,
        message: "Reply message cannot be empty."
      });
    }

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid notification ID format."
      });
    }

    const notification = await Notification.findById(id);
    if (!notification) {
      return res.status(404).json({
        success: false,
        message: "Notification not found."
      });
    }

    // Resolve owner recipient
    let owner = null;
    if (notification.sender) {
      owner = await User.findById(notification.sender);
    }
    if (!owner) {
      owner = await User.findOne({ role: "owner", isActive: true });
    }

    if (!owner) {
      return res.status(500).json({
        success: false,
        message: "Owner account could not be found to route reply."
      });
    }

    // Find or create private conversation between tenant and owner
    let conversation = await Conversation.findOne({
      type: "private",
      participants: { $all: [req.user._id, owner._id] }
    });

    if (!conversation) {
      conversation = await Conversation.create({
        type: "private",
        name: `Chat with ${req.user.name}`,
        participants: [req.user._id, owner._id],
        lastMessage: {
          text: replyText.trim(),
          sender: req.user._id,
          sentAt: new Date()
        },
        lastMessageAt: new Date()
      });
    }

    const fullMessageText = `[Re: ${notification.title}] ${replyText.trim()}`;

    // Create Message
    const newMsg = await Message.create({
      conversation: conversation._id,
      sender: req.user._id,
      content: fullMessageText,
      readBy: [req.user._id]
    });

    // Update Conversation last message
    conversation.lastMessage = {
      text: fullMessageText,
      sender: req.user._id,
      sentAt: new Date()
    };
    conversation.lastMessageAt = new Date();
    await conversation.save();

    // Notify Owner of reply
    await Notification.create({
      recipient: owner._id,
      sender: req.user._id,
      title: `Reply from ${req.user.name}`,
      message: fullMessageText,
      category: "general_announcement",
      audience: "tenant"
    });

    // Also mark the original notification as read
    notification.isRead = true;
    notification.readAt = new Date();
    await notification.save();

    return res.status(200).json({
      success: true,
      message: "Reply sent to Owner chat successfully.",
      data: {
        conversationId: conversation._id,
        message: newMsg
      }
    });
  } catch (error) {
    console.error("Reply To Notification Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error sending reply.",
      error: error.message
    });
  }
};

/**
 * @desc    Get sent notifications history
 * @route   GET /api/notifications/sent
 * @access  Private (Owner only)
 */
const getSentNotifications = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.max(1, Math.min(100, parseInt(req.query.limit) || 30));
    const skip = (page - 1) * limit;

    const query = { sender: req.user._id };

    const total = await Notification.countDocuments(query);
    const sent = await Notification.find(query)
      .populate("recipient", "name email")
      .populate("targetRoom", "roomNumber floor")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    return res.status(200).json({
      success: true,
      count: sent.length,
      pagination: {
        total,
        page,
        pages: Math.ceil(total / limit),
        limit
      },
      data: sent
    });
  } catch (error) {
    console.error("Get Sent Notifications Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching sent notifications.",
      error: error.message
    });
  }
};

/**
 * @desc    Register or update device push token
 * @route   POST /api/notifications/device-token
 * @access  Private
 */
const registerDeviceToken = async (req, res) => {
  try {
    const { token, platform, deviceId } = req.body;
    if (!token || typeof token !== "string" || !token.trim()) {
      return res.status(400).json({
        success: false,
        message: "Device token is required."
      });
    }

    const doc = await pushService.registerDeviceToken({
      userId: req.user._id,
      token: token.trim(),
      platform: platform || "android",
      deviceId: deviceId || null
    });

    return res.status(200).json({
      success: true,
      message: "Device token registered successfully.",
      data: doc
    });
  } catch (error) {
    console.error("Register Device Token Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error registering device token.",
      error: error.message
    });
  }
};

/**
 * @desc    Remove device push token upon logout
 * @route   DELETE /api/notifications/device-token
 * @access  Private
 */
const removeDeviceToken = async (req, res) => {
  try {
    const { token } = req.body;
    if (!token || typeof token !== "string" || !token.trim()) {
      return res.status(400).json({
        success: false,
        message: "Device token is required."
      });
    }

    await pushService.removeDeviceToken({
      userId: req.user._id,
      token: token.trim()
    });

    return res.status(200).json({
      success: true,
      message: "Device token removed successfully."
    });
  } catch (error) {
    console.error("Remove Device Token Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error removing device token.",
      error: error.message
    });
  }
};

module.exports = {
  createNotification,
  getMyNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  replyToNotification,
  getSentNotifications,
  registerDeviceToken,
  removeDeviceToken
};
