import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class BioScreen extends ConsumerStatefulWidget {
  const BioScreen({super.key});

  @override
  ConsumerState<BioScreen> createState() => _BioScreenState();
}

class _BioScreenState extends ConsumerState<BioScreen> {
  static const _maxChars = 300;
  late final TextEditingController _ctl;

  @override
  void initState() {
    super.initState();
    _ctl = TextEditingController(text: ref.read(onboardingProvider).bio);
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _next() => context.push(OnboardingSteps.next('/onboarding/bio')!);

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Write a short\nbio',
      subtitle: 'Tell people what makes you, you. Optional.',
      progress: OnboardingSteps.progress('/onboarding/bio'),
      onSkip: _next,
      onNext: () {
        ref.read(onboardingProvider.notifier).setBio(_ctl.text.trim());
        _next();
      },
      child: TextField(
        controller: _ctl,
        autofocus: true,
        maxLines: 5,
        maxLength: _maxChars,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        decoration: const InputDecoration(
          hintText: 'e.g. Coffee-fuelled hiker who loves bad puns…',
          hintStyle: TextStyle(color: AppColors.textHint),
          border: UnderlineInputBorder(
            borderSide: BorderSide(color: AppColors.divider),
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
