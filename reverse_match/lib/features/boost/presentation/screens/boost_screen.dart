import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/boost_repository.dart';

// `BoostPlan` previously lived in this file. It moved to
// `data/boost_repository.dart` (Phase 1.8). No external imports of it
// were found, so we don't re-export — new code should import from
// `data/boost_repository.dart` directly.

final boostPlansProvider =
    FutureProvider.autoDispose<List<BoostPlan>>((ref) async {
  final repo = ref.read(boostRepositoryProvider);
  final result = await repo.getPlans();
  switch (result) {
    case Success(:final data):
      return data;
    case Failure(:final exception):
      throw exception;
  }
});

class BoostScreen extends ConsumerWidget {
  const BoostScreen({super.key});

  Future<void> _purchaseBoost(
      BuildContext context, WidgetRef ref, String tier) async {
    final repo = ref.read(boostRepositoryProvider);
    final result = await repo.purchase(tier);
    switch (result) {
      case Success(:final data):
        final url = data;
        if (url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (context.mounted) {
              context.showSnackBar('Could not open payment page',
                  isError: true);
            }
          }
        }
      case Failure(:final exception):
        if (context.mounted) {
          context.showSnackBar(exception.message, isError: true);
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(boostPlansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Boost Your Profile')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.rocket_launch, size: 64, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text(
              'Get Seen by More People',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Boost your profile to appear higher in search results',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Expanded(
              child: plansAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Failed to load plans'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref.invalidate(boostPlansProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (plans) => Column(
                  children: plans.map((plan) {
                    final isPopular = plan.tier == 'silver';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _BoostCard(
                        title: plan.tier[0].toUpperCase() + plan.tier.substring(1),
                        subtitle: plan.label,
                        price: plan.priceFormatted,
                        color: plan.color,
                        isPopular: isPopular,
                        onTap: () => _purchaseBoost(context, ref, plan.tier),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Text(
              'Free auto-boost activates after 7 days without a match',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _BoostCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final Color color;
  final bool isPopular;
  final VoidCallback onTap;

  const _BoostCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.color,
    this.isPopular = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPopular ? AppColors.primary : AppColors.divider,
            width: isPopular ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withAlpha(50),
              child: Icon(Icons.bolt, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                      if (isPopular) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('Popular',
                              style:
                                  TextStyle(color: Colors.white, fontSize: 10)),
                        ),
                      ],
                    ],
                  ),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
            ),
            Text(price,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }
}
