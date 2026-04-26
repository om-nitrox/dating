import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class DatingPreferenceScreen extends ConsumerWidget {
  const DatingPreferenceScreen({super.key});

  static const _options = ['Men', 'Women', 'Everyone'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider).datingPreference;

    return OnboardingScaffold(
      title: 'Who would you like to date?',
      subtitle: "We'll show you profiles based on your selection.",
      progress: OnboardingSteps.progress('/onboarding/dating-pref'),
      onNext: selected != null
          ? () =>
              context.push(OnboardingSteps.next('/onboarding/dating-pref')!)
          : null,
      child: SingleSelectList(
        options: _options,
        selected: selected,
        onSelect: (v) =>
            ref.read(onboardingProvider.notifier).setDatingPreference(v),
      ),
    );
  }
}
