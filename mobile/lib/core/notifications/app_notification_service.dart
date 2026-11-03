import 'dart:async';
import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

enum NotificationType { success, error, warning, info }

class BannerNotificationData {
  final String id;
  final String message;
  final NotificationType type;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool autoDismiss;
  final Duration duration;

  BannerNotificationData({
    required this.id,
    required this.message,
    this.type = NotificationType.info,
    this.actionLabel,
    this.onAction,
    this.autoDismiss = true,
    this.duration = const Duration(seconds: 4),
  });
}

class AppNotificationService {
  AppNotificationService._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static final ValueNotifier<BannerNotificationData?> topBannerNotifier =
      ValueNotifier<BannerNotificationData?>(null);

  // De-duplication tracking
  static String? _lastMessage;
  static DateTime? _lastMessageTime;
  static const Duration _duplicateThrottle = Duration(milliseconds: 2500);

  // Top banner timer
  static Timer? _bannerDismissTimer;

  static bool _isDuplicate(String message) {
    final now = DateTime.now();
    if (_lastMessage == message &&
        _lastMessageTime != null &&
        now.difference(_lastMessageTime!) < _duplicateThrottle) {
      return true;
    }
    _lastMessage = message;
    _lastMessageTime = now;
    return false;
  }

  /// Show a floating SnackBar with designated type, auto-dismiss and spacing
  static void showSnackBar(
    String message, {
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
    BuildContext? context,
  }) {
    if (message.trim().isEmpty) return;
    if (_isDuplicate(message)) return;

    final messenger = context != null
        ? ScaffoldMessenger.maybeOf(context) ?? messengerKey.currentState
        : messengerKey.currentState;

    if (messenger == null) return;

    messenger.hideCurrentSnackBar();

    Color bg;
    IconData icon;
    switch (type) {
      case NotificationType.success:
        bg = AppColors.success;
        icon = Icons.check_circle_rounded;
        break;
      case NotificationType.error:
        bg = AppColors.error;
        icon = Icons.error_rounded;
        break;
      case NotificationType.warning:
        bg = AppColors.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case NotificationType.info:
        bg = AppColors.info;
        icon = Icons.info_rounded;
        break;
    }

    // Determine bottom padding for floating SnackBar
    double bottomMargin = 16.0;
    if (context != null) {
      final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
      final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
      bottomMargin = 16.0 + (bottomInset > 0 ? bottomInset : bottomPadding);
    }

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        margin: EdgeInsets.only(
          left: 16.0,
          right: 16.0,
          bottom: bottomMargin,
        ),
        duration: duration,
      ),
    );
  }

  static void showSuccess(String message, {BuildContext? context, Duration? duration}) {
    showSnackBar(
      message,
      type: NotificationType.success,
      duration: duration ?? const Duration(seconds: 3),
      context: context,
    );
  }

  static void showError(String message, {BuildContext? context, Duration? duration}) {
    showSnackBar(
      message,
      type: NotificationType.error,
      duration: duration ?? const Duration(seconds: 4),
      context: context,
    );
  }

  static void showWarning(String message, {BuildContext? context, Duration? duration}) {
    showSnackBar(
      message,
      type: NotificationType.warning,
      duration: duration ?? const Duration(seconds: 3),
      context: context,
    );
  }

  static void showInfo(String message, {BuildContext? context, Duration? duration}) {
    showSnackBar(
      message,
      type: NotificationType.info,
      duration: duration ?? const Duration(seconds: 3),
      context: context,
    );
  }

  /// Show a system-level top notification banner
  static void showTopBanner({
    required String message,
    NotificationType type = NotificationType.info,
    String? actionLabel,
    VoidCallback? onAction,
    bool autoDismiss = true,
    Duration duration = const Duration(seconds: 4),
  }) {
    _bannerDismissTimer?.cancel();

    final data = BannerNotificationData(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      message: message,
      type: type,
      actionLabel: actionLabel,
      onAction: onAction,
      autoDismiss: autoDismiss,
      duration: duration,
    );

    topBannerNotifier.value = data;

    if (autoDismiss) {
      _bannerDismissTimer = Timer(duration, () {
        if (topBannerNotifier.value?.id == data.id) {
          topBannerNotifier.value = null;
        }
      });
    }
  }

  static void dismissTopBanner() {
    _bannerDismissTimer?.cancel();
    topBannerNotifier.value = null;
  }
}
