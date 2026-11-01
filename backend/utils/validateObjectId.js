const mongoose = require("mongoose");

/**
 * Validates whether a given string is a valid MongoDB ObjectId
 * @param {string} id ID to validate
 * @returns {boolean} True if valid ObjectId, false otherwise
 */
const isValidObjectId = (id) => {
  return mongoose.Types.ObjectId.isValid(id) && new mongoose.Types.ObjectId(id).toString() === id;
};

module.exports = { isValidObjectId };
