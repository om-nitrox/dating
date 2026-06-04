import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/models/match_model.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/app_cached_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Celebration dialog shown when two users match. Animates two avatars
/// converging, a sparkle burst, and "It's a Match!" text, then offers
/// Send Message + Keep Browsing.
Future<void> showMatchDialog(BuildContext context, MatchModel match) async {
  HapticFeedback.heavyImpact();
  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Match',
    barrierColor: const Color(0xFF2E2A3A).withValues(alpha: 0.82),
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (_, __, ___) => _MatchDialog(match: match),
    transitionBuilder: (_, anim, __, child) {
      return FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
  );
}

class _MatchDialog extends ConsumerStatefulWidget {
  final MatchModel match;

  const _MatchDialog({required this.match});

  @override
  ConsumerState<_MatchDialog> createState() => _MatchDialogState();
}

class _MatchDialogState extends ConsumerState<_MatchDialog>
    with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _sparkles;

  UserModel? _me;
  UserModel? _them;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _sparkles = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _resolveUsers();
  }

  Future<void> _resolveUsers() async {
    final myId = await ref.read(secureStorageProvider).getUserId();
    if (!mounted) return;
    setState(() {
      if (myId != null && widget.match.users.length >= 2) {
        _me = widget.match.users.firstWhere(
          (u) => u.id == myId,
          orElse: () => widget.match.users.first,
        );
        _them = widget.match.users.firstWhere(
          (u) => u.id != myId,
          orElse: () => widget.match.users.last,
        );
      } else if (widget.match.users.isNotEmpty) {
        _them = widget.match.users.first;
        _me = widget.match.users.length > 1
            ? widget.match.users[1]
            : null;
      }
    });
  }

  @override
  void dispose() {
    _intro.dispose();
    _sparkles.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titleCurve = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.25, 0.75, curve: Curves.easeOutBack),
    );
    final ctaFade = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Soft clay lilac→mint glow wash behind the sparkles.
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.1,
                colors: [
                  AppColors.grape.withValues(alpha: 0.55),
                  AppColors.primary.withValues(alpha: 0.18),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),
          // Sparkles background
          AnimatedBuilder(
            animation: _sparkles,
            builder: (_, __) =>
                CustomPaint(painter: _SparklesPainter(t: _sparkles.value)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  ScaleTransition(
                    scale: titleCurve,
                    child: const Text(
                      "It's a Match!",
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1.0,
                        shadows: [
                          Shadow(
                            color: Colors.black54,
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeTransition(
                    opacity: ctaFade,
                    child: Text(
                      _them != null
                          ? 'You and ${_them!.name ?? "your match"} liked each other'
                          : 'You both liked each other',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.45,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    height: 200,
                    child: AnimatedBuilder(
                      animation: _intro,
                      builder: (_, __) {
                        final glide = Curves.easeOutCubic.transform(
                          (_intro.value).clamp(0.0, 1.0),
                        );
                        return Stack(
                          alignment: Alignment.center,
                          children: [
                            // Left avatar slides in from left
                            Positioned(
                              left: 80 - (60 * glide),
                              child: _MatchAvatar(
                                user: _me,
                                tilt: -0.08,
                              ),
                            ),
                            // Right avatar slides in from right
                            Positioned(
                              right: 80 - (60 * glide),
                              child: _MatchAvatar(
                                user: _them,
                                tilt: 0.08,
                              ),
                            ),
                            // Heart pop in center on impact
                            if (_intro.value > 0.55)
                              Opacity(
                                opacity:
                                    ((_intro.value - 0.55) / 0.3).clamp(0.0, 1.0),
                                child: Transform.scale(
                                  scale: 0.6 +
                                      0.4 *
                                          Curves.elasticOut.transform(
                                            ((_intro.value - 0.55) / 0.4)
                                                .clamp(0.0, 1.0),
                                          ),
                                  child: Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppColors.grape,
                                          AppColors.primary
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.grape
                                              .withValues(alpha: 0.55),
                                          blurRadius: 28,
                                          spreadRadius: 4,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.favorite_rounded,
                                      color: Colors.white,
                                      size: 36,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                  const Spacer(),
                  FadeTransition(
                    opacity: ctaFade,
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              context.push('/chat/${widget.match.id}',
                                  extra: _them);
                            },
                            icon: const Icon(Icons.chat_bubble_rounded),
                            label: const Text('Send a message'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.primary,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            minimumSize:
                                const Size(double.infinity, 48),
                          ),
                          child: const Text(
                            'Keep browsing',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  final UserModel? user;
  final double tilt;

  const _MatchAvatar({required this.user, required this.tilt});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: tilt,
      child: Container(
        width: 128,
        height: 168,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: (user?.firstPhoto.isNotEmpty ?? false)
            ? AppCachedImage(
                imageUrl: user!.firstPhoto,
                fit: BoxFit.cover,
              )
            : Container(
                color: AppColors.surfaceVariant,
                child: const Icon(Icons.person,
                    size: 60, color: AppColors.textHint),
              ),
      ),
    );
  }
}

class _SparklesPainter extends CustomPainter {
  final double t;
  final List<_Spark> _sparks = List.generate(28, (i) {
    final r = math.Random(i * 37);
    return _Spark(
      x: r.nextDouble(),
      y: r.nextDouble(),
      size: 2 + r.nextDouble() * 4,
      phase: r.nextDouble(),
    );
  });

  _SparklesPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final s in _sparks) {
      final localT = (t + s.phase) % 1.0;
      final fade = math.sin(localT * math.pi); // 0→1→0
      if (fade < 0.05) continue;
      paint.color = Colors.white.withValues(alpha: fade * 0.6);
      final cx = s.x * size.width;
      final cy = s.y * size.height;
      canvas.drawCircle(Offset(cx, cy), s.size * fade, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SparklesPainter old) => true;
}

class _Spark {
  final double x;
  final double y;
  final double size;
  final double phase;
  const _Spark({
    required this.x,
    required this.y,
    required this.size,
    required this.phase,
  });
}
