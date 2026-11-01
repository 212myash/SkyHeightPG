import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/change_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/owner/presentation/owner_main_screen.dart';
import '../../features/owner/presentation/owner_settings_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: notifier,
    redirect: (BuildContext context, GoRouterState state) {
      final auth = ref.read(authProvider);
      final isAuth = auth.isAuthenticated;
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
        path: '/tenant',
        builder: (context, state) => const TenantMainScreen(),
      ),
    ],
  );
});
