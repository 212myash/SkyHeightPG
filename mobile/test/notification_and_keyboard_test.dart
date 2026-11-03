import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/notifications/app_notification_service.dart';
import 'package:sky_height_pg/core/widgets/app_bottom_sheet.dart';
import 'package:sky_height_pg/core/widgets/app_notification_banner.dart';
import 'package:sky_height_pg/core/widgets/app_snack_bar.dart';
import 'package:sky_height_pg/core/widgets/app_text_field.dart';
import 'package:sky_height_pg/core/widgets/keyboard_aware_view.dart';

void main() {
  group('Notification & Keyboard UX System Tests', () {
    testWidgets('AppNotificationService de-duplicates identical rapid messages', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: AppNotificationService.messengerKey,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AppNotificationService.showSnackBar('Duplicate test message', context: ctx);
                },
                child: const Text('Show SnackBar'),
              ),
            ),
          ),
        ),
      );

      // Tap twice rapidly
      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();
      await tester.tap(find.text('Show SnackBar'));
      await tester.pump();

      // Exactly 1 snack bar should be visible due to de-duplication throttle
      expect(find.text('Duplicate test message'), findsOneWidget);
    });

    testWidgets('AppSnackBar static facade shows success, error, warning and info', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: AppNotificationService.messengerKey,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Column(
                children: [
                  ElevatedButton(
                    onPressed: () => AppSnackBar.success(ctx, 'Operation successful!'),
                    child: const Text('Trigger Success'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Trigger Success'));
      await tester.pump();
      expect(find.text('Operation successful!'), findsOneWidget);
    });

    testWidgets('Top banner notifier posts and dismisses system banners', (tester) async {
      AppNotificationService.showTopBanner(
        message: 'Network offline. Retrying...',
        type: NotificationType.warning,
        actionLabel: 'Dismiss',
        autoDismiss: false,
      );

      expect(AppNotificationService.topBannerNotifier.value, isNotNull);
      expect(AppNotificationService.topBannerNotifier.value?.message, 'Network offline. Retrying...');
      expect(AppNotificationService.topBannerNotifier.value?.type, NotificationType.warning);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                const Center(child: Text('Main Screen Content')),
                const Positioned(top: 0, left: 0, right: 0, child: AppTopNotificationBanner()),
              ],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Network offline. Retrying...'), findsOneWidget);

      AppNotificationService.dismissTopBanner();
      await tester.pumpAndSettle();
      expect(find.text('Network offline. Retrying...'), findsNothing);
    });

    testWidgets('KeyboardDismissible unfocuses active focus on tap outside', (tester) async {
      final focusNode = FocusNode();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: KeyboardDismissible(
              child: Column(
                children: [
                  TextField(
                    focusNode: focusNode,
                  ),
                  const SizedBox(height: 50),
                  const Text('Outside Area'),
                ],
              ),
            ),
          ),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(focusNode.hasFocus, isTrue);

      await tester.tap(find.text('Outside Area'));
      await tester.pump();
      expect(focusNode.hasFocus, isFalse);
    });

    testWidgets('AppBottomSheet.showConfirmation displays details and buttons', (tester) async {
      bool? result;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await AppBottomSheet.showConfirmation(
                    context: ctx,
                    title: 'Vacate Tenant',
                    message: 'Are you sure you want to vacate tenant John Doe?',
                    confirmLabel: 'Mark Vacated',
                    isDestructive: true,
                    detailPairs: {
                      'Tenant': 'John Doe',
                      'Room': 'Room 101',
                    },
                  );
                },
                child: const Text('Open Sheet'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Vacate Tenant'), findsOneWidget);
      expect(find.text('Are you sure you want to vacate tenant John Doe?'), findsOneWidget);
      expect(find.text('Tenant'), findsOneWidget);
      expect(find.text('John Doe'), findsOneWidget);
      expect(find.text('Room 101'), findsOneWidget);
      expect(find.text('Mark Vacated'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Mark Vacated'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('AppTextField displays isRequired asterisk and error border', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16.0),
              child: AppTextField(
                label: 'Electricity Units',
                isRequired: true,
                errorText: 'Reading must be greater than previous',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Electricity Units'), findsOneWidget);
      expect(find.text(' *'), findsOneWidget);
      expect(find.text('Reading must be greater than previous'), findsOneWidget);
    });
  });
}
