import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Hinge-style selectable row — large, minimal, with a radio/check on the right.
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
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
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(sublabel!,
                        style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                multiSelect ? Icons.check_box : Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              )
            else
              Icon(
                multiSelect
                    ? Icons.check_box_outline_blank
                    : Icons.radio_button_unchecked,
                color: AppColors.textHint,
                size: 24,
              ),
          ],
        ),
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
            padding: const EdgeInsets.only(bottom: 10),
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
            padding: const EdgeInsets.only(bottom: 10),
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
