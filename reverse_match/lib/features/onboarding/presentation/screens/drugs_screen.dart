import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class DrugsScreen extends ConsumerWidget {
  const DrugsScreen({super.key});

  static const _options = [
    'Yes',
    'Sometimes',
    'Rarely',
    'No',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).drugs;
    void next() =>
        context.push(OnboardingSteps.next('/onboarding/drugs')!);

    return OnboardingScaffold(
      title: 'Do you use drugs?',
      progress: OnboardingSteps.progress('/onboarding/drugs'),
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: _options,
        selected: selected,
        onSelect: (v) =>
            ref.read(onboardingProvider.notifier).setDrugs(v),
      ),
    );
  }
}
