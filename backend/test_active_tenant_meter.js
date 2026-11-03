const BASE_URL = 'https://skyheightpg.onrender.com';

async function testActiveRoomTenant() {
  const res = await fetch(`${BASE_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'tenanta_1793533117859@skyheight-test.com',
      password: 'TenantPassword123!'
    })
  });
  const data = await res.json();
  console.log(`Tenant Login: HTTP ${res.status}`);
  const token = data.token;
  if (!token) return;

  const headers = { Authorization: `Bearer ${token}` };

  const meterRes = await fetch(`${BASE_URL}/api/meters/my-meter`, { headers });
  const meterData = await meterRes.json();
  console.log(`Tenant Meter (/api/meters/my-meter): HTTP ${meterRes.status}`);
  console.log('Meter Data:', JSON.stringify(meterData, null, 2));
}

testActiveRoomTenant().catch(console.error);
