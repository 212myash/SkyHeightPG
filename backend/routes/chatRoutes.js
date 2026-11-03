const express = require("express");
const router = express.Router();
const {
  getConversations,
  getOrCreatePrivateConversation,
  getConversationMessages,
  sendMessage,
  markConversationAsRead
} = require("../controllers/chatController");
const { protect } = require("../middleware/authMiddleware");

// All chat routes require authentication
router.use(protect);

router.get("/", getConversations);
router.post("/private", getOrCreatePrivateConversation);
router.get("/:id/messages", getConversationMessages);
router.post("/:id/messages", sendMessage);
router.put("/:id/read", markConversationAsRead);

module.exports = router;
