import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  late final TextEditingController _firstCtl;
  late final FocusNode _firstFocus;

  @override
  void initState() {
    super.initState();
    final data = ref.read(onboardingProvider);
    _firstCtl = TextEditingController(text: data.firstName);
    _firstFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _firstFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _firstCtl.dispose();
    _firstFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final first = _firstCtl.text.trim();
    final canProceed = first.length >= 2;

    return OnboardingScaffold(
      title: "What's your\nname?",
      subtitle:
          "Reverse Match doesn't verify names or run background checks. We count on daters to be real with each other.",
      progress: OnboardingSteps.progress('/onboarding/name'),
      onNext: canProceed
          ? () {
              ref.read(onboardingProvider.notifier).setFirstName(first);
              context.push(OnboardingSteps.next('/onboarding/name')!);
            }
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _firstCtl,
            focusNode: _firstFocus,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'First name',
              hintText: 'Your first name',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'Only your first name is shown on your profile.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF55524C)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
