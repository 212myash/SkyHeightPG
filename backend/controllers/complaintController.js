const Complaint = require("../models/Complaint");
const Tenant = require("../models/Tenant");
const Notification = require("../models/Notification");
const User = require("../models/User");
const { isValidObjectId } = require("../utils/validateObjectId");

/**
 * @desc    File a new complaint
 * @route   POST /api/complaints
 * @access  Private (Tenant only)
 */
const createComplaint = async (req, res) => {
  try {
    const { title, description, category, priority } = req.body;

    if (!title || !description) {
      return res.status(400).json({
        success: false,
        message: "Please provide both complaint title and description."
      });
    }

    const tenant = await Tenant.findOne({ user: req.user._id, status: "active" });
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "Active tenant profile required to file a complaint."
      });
    }

    const complaint = await Complaint.create({
      tenant: tenant._id,
      room: tenant.room,
      title: title.trim(),
      description: description.trim(),
      category: category || "other",
      priority: priority || "medium",
      status: "open"
    });

    // Send in-app notification to all active Owners
    try {
      const owners = await User.find({ role: "owner", isActive: true });
      for (const owner of owners) {
        await Notification.create({
          recipient: owner._id,
          sender: req.user._id,
          title: `New Complaint: ${complaint.title}`,
          message: `${tenant.fullName} has filed a ${complaint.priority} priority complaint (${complaint.category}).`,
          category: "complaint_update",
          audience: "tenant",
          targetTenant: tenant._id,
          targetRoom: tenant.room,
          relatedComplaint: complaint._id
        });
      }
    } catch (notifErr) {
      console.error("Failed to notify owners of new complaint:", notifErr);
    }

    return res.status(201).json({
      success: true,
      message: "Complaint registered successfully.",
      data: complaint
    });
  } catch (error) {
    console.error("Create Complaint Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error registering complaint.",
      error: error.message
    });
  }
};

/**
 * @desc    Get complaints filed by authenticated tenant
 * @route   GET /api/complaints/my-complaints
 * @access  Private (Tenant only)
 */
const getMyComplaints = async (req, res) => {
  try {
    const tenant = await Tenant.findOne({ user: req.user._id });
    if (!tenant) {
      return res.status(404).json({
        success: false,
        message: "No tenant profile found."
      });
    }

    const complaints = await Complaint.find({ tenant: tenant._id })
      .populate("room", "roomNumber floor")
      .populate("resolvedBy", "name")
      .sort({ createdAt: -1 });

    return res.status(200).json({
      success: true,
      count: complaints.length,
      data: complaints
    });
  } catch (error) {
    console.error("Get My Complaints Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error retrieving complaints.",
      error: error.message
    });
  }
};

/**
 * @desc    Get all complaints across the PG
 * @route   GET /api/complaints
 * @access  Private (Owner only)
 */
const getAllComplaints = async (req, res) => {
  try {
    const page = Math.max(1, parseInt(req.query.page) || 1);
    const limit = Math.max(1, Math.min(100, parseInt(req.query.limit) || 20));
    const skip = (page - 1) * limit;

    const query = {};

    if (req.query.status) query.status = req.query.status;
    if (req.query.priority) query.priority = req.query.priority;
    if (req.query.category) query.category = req.query.category;
    if (req.query.roomId && isValidObjectId(req.query.roomId)) query.room = req.query.roomId;

    const totalComplaints = await Complaint.countDocuments(query);
    const complaints = await Complaint.find(query)
      .populate("tenant", "fullName phone email")
      .populate("room", "roomNumber floor")
      .populate("resolvedBy", "name")
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    return res.status(200).json({
      success: true,
      count: complaints.length,
      pagination: {
        total: totalComplaints,
        page,
        pages: Math.ceil(totalComplaints / limit),
        limit
      },
      data: complaints
    });
  } catch (error) {
    console.error("Get All Complaints Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching complaints.",
      error: error.message
    });
  }
};

/**
 * @desc    Get complaint details by ID
 * @route   GET /api/complaints/:id
 * @access  Private (Owner or Complaint Tenant)
 */
const getComplaintById = async (req, res) => {
  try {
    const { id } = req.params;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Complaint ID format."
      });
    }

    const complaint = await Complaint.findById(id)
      .populate("tenant", "fullName phone email user")
      .populate("room", "roomNumber floor")
      .populate("resolvedBy", "name email");

    if (!complaint) {
      return res.status(404).json({
        success: false,
        message: "Complaint not found."
      });
    }

    // Role verification: Tenant can only view their own complaint
    if (req.user.role === "tenant" && String(complaint.tenant.user) !== String(req.user._id)) {
      return res.status(403).json({
        success: false,
        message: "Forbidden: You are not authorized to view another tenant's complaint."
      });
    }

    return res.status(200).json({
      success: true,
      data: complaint
    });
  } catch (error) {
    console.error("Get Complaint By ID Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching complaint details.",
      error: error.message
    });
  }
};

/**
 * @desc    Update complaint status and resolution
 * @route   PUT /api/complaints/:id/status
 * @access  Private (Owner only)
 */
const updateComplaintStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status, resolution } = req.body;

    if (!isValidObjectId(id)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Complaint ID format."
      });
    }

    const validStatuses = ["open", "in_progress", "resolved", "rejected"];
    if (!status || !validStatuses.includes(status)) {
      return res.status(400).json({
        success: false,
        message: `Status must be one of: ${validStatuses.join(", ")}`
      });
    }

    const complaint = await Complaint.findById(id).populate("tenant", "fullName user");
    if (!complaint) {
      return res.status(404).json({
        success: false,
        message: "Complaint not found."
      });
    }

    complaint.status = status;
    if (resolution !== undefined) {
      complaint.resolution = resolution.trim();
    }

    if (status === "resolved") {
      complaint.resolvedBy = req.user._id;
      complaint.resolvedAt = new Date();
    }

    await complaint.save();

    // Send in-app notification to the tenant regarding complaint resolution/status change
    try {
      if (complaint.tenant && complaint.tenant.user) {
        await Notification.create({
          recipient: complaint.tenant.user,
          sender: req.user._id,
          title: `Complaint Updated: ${complaint.title}`,
          message: `Your complaint status has been updated to '${status}'.${complaint.resolution ? ` Resolution notes: ${complaint.resolution}` : ""}`,
          category: "complaint_update",
          audience: "tenant",
          targetTenant: complaint.tenant._id,
          relatedComplaint: complaint._id
        });
      }
    } catch (notifErr) {
      console.error("Failed to notify tenant of complaint update:", notifErr);
    }

    return res.status(200).json({
      success: true,
      message: `Complaint status updated to '${status}'.`,
      data: complaint
    });
  } catch (error) {
    console.error("Update Complaint Status Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error updating complaint.",
      error: error.message
    });
  }
};

module.exports = {
  createComplaint,
  getMyComplaints,
  getAllComplaints,
  getComplaintById,
  updateComplaintStatus
};
