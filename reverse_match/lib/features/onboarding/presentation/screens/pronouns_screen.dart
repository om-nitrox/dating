import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class PronounsScreen extends ConsumerWidget {
  const PronounsScreen({super.key});

  static const _options = ['he/him', 'she/her', 'they/them', 'ze/zir', 'other'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).pronouns;

    void next() => context.push(OnboardingSteps.next('/onboarding/pronouns')!);

    return OnboardingScaffold(
      title: 'What are your pronouns?',
      subtitle: 'Select up to 3. This is optional.',
      progress: OnboardingSteps.progress('/onboarding/pronouns'),
      onNext: next,
      onSkip: next,
      child: MultiSelectList(
        options: _options,
        selected: selected,
        maxSelections: 3,
        onChange: (list) =>
            ref.read(onboardingProvider.notifier).setPronouns(list),
      ),
    );
  }
}
