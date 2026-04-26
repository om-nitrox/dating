import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class ReligionScreen extends ConsumerWidget {
  const ReligionScreen({super.key});

  static const _options = [
    'Agnostic',
    'Atheist',
    'Buddhist',
    'Catholic',
    'Christian',
    'Hindu',
    'Jewish',
    'Muslim',
    'Sikh',
    'Spiritual',
    'Other',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).religion;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/religion')!);

    return OnboardingScaffold(
      title: 'What are your religious beliefs?',
      progress: OnboardingSteps.progress('/onboarding/religion'),
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: _options,
        selected: selected,
        onSelect: (v) =>
            ref.read(onboardingProvider.notifier).setReligion(v),
      ),
    );
  }
}
