const BASE_URL = 'https://skyheightpg.onrender.com';

async function testFullTenantFlow() {
  console.log('Testing Full Tenant Flow with tenanta_1793526965606@skyheight-test.com:\n');

  // Tenant Login
  const res = await fetch(`${BASE_URL}/api/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      email: 'tenanta_1793526965606@skyheight-test.com',
      password: 'Password123'
    })
  });
  const data = await res.json();
  console.log(`Tenant Login HTTP Status: ${res.status}`);
  console.log(`User: ${data.user?.name}, Role: ${data.user?.role}`);

  const token = data.token;
  if (!token) {
    console.error('No token returned');
    return;
  }
  const headers = { Authorization: `Bearer ${token}` };

  // Profile
  const profileRes = await fetch(`${BASE_URL}/api/tenants/me`, { headers });
  const profileData = await profileRes.json();
  console.log(`✓ Tenant Profile (/api/tenants/me): HTTP ${profileRes.status}`);
  console.log('  Profile:', profileData.data?.fullName, 'Bed:', profileData.data?.bedNumber, 'Rent:', profileData.data?.rentAmount);

  // My Bills
  const billsRes = await fetch(`${BASE_URL}/api/bills/my-bills`, { headers });
  const billsData = await billsRes.json();
  console.log(`✓ Tenant Bills (/api/bills/my-bills): HTTP ${billsRes.status}`);
  const bills = billsData.data?.bills || billsData.data || [];
  console.log(`  Bills Count: ${bills.length}`);
  if (bills.length > 0) {
    console.log(`  Latest Bill: Month=${bills[0].billingMonth}, Total=₹${bills[0].totalAmount}, Status=${bills[0].paymentStatus}`);
  }

  // My Room Meter
  const meterRes = await fetch(`${BASE_URL}/api/meters/my-meter`, { headers });
  const meterData = await meterRes.json();
  console.log(`✓ Tenant Meter (/api/meters/my-meter): HTTP ${meterRes.status}`);
  console.log('  Meter Data:', meterData.data ? 'Found' : JSON.stringify(meterData));

  // My Payments
  const paymentsRes = await fetch(`${BASE_URL}/api/payments/my-payments`, { headers });
  const paymentsData = await paymentsRes.json();
  console.log(`✓ Tenant Payments (/api/payments/my-payments): HTTP ${paymentsRes.status}`);
  const payments = paymentsData.data?.payments || paymentsData.data || [];
  console.log(`  Payments Count: ${payments.length}`);

  // My Complaints
  const complaintsRes = await fetch(`${BASE_URL}/api/complaints/my-complaints`, { headers });
  const complaintsData = await complaintsRes.json();
  console.log(`✓ Tenant Complaints (/api/complaints/my-complaints): HTTP ${complaintsRes.status}`);
  const complaints = complaintsData.data?.complaints || complaintsData.data || [];
  console.log(`  Complaints Count: ${complaints.length}`);
  if (complaints.length > 0) {
    console.log(`  Latest Complaint: Title="${complaints[0].title}", Status=${complaints[0].status}`);
  }
}

testFullTenantFlow().catch(console.error);
