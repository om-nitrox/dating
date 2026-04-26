import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class RelationshipTypeScreen extends ConsumerWidget {
  const RelationshipTypeScreen({super.key});

  static const _options = [
    'Monogamy',
    'Non-monogamy',
    'Open to exploring',
    'Prefer not to say',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).relationshipType;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/relationship')!);

    return OnboardingScaffold(
      title: 'What kind of relationship are you looking for?',
      progress: OnboardingSteps.progress('/onboarding/relationship'),
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: _options,
        selected: selected,
        onSelect: (v) =>
            ref.read(onboardingProvider.notifier).setRelationshipType(v),
      ),
    );
  }
}
