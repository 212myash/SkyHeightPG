const express = require("express");
const router = express.Router();

const {
  registerTenant,
  getAllTenants,
  getMyTenantProfile,
  getTenantById,
  updateTenant,
  changeRoomAssignment,
  vacateTenant
} = require("../controllers/tenantController");

const { protect, authorize } = require("../middleware/authMiddleware");

// All tenant routes require authentication
router.use(protect);

// Get currently authenticated tenant's profile
router.get("/me", authorize("tenant"), getMyTenantProfile);

// List all tenants (Owner only)
router.get("/", authorize("owner"), getAllTenants);

// Onboard / register a tenant (Owner only)
router.post("/", authorize("owner"), registerTenant);

// Get tenant by ID (Owner or Self)
router.get("/:id", getTenantById);

// Update tenant profile (Owner or Self)
router.put("/:id", updateTenant);

// Change room assignment (Owner only)
router.put("/:id/change-room", authorize("owner"), changeRoomAssignment);

// Mark tenant as vacated / release room bed (Owner only)
router.put("/:id/vacate", authorize("owner"), vacateTenant);

module.exports = router;
