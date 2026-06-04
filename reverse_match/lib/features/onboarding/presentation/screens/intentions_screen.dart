import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class IntentionsScreen extends ConsumerWidget {
  const IntentionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(onboardingProvider).datingIntentions;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/intentions')!);

    return OnboardingScaffold(
      title: 'What kind of\nconnection are\nyou open to?',
      progress: OnboardingSteps.progress('/onboarding/intentions'),
      useCircleNext: true,
      onNext: selectedKey != null ? next : null,
      onSkip: next,
      child: SingleSelectList(
        options: DatingIntentions.displayLabels,
        selected: DatingIntentions.labels[selectedKey],
        onSelect: (label) {
          final key = DatingIntentions.labels.entries
              .firstWhere((e) => e.value == label)
              .key;
          ref.read(onboardingProvider.notifier).setDatingIntentions(key);
        },
      ),
    );
  }
}
