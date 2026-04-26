import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/text_input_page.dart';

class WorkplaceScreen extends ConsumerWidget {
  const WorkplaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextInputPage(
      title: 'Where do you work?',
      hint: 'Workplace (e.g. Acme Corp)',
      initialValue: ref.read(onboardingProvider).workplace,
      progress: OnboardingSteps.progress('/onboarding/workplace'),
      optional: true,
      onSubmit: (v) =>
          ref.read(onboardingProvider.notifier).setWorkplace(v),
      onNext: () =>
          context.push(OnboardingSteps.next('/onboarding/workplace')!),
    );
  }
}
