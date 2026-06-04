import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class RelationshipTypeScreen extends ConsumerWidget {
  const RelationshipTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedKey = ref.watch(onboardingProvider).relationshipType;

    void next() =>
        context.push(OnboardingSteps.next('/onboarding/relationship')!);

    return OnboardingScaffold(
      title: 'What type of\nrelationship are\nyou looking for?',
      subtitle: 'Select all that apply.',
      progress: OnboardingSteps.progress('/onboarding/relationship'),
      useCircleNext: true,
      onNext: next,
      onSkip: next,
      child: SingleSelectList(
        options: RelationshipType.displayLabels,
        selected: RelationshipType.labels[selectedKey],
        onSelect: (label) {
          final key = RelationshipType.labels.entries
              .firstWhere((e) => e.value == label)
              .key;
          ref.read(onboardingProvider.notifier).setRelationshipType(key);
        },
      ),
    );
  }
}
