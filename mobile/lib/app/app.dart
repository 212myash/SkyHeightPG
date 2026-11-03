import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/notifications/app_notification_service.dart';
import '../core/widgets/app_notification_banner.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class SkyHeightApp extends ConsumerWidget {
  const SkyHeightApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Sky Height PG',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: AppNotificationService.messengerKey,
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            ?child,
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AppTopNotificationBanner(),
            ),
          ],
        );
      },
    );
  }
}
