import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/clay.dart';

/// Claymorphic selectable row — puffy clay card that fills with the coral→grape
/// gradient and squishes in when selected. API preserved (label, sublabel,
/// isSelected, onTap, multiSelect).
class OptionTile extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool isSelected;
  final VoidCallback onTap;
  final bool multiSelect;

  const OptionTile({
    super.key,
    required this.label,
    this.sublabel,
    required this.isSelected,
    required this.onTap,
    this.multiSelect = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subColor = Theme.of(context).textTheme.bodyMedium?.color;
    return ClayButton(
      onTap: onTap,
      borderRadius: 22,
      depth: isSelected ? 0.5 : 0.8,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
      gradient: isSelected
          ? const LinearGradient(
              colors: [AppColors.primary, AppColors.grape],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: isSelected ? null : Clay.surface(context),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected ? Colors.white : textColor,
                  ),
                ),
                if (sublabel != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    sublabel!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white.withValues(alpha: 0.85)
                          : subColor,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _Indicator(selected: isSelected, multi: multiSelect),
        ],
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final bool selected;
  final bool multi;

  const _Indicator({required this.selected, required this.multi});

  @override
  Widget build(BuildContext context) {
    if (selected) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: multi ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: multi ? BorderRadius.circular(7) : null,
        ),
        child: const Icon(Icons.check_rounded,
            size: 17, color: AppColors.primary),
      );
    }
    final borderColor =
        Theme.of(context).dividerTheme.color ?? AppColors.inputBorder;
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: multi ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: multi ? BorderRadius.circular(7) : null,
        border: Border.all(color: borderColor, width: 1.6),
      ),
    );
  }
}

/// Pre-built single-select list.
class SingleSelectList extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onSelect;

  const SingleSelectList({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final opt in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: OptionTile(
              label: opt,
              isSelected: selected == opt,
              onTap: () => onSelect(opt),
            ),
          ),
      ],
    );
  }
}

/// Pre-built multi-select list.
class MultiSelectList extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<List<String>> onChange;
  final int? maxSelections;

  const MultiSelectList({
    super.key,
    required this.options,
    required this.selected,
    required this.onChange,
    this.maxSelections,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final opt in options)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: OptionTile(
              label: opt,
              isSelected: selected.contains(opt),
              multiSelect: true,
              onTap: () {
                final list = [...selected];
                if (list.contains(opt)) {
                  list.remove(opt);
                } else {
                  if (maxSelections != null &&
                      list.length >= maxSelections!) {
                    return;
                  }
                  list.add(opt);
                }
                onChange(list);
              },
            ),
          ),
      ],
    );
  }
}
