const BASE_URL = 'https://skyheightpg.onrender.com';

async function testMeterRoutes() {
  // Owner login
  const ownerRes = await fetch(`${BASE_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email: '212myashraj@gmail.com', password: '123456789' })
  });
  const ownerData = await ownerRes.json();
  const ownerToken = ownerData.token;

  // Test Owner Monthly Usage
  const meterUsageRes = await fetch(`${BASE_URL}/api/meters/monthly-usage`, {
    headers: { Authorization: `Bearer ${ownerToken}` }
  });
  const meterUsageData = await meterUsageRes.json();
  console.log(`Owner /api/meters/monthly-usage: HTTP ${meterUsageRes.status}`, meterUsageData);

  // Test Room History for Room G101 (ID: 6ae6cb413c12a54fa65c6803)
  const roomMeterRes = await fetch(`${BASE_URL}/api/meters/room/6ae6cb413c12a54fa65c6803`, {
    headers: { Authorization: `Bearer ${ownerToken}` }
  });
  const roomMeterData = await roomMeterRes.json();
  console.log(`Room G101 /api/meters/room/:roomId: HTTP ${roomMeterRes.status}, Readings Count:`, roomMeterData.data?.length || roomMeterData.readings?.length);
}

testMeterRoutes().catch(console.error);
