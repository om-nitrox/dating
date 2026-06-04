import 'package:flutter/material.dart';

import '../../../../core/constants/taxonomies.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/discovery_filters.dart';

/// Bottom sheet for editing discovery filters (Age, Height, Looking for).
/// Returns the edited [DiscoveryFilters] via `Navigator.pop`, or null if
/// dismissed without applying.
class FilterSheet extends StatefulWidget {
  final DiscoveryFilters initial;
  const FilterSheet({super.key, required this.initial});

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late RangeValues _age;
  late bool _heightOn;
  late RangeValues _height;
  String? _intent;

  @override
  void initState() {
    super.initState();
    final f = widget.initial;
    _age = RangeValues(
      f.ageMin.toDouble().clamp(
          DiscoveryFilters.ageFloor.toDouble(), DiscoveryFilters.ageCeil.toDouble()),
      f.ageMax.toDouble().clamp(
          DiscoveryFilters.ageFloor.toDouble(), DiscoveryFilters.ageCeil.toDouble()),
    );
    _heightOn = f.hasHeight;
    _height = RangeValues(
      (f.heightMin ?? 160).toDouble(),
      (f.heightMax ?? 190).toDouble(),
    );
    _intent = f.intent;
  }

  void _reset() {
    setState(() {
      _age = const RangeValues(18, 50);
      _heightOn = false;
      _height = const RangeValues(160, 190);
      _intent = null;
    });
  }

  void _apply() {
    final filters = DiscoveryFilters(
      ageMin: _age.start.round(),
      ageMax: _age.end.round(),
      heightMin: _heightOn ? _height.start.round() : null,
      heightMax: _heightOn ? _height.end.round() : null,
      intent: _intent,
    );
    Navigator.of(context).pop(filters);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Grab handle
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Row(
                children: [
                  Text('Filters', style: AppTheme.serifHeading(fontSize: 24)),
                  const Spacer(),
                  TextButton(
                    onPressed: _reset,
                    child: const Text('Clear all'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ---- Age ----
              _SectionLabel(
                title: 'Age',
                value: '${_age.start.round()} – ${_age.end.round()}',
              ),
              RangeSlider(
                values: _age,
                min: DiscoveryFilters.ageFloor.toDouble(),
                max: DiscoveryFilters.ageCeil.toDouble(),
                divisions:
                    DiscoveryFilters.ageCeil - DiscoveryFilters.ageFloor,
                activeColor: AppColors.primary,
                inactiveColor: AppColors.surfaceVariant,
                labels: RangeLabels(
                  '${_age.start.round()}',
                  '${_age.end.round()}',
                ),
                onChanged: (v) => setState(() => _age = v),
              ),
              const SizedBox(height: 12),

              // ---- Height ----
              Row(
                children: [
                  Expanded(
                    child: _SectionLabel(
                      title: 'Height',
                      value: _heightOn
                          ? '${DiscoveryFilters.formatCm(_height.start.round())}  –  ${DiscoveryFilters.formatCm(_height.end.round())}'
                          : 'Any',
                    ),
                  ),
                  Switch(
                    value: _heightOn,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) => setState(() => _heightOn = v),
                  ),
                ],
              ),
              if (_heightOn)
                RangeSlider(
                  values: _height,
                  min: DiscoveryFilters.heightFloor.toDouble(),
                  max: DiscoveryFilters.heightCeil.toDouble(),
                  divisions:
                      DiscoveryFilters.heightCeil - DiscoveryFilters.heightFloor,
                  activeColor: AppColors.primary,
                  inactiveColor: AppColors.surfaceVariant,
                  labels: RangeLabels(
                    '${_height.start.round()} cm',
                    '${_height.end.round()} cm',
                  ),
                  onChanged: (v) => setState(() => _height = v),
                ),
              const SizedBox(height: 16),

              // ---- Dating intentions ----
              const _SectionLabel(title: 'Looking for'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _intentChip('Any', null),
                  for (final key in DatingIntentions.keys)
                    _intentChip(DatingIntentions.labels[key]!, key),
                ],
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _apply,
                  child: const Text('Show results'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _intentChip(String label, String? key) {
    final selected = _intent == key;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      backgroundColor: AppColors.surface,
      selectedColor: AppColors.primary,
      side: BorderSide(
        color: selected ? AppColors.primary : AppColors.divider,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      onSelected: (_) => setState(() => _intent = key),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String? value;
  const _SectionLabel({required this.title, this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        if (value != null)
          Flexible(
            child: Text(
              value!,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
      ],
    );
  }
}
