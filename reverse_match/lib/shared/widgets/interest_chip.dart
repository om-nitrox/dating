import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/clay.dart';

/// Claymorphic selectable chip — puffy pill that depresses + fills with the
/// lilac→mint gradient when selected.
class InterestChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const InterestChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClayButton(
      onTap: onTap,
      borderRadius: 20,
      depth: isSelected ? 0.5 : 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
      gradient: isSelected
          ? const LinearGradient(
              colors: [AppColors.grape, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: isSelected ? null : Clay.surface(context),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Colors.white
              : Theme.of(context).textTheme.bodyLarge?.color,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          fontSize: 14,
        ),
      ),
    );
  }
}
