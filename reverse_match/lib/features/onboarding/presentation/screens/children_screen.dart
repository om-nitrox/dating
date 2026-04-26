import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  static const _options = [
    "Don't have children",
    'Have children',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).children;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/children')!);

    return OnboardingScaffold(
      title: 'Do you have children?',
      progress: OnboardingSteps.progress('/onboarding/children'),
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: _options,
        selected: selected,
        onSelect: (v) =>
            ref.read(onboardingProvider.notifier).setChildren(v),
      ),
    );
  }
}
