import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class IntentionsScreen extends ConsumerWidget {
  const IntentionsScreen({super.key});

  static const _options = [
    'Life partner',
    'Long-term relationship',
    'Long-term, open to short',
    'Short-term, open to long',
    'Short-term fun',
    'New friends',
    'Still figuring it out',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).datingIntentions;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/intentions')!);

    return OnboardingScaffold(
      title: 'What are your dating intentions?',
      subtitle: 'Be upfront — it helps you find the right match.',
      progress: OnboardingSteps.progress('/onboarding/intentions'),
      onNext: selected != null ? next : null,
      child: SingleSelectList(
        options: _options,
        selected: selected,
        onSelect: (v) =>
            ref.read(onboardingProvider.notifier).setDatingIntentions(v),
      ),
    );
  }
}
