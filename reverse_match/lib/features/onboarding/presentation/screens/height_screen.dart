import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class HeightScreen extends ConsumerStatefulWidget {
  const HeightScreen({super.key});

  @override
  ConsumerState<HeightScreen> createState() => _HeightScreenState();
}

class _HeightScreenState extends ConsumerState<HeightScreen> {
  int _cm = 170;
  bool _metric = false;

  @override
  void initState() {
    super.initState();
    _cm = ref.read(onboardingProvider).heightCm ?? 170;
  }

  String get _display {
    if (_metric) return '$_cm cm';
    final totalIn = (_cm / 2.54).round();
    final ft = totalIn ~/ 12;
    final inch = totalIn % 12;
    return '$ft\' $inch"';
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'How tall are you?',
      subtitle: "This appears on your profile.",
      progress: OnboardingSteps.progress('/onboarding/height'),
      onNext: () {
        ref.read(onboardingProvider.notifier).setHeight(_cm);
        context.push(OnboardingSteps.next('/onboarding/height')!);
      },
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _unitChip('ft/in', !_metric, () => setState(() => _metric = false)),
                _unitChip('cm', _metric, () => setState(() => _metric = true)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          Text(
            _display,
            style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Slider(
            value: _cm.toDouble(),
            min: 140,
            max: 220,
            divisions: 80,
            activeColor: AppColors.primary,
            onChanged: (v) => setState(() => _cm = v.round()),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('4\'7"',
                    style: TextStyle(color: AppColors.textSecondary)),
                Text('7\'3"',
                    style: TextStyle(color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitChip(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
