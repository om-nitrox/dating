import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../../home/data/swipe_repository.dart';
import '../../data/ideal_match_repository.dart';

class IdealMatchScreen extends ConsumerStatefulWidget {
  const IdealMatchScreen({super.key});

  @override
  ConsumerState<IdealMatchScreen> createState() => _IdealMatchScreenState();
}

class _IdealMatchScreenState extends ConsumerState<IdealMatchScreen> {
  bool _loadingStatus = true;
  String? _statusError;
  IdealMatchStatus? _status;

  bool _revealing = false;
  IdealMatchResult? _result;
  bool _liked = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    setState(() {
      _loadingStatus = true;
      _statusError = null;
    });
    final res = await ref.read(idealMatchRepositoryProvider).getStatus();
    if (!mounted) return;
    switch (res) {
      case Success(:final data):
        setState(() {
          _status = data;
          _loadingStatus = false;
        });
      case Failure(:final exception):
        setState(() {
          _statusError = exception.message;
          _loadingStatus = false;
        });
    }
  }

  Future<void> _reveal() async {
    setState(() => _revealing = true);
    HapticFeedback.mediumImpact();
    final res = await ref.read(idealMatchRepositoryProvider).reveal();
    if (!mounted) return;
    setState(() => _revealing = false);
    switch (res) {
      case Success(:final data):
        setState(() => _result = data);
      case Failure(:final exception):
        context.showSnackBar(exception.message, isError: true);
        _loadStatus(); // refresh gate state (cap/profile may have changed)
    }
  }

  Future<void> _likeIdeal() async {
    final match = _result?.match;
    if (match == null) return;
    setState(() => _liked = true);
    final res = await ref.read(swipeRepositoryProvider).like(match.id);
    if (!mounted) return;
    if (res is Failure<void>) {
      setState(() => _liked = false);
      context.showSnackBar(res.exception.message, isError: true);
    } else {
      context.showSnackBar('Liked! If they accept, it\'s a match 💘');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Ideal Match',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    if (_result != null) return _ResultView(result: _result!, liked: _liked, onLike: _likeIdeal, onDone: () => context.pop());
    if (_loadingStatus) {
      return const Center(
        child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6)),
      );
    }
    if (_statusError != null) {
      return _Centered(
        icon: Icons.cloud_off_rounded,
        title: "Couldn't load",
        body: _statusError!,
        actionLabel: 'Try again',
        onAction: _loadStatus,
      );
    }
    return _StatusView(
      status: _status!,
      revealing: _revealing,
      onReveal: _reveal,
      onEditProfile: () => context.push('/edit-profile'),
    );
  }
}

// ---------------------------- status / gates ----------------------------

class _StatusView extends StatelessWidget {
  final IdealMatchStatus status;
  final bool revealing;
  final VoidCallback onReveal;
  final VoidCallback onEditProfile;

  const _StatusView({
    required this.status,
    required this.revealing,
    required this.onReveal,
    required this.onEditProfile,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          const SizedBox(height: 12),
          // Sparkle hero
          Container(
            width: 120,
            height: 120,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.grape, AppColors.hot],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 56),
          ),
          const SizedBox(height: 20),
          Text('Find your ideal match',
              textAlign: TextAlign.center,
              style: AppTheme.serifHeading(fontSize: 28)),
          const SizedBox(height: 8),
          const Text(
            'Our matchmaker learns from your swipes to find the one person most compatible with you.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 14, color: AppColors.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 24),

          // Gate checklist
          _GateRow(
            done: status.swipesOk,
            label: status.swipesOk
                ? 'Swiped enough (${status.swipeCount})'
                : 'Swipe ${status.swipesLeft} more to unlock',
          ),
          _GateRow(
            done: status.profileOk,
            label: status.profileOk
                ? 'Profile ready (${status.completionPercent}%)'
                : 'Complete profile to ${status.completionThresholdPercent}% (now ${status.completionPercent}%)',
          ),
          _GateRow(
            done: status.capOk,
            label: status.capOk
                ? '${status.usesLeft} of ${status.weeklyCap} left this week'
                : 'Used both this week${_resetSuffix(status.nextResetAt)}',
          ),

          const SizedBox(height: 28),
          _primaryAction(context),
        ],
      ),
    );
  }

  String _resetSuffix(DateTime? reset) {
    if (reset == null) return '';
    final diff = reset.difference(DateTime.now());
    if (diff.inDays >= 1) return ' · resets in ${diff.inDays}d';
    if (diff.inHours >= 1) return ' · resets in ${diff.inHours}h';
    return ' · resets soon';
  }

  Widget _primaryAction(BuildContext context) {
    if (status.eligible) {
      return Column(
        children: [
          _GradientButton(
            label: revealing ? 'Finding your ideal…' : 'Find My Ideal ✨',
            loading: revealing,
            onTap: revealing ? null : onReveal,
          ),
          const SizedBox(height: 10),
          Text('${status.usesLeft} of ${status.weeklyCap} left this week',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
        ],
      );
    }
    // Locked: most actionable next step
    if (!status.profileOk) {
      return SizedBox(
        width: 240,
        child: ElevatedButton(
          onPressed: onEditProfile,
          child: const Text('Complete profile'),
        ),
      );
    }
    if (!status.swipesOk) {
      return SizedBox(
        width: 240,
        child: ElevatedButton(
          onPressed: () => context.pop(),
          child: const Text('Keep swiping'),
        ),
      );
    }
    // cap reached
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        "You've found your ideal matches this week ✨\nCome back soon for more.",
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 13, color: AppColors.textSecondary, height: 1.4),
      ),
    );
  }
}

class _GateRow extends StatelessWidget {
  final bool done;
  final String label;
  const _GateRow({required this.done, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            color: done ? AppColors.lime : AppColors.textHint,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: done ? FontWeight.w600 : FontWeight.w500,
                color: done ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const _GradientButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.grape, AppColors.hot]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: AppColors.grape.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Colors.white))
            : Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

// ------------------------------- result -------------------------------

class _ResultView extends StatelessWidget {
  final IdealMatchResult result;
  final bool liked;
  final VoidCallback onLike;
  final VoidCallback onDone;

  const _ResultView({
    required this.result,
    required this.liked,
    required this.onLike,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final UserModel u = result.match;
    final photo = u.firstPhoto;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: Column(
        children: [
          // Celebratory banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(colors: [AppColors.grape, AppColors.hot]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                const Text('✨ Your Ideal Match ✨',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w800)),
                if (result.scorePercent > 0) ...[
                  const SizedBox(height: 2),
                  Text('${result.scorePercent}% compatible',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Photo
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: AspectRatio(
              aspectRatio: 0.82,
              child: photo.isNotEmpty
                  ? AppCachedImage(imageUrl: photo, fit: BoxFit.cover)
                  : Container(
                      color: AppColors.surfaceVariant,
                      child: const Icon(Icons.person_rounded,
                          size: 80, color: AppColors.textHint),
                    ),
            ),
          ),
          const SizedBox(height: 14),

          // Name + age + verified
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(u.name ?? 'Someone',
                  style: AppTheme.serifHeading(fontSize: 28)),
              if (u.age != null) ...[
                const SizedBox(width: 8),
                Text('${u.age}',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary)),
              ],
              if (u.isVerified) ...[
                const SizedBox(width: 6),
                const Icon(Icons.verified_rounded,
                    color: AppColors.grape, size: 22),
              ],
            ],
          ),

          if (result.commonalities.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Why you two click',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  ...result.commonalities.map((c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.favorite_rounded,
                                size: 16, color: AppColors.hot),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(c,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      color: AppColors.textPrimary,
                                      height: 1.4)),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],

          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDone,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                  ),
                  child: const Text('Maybe later'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: liked ? null : onLike,
                  icon: Icon(
                      liked ? Icons.check_rounded : Icons.favorite_rounded,
                      size: 20),
                  label: Text(liked ? 'Liked' : 'Like'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    backgroundColor: AppColors.hot,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Centered extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final String actionLabel;
  final VoidCallback onAction;

  const _Centered({
    required this.icon,
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 60, color: AppColors.textHint),
            const SizedBox(height: 16),
            Text(title, style: AppTheme.serifHeading(fontSize: 22)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 14)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onAction, child: Text(actionLabel)),
          ],
        ),
      ),
    );
  }
}
