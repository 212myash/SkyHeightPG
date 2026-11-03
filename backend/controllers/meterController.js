const MeterReading = require("../models/MeterReading");
const Room = require("../models/Room");
const Tenant = require("../models/Tenant");
const Bill = require("../models/Bill");
const PGSettings = require("../models/PGSettings");
const { isValidObjectId } = require("../utils/validateObjectId");
const pushService = require("../services/pushNotificationService");

/**
 * @desc    Record a monthly meter reading for a room
 * @route   POST /api/meters
 * @access  Private (Owner only)
 */
const addMeterReading = async (req, res) => {
  try {
    const { roomId, currentReading, readingMonth, ratePerUnit, previousReading: manualPrevReading, remarks } = req.body;

    if (!roomId || currentReading === undefined || !readingMonth) {
      return res.status(400).json({
        success: false,
        message: "Please provide roomId, currentReading, and readingMonth (YYYY-MM)."
      });
    }

    if (!isValidObjectId(roomId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid roomId format."
      });
    }

    // Validate readingMonth format
    const monthRegex = /^\d{4}-(0[1-9]|1[0-2])$/;
    if (!monthRegex.test(readingMonth)) {
      return res.status(400).json({
        success: false,
        message: "readingMonth must be in YYYY-MM format (e.g. 2026-11)."
      });
    }

    const room = await Room.findById(roomId);
    if (!room) {
      return res.status(404).json({
        success: false,
        message: "Room not found."
      });
    }

    // Check duplicate reading for this room and month
    const existingReading = await MeterReading.findOne({ room: roomId, readingMonth });
    if (existingReading) {
      return res.status(400).json({
        success: false,
        message: `Meter reading for Room ${room.roomNumber} for month ${readingMonth} already exists.`
      });
    }

    // Fetch chronologically previous reading for this room
    const lastReadingDoc = await MeterReading.findOne({
      room: roomId,
      readingMonth: { $lt: readingMonth }
    }).sort({ readingMonth: -1 });

    let calculatedPrevReading;
    if (lastReadingDoc) {
      calculatedPrevReading = lastReadingDoc.currentReading;
    } else if (manualPrevReading !== undefined && !isNaN(Number(manualPrevReading))) {
      calculatedPrevReading = Number(manualPrevReading);
    } else {
      // Check if any prior reading exists at all
      const anyPrior = await MeterReading.findOne({ room: roomId }).sort({ readingDate: -1 });
      calculatedPrevReading = anyPrior ? anyPrior.currentReading : 0;
    }

    const currReadingNum = Number(currentReading);
    if (isNaN(currReadingNum) || currReadingNum < 0) {
      return res.status(400).json({
        success: false,
        message: "Current reading must be a valid non-negative number."
      });
    }

    if (currReadingNum < calculatedPrevReading) {
      return res.status(400).json({
        success: false,
        message: `Current reading (${currReadingNum}) cannot be lower than previous reading (${calculatedPrevReading}).`
      });
    }

    // Check if a subsequent reading already exists and ensure consistency
    const nextReadingDoc = await MeterReading.findOne({
      room: roomId,
      readingMonth: { $gt: readingMonth }
    }).sort({ readingMonth: 1 });
    if (nextReadingDoc && currReadingNum > nextReadingDoc.previousReading) {
      return res.status(400).json({
        success: false,
        message: `Current reading (${currReadingNum}) exceeds the previous reading recorded for subsequent month ${nextReadingDoc.readingMonth} (${nextReadingDoc.previousReading}).`
      });
    }

    // Determine unit rate from PGSettings (with validated owner override support)
    const settings = await PGSettings.getSettings();
    let activeRate = settings.electricityRatePerUnit;

    if (ratePerUnit !== undefined && ratePerUnit !== null) {
      const parsedRate = Number(ratePerUnit);
      if (isNaN(parsedRate) || parsedRate < 0) {
        return res.status(400).json({
          success: false,
          message: "Specified ratePerUnit must be a valid non-negative number."
        });
      }
      activeRate = Math.round(parsedRate * 100) / 100;
    }

    const meterReading = await MeterReading.create({
      room: roomId,
      previousReading: calculatedPrevReading,
      currentReading: currReadingNum,
      ratePerUnit: activeRate,
      readingMonth,
      recordedBy: req.user._id,
      remarks: remarks ? remarks.trim() : ""
    });

    // Retroactive sync: If pending uncredited bills were generated before this meter reading,
    // update their electricity portion and recalculate total amounts
    try {
      const pendingBills = await Bill.find({
        room: roomId,
        billingMonth: readingMonth,
        paidAmount: 0,
        $or: [{ electricityAmount: 0 }, { meterReading: null }, { meterReading: { $exists: false } }]
      });

      if (pendingBills.length > 0) {
        const activeRoommatesCount = await Tenant.countDocuments({ room: roomId, status: "active" });
        const divisor = Math.max(1, activeRoommatesCount || pendingBills.length);
        const splitElec = Math.round((meterReading.electricityAmount / divisor) * 100) / 100;
        const splitUnits = Math.round((meterReading.unitsConsumed / divisor) * 100) / 100;

        for (const bill of pendingBills) {
          bill.electricityAmount = splitElec;
          bill.unitsConsumed = splitUnits;
          bill.previousReading = meterReading.previousReading;
          bill.currentReading = meterReading.currentReading;
          bill.meterReading = meterReading._id;
          await bill.save(); // triggers pre-save hook to recalculate totalAmount
        }
      }
    } catch (billSyncErr) {
      console.error("Retroactive Bill Sync Error in addMeterReading:", billSyncErr);
    }

    // Notify room occupants of recorded meter reading
    (async () => {
      try {
        const roomTenants = await Tenant.find({ room: roomId, status: "active" }).populate("user");
        for (const t of roomTenants) {
          if (t.user) {
            await pushService.dispatchNotificationAndPush({
              recipientId: t.user._id || t.user,
              senderId: req.user._id,
              title: `Meter Reading: Room ${room.roomNumber}`,
              message: `Reading for ${readingMonth}: ${unitsConsumed} units consumed (₹${electricityAmount}).`,
              category: "electricity_bill",
              targetRoom: roomId,
              data: {
                screen: "/tenant/dashboard",
                readingMonth,
                unitsConsumed: unitsConsumed.toString()
              },
              channelId: "billing"
            });
          }
        }
      } catch (e) {
        console.error("Meter reading push error:", e.message);
      }
    })();

    return res.status(201).json({
      success: true,
      message: `Meter reading for Room ${room.roomNumber} recorded successfully.`,
      data: meterReading
    });
  } catch (error) {
    console.error("Add Meter Reading Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error recording meter reading.",
      error: error.message
    });
  }
};

/**
 * @desc    Get meter reading history for a specific room
 * @route   GET /api/meters/room/:roomId
 * @access  Private (Owner, or Tenant assigned to this room)
 */
const getRoomMeterHistory = async (req, res) => {
  try {
    const { roomId } = req.params;

    if (!isValidObjectId(roomId)) {
      return res.status(400).json({
        success: false,
        message: "Invalid Room ID format."
      });
    }

    // Role check: Tenant can only view meter history of their own assigned room
    if (req.user.role === "tenant") {
      const tenant = await Tenant.findOne({ user: req.user._id, status: "active" });
      if (!tenant || String(tenant.room) !== String(roomId)) {
        return res.status(403).json({
          success: false,
          message: "Forbidden: You are not authorized to view this room's meter history."
        });
      }
    }

    const readings = await MeterReading.find({ room: roomId })
      .populate("recordedBy", "name")
      .sort({ readingMonth: -1 });

    return res.status(200).json({
      success: true,
      count: readings.length,
      data: readings
    });
  } catch (error) {
    console.error("Get Room Meter History Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching meter history.",
      error: error.message
    });
  }
};

/**
 * @desc    Get current meter details for authenticated tenant
 * @route   GET /api/meters/my-meter
 * @access  Private (Tenant only)
 */
const getMyMeterDetails = async (req, res) => {
  try {
    const tenant = await Tenant.findOne({ user: req.user._id, status: "active" }).populate("room");
    if (!tenant || !tenant.room) {
      return res.status(404).json({
        success: false,
        message: "No active room assignment found for your account."
      });
    }

    const latestReading = await MeterReading.findOne({ room: tenant.room._id })
      .sort({ readingMonth: -1 })
      .populate("recordedBy", "name");

    const recentHistory = await MeterReading.find({ room: tenant.room._id })
      .sort({ readingMonth: -1 })
      .limit(6);

    return res.status(200).json({
      success: true,
      data: {
        room: {
          _id: tenant.room._id,
          roomNumber: tenant.room.roomNumber,
          floor: tenant.room.floor
        },
        latestReading: latestReading || null,
        unitsConsumed: latestReading ? latestReading.unitsConsumed : 0,
        currentReading: latestReading ? latestReading.currentReading : 0,
        previousReading: latestReading ? latestReading.previousReading : 0,
        ratePerUnit: latestReading ? latestReading.ratePerUnit : 0,
        electricityAmount: latestReading ? latestReading.electricityAmount : 0,
        history: recentHistory
      }
    });
  } catch (error) {
    console.error("Get My Meter Details Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error retrieving meter details.",
      error: error.message
    });
  }
};

/**
 * @desc    Get monthly electricity usage across all rooms
 * @route   GET /api/meters/monthly-usage
 * @access  Private (Owner only)
 */
const getMonthlyUsageReport = async (req, res) => {
  try {
    const { month } = req.query;

    const query = {};
    if (month) {
      query.readingMonth = month;
    }

    const readings = await MeterReading.find(query)
      .populate("room", "roomNumber floor occupiedBeds capacity")
      .sort({ readingMonth: -1, room: 1 });

    const totalUnitsConsumed = readings.reduce((acc, r) => acc + (r.unitsConsumed || 0), 0);
    const totalElectricityAmount = readings.reduce((acc, r) => acc + (r.electricityAmount || 0), 0);

    return res.status(200).json({
      success: true,
      month: month || "all",
      totalUnitsConsumed: Math.round(totalUnitsConsumed * 100) / 100,
      totalElectricityAmount: Math.round(totalElectricityAmount * 100) / 100,
      readingsCount: readings.length,
      data: readings
    });
  } catch (error) {
    console.error("Get Monthly Usage Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error generating usage report.",
      error: error.message
    });
  }
};

module.exports = {
  addMeterReading,
  getRoomMeterHistory,
  getMyMeterDetails,
  getMonthlyUsageReport
};
