import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/owner/presentation/owner_main_screen.dart';
import '../../features/owner/presentation/owner_settings_screen.dart';
import '../../features/owner/presentation/owner_meter_screen.dart';
import '../../features/owner/presentation/owner_billing_screen.dart';
import '../../features/owner/presentation/owner_complaints_screen.dart';
import '../../features/owner/presentation/owner_expenses_screen.dart';
import '../../features/owner/presentation/owner_registrations_screen.dart';
import '../../features/owner/presentation/owner_payments_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/notifications/presentation/owner_create_notification_screen.dart';
import '../../features/chat/presentation/chat_list_screen.dart';
import '../../features/chat/presentation/conversation_screen.dart';
import '../../features/splash/presentation/splash_screen.dart';
import '../../features/tenant/presentation/tenant_main_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (previous, current) => notifyListeners(),
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      final auth = ref.read(authProvider);
      final isAuth = auth.hasActiveSession;
      final location = state.matchedLocation;

      final isSplash = location == '/splash';
      final isLogin = location == '/login';
      final isRegister = location == '/register';

      // Keep showing splash if verifying initial auth state
      if (auth.status == AuthStatus.initial || (auth.status == AuthStatus.loading && isSplash)) {
        return null;
      }

      // If not authenticated, allow login and register
      if (!isAuth) {
        if (isLogin || isRegister) return null;
        return '/login';
      }

      // Authenticated user trying to access public auth screens
      final isOwner = auth.isOwner;
      if (isSplash || isLogin || isRegister) {
        return isOwner ? '/owner' : '/tenant';
      }

      // Role boundary guards
      if (isOwner && location.startsWith('/tenant')) {
        return '/owner';
      }
      if (!isOwner && location.startsWith('/owner')) {
        return '/tenant';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/change-password',
        builder: (context, state) => const ChangePasswordScreen(),
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => const OwnerMainScreen(),
      ),
      GoRoute(
        path: '/owner/settings',
        builder: (context, state) => const OwnerSettingsScreen(),
      ),
      GoRoute(
        path: '/owner/meter',
        builder: (context, state) => const OwnerMeterScreen(),
      ),
      GoRoute(
        path: '/owner/billing',
        builder: (context, state) => const OwnerBillingScreen(),
      ),
      GoRoute(
        path: '/owner/complaints',
        builder: (context, state) => const OwnerComplaintsScreen(),
      ),
      GoRoute(
        path: '/owner/expenses',
        builder: (context, state) => const OwnerExpensesScreen(),
      ),
      GoRoute(
        path: '/owner/registrations',
        builder: (context, state) => const OwnerRegistrationsScreen(),
      ),
      GoRoute(
        path: '/owner/payments',
        builder: (context, state) => const OwnerPaymentsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/notifications/create',
        builder: (context, state) => const OwnerCreateNotificationScreen(),
      ),
      GoRoute(
        path: '/chat',
        builder: (context, state) => const ChatListScreen(),
      ),
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => ConversationScreen(
          conversationId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/tenant',
        builder: (context, state) => const TenantMainScreen(),
      ),
      GoRoute(
        path: '/tenant/bills',
        builder: (context, state) => const TenantMainScreen(initialIndex: 1),
      ),
      GoRoute(
        path: '/tenant/payments',
        builder: (context, state) => const TenantMainScreen(initialIndex: 2),
      ),
      GoRoute(
        path: '/tenant/complaints',
        builder: (context, state) => const TenantMainScreen(initialIndex: 3),
      ),
      GoRoute(
        path: '/tenant/profile',
        builder: (context, state) => const TenantMainScreen(initialIndex: 4),
      ),
    ],
  );
});
