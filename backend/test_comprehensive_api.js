const BASE_URL = 'https://skyheightpg.onrender.com';

let totalTests = 0;
let passedTests = 0;
let failedTests = 0;

function assert(description, condition, details = '') {
  totalTests++;
  if (condition) {
    passedTests++;
    console.log(`[PASS] ${description}`);
  } else {
    failedTests++;
    console.error(`[FAIL] ${description} ${details ? '- ' + details : ''}`);
  }
}

async function request(method, path, body = null, token = null) {
  const headers = { 'Content-Type': 'application/json' };
  if (token) headers['Authorization'] = `Bearer ${token}`;
  
  const options = {
    method,
    headers
  };
  if (body) options.body = JSON.stringify(body);

  const res = await fetch(`${BASE_URL}${path}`, options);
  let data = null;
  try {
    data = await res.json();
  } catch (e) {
    data = null;
  }
  return { status: res.status, ok: res.ok, data };
}

async function runComprehensiveBackendAudit() {
  console.log('====================================================');
  console.log('   SKY HEIGHT APARTMENT — COMPREHENSIVE API AUDIT   ');
  console.log(`   Target: ${BASE_URL}`);
  console.log('====================================================\n');

  // --- 1. HEALTH & ROOT ENDPOINTS ---
  console.log('--- 1. Health & Server Info ---');
  const rootRes = await request('GET', '/');
  assert('Root endpoint (/) returns HTTP 200', rootRes.status === 200 && rootRes.data?.success === true);

  const healthRes = await request('GET', '/health');
  assert('Health endpoint (/health) returns HTTP 200 with uptime', healthRes.status === 200 && healthRes.data?.status === 'healthy' && typeof healthRes.data?.uptime === 'number');

  const apiHealthRes = await request('GET', '/api/health');
  assert('API Health endpoint (/api/health) returns HTTP 200', apiHealthRes.status === 200 && apiHealthRes.data?.status === 'healthy');

  // --- 2. AUTHENTICATION & VALIDATION ---
  console.log('\n--- 2. Authentication & Error Handling ---');
  
  // Missing credentials
  const emptyLogin = await request('POST', '/api/auth/login', {});
  assert('Empty login body rejected with 400 Bad Request', emptyLogin.status === 400 && emptyLogin.data?.success === false);

  // Invalid email format on registration
  const badEmailRegister = await request('POST', '/api/auth/register', { name: 'Test', email: 'notanemail', password: 'password123', role: 'tenant' });
  assert('Malformed email on registration rejected with 400 Bad Request', badEmailRegister.status === 400 && badEmailRegister.data?.success === false);

  // Incorrect password
  const wrongPassLogin = await request('POST', '/api/auth/login', { email: '212myashraj@gmail.com', password: 'WrongPassword999!' });
  assert('Incorrect password rejected with 401 Unauthorized', wrongPassLogin.status === 401 && wrongPassLogin.data?.success === false);

  // Nonexistent user
  const nonExistLogin = await request('POST', '/api/auth/login', { email: 'nonexistent_user_999@test.com', password: 'Password123' });
  assert('Nonexistent user rejected with 401 Unauthorized', nonExistLogin.status === 401 && nonExistLogin.data?.success === false);

  // Missing token on protected endpoint
  const noTokenRes = await request('GET', '/api/dashboard/summary');
  assert('Protected endpoint without token rejected with 401', noTokenRes.status === 401 && noTokenRes.data?.success === false);

  // Malformed token
  const badTokenRes = await request('GET', '/api/dashboard/summary', null, 'malformed.token.here');
  assert('Protected endpoint with malformed token rejected with 401', badTokenRes.status === 401 && badTokenRes.data?.success === false);

  // Valid Owner Login
  const ownerLoginRes = await request('POST', '/api/auth/login', {
    email: '212myashraj@gmail.com',
    password: 'Password123'
  });
  assert('Genuine Owner login succeeds with 200 OK', ownerLoginRes.status === 200 && ownerLoginRes.data?.token && ownerLoginRes.data?.user?.role === 'owner');
  const ownerToken = ownerLoginRes.data?.token;

  // Valid Tenant Login
  const tenantLoginRes = await request('POST', '/api/auth/login', {
    email: 'tenanta_1793533117859@skyheight-test.com',
    password: 'TenantPassword123!'
  });
  assert('Active Tenant login succeeds with 200 OK', tenantLoginRes.status === 200 && tenantLoginRes.data?.token && tenantLoginRes.data?.user?.role === 'tenant');
  const tenantToken = tenantLoginRes.data?.token;

  // --- 3. RBAC & DATA ISOLATION ---
  console.log('\n--- 3. Role-Based Access Control (RBAC) ---');
  
  // Tenant calling Owner Dashboard
  const tenantToDashboard = await request('GET', '/api/dashboard/summary', null, tenantToken);
  assert('Tenant calling /api/dashboard/summary is blocked with 403 Forbidden', tenantToDashboard.status === 403);

  // Tenant calling Owner Rooms creation
  const tenantToCreateRoom = await request('POST', '/api/rooms', { roomNumber: 'H999', floor: 1, capacity: 2 }, tenantToken);
  assert('Tenant calling POST /api/rooms is blocked with 403 Forbidden', tenantToCreateRoom.status === 403);

  // Tenant calling Owner Settings update
  const tenantToUpdateSettings = await request('PUT', '/api/settings', { electricityRatePerUnit: 15 }, tenantToken);
  assert('Tenant calling PUT /api/settings is blocked with 403 Forbidden', tenantToUpdateSettings.status === 403);

  // --- 4. OWNER WORKFLOW ENDPOINTS ---
  console.log('\n--- 4. Owner Operations Endpoints ---');

  if (ownerToken) {
    // Dashboard summary
    const summaryRes = await request('GET', '/api/dashboard/summary', null, ownerToken);
    assert('GET /api/dashboard/summary returns total rooms, occupied beds, financials', 
      summaryRes.status === 200 && 
      summaryRes.data?.data?.rooms?.total > 0 && 
      summaryRes.data?.data?.financials?.monthlyRentCollection > 0
    );

    // Financial report
    const finReportRes = await request('GET', '/api/dashboard/reports/financial', null, ownerToken);
    assert('GET /api/dashboard/reports/financial returns 200 OK', finReportRes.status === 200);

    // Rooms listing
    const roomsRes = await request('GET', '/api/rooms', null, ownerToken);
    const rooms = roomsRes.data?.data?.rooms || roomsRes.data?.data || [];
    assert('GET /api/rooms returns active rooms array', roomsRes.status === 200 && Array.isArray(rooms) && rooms.length > 0);

    // Room occupancy stats
    const occupancyRes = await request('GET', '/api/rooms/stats/occupancy', null, ownerToken);
    assert('GET /api/rooms/stats/occupancy returns 200 OK', occupancyRes.status === 200);

    // Room by ID
    const testRoomId = rooms[0]?._id;
    if (testRoomId) {
      const singleRoomRes = await request('GET', `/api/rooms/${testRoomId}`, null, ownerToken);
      assert(`GET /api/rooms/${testRoomId} returns correct room details`, singleRoomRes.status === 200 && singleRoomRes.data?.data?._id === testRoomId);
    }

    // Invalid Room ID
    const badRoomIdRes = await request('GET', '/api/rooms/invalid_room_id', null, ownerToken);
    assert('GET /api/rooms/invalid_id returns 400 Bad Request', badRoomIdRes.status === 400);

    // Nonexistent Room ID
    const missingRoomRes = await request('GET', '/api/rooms/666666666666666666666666', null, ownerToken);
    assert('GET /api/rooms/nonexistent returns 404 Not Found', missingRoomRes.status === 404);

    // Tenants listing
    const tenantsRes = await request('GET', '/api/tenants', null, ownerToken);
    const tenants = tenantsRes.data?.data?.tenants || tenantsRes.data?.data || [];
    assert('GET /api/tenants returns active tenants array', tenantsRes.status === 200 && Array.isArray(tenants) && tenants.length > 0);

    // Filter tenants by status
    const filteredTenantsRes = await request('GET', '/api/tenants?status=active', null, ownerToken);
    assert('GET /api/tenants?status=active filters properly', filteredTenantsRes.status === 200);

    // Electricity monthly usage
    const meterUsageRes = await request('GET', '/api/meters/monthly-usage', null, ownerToken);
    assert('GET /api/meters/monthly-usage returns PG usage stats', meterUsageRes.status === 200 && typeof meterUsageRes.data?.totalUnitsConsumed === 'number');

    // Room meter history
    if (testRoomId) {
      const roomMeterRes = await request('GET', `/api/meters/room/${testRoomId}`, null, ownerToken);
      assert(`GET /api/meters/room/${testRoomId} returns reading history`, roomMeterRes.status === 200);
    }

    // Bills listing
    const billsRes = await request('GET', '/api/bills', null, ownerToken);
    const bills = billsRes.data?.data?.bills || billsRes.data?.data || [];
    assert('GET /api/bills returns bills list', billsRes.status === 200 && Array.isArray(bills) && bills.length > 0);

    // Pending bills
    const pendingBillsRes = await request('GET', '/api/bills/pending', null, ownerToken);
    assert('GET /api/bills/pending returns 200 OK', pendingBillsRes.status === 200);

    // Payments listing
    const paymentsRes = await request('GET', '/api/payments', null, ownerToken);
    const payments = paymentsRes.data?.data?.payments || paymentsRes.data?.data || [];
    assert('GET /api/payments returns payment records', paymentsRes.status === 200 && Array.isArray(payments) && payments.length > 0);

    // Complaints listing
    const complaintsRes = await request('GET', '/api/complaints', null, ownerToken);
    const complaints = complaintsRes.data?.data?.complaints || complaintsRes.data?.data || [];
    assert('GET /api/complaints returns complaints list', complaintsRes.status === 200 && Array.isArray(complaints));

    // Expenses listing
    const expensesRes = await request('GET', '/api/expenses', null, ownerToken);
    assert('GET /api/expenses returns 200 OK', expensesRes.status === 200);

    // Expenses summary
    const expenseSumRes = await request('GET', '/api/expenses/summary', null, ownerToken);
    assert('GET /api/expenses/summary returns 200 OK', expenseSumRes.status === 200);

    // PG Settings
    const settingsRes = await request('GET', '/api/settings', null, ownerToken);
    assert('GET /api/settings returns PG configuration', settingsRes.status === 200 && settingsRes.data?.data?.pgName === 'Sky Height PG');
  }

  // --- 5. TENANT WORKFLOW ENDPOINTS ---
  console.log('\n--- 5. Tenant Operations Endpoints ---');

  if (tenantToken) {
    // Tenant profile
    const tenantProfileRes = await request('GET', '/api/tenants/me', null, tenantToken);
    assert('GET /api/tenants/me returns authenticated tenant profile', tenantProfileRes.status === 200 && tenantProfileRes.data?.data?.email);

    // Tenant bills
    const tenantBillsRes = await request('GET', '/api/bills/my-bills', null, tenantToken);
    assert('GET /api/bills/my-bills returns tenant specific bills', tenantBillsRes.status === 200 && Array.isArray(tenantBillsRes.data?.data));

    // Tenant meter
    const tenantMeterRes = await request('GET', '/api/meters/my-meter', null, tenantToken);
    assert('GET /api/meters/my-meter returns room meter details', tenantMeterRes.status === 200 && tenantMeterRes.data?.data?.room);

    // Tenant payments
    const tenantPaymentsRes = await request('GET', '/api/payments/my-payments', null, tenantToken);
    assert('GET /api/payments/my-payments returns payment history', tenantPaymentsRes.status === 200 && Array.isArray(tenantPaymentsRes.data?.data));

    // Tenant complaints
    const tenantComplaintsRes = await request('GET', '/api/complaints/my-complaints', null, tenantToken);
    assert('GET /api/complaints/my-complaints returns tenant complaints', tenantComplaintsRes.status === 200 && Array.isArray(tenantComplaintsRes.data?.data));
  }

  console.log('\n====================================================');
  console.log(`TOTAL API AUDIT TESTS: ${totalTests}`);
  console.log(`PASSED:                 ${passedTests}`);
  console.log(`FAILED:                 ${failedTests}`);
  console.log('====================================================\n');

  if (failedTests > 0) {
    process.exit(1);
  }
}

runComprehensiveBackendAudit().catch(err => {
  console.error('Fatal API audit failure:', err);
  process.exit(1);
});
