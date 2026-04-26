import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class EthnicityScreen extends ConsumerWidget {
  const EthnicityScreen({super.key});

  static const _options = [
    'Asian',
    'Black/African Descent',
    'Hispanic/Latino',
    'Middle Eastern',
    'Native American',
    'Pacific Islander',
    'South Asian',
    'White/Caucasian',
    'Other',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).ethnicity;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/ethnicity')!);

    return OnboardingScaffold(
      title: 'What is your ethnicity?',
      subtitle: 'Select up to 3. This is optional.',
      progress: OnboardingSteps.progress('/onboarding/ethnicity'),
      onNext: next,
      onSkip: next,
      child: MultiSelectList(
        options: _options,
        selected: selected,
        maxSelections: 3,
        onChange: (list) =>
            ref.read(onboardingProvider.notifier).setEthnicity(list),
      ),
    );
  }
}
