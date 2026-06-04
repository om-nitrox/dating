import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class FamilyPlansScreen extends ConsumerWidget {
  const FamilyPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(onboardingProvider).familyPlans;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/family-plans')!);

    return OnboardingScaffold(
      title: 'Do you want\nchildren?',
      progress: OnboardingSteps.progress('/onboarding/family-plans'),
      useCircleNext: true,
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: FamilyPlans.displayLabels,
        selected: FamilyPlans.labels[selectedKey],
        onSelect: (label) {
          final key = FamilyPlans.labels.entries
              .firstWhere((e) => e.value == label)
              .key;
          ref.read(onboardingProvider.notifier).setFamilyPlans(key);
        },
      ),
    );
  }
}
