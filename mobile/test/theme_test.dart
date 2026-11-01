import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sky_height_pg/app/theme/app_colors.dart';
import 'package:sky_height_pg/app/theme/app_theme.dart';

void main() {
  group('Theme System Tests', () {
    test('AppColors matches required design system palette', () {
      expect(AppColors.primary, const Color(0xFFE63946));
      expect(AppColors.primaryDark, const Color(0xFFC62828));
      expect(AppColors.primaryLight, const Color(0xFFFFF3F3));
      expect(AppColors.background, const Color(0xFFF8F9FA));
      expect(AppColors.cardSurface, const Color(0xFFFFFFFF));
      expect(AppColors.textPrimary, const Color(0xFF1A1A1A));
      expect(AppColors.textSecondary, const Color(0xFF64748B));
      expect(AppColors.border, const Color(0xFFE2E8F0));
      expect(AppColors.success, const Color(0xFF15803D));
      expect(AppColors.warning, const Color(0xFFD97706));
      expect(AppColors.error, const Color(0xFFDC2626));
    });

    test('AppTheme.lightTheme produces valid Material 3 theme', () {
      final theme = AppTheme.lightTheme;

      expect(theme.useMaterial3, isTrue);
      expect(theme.scaffoldBackgroundColor, AppColors.background);
      expect(theme.colorScheme.primary, AppColors.primary);
      expect(theme.colorScheme.error, AppColors.error);
      expect(theme.appBarTheme.backgroundColor, Colors.white);
      expect(theme.appBarTheme.foregroundColor, AppColors.textPrimary);
    });
  });
}
