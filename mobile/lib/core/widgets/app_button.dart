import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

class AppButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;
  final double? width;
  final Color? backgroundColor;
  final bool debounce;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
    this.width,
    this.backgroundColor,
    this.debounce = false,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  int _lastTapTime = 0;

  @override
  Widget build(BuildContext context) {
    final effectiveOnPressed = widget.isLoading || widget.onPressed == null
        ? null
        : () {
            if (widget.debounce) {
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now - _lastTapTime < 600) {
                return; // Suppress rapid double-tap
              }
              _lastTapTime = now;
            }
            widget.onPressed!();
          };

    Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                widget.isOutlined ? AppColors.primary : Colors.white,
              ),
            ),
          )
        else ...[
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(
              widget.label,
              style: AppTextStyles.button.copyWith(
                color: widget.isOutlined ? AppColors.primary : Colors.white,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ],
    );

    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: widget.backgroundColor ?? (widget.isOutlined ? Colors.transparent : AppColors.primary),
      foregroundColor: widget.isOutlined ? AppColors.primary : Colors.white,
      elevation: widget.isOutlined ? 0 : 2,
      shadowColor: widget.isOutlined ? Colors.transparent : AppColors.primary.withAlpha(50),
      side: widget.isOutlined ? const BorderSide(color: AppColors.primary, width: 1.5) : BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      minimumSize: Size(widget.width ?? double.infinity, 48),
    );

    return SizedBox(
      width: widget.width,
      child: ElevatedButton(
        onPressed: effectiveOnPressed,
        style: buttonStyle,
        child: content,
      ),
    );
  }
}
