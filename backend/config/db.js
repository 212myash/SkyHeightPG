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

  let uri = process.env.MONGODB_URI;
  if (process.env.ISOLATED_TEST === "true" && !uri.includes("skyheight_isolated_test")) {
    uri = uri.endsWith("/") ? uri + "skyheight_isolated_test" : uri + "/skyheight_isolated_test";
  }

  await mongoose.connect(uri, options);
  console.log(`MongoDB Connected Successfully to database [${mongoose.connection.name}] with hardened connection pool.`);
};

module.exports = connectDB;
