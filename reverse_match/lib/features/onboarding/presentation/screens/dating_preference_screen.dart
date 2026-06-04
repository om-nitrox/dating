import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/taxonomies.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

/// Hinge: "Who are you open to dating?" — closed enum on the backend
/// (men / women / everyone). Stored as a backend key in onboarding state.
class DatingPreferenceScreen extends ConsumerWidget {
  const DatingPreferenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(onboardingProvider);
    final selectedKey = data.datingPreference;
    final selectedLabel = GenderPreference.labels[selectedKey];
    final selectedList =
        selectedLabel == null ? <String>[] : [selectedLabel];

    return OnboardingScaffold(
      title: 'Who are you\nopen to dating?',
      subtitle: 'Select all that apply.',
      progress: OnboardingSteps.progress('/onboarding/dating-pref'),
      useCircleNext: true,
      visibility: OnboardingVisibility(
        visible: data.datingPreferenceVisible,
        onChanged: (v) => ref
            .read(onboardingProvider.notifier)
            .setDatingPreferenceVisible(v),
      ),
      onNext: selectedKey != null
          ? () =>
              context.push(OnboardingSteps.next('/onboarding/dating-pref')!)
          : null,
      child: MultiSelectList(
        options: GenderPreference.displayLabels,
        selected: selectedList,
        maxSelections: 1,
        onChange: (list) {
          if (list.isEmpty) return;
          final key = GenderPreference.labels.entries
              .firstWhere((e) => e.value == list.first)
              .key;
          ref.read(onboardingProvider.notifier).setDatingPreference(key);
        },
      ),
    );
  }
}
