/**
 * In-Memory Sliding Window Rate Limiter Middleware
 * 
 * ARCHITECTURAL SPECIFICATION & LIMITATIONS:
 * 1. Process-Local Storage: Rate limit counters are tracked in an in-memory Map. 
 *    State is reset whenever the Node.js server process restarts.
 * 2. Horizontal Scaling: In a multi-process or clustered environment (e.g. PM2 cluster 
 *    or multiple containers), each process maintains its own independent memory counter. 
 *    For distributed scaling across multiple servers without paid services, an external 
 *    free-tier Redis instance would be required. For single-instance production deployments, 
 *    this in-memory solution provides zero-latency, zero-cost brute-force protection.
 * 3. Memory Bounds: An automated periodic cleanup sweeps expired window records every 5 minutes 
 *    to prevent memory leaks from inactive IP addresses.
 * 4. Test Environment Bypass: In test environments (NODE_ENV === 'test'), rate limits are bypassed 
 *    to prevent false-positive blocks during automated test suite execution.
 */

const createRateLimiter = ({
  windowMs = 15 * 60 * 1000, // 15 minutes
  max = 10,                   // 10 requests per window
  message = "Too many requests from this IP. Please try again later.",
  keyGenerator = (req) => req.ip || req.headers["x-forwarded-for"] || req.socket.remoteAddress || "unknown"
} = {}) => {
  const hits = new Map();

  // Periodic memory cleanup every 5 minutes
  const cleanupInterval = setInterval(() => {
    const now = Date.now();
    for (const [key, record] of hits.entries()) {
      if (now > record.resetTime) {
        hits.delete(key);
      }
    }
  }, 5 * 60 * 1000);

  // Prevent interval from hanging Node event loop
  if (cleanupInterval.unref) {
    cleanupInterval.unref();
  }

  return (req, res, next) => {
    // Bypass in automated test suite
    if (process.env.NODE_ENV === "test") {
      return next();
    }

    const key = keyGenerator(req);
    const now = Date.now();

    let record = hits.get(key);
    if (!record || now > record.resetTime) {
      record = {
        count: 1,
        resetTime: now + windowMs
      };
      hits.set(key, record);
    } else {
      record.count += 1;
    }

    const remaining = Math.max(0, max - record.count);
    const resetSeconds = Math.ceil((record.resetTime - now) / 1000);

    res.setHeader("X-RateLimit-Limit", max);
    res.setHeader("X-RateLimit-Remaining", remaining);
    res.setHeader("X-RateLimit-Reset", resetSeconds);

    if (record.count > max) {
      res.setHeader("Retry-After", resetSeconds);
      return res.status(429).json({
        success: false,
        message,
        retryAfterSeconds: resetSeconds
      });
    }

    next();
  };
};

// Specialized pre-configured limiters
const authLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 15,                   // 15 attempts
  message: "Too many authentication attempts from this IP. Please try again after 15 minutes."
});

const paymentLimiter = createRateLimiter({
  windowMs: 10 * 60 * 1000, // 10 minutes
  max: 20,                   // 20 attempts
  message: "Payment rate limit exceeded. Please wait a few minutes before submitting again."
});

module.exports = {
  createRateLimiter,
  authLimiter,
  paymentLimiter
};
