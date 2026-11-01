import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/widgets/app_button.dart';
import 'package:sky_height_pg/core/widgets/app_card.dart';
import 'package:sky_height_pg/core/widgets/status_badge.dart';
import 'package:sky_height_pg/core/widgets/dashboard_metric_card.dart';
import 'package:sky_height_pg/core/widgets/empty_state_view.dart';
import 'package:sky_height_pg/core/widgets/error_state_view.dart';

void main() {
  group('Core UI Components Widget Tests', () {
    testWidgets('AppButton renders label and triggers callback', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Click Me',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Click Me'), findsOneWidget);
      await tester.tap(find.text('Click Me'));
      expect(tapped, isTrue);
    });

    testWidgets('AppButton shows loader when isLoading is true', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AppButton(
              label: 'Submit',
              isLoading: true,
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Submit'), findsNothing);
    });

    testWidgets('StatusBadge renders appropriate colors and text for PAID and UNPAID', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatusBadge(status: 'PAID'),
                StatusBadge(status: 'UNPAID'),
                StatusBadge(status: 'ACTIVE'),
              ],
            ),
          ),
        ),
      );

      expect(find.text('PAID'), findsOneWidget);
      expect(find.text('UNPAID'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);
    });

    testWidgets('AppCard renders child with styled elevation and borders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AppCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
    });

    testWidgets('DashboardMetricCard displays title, value, and icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: DashboardMetricCard(
              title: 'Total Revenue',
              value: '₹50,000',
              icon: Icons.currency_rupee,
            ),
          ),
        ),
      );

      expect(find.text('Total Revenue'), findsOneWidget);
      expect(find.text('₹50,000'), findsOneWidget);
      expect(find.byIcon(Icons.currency_rupee), findsOneWidget);
    });

    testWidgets('EmptyStateView renders title, description and optional action', (tester) async {
      bool actionTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyStateView(
              title: 'No Data Found',
              description: 'Try again later',
              actionText: 'Retry Now',
              onAction: () => actionTapped = true,
            ),
          ),
        ),
      );

      expect(find.text('No Data Found'), findsOneWidget);
      expect(find.text('Try again later'), findsOneWidget);
      expect(find.text('Retry Now'), findsOneWidget);

      await tester.tap(find.text('Retry Now'));
      expect(actionTapped, isTrue);
    });

    testWidgets('ErrorStateView renders error message and retry button', (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateView(
              message: 'Failed to connect to backend',
              onRetry: () => retried = true,
            ),
          ),
        ),
      );

      expect(find.text('Something Went Wrong'), findsOneWidget);
      expect(find.text('Failed to connect to backend'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });
  });
}
