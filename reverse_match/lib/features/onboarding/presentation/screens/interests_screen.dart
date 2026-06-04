import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class InterestsScreen extends ConsumerWidget {
  const InterestsScreen({super.key});

  static const _maxSelections = 10;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).interests;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/interests')!);

    return OnboardingScaffold(
      title: 'What are you\ninto?',
      subtitle: 'Pick up to $_maxSelections — these help us find your matches.',
      progress: OnboardingSteps.progress('/onboarding/interests'),
      onNext: next,
      onSkip: next,
      child: MultiSelectList(
        options: Interests.options,
        selected: selected,
        maxSelections: _maxSelections,
        onChange: (list) =>
            ref.read(onboardingProvider.notifier).setInterests(list),
      ),
    );
  }
}
