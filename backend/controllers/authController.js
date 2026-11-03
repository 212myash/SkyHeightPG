const User = require("../models/User");
const Tenant = require("../models/Tenant");
const Notification = require("../models/Notification");
const generateToken = require("../utils/generateToken");
const pushService = require("../services/pushNotificationService");

/**
 * @desc    Register a new user
 * @route   POST /api/auth/register
 * @access  Public (Owner protected after initial owner bootstrap)
 */
const registerUser = async (req, res) => {
  try {
    const { name, email, password, phone, role } = req.body;

    // Validate required fields
    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: "Please provide name, email, and password."
      });
    }

    // Validate email format
    const emailRegex = /^\S+@\S+\.\S+$/;
    if (!emailRegex.test(email)) {
      return res.status(400).json({
        success: false,
        message: "Please provide a valid email address."
      });
    }

    // Validate password length
    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Password must be at least 6 characters long."
      });
    }

    // Normalized email
    const normalizedEmail = email.toLowerCase().trim();

    // Check if user already exists
    const existingUser = await User.findOne({ email: normalizedEmail });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: "A user with this email already exists."
      });
    }

    // Determine target role (default to 'tenant' if not specified)
    const targetRole = role ? role.toLowerCase().trim() : "tenant";

    if (!["owner", "tenant"].includes(targetRole)) {
      return res.status(400).json({
        success: false,
        message: "Invalid role specified. Role must be either 'owner' or 'tenant'."
      });
    }

    // Owner-Only Registration Protection: public registration cannot create owner
    if (targetRole === "owner") {
      const ownerExists = await User.exists({ role: "owner" });
      if (ownerExists) {
        if (!req.user || req.user.role !== "owner") {
          return res.status(403).json({
            success: false,
            message: "Public registration as Owner is not permitted. Only an existing Owner can create another Owner."
          });
        }
      }
    }

    // Determine initial approval status:
    // If registered by existing owner -> 'approved'
    // Public tenant registrations -> 'pending'
    const isOwnerInitiated = req.user && req.user.role === "owner";
    const initialApprovalStatus = isOwnerInitiated || targetRole === "owner" ? "approved" : "pending";

    // Create user
    const user = await User.create({
      name: name.trim(),
      email: normalizedEmail,
      password,
      phone: phone ? phone.trim() : "",
      role: targetRole,
      approvalStatus: initialApprovalStatus,
      approvedAt: initialApprovalStatus === "approved" ? new Date() : null,
      approvedBy: isOwnerInitiated ? req.user._id : null,
      isActive: true
    });

    // If tenant, create unallocated Tenant profile if not exists
    if (targetRole === "tenant") {
      await Tenant.create({
        user: user._id,
        fullName: user.name,
        email: user.email,
        phone: user.phone || "0000000000",
        room: null,
        assignedBed: "",
        monthlyRent: 0,
        securityDeposit: 0,
        status: initialApprovalStatus === "approved" ? "active" : "pending_allocation",
        approvalStatus: initialApprovalStatus
      });

      // Send in-app notification to all active Owners about pending registration
      if (initialApprovalStatus === "pending") {
        try {
          const owners = await User.find({ role: "owner", isActive: true });
          for (const owner of owners) {
            await Notification.create({
              recipient: owner._id,
              sender: user._id,
              title: "New Registration Request",
              message: `${user.name} (${user.email}) has registered and requires approval.`,
              category: "registration_update",
              audience: "tenant"
            });
          }

          // Dispatch push to owner
          pushService.sendPushToRole("owner", {
            title: "New Registration Request",
            body: `${user.name} (${user.email}) has registered and requires approval.`,
            data: {
              category: "registration_update",
              screen: "/owner/registrations",
              userId: user._id.toString()
            },
            channelId: "alerts"
          }).catch((err) => console.error("Registration push error:", err.message));
        } catch (notifErr) {
          console.error("Failed to notify owners of registration:", notifErr);
        }
      }
    }

    // If pending approval, do not issue an active session token
    const token = initialApprovalStatus === "approved" ? generateToken(user._id, user.role) : null;

    return res.status(201).json({
      success: true,
      message: initialApprovalStatus === "pending"
        ? "Registration submitted successfully. Your account is pending approval by the owner."
        : "User registered successfully.",
      approvalStatus: initialApprovalStatus,
      token,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        approvalStatus: user.approvalStatus,
        isActive: user.isActive,
        createdAt: user.createdAt
      }
    });
  } catch (error) {
    console.error("Register Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error during registration.",
      error: error.message
    });
  }
};

/**
 * @desc    Authenticate user & get token
 * @route   POST /api/auth/login
 * @access  Public
 */
const loginUser = async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate inputs
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Please provide both email and password."
      });
    }

    const normalizedEmail = email.toLowerCase().trim();

    // Find user by email
    const user = await User.findOne({ email: normalizedEmail });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password."
      });
    }

    // Check password
    const isPasswordMatch = await user.comparePassword(password);
    if (!isPasswordMatch) {
      return res.status(401).json({
        success: false,
        message: "Invalid email or password."
      });
    }

    // Check if account is active
    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: "Your account is deactivated. Please contact the owner."
      });
    }

    // Check approval status for tenants
    if (user.role === "tenant" && user.approvalStatus === "pending") {
      return res.status(403).json({
        success: false,
        approvalStatus: "pending",
        message: "Your registration is pending approval from the apartment Owner."
      });
    }

    if (user.role === "tenant" && user.approvalStatus === "rejected") {
      return res.status(403).json({
        success: false,
        approvalStatus: "rejected",
        rejectionReason: user.rejectionReason || "",
        message: `Your registration was rejected: ${user.rejectionReason || "Please contact the owner."}`
      });
    }

    const token = generateToken(user._id, user.role);

    return res.status(200).json({
      success: true,
      message: "Login successful.",
      token,
      user: {
        _id: user._id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role,
        approvalStatus: user.approvalStatus,
        isActive: user.isActive,
        createdAt: user.createdAt
      }
    });
  } catch (error) {
    console.error("Login Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error during login.",
      error: error.message
    });
  }
};

/**
 * @desc    Get currently authenticated user profile
 * @route   GET /api/auth/profile
 * @access  Private (Owner / Tenant)
 */
const getProfile = async (req, res) => {
  try {
    return res.status(200).json({
      success: true,
      user: req.user
    });
  } catch (error) {
    console.error("Get Profile Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error retrieving profile.",
      error: error.message
    });
  }
};

/**
 * @desc    Change password for authenticated user
 * @route   PUT /api/auth/change-password
 * @access  Private
 */
const changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: "Please provide both current and new password."
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: "New password must be at least 6 characters long."
      });
    }

    const user = await User.findById(req.user._id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: "User not found."
      });
    }

    const isMatch = await user.comparePassword(currentPassword);
    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: "Current password does not match."
      });
    }

    user.password = newPassword;
    await user.save();

    return res.status(200).json({
      success: true,
      message: "Password changed successfully."
    });
  } catch (error) {
    console.error("Change Password Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error updating password.",
      error: error.message
    });
  }
};

/**
 * @desc    Check whether an initial owner account already exists
 * @route   GET /api/auth/owner-status
 * @access  Public
 */
const getOwnerStatus = async (req, res) => {
  try {
    const ownerExists = await User.exists({ role: "owner" });
    return res.status(200).json({
      success: true,
      hasOwner: Boolean(ownerExists)
    });
  } catch (error) {
    console.error("Owner Status Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error checking owner status.",
      error: error.message
    });
  }
};

module.exports = {
  registerUser,
  loginUser,
  getProfile,
  changePassword,
  getOwnerStatus
};
