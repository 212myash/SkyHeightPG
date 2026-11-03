/// Centralized API Endpoints for Sky Height PG
class ApiEndpoints {
  ApiEndpoints._();

  // Base prefix
  static const String prefix = '/api';

  // Authentication & Registrations
  static const String ownerStatus = '$prefix/auth/owner-status';
  static const String register = '$prefix/auth/register';
  static const String login = '$prefix/auth/login';
  static const String profile = '$prefix/auth/profile';
  static const String changePassword = '$prefix/auth/change-password';
  static const String registrations = '$prefix/owner/registrations';
  static String approveRegistration(String id) => '$prefix/owner/registrations/$id/approve';
  static String rejectRegistration(String id) => '$prefix/owner/registrations/$id/reject';

  // Rooms
  static const String rooms = '$prefix/rooms';
  static const String roomOccupancy = '$prefix/rooms/stats/occupancy';
  static String roomById(String id) => '$prefix/rooms/$id';
  static String roomTenants(String id) => '$prefix/rooms/$id/tenants';
  static String roomOccupancyHistory(String id) => '$prefix/rooms/$id/occupancy-history';

  // Tenants
  static const String tenants = '$prefix/tenants';
  static const String myTenantProfile = '$prefix/tenants/me';
  static const String myOccupancyHistory = '$prefix/tenants/me/occupancy-history';
  static String tenantById(String id) => '$prefix/tenants/$id';
  static String tenantOccupancyHistory(String id) => '$prefix/tenants/$id/occupancy-history';
  static String assignRoom(String id) => '$prefix/tenants/$id/assign-room';
  static String changeRoom(String id) => '$prefix/tenants/$id/change-room';
  static String vacateTenant(String id) => '$prefix/tenants/$id/vacate';

  // Notifications
  static const String notifications = '$prefix/notifications';
  static const String unreadNotificationCount = '$prefix/notifications/unread-count';
  static const String markAllNotificationsRead = '$prefix/notifications/read-all';
  static const String sentNotifications = '$prefix/notifications/sent';
  static String markNotificationRead(String id) => '$prefix/notifications/$id/read';
  static String replyNotification(String id) => '$prefix/notifications/$id/reply';

  // Chat & Messaging
  static const String conversations = '$prefix/conversations';
  static const String privateConversation = '$prefix/conversations/private';
  static String conversationMessages(String id) => '$prefix/conversations/$id/messages';
  static String sendMessage(String id) => '$prefix/conversations/$id/messages';
  static String markConversationRead(String id) => '$prefix/conversations/$id/read';

  // Electricity Meters
  static const String meters = '$prefix/meters';
  static const String myMeter = '$prefix/meters/my-meter';
  static const String monthlyUsage = '$prefix/meters/monthly-usage';
  static String roomMeterHistory(String roomId) => '$prefix/meters/room/$roomId';

  // Bills
  static const String bills = '$prefix/bills';
  static const String myBills = '$prefix/bills/my-bills';
  static const String pendingBills = '$prefix/bills/pending';
  static const String generateBills = '$prefix/bills/generate';
  static String billById(String id) => '$prefix/bills/$id';
  static String billAdjustments(String id) => '$prefix/bills/$id/adjustments';

  // Payments
  static const String payments = '$prefix/payments';
  static const String myPayments = '$prefix/payments/my-payments';
  static const String cashPayment = '$prefix/payments/cash';
  static const String submitUpi = '$prefix/payments/upi/submit';
  static String verifyPayment(String id) => '$prefix/payments/$id/verify';
  static String tenantBalance(String tenantId) => '$prefix/payments/balance/$tenantId';

  // Expenses
  static const String expenses = '$prefix/expenses';
  static const String expenseSummary = '$prefix/expenses/summary';
  static String expenseById(String id) => '$prefix/expenses/$id';

  // Complaints
  static const String complaints = '$prefix/complaints';
  static const String myComplaints = '$prefix/complaints/my-complaints';
  static String complaintById(String id) => '$prefix/complaints/$id';
  static String updateComplaintStatus(String id) => '$prefix/complaints/$id/status';

  // Dashboard
  static const String dashboardSummary = '$prefix/dashboard/summary';
  static const String financialReport = '$prefix/dashboard/reports/financial';

  // Settings
  static const String settings = '$prefix/settings';
}

