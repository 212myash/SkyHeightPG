const admin = require("firebase-admin");
const DeviceToken = require("../models/DeviceToken");
const Notification = require("../models/Notification");
const User = require("../models/User");

// Channel mapping for Android notification channels
const CATEGORY_CHANNEL_MAP = {
  rent_reminder: "billing",
  electricity_bill: "billing",
  payment_reminder: "billing",
  payment_received: "billing",
  maintenance: "maintenance",
  complaint_update: "maintenance",
  general_announcement: "announcements",
  security_alert: "alerts",
  registration_update: "alerts",
  chat_message: "messages",
  system: "alerts"
};

let isFirebaseConfigured = false;

/**
 * Safely initialize Firebase Admin SDK if credentials exist in environment
 */
function initFirebase() {
  const apps = typeof admin.getApps === "function" ? admin.getApps() : (admin.apps || []);
  if (apps.length > 0) {
    isFirebaseConfigured = true;
    return;
  }

  try {
    let credential = null;

    if (process.env.FIREBASE_SERVICE_ACCOUNT_KEY) {
      const raw = process.env.FIREBASE_SERVICE_ACCOUNT_KEY.trim();
      let serviceAccount;
      if (raw.startsWith("{")) {
        serviceAccount = JSON.parse(raw);
      } else {
        const fs = require("fs");
        if (fs.existsSync(raw)) {
          serviceAccount = JSON.parse(fs.readFileSync(raw, "utf8"));
        }
      }
      if (serviceAccount) {
        credential = admin.credential.cert(serviceAccount);
      }
    } else if (
      process.env.FIREBASE_PROJECT_ID &&
      process.env.FIREBASE_CLIENT_EMAIL &&
      process.env.FIREBASE_PRIVATE_KEY
    ) {
      credential = admin.credential.cert({
        projectId: process.env.FIREBASE_PROJECT_ID,
        clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
        privateKey: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, "\n")
      });
    } else if (process.env.GOOGLE_APPLICATION_CREDENTIALS) {
      credential = admin.credential.applicationDefault();
    }

    if (credential) {
      admin.initializeApp({ credential });
      isFirebaseConfigured = true;
      console.log("[PushNotificationService] Firebase Admin SDK initialized successfully.");
    } else {
      isFirebaseConfigured = false;
      console.warn(
        "[PushNotificationService] Firebase credentials not configured. Running in graceful offline/in-app notification mode."
      );
    }
  } catch (error) {
    isFirebaseConfigured = false;
    console.warn(
      `[PushNotificationService] Firebase Admin initialization failed (${error.message}). Running in graceful fallback mode.`
    );
  }
}

// Attempt initialization on module load
initFirebase();

/**
 * Register or update a device token for a user
 */
async function registerDeviceToken({ userId, token, platform = "android", deviceId = null }) {
  if (!userId || !token) {
    throw new Error("userId and token are required for device token registration.");
  }

  const cleanToken = token.trim();
  const cleanPlatform = ["android", "ios", "web"].includes(platform) ? platform : "android";

  // Upsert token to handle re-registration or device handover cleanly
  const updated = await DeviceToken.findOneAndUpdate(
    { token: cleanToken },
    {
      user: userId,
      platform: cleanPlatform,
      deviceId: deviceId || null,
      lastUsedAt: new Date()
    },
    { upsert: true, new: true, setDefaultsOnInsert: true }
  );

  return updated;
}

/**
 * Remove a specific device token (e.g. on logout)
 */
async function removeDeviceToken({ userId, token }) {
  if (!token) return { deletedCount: 0 };
  const query = { token: token.trim() };
  if (userId) query.user = userId;
  return await DeviceToken.deleteMany(query);
}

/**
 * Remove all tokens for a user
 */
async function removeAllUserTokens(userId) {
  if (!userId) return { deletedCount: 0 };
  return await DeviceToken.deleteMany({ user: userId });
}

/**
 * Remove invalid or unregistered tokens identified by FCM
 */
async function cleanInvalidTokens(tokens) {
  if (!tokens || tokens.length === 0) return 0;
  try {
    const res = await DeviceToken.deleteMany({ token: { $in: tokens } });
    if (res.deletedCount > 0) {
      console.log(`[PushNotificationService] Cleaned up ${res.deletedCount} invalid/expired device token(s).`);
    }
    return res.deletedCount;
  } catch (err) {
    console.error("[PushNotificationService] Error cleaning invalid tokens:", err.message);
    return 0;
  }
}

/**
 * Low-level dispatch to an array of FCM tokens
 */
async function sendPushToTokens(tokens, { title, body, data = {}, channelId = "alerts" }) {
  if (!tokens || tokens.length === 0) {
    return { successCount: 0, failureCount: 0, status: "no_tokens" };
  }

  // Graceful fallback if Firebase is unconfigured
  if (!isFirebaseConfigured) {
    console.log(
      `[PushNotificationService:Fallback] [Simulated Push] To ${tokens.length} token(s) | Channel: ${channelId} | Title: "${title}"`
    );
    return {
      successCount: tokens.length,
      failureCount: 0,
      status: "simulated_success",
      simulated: true
    };
  }

  // Ensure all data payload values are strings (FCM requirement)
  const stringifiedData = {};
  for (const [key, val] of Object.entries(data)) {
    if (val !== undefined && val !== null) {
      stringifiedData[key] = typeof val === "string" ? val : JSON.stringify(val);
    }
  }

  const payload = {
    notification: {
      title: String(title),
      body: String(body)
    },
    data: stringifiedData,
    android: {
      priority: "high",
      notification: {
        channelId: channelId || "alerts",
        sound: "default",
        priority: "high",
        visibility: "public"
      }
    },
    tokens: tokens
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(payload);
    const invalidTokens = [];

    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error) {
        const code = resp.error.code;
        if (
          code === "messaging/invalid-registration-token" ||
          code === "messaging/registration-token-not-registered" ||
          code === "messaging/mismatched-credential"
        ) {
          invalidTokens.push(tokens[idx]);
        }
      }
    });

    if (invalidTokens.length > 0) {
      await cleanInvalidTokens(invalidTokens);
    }

    return {
      successCount: response.successCount,
      failureCount: response.failureCount,
      status: "delivered",
      simulated: false
    };
  } catch (error) {
    console.error("[PushNotificationService] FCM Multicast dispatch error:", error.message);
    return {
      successCount: 0,
      failureCount: tokens.length,
      status: "error",
      error: error.message
    };
  }
}

/**
 * Send push notification to a specific user
 */
async function sendPushToUser(userId, { title, body, data = {}, channelId = "alerts" }) {
  if (!userId) return { successCount: 0, failureCount: 0 };
  const tokens = await DeviceToken.find({ user: userId }).distinct("token");
  if (!tokens || tokens.length === 0) {
    return { successCount: 0, failureCount: 0, status: "user_has_no_tokens" };
  }
  return await sendPushToTokens(tokens, { title, body, data, channelId });
}

/**
 * Send push notification to multiple user IDs
 */
async function sendPushToUsers(userIds, { title, body, data = {}, channelId = "alerts" }) {
  if (!userIds || userIds.length === 0) return { successCount: 0, failureCount: 0 };
  const tokens = await DeviceToken.find({ user: { $in: userIds } }).distinct("token");
  if (!tokens || tokens.length === 0) {
    return { successCount: 0, failureCount: 0, status: "users_have_no_tokens" };
  }
  return await sendPushToTokens(tokens, { title, body, data, channelId });
}

/**
 * Send push notification to all active users with a specific role
 */
async function sendPushToRole(role, { title, body, data = {}, channelId = "alerts" }) {
  const users = await User.find({ role, isActive: true }).select("_id");
  const userIds = users.map((u) => u._id);
  return await sendPushToUsers(userIds, { title, body, data, channelId });
}

/**
 * Centralized notification and push dispatcher:
 * 1. Creates persistent in-app Notification record in MongoDB
 * 2. Fires FCM push notification with appropriate Android notification channel
 */
async function dispatchNotificationAndPush({
  recipientId,
  role,
  senderId = null,
  title,
  message,
  category = "system",
  audience = "tenant",
  targetRoom = null,
  targetTenant = null,
  dueDate = null,
  relatedBill = null,
  relatedComplaint = null,
  data = {},
  channelId = null
}) {
  const effectiveChannel = channelId || CATEGORY_CHANNEL_MAP[category] || "alerts";
  const pushData = {
    category,
    ...data
  };

  try {
    if (recipientId) {
      const notif = await Notification.create({
        recipient: recipientId,
        sender: senderId,
        title,
        message,
        category,
        audience,
        targetRoom,
        targetTenant,
        dueDate,
        relatedBill,
        relatedComplaint
      });

      pushData.notificationId = notif._id.toString();

      const pushResult = await sendPushToUser(recipientId, {
        title,
        body: message,
        data: pushData,
        channelId: effectiveChannel
      });

      return { notification: notif, pushResult };
    }

    if (role) {
      const users = await User.find({ role, isActive: true }).select("_id");
      const createdNotifs = [];

      for (const u of users) {
        const notif = await Notification.create({
          recipient: u._id,
          sender: senderId,
          title,
          message,
          category,
          audience,
          targetRoom,
          targetTenant,
          dueDate,
          relatedBill,
          relatedComplaint
        });
        createdNotifs.push(notif);
      }

      const userIds = users.map((u) => u._id);
      const pushResult = await sendPushToUsers(userIds, {
        title,
        body: message,
        data: pushData,
        channelId: effectiveChannel
      });

      return { notifications: createdNotifs, pushResult };
    }

    return null;
  } catch (err) {
    console.error("[PushNotificationService] dispatchNotificationAndPush error:", err);
    return null;
  }
}

module.exports = {
  isFirebaseConfigured: () => isFirebaseConfigured,
  CATEGORY_CHANNEL_MAP,
  registerDeviceToken,
  removeDeviceToken,
  removeAllUserTokens,
  sendPushToTokens,
  sendPushToUser,
  sendPushToUsers,
  sendPushToRole,
  dispatchNotificationAndPush
};
