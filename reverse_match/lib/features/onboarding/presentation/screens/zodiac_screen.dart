import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class ZodiacScreen extends ConsumerWidget {
  const ZodiacScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(onboardingProvider).zodiac;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/zodiac')!);

    return OnboardingScaffold(
      title: "What's your\nzodiac sign?",
      progress: OnboardingSteps.progress('/onboarding/zodiac'),
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: Zodiac.displayLabels,
        selected: Zodiac.labels[selectedKey],
        onSelect: (label) {
          final key =
              Zodiac.labels.entries.firstWhere((e) => e.value == label).key;
          ref.read(onboardingProvider.notifier).setZodiac(key);
        },
      ),
    );
  }
}
