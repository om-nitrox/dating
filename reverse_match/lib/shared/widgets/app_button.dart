import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/clay.dart';

/// Claymorphic primary / outlined button with a squishy press animation.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final IconData? icon;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final fg = isOutlined ? AppColors.primary : Colors.white;

    final content = isLoading
        ? SizedBox(
            height: 20,
            width: 20,
            child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: fg),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          );

    return SizedBox(
      width: double.infinity,
      child: ClayButton(
        onTap: onPressed,
        enabled: enabled,
        borderRadius: 22,
        padding: const EdgeInsets.symmetric(vertical: 17),
        color: isOutlined ? Clay.surface(context) : null,
        gradient: isOutlined
            ? null
            : const LinearGradient(
                colors: [AppColors.grape, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        child: content,
      ),
    );
  }
}
