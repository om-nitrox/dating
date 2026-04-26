import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class FamilyPlansScreen extends ConsumerWidget {
  const FamilyPlansScreen({super.key});

  static const _options = [
    'Want children',
    "Don't want children",
    'Open to children',
    'Not sure yet',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).familyPlans;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/family-plans')!);

    return OnboardingScaffold(
      title: 'Do you want children?',
      progress: OnboardingSteps.progress('/onboarding/family-plans'),
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: _options,
        selected: selected,
        onSelect: (v) =>
            ref.read(onboardingProvider.notifier).setFamilyPlans(v),
      ),
    );
  }
}
