import 'package:flutter/material.dart';

/// Official Brand Asset Path Definitions for Sky Height Apartment
class AppAssets {
  AppAssets._();

  static const String _base = 'assets/images/branding';

  /// Primary Horizontal Logo with building symbol + "SKY HEIGHT APARTMENT" (Dark text for light backgrounds)
  static const String primaryLogo = '$_base/primary_logo.png';

  /// Primary Horizontal Logo with white text (for dark/colored surfaces and splash)
  static const String primaryLogoDark = '$_base/primary_logo_dark.png';

  /// Compact Horizontal Logo for smaller headers and navbars (Dark text for light backgrounds)
  static const String compactLogo = '$_base/compact_logo.png';

  /// Compact Horizontal Logo with white text (for dark headers)
  static const String compactLogoDark = '$_base/compact_logo_dark.png';

  /// Architectural Building Emblem without text
  static const String standaloneSymbol = '$_base/standalone_symbol.png';

  /// Master Square Rounded App Icon (512x512)
  static const String appIcon = '$_base/app_icon_source.png';
}

/// Enum representing the official brand logo variants
enum AppLogoVariant {
  primary,
  primaryDark,
  compact,
  compactDark,
  symbol,
  appIcon,
}

/// Official Sky Height Apartment Brand Logo Widget
class AppBrandLogo extends StatelessWidget {
  final AppLogoVariant variant;
  final double? height;
  final double? width;
  final BoxFit fit;

  const AppBrandLogo({
    super.key,
    this.variant = AppLogoVariant.primary,
    this.height,
    this.width,
    this.fit = BoxFit.contain,
  });

  /// Factory for standalone architectural symbol
  const AppBrandLogo.symbol({
    super.key,
    this.height = 48,
    this.width,
    this.fit = BoxFit.contain,
  }) : variant = AppLogoVariant.symbol;

  /// Factory for compact horizontal header logo
  const AppBrandLogo.compact({
    super.key,
    this.height = 32,
    this.width,
    this.fit = BoxFit.contain,
    bool isDark = false,
  }) : variant = isDark ? AppLogoVariant.compactDark : AppLogoVariant.compact;

  /// Factory for full horizontal primary logo
  const AppBrandLogo.primary({
    super.key,
    this.height = 56,
    this.width,
    this.fit = BoxFit.contain,
    bool isDark = false,
  }) : variant = isDark ? AppLogoVariant.primaryDark : AppLogoVariant.primary;

  /// Factory for square rounded app icon badge
  const AppBrandLogo.icon({
    super.key,
    this.height = 64,
    this.width = 64,
    this.fit = BoxFit.contain,
  }) : variant = AppLogoVariant.appIcon;

  String get _assetPath {
    switch (variant) {
      case AppLogoVariant.primary:
        return AppAssets.primaryLogo;
      case AppLogoVariant.primaryDark:
        return AppAssets.primaryLogoDark;
      case AppLogoVariant.compact:
        return AppAssets.compactLogo;
      case AppLogoVariant.compactDark:
        return AppAssets.compactLogoDark;
      case AppLogoVariant.symbol:
        return AppAssets.standaloneSymbol;
      case AppLogoVariant.appIcon:
        return AppAssets.appIcon;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _assetPath,
      height: height,
      width: width,
      fit: fit,
      filterQuality: FilterQuality.high,
      errorBuilder: (context, error, stackTrace) {
        return Icon(
          Icons.apartment_rounded,
          size: height ?? 32,
          color: Theme.of(context).primaryColor,
        );
      },
    );
  }
}
