import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class AppLoader extends StatelessWidget {
  final String? message;
  final double size;

  const AppLoader({
    super.key,
    String? message,
    String? text,
    this.size = 36,
  }) : message = message ?? text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: const CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 12),
            Text(
              message!,
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
