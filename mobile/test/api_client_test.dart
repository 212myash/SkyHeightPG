import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/network/api_endpoints.dart';
import 'package:sky_height_pg/core/network/api_exceptions.dart';

void main() {
  group('API Client & Exceptions Tests', () {
    test('ApiEndpoints maps correct prefixes and paths', () {
      expect(ApiEndpoints.prefix, '/api');
      expect(ApiEndpoints.login, '/api/auth/login');
      expect(ApiEndpoints.register, '/api/auth/register');
      expect(ApiEndpoints.profile, '/api/auth/profile');
      expect(ApiEndpoints.rooms, '/api/rooms');
      expect(ApiEndpoints.tenants, '/api/tenants');
      expect(ApiEndpoints.myTenantProfile, '/api/tenants/me');
      expect(ApiEndpoints.bills, '/api/bills');
      expect(ApiEndpoints.myBills, '/api/bills/my-bills');
      expect(ApiEndpoints.payments, '/api/payments');
      expect(ApiEndpoints.dashboardSummary, '/api/dashboard/summary');
      expect(ApiEndpoints.settings, '/api/settings');

      expect(ApiEndpoints.roomById('123'), '/api/rooms/123');
      expect(ApiEndpoints.verifyPayment('pay_456'), '/api/payments/pay_456/verify');
    });

    test('ApiException hierarchy and default status codes', () {
      final unauth = UnauthorizedException();
      expect(unauth.statusCode, 401);
      expect(unauth.message, contains('Session expired'));

      final forbidden = ForbiddenException();
      expect(forbidden.statusCode, 403);

      final notFound = NotFoundException();
      expect(notFound.statusCode, 404);

      final network = NetworkException();
      expect(network.statusCode, isNull);

      final timeout = TimeoutException();
      expect(timeout.statusCode, isNull);

      final validation = ValidationException(message: 'Invalid email');
      expect(validation.statusCode, 400);
      expect(validation.message, 'Invalid email');
    });
  });
}
