import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/text_input_page.dart';

class EducationScreen extends ConsumerWidget {
  const EducationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextInputPage(
      title: 'Where did you study?',
      hint: 'School / University',
      initialValue: ref.read(onboardingProvider).education,
      progress: OnboardingSteps.progress('/onboarding/education'),
      optional: true,
      onSubmit: (v) =>
          ref.read(onboardingProvider.notifier).setEducation(v),
      onNext: () =>
          context.push(OnboardingSteps.next('/onboarding/education')!),
    );
  }
}
