const http = require("http");
const dns = require("dns");
dns.setServers(["8.8.8.8", "8.8.4.4"]);
require("dotenv").config({ path: __dirname + "/.env" });
const mongoose = require("mongoose");
const User = require("./models/User");

const BASE_URL = "http://localhost:5000";

const makeRequest = (method, path, body = null, token = null) => {
  return new Promise((resolve, reject) => {
    const url = new URL(path, BASE_URL);
    const headers = {
      "Content-Type": "application/json"
    };
    if (token) {
      headers["Authorization"] = `Bearer ${token}`;
    }

    const payload = body ? JSON.stringify(body) : null;
    if (payload) {
      headers["Content-Length"] = Buffer.byteLength(payload);
    }

    const req = http.request(
      url,
      {
        method,
        headers
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          let parsed;
          try {
            parsed = JSON.parse(data);
          } catch {
            parsed = data;
          }
          resolve({ status: res.statusCode, data: parsed });
        });
      }
    );

    req.on("error", (err) => reject(err));
    if (payload) req.write(payload);
    req.end();
  });
};

const runTests = async () => {
  console.log("==================================================");
  console.log("   SKY HEIGHT PG — PHASE 1 AUTHENTICATION TESTS   ");
  console.log("==================================================\n");

  // Connect to DB directly to clear prior test accounts for clean test reproducibility
  await mongoose.connect(process.env.MONGODB_URI);
  await User.deleteMany({ email: { $regex: /@skyheight-test\.com$/ } });
  // Also clear any previous test users
  await User.deleteMany({ email: { $regex: /@skyheight\.com$/ } });
  console.log("Cleaned test users from database for repeatable testing.\n");

  let passed = 0;
  let failed = 0;

  const assert = (description, condition, details = "") => {
    if (condition) {
      console.log(`[PASS] ${description}`);
      passed++;
    } else {
      console.error(`[FAIL] ${description} - ${details}`);
      failed++;
    }
  };

  try {
    // 1. Root Endpoint
    const rootRes = await makeRequest("GET", "/");
    assert(
      "1. Root healthcheck returns status 200 and expected message",
      rootRes.status === 200 && rootRes.data.success === true && rootRes.data.message === "Sky Height PG Backend is Running!",
      JSON.stringify(rootRes.data)
    );

    // 2. Initial Owner Status Check (Before any owner exists)
    const ownerStatusBefore = await makeRequest("GET", "/api/auth/owner-status");
    assert(
      "2. Owner status check responds with hasOwner: false before any owner is created",
      ownerStatusBefore.status === 200 && ownerStatusBefore.data.hasOwner === false,
      JSON.stringify(ownerStatusBefore.data)
    );

    // 3. Initial Owner Registration (Bootstrap)
    const ownerEmail = `owner_${Date.now()}@skyheight-test.com`;
    const ownerPassword = "OwnerPassword123!";
    const ownerRegisterRes = await makeRequest("POST", "/api/auth/register", {
      name: "PG Owner Admin",
      email: ownerEmail,
      password: ownerPassword,
      phone: "+919876543210",
      role: "owner"
    });

    assert(
      "3. First Owner bootstrap registration succeeds (201 Created)",
      ownerRegisterRes.status === 201 &&
        ownerRegisterRes.data.success === true &&
        ownerRegisterRes.data.token &&
        ownerRegisterRes.data.user.role === "owner" &&
        !ownerRegisterRes.data.user.password,
      JSON.stringify(ownerRegisterRes.data)
    );
    const ownerToken = ownerRegisterRes.data.token;

    // 4. Verify Owner Status is now true
    const ownerStatusAfter = await makeRequest("GET", "/api/auth/owner-status");
    assert(
      "4. Owner status is now true (hasOwner: true)",
      ownerStatusAfter.status === 200 && ownerStatusAfter.data.hasOwner === true,
      JSON.stringify(ownerStatusAfter.data)
    );

    // 5. Public Owner Registration Prevention (Should be FORBIDDEN 403)
    const fakeOwnerRes = await makeRequest("POST", "/api/auth/register", {
      name: "Malicious Owner Attacker",
      email: `fake_owner_${Date.now()}@skyheight-test.com`,
      password: "HackerPassword123!",
      role: "owner"
    });
    assert(
      "5. Public attempt to register another owner is strictly blocked (403 Forbidden)",
      fakeOwnerRes.status === 403 && fakeOwnerRes.data.success === false,
      JSON.stringify(fakeOwnerRes.data)
    );

    // 6. Tenant Registration (Public Signup)
    const tenantEmail = `tenant_${Date.now()}@skyheight-test.com`;
    const tenantPassword = "TenantPassword123!";
    const tenantRegisterRes = await makeRequest("POST", "/api/auth/register", {
      name: "Rahul Sharma",
      email: tenantEmail,
      password: tenantPassword,
      phone: "+919812345678",
      role: "tenant"
    });
    assert(
      "6. Tenant public registration succeeds (201 Created)",
      tenantRegisterRes.status === 201 &&
        tenantRegisterRes.data.success === true &&
        tenantRegisterRes.data.token &&
        tenantRegisterRes.data.user.role === "tenant" &&
        !tenantRegisterRes.data.user.password,
      JSON.stringify(tenantRegisterRes.data)
    );
    const tenantToken = tenantRegisterRes.data.token;

    // 7. Duplicate Email Registration Prevention
    const duplicateEmailRes = await makeRequest("POST", "/api/auth/register", {
      name: "Duplicate User",
      email: tenantEmail,
      password: "SomePassword123!",
      role: "tenant"
    });
    assert(
      "7. Duplicate email registration is blocked (400 Bad Request)",
      duplicateEmailRes.status === 400 && duplicateEmailRes.data.success === false,
      JSON.stringify(duplicateEmailRes.data)
    );

    // 8. Invalid Short Password Prevention (<6 chars)
    const shortPasswordRes = await makeRequest("POST", "/api/auth/register", {
      name: "Short Pass",
      email: `shortpass_${Date.now()}@skyheight-test.com`,
      password: "123",
      role: "tenant"
    });
    assert(
      "8. Password under 6 characters is rejected (400 Bad Request)",
      shortPasswordRes.status === 400 && shortPasswordRes.data.success === false,
      JSON.stringify(shortPasswordRes.data)
    );

    // 9. Invalid Email Format Prevention
    const invalidEmailRes = await makeRequest("POST", "/api/auth/register", {
      name: "Bad Email",
      email: "invalid-email-format",
      password: "ValidPassword123!",
      role: "tenant"
    });
    assert(
      "9. Invalid email format is rejected (400 Bad Request)",
      invalidEmailRes.status === 400 && invalidEmailRes.data.success === false,
      JSON.stringify(invalidEmailRes.data)
    );

    // 10. Invalid Role Prevention
    const invalidRoleRes = await makeRequest("POST", "/api/auth/register", {
      name: "Hacker Role",
      email: `hacker_${Date.now()}@skyheight-test.com`,
      password: "ValidPassword123!",
      role: "superadmin"
    });
    assert(
      "10. Invalid role is rejected (400 Bad Request)",
      invalidRoleRes.status === 400 && invalidRoleRes.data.success === false,
      JSON.stringify(invalidRoleRes.data)
    );

    // 11. Successful Owner Login
    const ownerLoginRes = await makeRequest("POST", "/api/auth/login", {
      email: ownerEmail,
      password: ownerPassword
    });
    assert(
      "11. Owner login with valid credentials succeeds (200 OK)",
      ownerLoginRes.status === 200 &&
        ownerLoginRes.data.success === true &&
        ownerLoginRes.data.token &&
        ownerLoginRes.data.user.role === "owner" &&
        !ownerLoginRes.data.user.password,
      JSON.stringify(ownerLoginRes.data)
    );

    // 12. Successful Tenant Login
    const tenantLoginRes = await makeRequest("POST", "/api/auth/login", {
      email: tenantEmail,
      password: tenantPassword
    });
    assert(
      "12. Tenant login with valid credentials succeeds (200 OK)",
      tenantLoginRes.status === 200 &&
        tenantLoginRes.data.success === true &&
        tenantLoginRes.data.token &&
        tenantLoginRes.data.user.role === "tenant" &&
        !tenantLoginRes.data.user.password,
      JSON.stringify(tenantLoginRes.data)
    );

    // 13. Invalid Password Login
    const wrongPasswordRes = await makeRequest("POST", "/api/auth/login", {
      email: ownerEmail,
      password: "WrongPassword999!"
    });
    assert(
      "13. Login with incorrect password is rejected (401 Unauthorized)",
      wrongPasswordRes.status === 401 && wrongPasswordRes.data.success === false,
      JSON.stringify(wrongPasswordRes.data)
    );

    // 14. Non-existent Email Login
    const nonExistentEmailRes = await makeRequest("POST", "/api/auth/login", {
      email: `nobody_${Date.now()}@skyheight-test.com`,
      password: "SomePassword123!"
    });
    assert(
      "14. Login with non-existent email is rejected (401 Unauthorized)",
      nonExistentEmailRes.status === 401 && nonExistentEmailRes.data.success === false,
      JSON.stringify(nonExistentEmailRes.data)
    );

    // 15. Protected Route Access with Owner Token
    const ownerProfileRes = await makeRequest("GET", "/api/auth/profile", null, ownerToken);
    assert(
      "15. Protected /profile route succeeds with valid Owner JWT (200 OK)",
      ownerProfileRes.status === 200 &&
        ownerProfileRes.data.success === true &&
        ownerProfileRes.data.user.email === ownerEmail &&
        !ownerProfileRes.data.user.password,
      JSON.stringify(ownerProfileRes.data)
    );

    // 16. Protected Route Access with Tenant Token
    const tenantProfileRes = await makeRequest("GET", "/api/auth/profile", null, tenantToken);
    assert(
      "16. Protected /profile route succeeds with valid Tenant JWT (200 OK)",
      tenantProfileRes.status === 200 &&
        tenantProfileRes.data.success === true &&
        tenantProfileRes.data.user.email === tenantEmail &&
        !tenantProfileRes.data.user.password,
      JSON.stringify(tenantProfileRes.data)
    );

    // 17. Protected Route Access without Token
    const noTokenRes = await makeRequest("GET", "/api/auth/profile");
    assert(
      "17. Protected /profile route is rejected without token (401 Unauthorized)",
      noTokenRes.status === 401 && noTokenRes.data.success === false,
      JSON.stringify(noTokenRes.data)
    );

    // 18. Protected Route Access with Invalid Token
    const badTokenRes = await makeRequest("GET", "/api/auth/profile", null, "invalid.malformed.jwt");
    assert(
      "18. Protected /profile route is rejected with malformed token (401 Unauthorized)",
      badTokenRes.status === 401 && badTokenRes.data.success === false,
      JSON.stringify(badTokenRes.data)
    );

    // 19. Role Authorization: Owner accessing Owner-Only route
    const ownerAccessOwnerRes = await makeRequest("GET", "/api/auth/owner-check", null, ownerToken);
    assert(
      "19. Owner role authorization allows Owner accessing /owner-check (200 OK)",
      ownerAccessOwnerRes.status === 200 && ownerAccessOwnerRes.data.success === true,
      JSON.stringify(ownerAccessOwnerRes.data)
    );

    // 20. Role Authorization: Tenant blocked from Owner-Only route
    const tenantAccessOwnerRes = await makeRequest("GET", "/api/auth/owner-check", null, tenantToken);
    assert(
      "20. Tenant is blocked from Owner-Only route /owner-check (403 Forbidden)",
      tenantAccessOwnerRes.status === 403 && tenantAccessOwnerRes.data.success === false,
      JSON.stringify(tenantAccessOwnerRes.data)
    );

    // 21. Role Authorization: Tenant accessing Tenant-Only route
    const tenantAccessTenantRes = await makeRequest("GET", "/api/auth/tenant-check", null, tenantToken);
    assert(
      "21. Tenant role authorization allows Tenant accessing /tenant-check (200 OK)",
      tenantAccessTenantRes.status === 200 && tenantAccessTenantRes.data.success === true,
      JSON.stringify(tenantAccessTenantRes.data)
    );

    // 22. Role Authorization: Owner blocked from Tenant-Only route
    const ownerAccessTenantRes = await makeRequest("GET", "/api/auth/tenant-check", null, ownerToken);
    assert(
      "22. Owner is blocked from Tenant-Only route /tenant-check (403 Forbidden)",
      ownerAccessTenantRes.status === 403 && ownerAccessTenantRes.data.success === false,
      JSON.stringify(ownerAccessTenantRes.data)
    );

    // 23. Change Password (Success)
    const newPassword = "NewTenantPassword987!";
    const changePassRes = await makeRequest(
      "PUT",
      "/api/auth/change-password",
      {
        currentPassword: tenantPassword,
        newPassword: newPassword
      },
      tenantToken
    );
    assert(
      "23. Authenticated user can change password (200 OK)",
      changePassRes.status === 200 && changePassRes.data.success === true,
      JSON.stringify(changePassRes.data)
    );

    // 24. Login with Old Password fails after change
    const oldPassLoginRes = await makeRequest("POST", "/api/auth/login", {
      email: tenantEmail,
      password: tenantPassword
    });
    assert(
      "24. Login with old password fails after change (401 Unauthorized)",
      oldPassLoginRes.status === 401 && oldPassLoginRes.data.success === false,
      JSON.stringify(oldPassLoginRes.data)
    );

    // 25. Login with New Password succeeds
    const newPassLoginRes = await makeRequest("POST", "/api/auth/login", {
      email: tenantEmail,
      password: newPassword
    });
    assert(
      "25. Login with new password succeeds (200 OK)",
      newPassLoginRes.status === 200 && newPassLoginRes.data.success === true && newPassLoginRes.data.token,
      JSON.stringify(newPassLoginRes.data)
    );

    // 26. Authenticated Owner Can Create User
    const ownerCreatedUserEmail = `tenant_by_owner_${Date.now()}@skyheight-test.com`;
    const ownerCreatedRes = await makeRequest(
      "POST",
      "/api/auth/register",
      {
        name: "Tenant Added By Owner",
        email: ownerCreatedUserEmail,
        password: "TempPassword123!",
        role: "tenant"
      },
      ownerToken
    );
    assert(
      "26. Authenticated Owner can register a new tenant (201 Created)",
      ownerCreatedRes.status === 201 && ownerCreatedRes.data.success === true,
      JSON.stringify(ownerCreatedRes.data)
    );

    console.log("\n--------------------------------------------------");
    console.log(`TOTAL TESTS: ${passed + failed}`);
    console.log(`PASSED:      ${passed}`);
    console.log(`FAILED:      ${failed}`);
    console.log("--------------------------------------------------");

    await mongoose.disconnect();

    if (failed === 0) {
      console.log("\nALL 26 PHASE 1 AUTHENTICATION & AUTHORIZATION TESTS PASSED PERFECTLY!\n");
      process.exit(0);
    } else {
      console.error(`\n${failed} TEST(S) FAILED.\n`);
      process.exit(1);
    }
  } catch (err) {
    console.error("Test runner encountered an error:", err);
    await mongoose.disconnect();
    process.exit(1);
  }
};

runTests();
