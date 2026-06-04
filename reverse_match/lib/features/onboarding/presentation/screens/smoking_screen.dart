import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class SmokingScreen extends ConsumerWidget {
  const SmokingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(onboardingProvider).smoking;
    void next() =>
        context.push(OnboardingSteps.next('/onboarding/smoking')!);

    return OnboardingScaffold(
      title: 'Do you smoke?',
      progress: OnboardingSteps.progress('/onboarding/smoking'),
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
          ref.read(onboardingProvider.notifier).setSmoking(key);
        },
      ),
    );
  }
}
