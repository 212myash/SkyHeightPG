import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// Reusable modal bottom sheet component providing consistent UX for confirmations and actions
class AppBottomSheet {
  AppBottomSheet._();

  /// Show a standardized confirmation bottom sheet
  static Future<bool?> showConfirmation({
    required BuildContext context,
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    IconData? icon,
    Color? iconColor,
    bool isDestructive = false,
    Widget? customContent,
    Map<String, String>? detailPairs,
  }) {
    final effectiveIconColor = iconColor ?? (isDestructive ? AppColors.error : AppColors.primary);
    final effectiveIcon = icon ?? (isDestructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Icon and title
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDestructive ? AppColors.errorLight : AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(effectiveIcon, color: effectiveIconColor, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(title, style: AppTextStyles.h2),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Message
                Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),

                // Detail key-value pairs if provided
                if (detailPairs != null && detailPairs.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: detailPairs.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(e.key, style: AppTextStyles.bodySmall),
                              Flexible(
                                child: Text(
                                  e.value,
                                  style: AppTextStyles.labelLarge,
                                  textAlign: TextAlign.end,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                if (customContent != null) ...[
                  const SizedBox(height: 16),
                  customContent,
                ],

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.border),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(
                          cancelLabel,
                          style: AppTextStyles.labelLarge.copyWith(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDestructive ? AppColors.error : AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(
                          confirmLabel,
                          style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Show an interactive action bottom sheet with built-in loading and duplicate submit prevention
  static Future<T?> showActionSheet<T>({
    required BuildContext context,
    required String title,
    String? subtitle,
    required Widget Function(BuildContext context, bool isSubmitting, void Function(bool) setSubmitting) builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          bool isSubmitting = false;

          return SafeArea(
            child: Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    // Title
                    Text(title, style: AppTextStyles.h2),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Builder content
                    builder(
                      modalContext,
                      isSubmitting,
                      (val) => setModalState(() => isSubmitting = val),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
