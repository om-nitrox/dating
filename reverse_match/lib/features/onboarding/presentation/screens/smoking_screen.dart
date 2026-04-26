import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class SmokingScreen extends ConsumerWidget {
  const SmokingScreen({super.key});

  static const _options = [
    'Yes',
    'Sometimes',
    'Rarely',
    'No',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).smoking;
    void next() =>
        context.push(OnboardingSteps.next('/onboarding/smoking')!);

    return OnboardingScaffold(
      title: 'Do you smoke?',
      progress: OnboardingSteps.progress('/onboarding/smoking'),
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: _options,
        selected: selected,
        onSelect: (v) =>
            ref.read(onboardingProvider.notifier).setSmoking(v),
      ),
    );
  }
}
