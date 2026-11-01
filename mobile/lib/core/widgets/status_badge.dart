import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final String? customLabel;

  const StatusBadge({
    super.key,
    required this.status,
    this.customLabel,
  });

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    final normalized = status.toLowerCase().replaceAll(' ', '_');

    switch (normalized) {
      case 'paid':
      case 'verified':
      case 'active':
      case 'available':
      case 'resolved':
        bg = AppColors.successLight;
        fg = AppColors.success;
        break;
      case 'pending':
      case 'partially_paid':
      case 'notice_period':
      case 'in_progress':
      case 'medium':
        bg = AppColors.warningLight;
        fg = AppColors.warning;
        break;
      case 'overdue':
      case 'rejected':
      case 'occupied':
      case 'high':
      case 'urgent':
        bg = AppColors.errorLight;
        fg = AppColors.error;
        break;
      case 'maintenance':
      case 'vacated':
      case 'open':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
    }

    final displayText = customLabel ??
        status
            .replaceAll('_', ' ')
            .split(' ')
            .map((word) => word.isNotEmpty
                ? '${word[0].toUpperCase()}${word.substring(1)}'
                : '')
            .join(' ');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.25), width: 1),
      ),
      child: Text(
        displayText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
