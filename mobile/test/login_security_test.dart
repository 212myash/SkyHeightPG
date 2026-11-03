import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/features/auth/presentation/login_screen.dart';

void main() {
  group('Login Security & Credential Isolation Tests', () {
    test('Source code audit: No credentials or prefill helpers in login_screen.dart', () {
      final file = File('lib/features/auth/presentation/login_screen.dart');
      expect(file.existsSync(), isTrue, reason: 'login_screen.dart must exist');

      final content = file.readAsStringSync();

      // Ensure no production emails are present
      expect(content.contains('212myashraj@gmail.com'), isFalse,
          reason: 'Owner email must not be hardcoded in login_screen.dart');
      expect(content.contains('212rahul@gmail.com'), isFalse,
          reason: 'Tenant email must not be hardcoded in login_screen.dart');
      expect(content.contains('devtest_tenant@skyheight.in'), isFalse,
          reason: 'Test email must not be hardcoded in login_screen.dart');

      // Ensure no passwords are hardcoded
      expect(content.contains('Password123'), isFalse,
          reason: 'Passwords must not be hardcoded in login_screen.dart');
      expect(content.contains('123456789'), isFalse,
          reason: 'Plain text passwords must not be hardcoded in login_screen.dart');

      // Ensure no debug prefill buttons exist
      expect(content.contains('Fill Owner'), isFalse,
          reason: 'Fill Owner helper button must be removed');
      expect(content.contains('Fill Tenant'), isFalse,
          reason: 'Fill Tenant helper button must be removed');
    });

    testWidgets('UI Widget Audit: LoginScreen initial fields are blank and debug helpers are absent',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Verify no "Fill Owner" or "Fill Tenant" buttons exist in the widget tree
      expect(find.text('Fill Owner'), findsNothing);
      expect(find.text('Fill Tenant'), findsNothing);
      expect(find.byIcon(Icons.admin_panel_settings_outlined), findsNothing);

      // Verify email and password text fields are present and empty initially
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));

      final emailField = tester.widget<TextField>(textFields.first);
      expect(emailField.controller?.text, isEmpty,
          reason: 'Email field must be blank initially');

      final passwordField = tester.widget<TextField>(textFields.last);
      expect(passwordField.controller?.text, isEmpty,
          reason: 'Password field must be blank initially');

      // Verify Sign In button is present
      expect(find.text('Sign In'), findsOneWidget);
    });
  });
}
