import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class PoliticsScreen extends ConsumerWidget {
  const PoliticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(onboardingProvider).politics;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/politics')!);

    return OnboardingScaffold(
      title: 'What are your\npolitics?',
      progress: OnboardingSteps.progress('/onboarding/politics'),
      useCircleNext: true,
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: Politics.displayLabels,
        selected: Politics.labels[selectedKey],
        onSelect: (label) {
          final key = Politics.labels.entries
              .firstWhere((e) => e.value == label)
              .key;
          ref.read(onboardingProvider.notifier).setPolitics(key);
        },
      ),
    );
  }
}
