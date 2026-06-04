import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';
import '../widgets/option_tile.dart';

class PronounsScreen extends ConsumerWidget {
  const PronounsScreen({super.key});

  static const _options = [
    'she',
    'her',
    'hers',
    'he',
    'him',
    'his',
    'they',
    'them',
    'theirs',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(onboardingProvider);
    final selected = data.pronouns;

    void next() => context.push(OnboardingSteps.next('/onboarding/pronouns')!);

    return OnboardingScaffold(
      title: 'What are your\npronouns?',
      subtitle: 'Optional. Pick up to 4 that feel right.',
      progress: OnboardingSteps.progress('/onboarding/pronouns'),
      useCircleNext: true,
      visibility: OnboardingVisibility(
        visible: data.pronounsVisible,
        onChanged: (v) =>
            ref.read(onboardingProvider.notifier).setPronounsVisible(v),
      ),
      onNext: next,
      onSkip: next,
      child: Column(
        children: [
          MultiSelectList(
            options: _options,
            selected: selected,
            maxSelections: 4,
            onChange: (list) =>
                ref.read(onboardingProvider.notifier).setPronouns(list),
          ),
          if (selected.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: selected
                  .map((p) => _PronounChip(
                        label: p,
                        onRemove: () {
                          final list = [...selected]..remove(p);
                          ref
                              .read(onboardingProvider.notifier)
                              .setPronouns(list);
                        },
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _PronounChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _PronounChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.pill,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onRemove,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.close, size: 14, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
