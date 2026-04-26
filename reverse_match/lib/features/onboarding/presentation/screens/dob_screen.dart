import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class DobScreen extends ConsumerStatefulWidget {
  const DobScreen({super.key});

  @override
  ConsumerState<DobScreen> createState() => _DobScreenState();
}

class _DobScreenState extends ConsumerState<DobScreen> {
  DateTime? _dob;

  @override
  void initState() {
    super.initState();
    _dob = ref.read(onboardingProvider).dob;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 22, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1950),
      lastDate: DateTime(now.year - 18, now.month, now.day),
      helpText: 'Date of birth',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  int? _ageFromDob(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    var a = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      a--;
    }
    return a;
  }

  @override
  Widget build(BuildContext context) {
    final age = _ageFromDob(_dob);
    final canProceed = age != null && age >= 18;
    final dobStr = _dob == null
        ? 'Tap to select'
        : '${_dob!.day.toString().padLeft(2, '0')}/${_dob!.month.toString().padLeft(2, '0')}/${_dob!.year}';

    return OnboardingScaffold(
      title: "When's your birthday?",
      subtitle: 'You must be 18+ to use Reverse Match.',
      whyText:
          'We show your age on your profile, not your birthday. You must be 18 or older to continue.',
      progress: OnboardingSteps.progress('/onboarding/dob'),
      onNext: canProceed
          ? () {
              ref.read(onboardingProvider.notifier).setDob(_dob!);
              context.push(OnboardingSteps.next('/onboarding/dob')!);
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined,
                      color: AppColors.textSecondary),
                  const SizedBox(width: 14),
                  Text(dobStr,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  const Icon(Icons.chevron_right,
                      color: AppColors.textHint),
                ],
              ),
            ),
          ),
          if (age != null) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(
                  age >= 18 ? Icons.check_circle : Icons.error_outline,
                  color: age >= 18 ? AppColors.success : AppColors.error,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  age >= 18
                      ? "You'll appear as $age"
                      : "You must be at least 18",
                  style: TextStyle(
                    color: age >= 18 ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
