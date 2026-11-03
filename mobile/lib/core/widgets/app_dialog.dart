import 'package:flutter/material.dart';
import '../notifications/app_notification_service.dart';
import 'app_bottom_sheet.dart';

class AppDialog {
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String content,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color? confirmColor,
    bool isDestructive = false,
    Map<String, String>? detailPairs,
  }) {
    return AppBottomSheet.showConfirmation(
      context: context,
      title: title,
      message: content,
      confirmLabel: confirmText,
      cancelLabel: cancelText,
      iconColor: confirmColor,
      isDestructive: isDestructive,
      detailPairs: detailPairs,
    );
  }

  static void showSnackBar(BuildContext context, String message, {bool isError = false}) {
    AppNotificationService.showSnackBar(
      message,
      type: isError ? NotificationType.error : NotificationType.success,
      context: context,
    );
  }
}
