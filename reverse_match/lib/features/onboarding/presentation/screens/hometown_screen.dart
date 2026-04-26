import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/text_input_page.dart';

class HometownScreen extends ConsumerWidget {
  const HometownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextInputPage(
      title: 'Where are you from?',
      subtitle: 'Your hometown appears on your profile.',
      hint: 'Hometown',
      initialValue: ref.read(onboardingProvider).hometown,
      progress: OnboardingSteps.progress('/onboarding/hometown'),
      optional: true,
      onSubmit: (v) =>
          ref.read(onboardingProvider.notifier).setHometown(v),
      onNext: () =>
          context.push(OnboardingSteps.next('/onboarding/hometown')!),
    );
  }
}
