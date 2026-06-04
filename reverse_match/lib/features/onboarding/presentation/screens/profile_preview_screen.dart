import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../onboarding_steps.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

/// Hinge "Here's how some of what you share will appear" preview card.
/// Shown after the location step so the user can see what's already filled
/// in vs what comes next.
class ProfilePreviewScreen extends ConsumerWidget {
  const ProfilePreviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(onboardingProvider);
    final name = data.firstName.isEmpty ? '—' : data.firstName;
    final age = data.age?.toString() ?? '—';
    final city = data.city ?? '—';

    return OnboardingScaffold(
      title: "Here's how some of\nwhat you share will\nappear.",
      progress: OnboardingSteps.progress('/onboarding/preview-card'),
      onNext: () =>
          context.push(OnboardingSteps.next('/onboarding/preview-card')!),
      child: Material(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.inputBorder, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Column(
            children: [
              _PreviewRow(
                icon: Icons.person_outline,
                label: name,
                filled: data.firstName.isNotEmpty,
              ),
              _PreviewRow(
                icon: Icons.cake_outlined,
                label: age,
                filled: data.dob != null,
              ),
              _PreviewRow(
                icon: Icons.location_on_outlined,
                label: city,
                filled: data.city != null,
              ),
              _PreviewRow(
                icon: Icons.home_outlined,
                label: 'Your hometown',
                filled: false,
              ),
              _PreviewRow(
                icon: Icons.search,
                label: "Connections you're open to",
                filled: false,
              ),
              _PreviewRow(
                icon: Icons.group_outlined,
                label: 'Your relationship type',
                filled: false,
                last: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool last;

  const _PreviewRow({
    required this.icon,
    required this.label,
    required this.filled,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: filled ? AppColors.surface : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: filled ? AppColors.inputBorder : Colors.transparent,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: filled ? AppColors.textPrimary : AppColors.textHint,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      filled ? FontWeight.w600 : FontWeight.w400,
                  color:
                      filled ? AppColors.textPrimary : AppColors.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
