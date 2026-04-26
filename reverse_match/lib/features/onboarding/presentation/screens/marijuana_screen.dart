import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class MarijuanaScreen extends ConsumerWidget {
  const MarijuanaScreen({super.key});

  static const _options = [
    'Yes',
    'Sometimes',
    'Rarely',
    'No',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).marijuana;
    void next() =>
        context.push(OnboardingSteps.next('/onboarding/marijuana')!);

    return OnboardingScaffold(
      title: 'Do you use marijuana?',
      progress: OnboardingSteps.progress('/onboarding/marijuana'),
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: _options,
        selected: selected,
        onSelect: (v) =>
            ref.read(onboardingProvider.notifier).setMarijuana(v),
      ),
    );
  }
}
