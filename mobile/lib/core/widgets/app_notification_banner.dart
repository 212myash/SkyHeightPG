import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../notifications/app_notification_service.dart';

/// Animated system-level notification banner shown at top of screen
class AppTopNotificationBanner extends StatelessWidget {
  const AppTopNotificationBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BannerNotificationData?>(
      valueListenable: AppNotificationService.topBannerNotifier,
      builder: (context, bannerData, child) {
        if (bannerData == null) {
          return const SizedBox.shrink();
        }

        Color bgColor;
        Color textColor = Colors.white;
        IconData icon;

        switch (bannerData.type) {
          case NotificationType.error:
            bgColor = AppColors.error;
            icon = Icons.cloud_off_rounded;
            break;
          case NotificationType.warning:
            bgColor = AppColors.warning;
            icon = Icons.warning_amber_rounded;
            break;
          case NotificationType.success:
            bgColor = AppColors.success;
            icon = Icons.cloud_done_rounded;
            break;
          case NotificationType.info:
            bgColor = AppColors.info;
            icon = Icons.info_outline_rounded;
            break;
        }

        return SafeArea(
          bottom: false,
          child: Material(
            color: Colors.transparent,
            elevation: 4,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(icon, color: textColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      bannerData.message,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (bannerData.actionLabel != null && bannerData.onAction != null) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                      onPressed: () {
                        bannerData.onAction?.call();
                        AppNotificationService.dismissTopBanner();
                      },
                      child: Text(
                        bannerData.actionLabel!,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: AppNotificationService.dismissTopBanner,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(Icons.close_rounded, color: textColor.withValues(alpha: 0.8), size: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
