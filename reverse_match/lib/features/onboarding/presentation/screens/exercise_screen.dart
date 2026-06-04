import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class ExerciseScreen extends ConsumerWidget {
  const ExerciseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(onboardingProvider).exercise;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/exercise')!);

    return OnboardingScaffold(
      title: 'Do you\nwork out?',
      progress: OnboardingSteps.progress('/onboarding/exercise'),
      useCircleNext: true,
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: Exercise.displayLabels,
        selected: Exercise.labels[selectedKey],
        onSelect: (label) {
          final key = Exercise.labels.entries
              .firstWhere((e) => e.value == label)
              .key;
          ref.read(onboardingProvider.notifier).setExercise(key);
        },
      ),
    );
  }
}
