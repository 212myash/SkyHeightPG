import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/core/widgets/dashboard_metric_card.dart';
import 'package:sky_height_pg/core/widgets/status_badge.dart';

void main() {
  group('Responsive UI & Overflow Tests across Screen Widths', () {
    final screenSizes = [
      const Size(320, 600), // Small compact Android / iPhone SE
      const Size(360, 800), // Standard compact Android
      const Size(375, 812), // Standard iPhone / Modern Android
      const Size(414, 896), // Large device
    ];

    for (final size in screenSizes) {
      testWidgets('DashboardMetricCard renders without overflow at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: size.width - 32,
                  child: const DashboardMetricCard(
                    title: 'Total Outstanding Revenue for Sky Height PG',
                    value: '₹ 12,34,56,789.00',
                    icon: Icons.account_balance_wallet_outlined,
                    subtitle: 'Excludes active security deposits and historical arrears',
                  ),
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Total Outstanding Revenue for Sky Height PG'), findsOneWidget);
        expect(find.text('₹ 12,34,56,789.00'), findsOneWidget);
      });

      testWidgets('Row with Expanded header and StatusBadge renders without overflow at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const CircleAvatar(radius: 20, child: Icon(Icons.person)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Shashank Shekhar Upadhyay Extended Long Name',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Room 304 - Bed B • Joined 15 Sep 2025',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const StatusBadge(status: 'ACTIVE'),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('ACTIVE'), findsOneWidget);
      });

      testWidgets('Billing item columns render with FittedBox without overflow at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Total', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '₹ 99,99,999.00',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Paid', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '₹ 88,88,888.00',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.green),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Outstanding', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '₹ 11,11,111.00',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('Total'), findsOneWidget);
        expect(find.text('Paid'), findsOneWidget);
        expect(find.text('Outstanding'), findsOneWidget);
      });

      testWidgets('Responsive Wrap for category and tags does not overflow at ${size.width}x${size.height}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: const [
                    StatusBadge(status: 'OPEN'),
                    StatusBadge(status: 'HIGH'),
                    Chip(label: Text('Electrical Maintenance')),
                    Chip(label: Text('Room 201 - Bed A')),
                    Chip(label: Text('Priority: Urgent')),
                  ],
                ),
              ),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.text('OPEN'), findsOneWidget);
        expect(find.text('HIGH'), findsOneWidget);
        expect(find.text('Electrical Maintenance'), findsOneWidget);
      });
    }
  });
}
