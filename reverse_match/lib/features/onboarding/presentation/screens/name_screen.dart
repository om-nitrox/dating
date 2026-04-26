import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        TextEditingController(text: ref.read(onboardingProvider).firstName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final name = _controller.text.trim();
    final canProceed = name.length >= 2;

    return OnboardingScaffold(
      title: "What's your first name?",
      subtitle: "This is how you'll appear on Reverse Match.",
      whyText:
          'We use your first name to personalize your profile. You can only change this later by contacting support.',
      progress: OnboardingSteps.progress('/onboarding/name'),
      onNext: canProceed
          ? () {
              ref
                  .read(onboardingProvider.notifier)
                  .setFirstName(_controller.text.trim());
              context.push(OnboardingSteps.next('/onboarding/name')!);
            }
          : null,
      child: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(
            fontSize: 22, fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
          hintText: 'First name',
          hintStyle: TextStyle(color: AppColors.textHint),
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.divider, width: 1),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }
}
