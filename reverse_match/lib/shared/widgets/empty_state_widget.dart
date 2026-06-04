import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/clay.dart';

/// Claymorphic empty state — a puffy clay medallion holding the icon.
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClayContainer(
              width: 116,
              height: 116,
              borderRadius: 40,
              alignment: Alignment.center,
              child: Icon(icon, size: 52, color: AppColors.primary),
            ),
            const SizedBox(height: 28),
            Text(
              title,
              style: textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 10),
              Text(
                subtitle!,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 28),
              ClayButton(
                onTap: onAction,
                borderRadius: 20,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                gradient: const LinearGradient(
                  colors: [AppColors.grape, AppColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                child: Text(
                  actionLabel!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
