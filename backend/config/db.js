const mongoose = require("mongoose");

const connectDB = async () => {
  const options = {
    maxPoolSize: 10,
    minPoolSize: 2,
    serverSelectionTimeoutMS: 5000,
    socketTimeoutMS: 45000,
  };

  mongoose.connection.on("connected", () => {
    console.log("MongoDB connection established.");
  });

  mongoose.connection.on("error", (err) => {
    console.error("MongoDB runtime connection error:", err.message);
  });

  mongoose.connection.on("disconnected", () => {
    console.warn("MongoDB disconnected. Awaiting automatic reconnect...");
  });

  await mongoose.connect(process.env.MONGODB_URI, options);
  console.log("MongoDB Connected Successfully with hardened connection pool.");
};

module.exports = connectDB;
