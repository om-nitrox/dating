import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/text_input_page.dart';

class JobScreen extends ConsumerWidget {
  const JobScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextInputPage(
      title: 'What do you do for work?',
      subtitle: "We'll show this on your profile.",
      hint: 'Job title (e.g. Product Designer)',
      initialValue: ref.read(onboardingProvider).jobTitle,
      progress: OnboardingSteps.progress('/onboarding/job'),
      optional: true,
      onSubmit: (v) =>
          ref.read(onboardingProvider.notifier).setJobTitle(v),
      onNext: () => context.push(OnboardingSteps.next('/onboarding/job')!),
    );
  }
}
