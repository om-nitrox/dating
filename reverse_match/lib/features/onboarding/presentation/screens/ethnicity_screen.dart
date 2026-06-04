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
    'Black/African Descent',
    'East Asian',
    'Hispanic/Latino',
    'Middle Eastern',
    'Native American',
    'Pacific Islander',
    'South Asian',
    'Southeast Asian',
    'White/Caucasian',
    'Other',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(onboardingProvider);
    final selected = data.ethnicity;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/ethnicity')!);

    return OnboardingScaffold(
      title: 'How would you\ndescribe your ethnicity?',
      subtitle: 'Select all that apply.',
      progress: OnboardingSteps.progress('/onboarding/ethnicity'),
      useCircleNext: true,
      visibility: OnboardingVisibility(
        visible: data.ethnicityVisible,
        onChanged: (v) =>
            ref.read(onboardingProvider.notifier).setEthnicityVisible(v),
      ),
      onNext: next,
      onSkip: next,
      child: MultiSelectList(
        options: _options,
        selected: selected,
        onChange: (list) =>
            ref.read(onboardingProvider.notifier).setEthnicity(list),
      ),
    );
  }
}
