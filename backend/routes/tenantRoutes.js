const express = require("express");
const router = express.Router();

const {
  registerTenant,
  getAllTenants,
  getMyTenantProfile,
  getTenantById,
  updateTenant,
  assignRoom,
  changeRoomAssignment,
  vacateTenant,
  getTenantOccupancyHistory,
  getMyOccupancyHistory
} = require("../controllers/tenantController");

const { protect, authorize } = require("../middleware/authMiddleware");

// All tenant routes require authentication
router.use(protect);

// Get currently authenticated tenant's profile
router.get("/me", authorize("tenant"), getMyTenantProfile);

// Get currently authenticated tenant's occupancy history
router.get("/me/occupancy-history", authorize("tenant"), getMyOccupancyHistory);

// List all tenants (Owner only)
router.get("/", authorize("owner"), getAllTenants);

// Onboard / register a tenant (Owner only)
router.post("/", authorize("owner"), registerTenant);

// Get tenant occupancy history (Owner or Self)
router.get("/:id/occupancy-history", getTenantOccupancyHistory);

// Get tenant by ID (Owner or Self)
router.get("/:id", getTenantById);

// Update tenant profile (Owner or Self)
router.put("/:id", updateTenant);

// Assign room to tenant (Owner only)
router.put("/:id/assign-room", authorize("owner"), assignRoom);

// Change room assignment (Owner only)
router.put("/:id/change-room", authorize("owner"), changeRoomAssignment);

// Mark tenant as vacated / release room bed (Owner only)
router.put("/:id/vacate", authorize("owner"), vacateTenant);

module.exports = router;
