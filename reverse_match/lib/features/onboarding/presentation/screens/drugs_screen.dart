import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class DrugsScreen extends ConsumerWidget {
  const DrugsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(onboardingProvider).drugs;
    void next() =>
        context.push(OnboardingSteps.next('/onboarding/drugs')!);

    return OnboardingScaffold(
      title: 'Do you use\ndrugs?',
      progress: OnboardingSteps.progress('/onboarding/drugs'),
      useCircleNext: true,
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: ViceLevels.displayLabels,
        selected: ViceLevels.labels[selectedKey],
        onSelect: (label) {
          final key = ViceLevels.labels.entries
              .firstWhere((e) => e.value == label)
              .key;
          ref.read(onboardingProvider.notifier).setDrugs(key);
        },
      ),
    );
  }
}
