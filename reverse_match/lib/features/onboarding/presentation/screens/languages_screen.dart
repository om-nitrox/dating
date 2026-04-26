import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class LanguagesScreen extends ConsumerWidget {
  const LanguagesScreen({super.key});

  static const _options = [
    'English',
    'Hindi',
    'Spanish',
    'French',
    'German',
    'Mandarin',
    'Arabic',
    'Portuguese',
    'Russian',
    'Japanese',
    'Korean',
    'Italian',
    'Bengali',
    'Tamil',
    'Other',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).languages;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/languages')!);

    return OnboardingScaffold(
      title: 'Which languages do you speak?',
      subtitle: 'Select up to 5.',
      progress: OnboardingSteps.progress('/onboarding/languages'),
      onNext: next,
      onSkip: next,
      child: MultiSelectList(
        options: _options,
        selected: selected,
        maxSelections: 5,
        onChange: (list) =>
            ref.read(onboardingProvider.notifier).setLanguages(list),
      ),
    );
  }
}
