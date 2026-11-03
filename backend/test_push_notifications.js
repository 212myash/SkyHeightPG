/**
 * Test Suite: Complete Push Notification & Device Token Architecture
 * Runs against the isolated test backend on port 5000.
 */
const BASE_URL = "http://127.0.0.1:5000/api";

let ownerToken = "";
let tenantToken = "";
let ownerId = "";
let tenantId = "";

let passed = 0;
let failed = 0;

function assert(condition, message) {
  if (condition) {
    console.log(`  PASS: ${message}`);
    passed++;
  } else {
    console.error(`  FAIL: ${message}`);
    failed++;
  }
}

async function request(endpoint, options = {}) {
  const url = `${BASE_URL}${endpoint}`;
  const headers = {
    "Content-Type": "application/json",
    ...(options.headers || {})
  };
  const res = await fetch(url, { ...options, headers });
  const data = await res.json().catch(() => ({}));
  return { status: res.status, ok: res.ok, data };
}

async function run() {
  console.log("=================================================");
  console.log("PUSH NOTIFICATION & DEVICE TOKEN TEST SUITE");
  console.log("=================================================");

  // 1. Authenticate Owner
  console.log("\n1. Authenticate Owner");
  const ownerAuth = await request("/auth/login", {
    method: "POST",
    body: JSON.stringify({ email: "testowner@skyheightpg.com", password: "Password@123" })
  });
  assert(ownerAuth.ok && ownerAuth.data.token, "Owner logged in successfully");
  ownerToken = ownerAuth.data.token;
  ownerId = ownerAuth.data.user ? ownerAuth.data.user._id : (ownerAuth.data.data?.user?._id);

  // 2. Authenticate Tenant
  console.log("\n2. Authenticate Tenant");
  const tenantAuth = await request("/auth/login", {
    method: "POST",
    body: JSON.stringify({ email: "aman@skyheightpg.com", password: "Password@123" })
  });
  assert(tenantAuth.ok && tenantAuth.data.token, "Tenant logged in successfully");
  tenantToken = tenantAuth.data.token;
  tenantId = tenantAuth.data.user ? tenantAuth.data.user._id : (tenantAuth.data.data?.user?._id);

  // 3. Register Device Token for Owner
  console.log("\n3. Register Device Token for Owner");
  const regOwnerToken1 = await request("/notifications/device-token", {
    method: "POST",
    headers: { Authorization: `Bearer ${ownerToken}` },
    body: JSON.stringify({
      token: "fcm_owner_device_1_token_sample_string_12345",
      platform: "android",
      deviceId: "pixel_8_pro_id_1"
    })
  });
  assert(regOwnerToken1.ok && regOwnerToken1.data.success, "Owner device 1 registered");
  assert(regOwnerToken1.data.data.platform === "android", "Platform is android");

  // 4. Multi-device support: Register Device 2 for Owner
  console.log("\n4. Register Device 2 for Owner (Multi-device)");
  const regOwnerToken2 = await request("/notifications/device-token", {
    method: "POST",
    headers: { Authorization: `Bearer ${ownerToken}` },
    body: JSON.stringify({
      token: "fcm_owner_device_2_token_sample_string_67890",
      platform: "android",
      deviceId: "galaxy_tab_s9_id_2"
    })
  });
  assert(regOwnerToken2.ok && regOwnerToken2.data.success, "Owner device 2 registered");

  // 5. Register Device Token for Tenant
  console.log("\n5. Register Device Token for Tenant");
  const regTenantToken = await request("/notifications/device-token", {
    method: "POST",
    headers: { Authorization: `Bearer ${tenantToken}` },
    body: JSON.stringify({
      token: "fcm_tenant_device_token_sample_string_abcde",
      platform: "android",
      deviceId: "oneplus_11_id_3"
    })
  });
  assert(regTenantToken.ok && regTenantToken.data.success, "Tenant device registered");

  // 6. Test Token Re-registration (Idempotency)
  console.log("\n6. Re-register Same Token with Updated Device Info");
  const reRegToken = await request("/notifications/device-token", {
    method: "POST",
    headers: { Authorization: `Bearer ${tenantToken}` },
    body: JSON.stringify({
      token: "fcm_tenant_device_token_sample_string_abcde",
      platform: "android",
      deviceId: "oneplus_11_updated_id"
    })
  });
  assert(reRegToken.ok && reRegToken.data.data.deviceId === "oneplus_11_updated_id", "Token updated seamlessly without duplicate key error");

  // 7. Validate Missing Token Validation
  console.log("\n7. Validate Missing Token Error Handling");
  const badTokenReq = await request("/notifications/device-token", {
    method: "POST",
    headers: { Authorization: `Bearer ${tenantToken}` },
    body: JSON.stringify({ platform: "android" })
  });
  assert(!badTokenReq.ok && badTokenReq.status === 400, "Rejected registration with missing token");

  // 8. Event Push: Owner dispatches notification/announcement
  console.log("\n8. Owner creates announcement notification");
  const notifCreate = await request("/notifications", {
    method: "POST",
    headers: { Authorization: `Bearer ${ownerToken}` },
    body: JSON.stringify({
      title: "Water Tank Maintenance Notice",
      message: "The water tank will be serviced tomorrow between 10 AM and 1 PM.",
      category: "maintenance",
      audience: "all"
    })
  });
  assert(notifCreate.ok && notifCreate.data.success, "Owner announcement created and dispatched with push");

  // 9. Tenant fetches notifications and verifies announcement received
  console.log("\n9. Tenant fetches notifications");
  const tenantNotifs = await request("/notifications", {
    method: "GET",
    headers: { Authorization: `Bearer ${tenantToken}` }
  });
  assert(tenantNotifs.ok && tenantNotifs.data.data.length > 0, "Tenant received in-app notification");
  const foundNotif = tenantNotifs.data.data.find(n => n.title.includes("Water Tank"));
  assert(foundNotif !== undefined, "Found created announcement in tenant notifications");

  // 10. Deregister Device Token on Logout
  console.log("\n10. Deregister Device Token on Logout");
  const deleteToken = await request("/notifications/device-token", {
    method: "DELETE",
    headers: { Authorization: `Bearer ${tenantToken}` },
    body: JSON.stringify({ token: "fcm_tenant_device_token_sample_string_abcde" })
  });
  assert(deleteToken.ok && deleteToken.data.success, "Device token deregistered successfully");

  console.log("\n=================================================");
  console.log(`RESULTS: ${passed} PASSED, ${failed} FAILED`);
  console.log("=================================================");

  if (failed > 0) process.exit(1);
}

run().catch((e) => {
  console.error("Test Suite Fatal Error:", e);
  process.exit(1);
});
