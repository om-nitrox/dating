import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';

class BoostSuccessScreen extends StatefulWidget {
  const BoostSuccessScreen({super.key});

  @override
  State<BoostSuccessScreen> createState() => _BoostSuccessScreenState();
}

class _BoostSuccessScreenState extends State<BoostSuccessScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..forward();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _entry.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primary,
              AppColors.primaryLight,
              AppColors.secondary,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              AnimatedBuilder(
                animation: _entry,
                builder: (_, __) =>
                    CustomPaint(painter: _ConfettiPainter(t: _entry.value)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    AnimatedBuilder(
                      animation: Listenable.merge([_entry, _pulse]),
                      builder: (_, __) {
                        final intro = Curves.easeOutBack.transform(
                          _entry.value.clamp(0.0, 1.0),
                        );
                        final pulse = 1.0 + (_pulse.value * 0.06);
                        return Transform.scale(
                          scale: intro * pulse,
                          child: Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    Colors.white.withValues(alpha: 0.4),
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.flash_on_rounded,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 36),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entry,
                        curve: const Interval(0.3, 1.0),
                      ),
                      child: const Text(
                        'You\'re boosted!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: -0.8,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entry,
                        curve: const Interval(0.45, 1.0),
                      ),
                      child: Text(
                        'Your profile is at the top of the feed.\nGet ready for more views.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withValues(alpha: 0.92),
                          height: 1.5,
                        ),
                      ),
                    ),
                    const Spacer(flex: 4),
                    FadeTransition(
                      opacity: CurvedAnimation(
                        parent: _entry,
                        curve: const Interval(0.6, 1.0),
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () => context.go('/home'),
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
                          child: const Text('Back to discover'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double t;
  final List<_Confetti> _pieces = List.generate(40, (i) {
    final r = math.Random(i * 23);
    return _Confetti(
      x: r.nextDouble(),
      y: -0.2 - r.nextDouble() * 0.5,
      drift: (r.nextDouble() - 0.5) * 0.4,
      rotation: r.nextDouble() * math.pi * 2,
      size: 4 + r.nextDouble() * 6,
      color: _colors[r.nextInt(_colors.length)],
      speed: 0.4 + r.nextDouble() * 0.6,
    );
  });

  static const List<Color> _colors = [
    Colors.white,
    AppColors.secondary,
    AppColors.secondaryLight,
    AppColors.primaryLight,
    AppColors.hot,
  ];

  _ConfettiPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (final c in _pieces) {
      final y = c.y + (c.speed * t * 1.6);
      if (y < 0 || y > 1) continue;
      final x = c.x + c.drift * t;
      paint.color = c.color.withValues(alpha: 1 - (t * 0.4));
      final cx = x * size.width;
      final cy = y * size.height;
      canvas.save();
      canvas.translate(cx, cy);
      canvas.rotate(c.rotation + t * 6);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: c.size,
          height: c.size * 0.5,
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

class _Confetti {
  final double x;
  final double y;
  final double drift;
  final double rotation;
  final double size;
  final Color color;
  final double speed;

  const _Confetti({
    required this.x,
    required this.y,
    required this.drift,
    required this.rotation,
    required this.size,
    required this.color,
    required this.speed,
  });
}
