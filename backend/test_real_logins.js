const BASE_URL = 'https://skyheightpg.onrender.com';

async function testRealLogins() {
  console.log('Testing Real User Logins against Render Live API:\n');

  // 1. Owner Login
  console.log('--- 1. OWNER LOGIN (212myashraj@gmail.com) ---');
  const ownerRes = await fetch(`${BASE_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: '212myashraj@gmail.com',
      password: '123456789'
    })
  });
  const ownerData = await ownerRes.json();
  console.log(`Owner Login HTTP Status: ${ownerRes.status}`);
  console.log(`User: ${ownerData.user?.name}, Role: ${ownerData.user?.role}`);

  const ownerToken = ownerData.token;

  if (ownerToken) {
    const ownerHeaders = { Authorization: `Bearer ${ownerToken}` };

    // Dashboard Summary
    const summaryRes = await fetch(`${BASE_URL}/api/dashboard/summary`, { headers: ownerHeaders });
    const summaryData = await summaryRes.json();
    console.log(`✓ Owner Dashboard Summary: HTTP ${summaryRes.status}`);
    console.log('  Rooms Total:', summaryData.data?.rooms?.total, 'Occupied Beds:', summaryData.data?.rooms?.occupiedBeds);
    console.log('  Monthly Rent Collection: ₹' + summaryData.data?.financials?.monthlyRentCollection);

    // Rooms
    const roomsRes = await fetch(`${BASE_URL}/api/rooms`, { headers: ownerHeaders });
    const roomsData = await roomsRes.json();
    console.log(`✓ Owner Rooms: HTTP ${roomsRes.status}, Count: ${(roomsData.data?.rooms || roomsData.data || []).length}`);

    // Tenants
    const tenantsRes = await fetch(`${BASE_URL}/api/tenants`, { headers: ownerHeaders });
    const tenantsData = await tenantsRes.json();
    console.log(`✓ Owner Tenants: HTTP ${tenantsRes.status}, Count: ${(tenantsData.data?.tenants || tenantsData.data || []).length}`);

    // Meters
    const metersRes = await fetch(`${BASE_URL}/api/meters`, { headers: ownerHeaders });
    const metersData = await metersRes.json();
    console.log(`✓ Owner Meters: HTTP ${metersRes.status}, Count: ${(metersData.data?.readings || metersData.data || []).length}`);

    // Bills
    const billsRes = await fetch(`${BASE_URL}/api/bills`, { headers: ownerHeaders });
    const billsData = await billsRes.json();
    console.log(`✓ Owner Bills: HTTP ${billsRes.status}, Count: ${(billsData.data?.bills || billsData.data || []).length}`);

    // Payments
    const paymentsRes = await fetch(`${BASE_URL}/api/payments`, { headers: ownerHeaders });
    const paymentsData = await paymentsRes.json();
    console.log(`✓ Owner Payments: HTTP ${paymentsRes.status}, Count: ${(paymentsData.data?.payments || paymentsData.data || []).length}`);

    // Complaints
    const complaintsRes = await fetch(`${BASE_URL}/api/complaints`, { headers: ownerHeaders });
    const complaintsData = await complaintsRes.json();
    console.log(`✓ Owner Complaints: HTTP ${complaintsRes.status}, Count: ${(complaintsData.data?.complaints || complaintsData.data || []).length}`);

    // Settings
    const settingsRes = await fetch(`${BASE_URL}/api/settings`, { headers: ownerHeaders });
    const settingsData = await settingsRes.json();
    console.log(`✓ Owner Settings: HTTP ${settingsRes.status}, Data:`, settingsData.data || settingsData.settings);
  }

  // 2. Tenant Login
  console.log('\n--- 2. TENANT LOGIN (212rahul@gmail.com) ---');
  const tenantRes = await fetch(`${BASE_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: '212rahul@gmail.com',
      password: '123456789'
    })
  });
  const tenantData = await tenantRes.json();
  console.log(`Tenant Login HTTP Status: ${tenantRes.status}`);
  console.log(`User: ${tenantData.user?.name}, Role: ${tenantData.user?.role}`);

  const tenantToken = tenantData.token;

  if (tenantToken) {
    const tenantHeaders = { Authorization: `Bearer ${tenantToken}` };

    // Tenant Profile
    const profileRes = await fetch(`${BASE_URL}/api/tenants/me`, { headers: tenantHeaders });
    const profileData = await profileRes.json();
    console.log(`Tenant Profile /me: HTTP ${profileRes.status}`, profileData.message || profileData.data?.fullName || '');

    // Tenant Bills
    const myBillsRes = await fetch(`${BASE_URL}/api/bills/my-bills`, { headers: tenantHeaders });
    const myBillsData = await myBillsRes.json();
    console.log(`Tenant Bills /my-bills: HTTP ${myBillsRes.status}, Count: ${(myBillsData.data?.bills || myBillsData.data || []).length}`);

    // Tenant Room Meter
    const myMetersRes = await fetch(`${BASE_URL}/api/meters/my-room`, { headers: tenantHeaders });
    const myMetersData = await myMetersRes.json();
    console.log(`Tenant Meters /my-room: HTTP ${myMetersRes.status}`);

    // Tenant Payments
    const myPaymentsRes = await fetch(`${BASE_URL}/api/payments/my-payments`, { headers: tenantHeaders });
    const myPaymentsData = await myPaymentsRes.json();
    console.log(`Tenant Payments /my-payments: HTTP ${myPaymentsRes.status}, Count: ${(myPaymentsData.data?.payments || myPaymentsData.data || []).length}`);

    // Tenant Complaints
    const myComplaintsRes = await fetch(`${BASE_URL}/api/complaints/my-complaints`, { headers: tenantHeaders });
    const myComplaintsData = await myComplaintsRes.json();
    console.log(`Tenant Complaints /my-complaints: HTTP ${myComplaintsRes.status}, Count: ${(myComplaintsData.data?.complaints || myComplaintsData.data || []).length}`);

    // RBAC Test: Tenant accessing Owner summary
    console.log('\n--- 3. RBAC TEST (Tenant accessing /api/dashboard/summary) ---');
    const rbacRes = await fetch(`${BASE_URL}/api/dashboard/summary`, { headers: tenantHeaders });
    const rbacData = await rbacRes.json();
    console.log(`Tenant accessing /api/dashboard/summary: HTTP ${rbacRes.status}`);
    console.log(`Response message: "${rbacData.message}"`);
  }
}

testRealLogins().catch(console.error);
