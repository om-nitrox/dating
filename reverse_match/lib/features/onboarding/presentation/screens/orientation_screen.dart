import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class OrientationScreen extends ConsumerWidget {
  const OrientationScreen({super.key});

  static const _options = [
    'Straight',
    'Gay',
    'Lesbian',
    'Bisexual',
    'Asexual',
    'Demisexual',
    'Pansexual',
    'Queer',
    'Questioning',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).orientation;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/orientation')!);

    return OnboardingScaffold(
      title: 'What is your sexual orientation?',
      subtitle: 'Select up to 3. This is optional.',
      progress: OnboardingSteps.progress('/onboarding/orientation'),
      onNext: next,
      onSkip: next,
      child: MultiSelectList(
        options: _options,
        selected: selected,
        maxSelections: 3,
        onChange: (list) =>
            ref.read(onboardingProvider.notifier).setOrientation(list),
      ),
    );
  }
}
