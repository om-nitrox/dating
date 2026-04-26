import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class PoliticsScreen extends ConsumerWidget {
  const PoliticsScreen({super.key});

  static const _options = [
    'Liberal',
    'Moderate',
    'Conservative',
    'Not political',
    'Other',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).politics;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/politics')!);

    return OnboardingScaffold(
      title: 'What are your politics?',
      progress: OnboardingSteps.progress('/onboarding/politics'),
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: _options,
        selected: selected,
        onSelect: (v) =>
            ref.read(onboardingProvider.notifier).setPolitics(v),
      ),
    );
  }
}
