const jwt = require("jsonwebtoken");
const User = require("../models/User");

/**
 * Protect routes - Verifies JWT and attaches authenticated user to req.user
 */
const protect = async (req, res, next) => {
  try {
    let token;

    if (
      req.headers.authorization &&
      req.headers.authorization.startsWith("Bearer ")
    ) {
      token = req.headers.authorization.split(" ")[1];
    }

    if (!token) {
      return res.status(401).json({
        success: false,
        message: "Authentication required. No token provided."
      });
    }

    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // Fetch user from database
    const user = await User.findById(decoded.id).select("-password");
    if (!user) {
      return res.status(401).json({
        success: false,
        message: "User associated with this token no longer exists."
      });
    }

    if (!user.isActive) {
      return res.status(403).json({
        success: false,
        message: "Account is inactive. Please contact the administrator."
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

    req.user = user;
    next();
  } catch (error) {
    if (error.name === "TokenExpiredError") {
      return res.status(401).json({
        success: false,
        message: "Token has expired. Please log in again."
      });
    }
    return res.status(401).json({
      success: false,
      message: "Invalid or malformed token."
    });
  }
};

/**
 * Role-based authorization middleware
 * @param  {...string} roles Allowed roles (e.g. 'owner', 'tenant')
 */
const authorize = (...roles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: "Authentication required."
      });
    }

    if (!roles.includes(req.user.role)) {
      return res.status(403).json({
        success: false,
        message: `Forbidden: Access denied for role '${req.user.role}'. Requires: ${roles.join(", ")}`
      });
    }

    next();
  };
};

/**
 * Optional authentication - attaches user if valid token present, but doesn't reject if not
 */
const optionalAuth = async (req, res, next) => {
  try {
    let token;
    if (
      req.headers.authorization &&
      req.headers.authorization.startsWith("Bearer ")
    ) {
      token = req.headers.authorization.split(" ")[1];
    }

    if (token) {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const user = await User.findById(decoded.id).select("-password");
      if (user && user.isActive) {
        req.user = user;
      }
    }
  } catch {
    // Silently continue without user attached
  }
  next();
};

module.exports = {
  protect,
  authorize,
  optionalAuth
};
