const PGSettings = require("../models/PGSettings");

/**
 * @desc    Get current PG configuration settings
 * @route   GET /api/settings
 * @access  Private (Owner / Tenant)
 */
const getSettings = async (req, res) => {
  try {
    const settings = await PGSettings.getSettings();
    return res.status(200).json({
      success: true,
      data: settings
    });
  } catch (error) {
    console.error("Get Settings Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error fetching settings.",
      error: error.message
    });
  }
};

/**
 * @desc    Update PG configuration settings
 * @route   PUT /api/settings
 * @access  Private (Owner only)
 */
const updateSettings = async (req, res) => {
  try {
    const {
      pgName,
      address,
      contactNumber,
      email,
      electricityRatePerUnit,
      defaultDueDateDay,
      upiId,
      upiQrImageUrl,
      noticePeriodDays,
      rulesAndRegulations
    } = req.body;

    const settings = await PGSettings.getSettings();

    if (pgName) settings.pgName = pgName.trim();
    if (address) settings.address = { ...settings.address, ...address };
    if (contactNumber) settings.contactNumber = contactNumber.trim();
    if (email) settings.email = email.trim();

    if (electricityRatePerUnit !== undefined) {
      const rate = Number(electricityRatePerUnit);
      if (rate < 0) {
        return res.status(400).json({
          success: false,
          message: "Electricity rate cannot be negative."
        });
      }
      settings.electricityRatePerUnit = rate;
    }

    if (defaultDueDateDay !== undefined) {
      const dueDay = Number(defaultDueDateDay);
      if (dueDay < 1 || dueDay > 28) {
        return res.status(400).json({
          success: false,
          message: "Due date day must be between 1 and 28."
        });
      }
      settings.defaultDueDateDay = dueDay;
    }

    if (upiId !== undefined) settings.upiId = upiId.trim();
    if (upiQrImageUrl !== undefined) settings.upiQrImageUrl = upiQrImageUrl.trim();
    if (noticePeriodDays !== undefined) settings.noticePeriodDays = Number(noticePeriodDays);
    if (Array.isArray(rulesAndRegulations)) settings.rulesAndRegulations = rulesAndRegulations;

    await settings.save();

    return res.status(200).json({
      success: true,
      message: "PG settings updated successfully.",
      data: settings
    });
  } catch (error) {
    console.error("Update Settings Error:", error);
    return res.status(500).json({
      success: false,
      message: "Server error updating settings.",
      error: error.message
    });
  }
};

module.exports = {
  getSettings,
  updateSettings
};
