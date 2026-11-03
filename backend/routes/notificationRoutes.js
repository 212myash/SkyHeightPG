const express = require("express");
const router = express.Router();
const {
  createNotification,
  getMyNotifications,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  replyToNotification,
  getSentNotifications,
  registerDeviceToken,
  removeDeviceToken
} = require("../controllers/notificationController");
const { protect, authorize } = require("../middleware/authMiddleware");

// All notification routes require authentication
router.use(protect);

// Device token registration & removal (All authenticated users)
router.post("/device-token", registerDeviceToken);
router.delete("/device-token", removeDeviceToken);

// User notification endpoints
router.get("/", getMyNotifications);
router.get("/unread-count", getUnreadCount);
router.put("/read-all", markAllAsRead);
router.put("/:id/read", markAsRead);
router.post("/:id/reply", replyToNotification);

// Owner-only endpoints
router.post("/", authorize("owner"), createNotification);
router.get("/sent", authorize("owner"), getSentNotifications);

module.exports = router;
