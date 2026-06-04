import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/network/api_result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/clay.dart';
import '../../../../shared/models/like_model.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import '../../data/queue_repository.dart';
import '../widgets/match_dialog.dart';

final queueProvider =
    StateNotifierProvider<QueueNotifier, QueueState>((ref) {
  return QueueNotifier(ref.read(queueRepositoryProvider));
});

class QueueState {
  final List<LikeModel> likes;
  final bool isLoading;
  final String? error;

  QueueState({this.likes = const [], this.isLoading = false, this.error});

  QueueState copyWith({
    List<LikeModel>? likes,
    bool? isLoading,
    String? error,
  }) {
    return QueueState(
      likes: likes ?? this.likes,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class QueueNotifier extends StateNotifier<QueueState> {
  final QueueRepository _repo;

  QueueNotifier(this._repo) : super(QueueState()) {
    loadQueue();
  }

  Future<void> loadQueue() async {
    state = state.copyWith(isLoading: true);
    final result = await _repo.getQueue();
    switch (result) {
      case Success(:final data):
        state = state.copyWith(likes: data, isLoading: false);
      case Failure(:final exception):
        state = state.copyWith(isLoading: false, error: exception.message);
    }
  }

  Future<void> accept(String likeId, BuildContext context) async {
    final result = await _repo.accept(likeId);
    switch (result) {
      case Success(:final data):
        state = state.copyWith(
          likes: state.likes.where((l) => l.id != likeId).toList(),
        );
        if (context.mounted) {
          showMatchDialog(context, data);
        }
      case Failure(:final exception):
        if (context.mounted) {
          context.showSnackBar(exception.message, isError: true);
        }
    }
  }

  Future<void> reject(String likeId) async {
    state = state.copyWith(
      likes: state.likes.where((l) => l.id != likeId).toList(),
    );
    _repo.reject(likeId);
  }
}

class BoyHomeScreen extends ConsumerWidget {
  const BoyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(queueProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(count: queueState.likes.length),
            Expanded(child: _body(context, ref, queueState)),
          ],
        ),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, QueueState state) {
    if (state.isLoading && state.likes.isEmpty) {
      return const _LoadingSkeleton();
    }
    if (state.likes.isEmpty) {
      return _EmptyQueue(
        onRefresh: () => ref.read(queueProvider.notifier).loadQueue(),
      );
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => ref.read(queueProvider.notifier).loadQueue(),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        itemCount: state.likes.length,
        itemBuilder: (context, index) {
          final like = state.likes[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _QueueCard(
              key: ValueKey(like.id),
              like: like,
              onAccept: () =>
                  ref.read(queueProvider.notifier).accept(like.id, context),
              onReject: () =>
                  ref.read(queueProvider.notifier).reject(like.id),
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int count;

  const _TopBar({required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.favorite_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          const Text(
            'Your Likes',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(width: 10),
          if (count > 0)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          const Spacer(),
        ],
      ),
    );
  }
}

class _QueueCard extends StatefulWidget {
  final LikeModel like;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _QueueCard({
    super.key,
    required this.like,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<_QueueCard>
    with TickerProviderStateMixin {
  static const _threshold = 100.0;

  double _dx = 0;
  bool _leaving = false;
  late final AnimationController _ctrl;
  Animation<double>? _anim;
  late final AnimationController _entrance;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..addListener(() {
        if (_anim != null) setState(() => _dx = _anim!.value);
      });
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _entrance.dispose();
    super.dispose();
  }

  void _animateTo(double target,
      {Curve curve = Curves.easeOut, int ms = 280, VoidCallback? then}) {
    _ctrl.duration = Duration(milliseconds: ms);
    _anim = Tween<double>(begin: _dx, end: target)
        .animate(CurvedAnimation(parent: _ctrl, curve: curve));
    _ctrl
      ..reset()
      ..forward().whenComplete(() {
        if (then != null) then();
      });
  }

  void _accept(double width) {
    if (_leaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _leaving = true);
    _animateTo(width * 1.4,
        curve: Curves.easeIn, ms: 300, then: widget.onAccept);
  }

  void _reject(double width) {
    if (_leaving) return;
    HapticFeedback.lightImpact();
    setState(() => _leaving = true);
    _animateTo(-width * 1.4,
        curve: Curves.easeIn, ms: 300, then: widget.onReject);
  }

  void _onDragEnd(double width) {
    if (_dx > _threshold) {
      _accept(width);
    } else if (_dx < -_threshold) {
      _reject(width);
    } else {
      _animateTo(0, curve: Curves.easeOutBack, ms: 320);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final angle = (_dx / width).clamp(-1.0, 1.0) * 0.06;
    final likeOpacity = (_dx / 80).clamp(0.0, 1.0);
    final passOpacity = (-_dx / 80).clamp(0.0, 1.0);
    final flyOpacity =
        _leaving ? (1 - (_dx.abs() / width).clamp(0.0, 1.0)) : 1.0;

    return GestureDetector(
      // Swipe right = Match, swipe left = Pass; the buttons do the same.
      onHorizontalDragUpdate: (d) {
        if (_leaving) return;
        _anim = null;
        setState(() => _dx += d.delta.dx);
      },
      onHorizontalDragEnd: (_) => _onDragEnd(width),
      child: AnimatedBuilder(
        animation: _entrance,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_entrance.value);
          return Opacity(
            opacity: (flyOpacity * t).clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(_dx, (1 - t) * 26),
              child: Transform.rotate(
                angle: angle,
                child: Transform.scale(
                  scale: 0.96 + 0.04 * t,
                  child: child,
                ),
              ),
            ),
          );
        },
        child: _card(context, width, likeOpacity, passOpacity),
      ),
    );
  }

  Widget _card(
      BuildContext context, double width, double likeOpacity, double passOpacity) {
    final user = widget.like.fromUser;
    return ClayContainer(
      borderRadius: 22,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              children: [
                // Photo banner
                Stack(
                  children: [
                    SizedBox(
                      height: 230,
                      width: double.infinity,
                      child: user.firstPhoto.isNotEmpty
                          ? AppCachedImage(
                              imageUrl: user.firstPhoto,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: AppColors.surfaceVariant,
                              child: const Icon(Icons.person,
                                  size: 80, color: AppColors.textHint),
                            ),
                    ),
                    // Bottom gradient + name
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.8),
                              Colors.black.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Flexible(
                              child: Text(
                                user.name ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (user.age != null)
                              Text(
                                '${user.age}',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            const SizedBox(width: 6),
                            if (user.isVerified)
                              const Icon(
                                Icons.verified_rounded,
                                color: AppColors.grape,
                                size: 18,
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Time-ago chip top-right
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _timeAgo(widget.like.createdAt),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Bio + actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (user.bio != null && user.bio!.isNotEmpty)
                        Text(
                          user.bio!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      if (user.interests.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: user.interests.take(3).map((i) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.primary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                i,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: () => _reject(width),
                                icon: const Icon(Icons.close_rounded, size: 20),
                                label: const Text('Pass'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.nopeRed,
                                  side: const BorderSide(
                                      color: AppColors.nopeRed, width: 1.4),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: SizedBox(
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () => _accept(width),
                                icon: const Icon(Icons.favorite_rounded,
                                    size: 20),
                                label: const Text('Match'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.likeGreen,
                                  foregroundColor: Colors.white,
                                  elevation: 1,
                                  shadowColor: AppColors.likeGreen
                                      .withValues(alpha: 0.3),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Swipe stamps — fade/scale in as the card is dragged.
          Positioned(
            top: 18,
            left: 18,
            child: Opacity(
              opacity: likeOpacity,
              child: Transform.scale(
                scale: 0.8 + 0.2 * likeOpacity,
                child:
                    const _SwipeStamp(text: 'MATCH', color: AppColors.likeGreen),
              ),
            ),
          ),
          Positioned(
            top: 18,
            right: 18,
            child: Opacity(
              opacity: passOpacity,
              child: Transform.scale(
                scale: 0.8 + 0.2 * passOpacity,
                child: const _SwipeStamp(text: 'PASS', color: AppColors.nopeRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }
}

/// Tilted MATCH / PASS stamp that fades in as a queue card is swiped.
class _SwipeStamp extends StatelessWidget {
  final String text;
  final Color color;
  const _SwipeStamp({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: text == 'PASS' ? 0.18 : -0.18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: 3,
      itemBuilder: (_, __) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Shimmer.fromColors(
            baseColor: AppColors.surfaceVariant,
            highlightColor: AppColors.divider.withValues(alpha: 0.4),
            child: Container(
              height: 380,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  final VoidCallback onRefresh;

  const _EmptyQueue({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRefresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.7,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceVariant,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_outline_rounded,
                        size: 54,
                        color: AppColors.grape,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Complete your profile\nto start getting likes',
                      textAlign: TextAlign.center,
                      style: AppTheme.serifHeading(fontSize: 24),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When someone likes your profile,\nthey\'ll show up here.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: 220,
                      child: ElevatedButton(
                        onPressed: () => context.push('/edit-profile'),
                        child: const Text('Edit profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
