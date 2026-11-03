import 'package:flutter/material.dart';
import '../notifications/app_notification_service.dart';

/// Reusable Floating SnackBar utility providing consistent visual messaging
class AppSnackBar {
  AppSnackBar._();

  static void show(
    BuildContext context,
    String message, {
    NotificationType type = NotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    AppNotificationService.showSnackBar(
      message,
      type: type,
      duration: duration,
      context: context,
    );
  }

  static void success(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    AppNotificationService.showSuccess(
      message,
      context: context,
      duration: duration,
    );
  }

  static void error(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 4),
  }) {
    AppNotificationService.showError(
      message,
      context: context,
      duration: duration,
    );
  }

  static void warning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    AppNotificationService.showWarning(
      message,
      context: context,
      duration: duration,
    );
  }

  static void info(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) {
    AppNotificationService.showInfo(
      message,
      context: context,
      duration: duration,
    );
  }
}
