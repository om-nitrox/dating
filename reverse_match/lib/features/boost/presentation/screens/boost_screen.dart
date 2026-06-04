import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/clay.dart';
import '../../data/boost_repository.dart';

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

class BoostScreen extends ConsumerStatefulWidget {
  const BoostScreen({super.key});

  @override
  ConsumerState<BoostScreen> createState() => _BoostScreenState();
}

class _BoostScreenState extends ConsumerState<BoostScreen> {
  String? _selectedTier;
  bool _purchasing = false;

  Future<void> _purchase() async {
    if (_selectedTier == null) return;
    setState(() => _purchasing = true);

    final repo = ref.read(boostRepositoryProvider);
    final result = await repo.purchase(_selectedTier!);

    if (!mounted) return;
    setState(() => _purchasing = false);

    switch (result) {
      case Success(:final data):
        final url = data;
        if (url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else if (mounted) {
            context.showSnackBar('Could not open payment page',
                isError: true);
          }
        }
      case Failure(:final exception):
        if (mounted) {
          context.showSnackBar(exception.message, isError: true);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final plansAsync = ref.watch(boostPlansProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onClose: () => context.pop()),
            Expanded(
              child: plansAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                ),
                error: (e, _) => _ErrorState(
                  message: e.toString(),
                  onRetry: () => ref.invalidate(boostPlansProvider),
                ),
                data: (plans) {
                  final ordered = [...plans]
                    ..sort((a, b) => a.price.compareTo(b.price));
                  _selectedTier ??= ordered
                      .firstWhere(
                        (p) => p.tier == 'silver',
                        orElse: () => ordered.first,
                      )
                      .tier;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      const _Benefits(),
                      const SizedBox(height: 24),
                      ...ordered.map((p) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _BoostCard(
                            plan: p,
                            isSelected: _selectedTier == p.tier,
                            isPopular: p.tier == 'silver',
                            onTap: () =>
                                setState(() => _selectedTier = p.tier),
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      const _AutoBoostNote(),
                    ],
                  );
                },
              ),
            ),
            _CheckoutBar(
              plan: _planFor(plansAsync, _selectedTier),
              isLoading: _purchasing,
              onCheckout: _purchase,
            ),
          ],
        ),
      ),
    );
  }

  BoostPlan? _planFor(
      AsyncValue<List<BoostPlan>> plans, String? tier) {
    if (tier == null) return null;
    return plans.maybeWhen(
      data: (list) => list.firstWhere(
        (p) => p.tier == tier,
        orElse: () => list.first,
      ),
      orElse: () => null,
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onClose;

  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
          const Spacer(),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.flash_on_rounded,
                    color: Colors.white, size: 14),
                SizedBox(width: 4),
                Text(
                  'BOOST',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Benefits extends StatelessWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Get seen first.',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -0.6,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Boost puts your profile at the top of the feed so more people see you.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 18),
        _BenefitRow(
          icon: Icons.trending_up_rounded,
          color: AppColors.primary,
          text: 'Up to 10× more profile views',
        ),
        _BenefitRow(
          icon: Icons.favorite_rounded,
          color: AppColors.likeGreen,
          text: 'Higher chance of mutual matches',
        ),
        _BenefitRow(
          icon: Icons.flash_on_rounded,
          color: AppColors.warning,
          text: 'Instant boost — starts the second you pay',
        ),
      ],
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _BenefitRow({
    required this.icon,
    required this.color,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BoostCard extends StatelessWidget {
  final BoostPlan plan;
  final bool isSelected;
  final bool isPopular;
  final VoidCallback onTap;

  const _BoostCard({
    required this.plan,
    required this.isSelected,
    required this.isPopular,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tierTitle = plan.tier[0].toUpperCase() + plan.tier.substring(1);
    final hours = (plan.duration / 60).round();
    return ClayButton(
      onTap: onTap,
      borderRadius: 24,
      depth: isSelected ? 0.55 : 0.85,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.10)
          : Clay.surface(context),
      child: Row(
          mainAxisSize: MainAxisSize.max,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    plan.color,
                    plan.color.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: plan.color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.flash_on_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        tierTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (isPopular)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'POPULAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${hours == 0 ? plan.duration : hours} ${hours == 0 ? "min" : (hours == 1 ? "hour" : "hours")} of boost',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  plan.priceFormatted,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.divider,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 14,
                        )
                      : null,
                ),
              ],
            ),
          ],
        ),
    );
  }
}

class _AutoBoostNote extends StatelessWidget {
  const _AutoBoostNote();

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      pressed: true,
      borderRadius: 18,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          const Icon(Icons.card_giftcard_rounded,
              size: 20, color: AppColors.sunset),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Free auto-boost after 7 days without a match.',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final BoostPlan? plan;
  final bool isLoading;
  final VoidCallback onCheckout;

  const _CheckoutBar({
    required this.plan,
    required this.isLoading,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed:
                  (plan == null || isLoading) ? null : onCheckout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 1,
                shadowColor: AppColors.primary.withValues(alpha: 0.35),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.lock_rounded, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          plan != null
                              ? 'Continue — ${plan!.priceFormatted}'
                              : 'Choose a plan',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 64, color: AppColors.textHint),
            const SizedBox(height: 16),
            const Text(
              'Couldn\'t load plans',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
