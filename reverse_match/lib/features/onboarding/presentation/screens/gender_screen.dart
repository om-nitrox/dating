import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class GenderScreen extends ConsumerWidget {
  const GenderScreen({super.key});

  static const _options = {
    'male': 'Man',
    'female': 'Woman',
    'nonbinary': 'Non-binary',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).gender;

    return OnboardingScaffold(
      title: 'Which gender best describes you?',
      subtitle: 'This helps us match you with the right people.',
      progress: OnboardingSteps.progress('/onboarding/gender'),
      onNext: selected != null
          ? () => context.push(OnboardingSteps.next('/onboarding/gender')!)
          : null,
      child: SingleSelectList(
        options: _options.values.toList(),
        selected: _options[selected],
        onSelect: (label) {
          final key =
              _options.entries.firstWhere((e) => e.value == label).key;
          ref.read(onboardingProvider.notifier).setGender(key);
        },
      ),
    );
  }
}
