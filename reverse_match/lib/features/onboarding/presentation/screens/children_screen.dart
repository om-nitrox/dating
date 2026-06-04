import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class ChildrenScreen extends ConsumerWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(onboardingProvider).children;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/children')!);

    return OnboardingScaffold(
      title: 'Do you have\nchildren?',
      progress: OnboardingSteps.progress('/onboarding/children'),
      useCircleNext: true,
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: Children.displayLabels,
        selected: Children.labels[selectedKey],
        onSelect: (label) {
          final key = Children.labels.entries
              .firstWhere((e) => e.value == label)
              .key;
          ref.read(onboardingProvider.notifier).setChildren(key);
        },
      ),
    );
  }
}
