import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class PreviewScreen extends ConsumerWidget {
  const PreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(onboardingProvider);
    final age = data.age;

    return OnboardingScaffold(
      title: 'Your profile',
      subtitle: "Here's how others will see you. You can edit anytime.",
      progress: OnboardingSteps.progress('/onboarding/preview'),
      nextLabel: 'Looks good',
      onNext: () =>
          context.push(OnboardingSteps.next('/onboarding/preview')!),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.photos.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: Image.file(data.photos.first,
                    fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            data.firstName.isNotEmpty ? data.firstName : 'You',
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700),
          ),
          if (age != null || data.city != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (age != null) age.toString(),
                if (data.city != null && data.city!.isNotEmpty) data.city,
              ].join(' • '),
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 20),
          _chipWrap([
            if (data.heightCm != null) _formatHeight(data.heightCm!),
            if (data.jobTitle.isNotEmpty) data.jobTitle,
            if (data.education.isNotEmpty) data.education,
            if (data.hometown.isNotEmpty) 'From ${data.hometown}',
            if (data.religion != null) data.religion!,
            if (data.datingIntentions != null) data.datingIntentions!,
          ]),
          const SizedBox(height: 20),
          for (final p in data.prompts) _promptCard(p.question, p.answer),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: const [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'You can edit any of this later from your profile tab.',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _chipWrap(List<String> items) {
    final visible = items.where((s) => s.isNotEmpty).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in visible)
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: Text(s,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ),
      ],
    );
  }

  Widget _promptCard(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(q,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text(a,
              style: const TextStyle(fontSize: 16, height: 1.4)),
        ],
      ),
    );
  }

  String _formatHeight(int cm) {
    final totalIn = (cm / 2.54).round();
    final ft = totalIn ~/ 12;
    final inch = totalIn % 12;
    return "$ft' $inch\"";
  }
}
