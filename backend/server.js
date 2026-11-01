const dns = require("dns");
// On development / local environments, ensure DNS fallback for Atlas SRV resolution
if (process.env.CUSTOM_DNS === "true" || (!process.env.RENDER && process.env.NODE_ENV !== "production")) {
  try {
    dns.setServers(["8.8.8.8", "8.8.4.4"]);
  } catch (e) {
    // Keep system default if setServers is restricted
  }
}

require("dotenv").config();

const express = require("express");
const cors = require("cors");
const mongoose = require("mongoose");
const connectDB = require("./config/db");

// Route imports
const authRoutes = require("./routes/authRoutes");
const roomRoutes = require("./routes/roomRoutes");
const tenantRoutes = require("./routes/tenantRoutes");
const meterRoutes = require("./routes/meterRoutes");
const billRoutes = require("./routes/billRoutes");
const paymentRoutes = require("./routes/paymentRoutes");
const expenseRoutes = require("./routes/expenseRoutes");
const complaintRoutes = require("./routes/complaintRoutes");
const dashboardRoutes = require("./routes/dashboardRoutes");
const settingsRoutes = require("./routes/settingsRoutes");

const app = express();

// Security Hardening: Disable Express Fingerprint
app.disable("x-powered-by");

// Security Hardening: Standard HTTP Response Headers
app.use((req, res, next) => {
  res.setHeader("X-Content-Type-Options", "nosniff");
  res.setHeader("X-Frame-Options", "DENY");
  res.setHeader("X-XSS-Protection", "1; mode=block");
  res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  if (process.env.NODE_ENV === "production") {
    res.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains");
  }
  next();
});

// CORS Configuration (Permits mobile app API clients and local developer testing)
const corsOptions = {
  origin: process.env.NODE_ENV === "production" && process.env.ALLOWED_ORIGINS
    ? process.env.ALLOWED_ORIGINS.split(",").map(o => o.trim())
    : true,
  methods: ["GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS"],
  allowedHeaders: ["Content-Type", "Authorization", "Accept", "X-Requested-With"],
  credentials: true
};
app.use(cors(corsOptions));
app.use(express.json({ limit: "1mb" }));

// Root Health Check Route
app.get("/", (req, res) => {
  res.json({
    success: true,
    message: "Sky Height PG Backend is Running!",
    environment: process.env.NODE_ENV || "development"
  });
});

// Render / Uptime Monitoring Health Check Route
app.get(["/health", "/api/health"], (req, res) => {
  res.status(200).json({
    status: "healthy",
    uptime: Math.floor(process.uptime()),
    timestamp: new Date().toISOString()
  });
});

// API Routes
app.use("/api/auth", authRoutes);
app.use("/api/rooms", roomRoutes);
app.use("/api/tenants", tenantRoutes);
app.use("/api/meters", meterRoutes);
app.use("/api/bills", billRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/expenses", expenseRoutes);
app.use("/api/complaints", complaintRoutes);
app.use("/api/dashboard", dashboardRoutes);
app.use("/api/settings", settingsRoutes);

// 404 Not Found Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: `Cannot ${req.method} ${req.originalUrl}`
  });
});

// Global Error Handler with Production Sanitization
app.use((err, req, res, next) => {
  console.error("Unhandled Server Error:", err);
  const status = err.status || 500;
  const isProd = process.env.NODE_ENV === "production";
  
  res.status(status).json({
    success: false,
    message: isProd && status === 500
      ? "An internal server error occurred. Please try again later."
      : (err.message || "Internal Server Error")
  });
});

const PORT = process.env.PORT || 5000;

let server;

const startServer = async () => {
  try {
    await connectDB();

    server = app.listen(PORT, "0.0.0.0", () => {
      console.log(`Server running on port ${PORT}`);
    });
  } catch (error) {
    console.error("Server startup failed:", error.message);
    process.exit(1);
  }
};

// Graceful Shutdown Handlers
const handleShutdown = async (signal) => {
  console.log(`\nReceived ${signal}. Initiating graceful shutdown...`);
  if (server) {
    server.close(() => {
      console.log("HTTP server closed.");
    });
  }
  try {
    await mongoose.connection.close(false);
    console.log("MongoDB connection closed gracefully.");
  } catch (err) {
    console.error("Error closing MongoDB connection:", err);
  }
  process.exit(0);
};

process.on("SIGTERM", () => handleShutdown("SIGTERM"));
process.on("SIGINT", () => handleShutdown("SIGINT"));

startServer();
