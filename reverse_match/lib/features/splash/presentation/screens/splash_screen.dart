import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entry;
  late final AnimationController _pulse;

  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<double> _wordmarkOpacity;
  late final Animation<Offset> _wordmarkSlide;
  late final Animation<double> _taglineOpacity;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _entry,
        curve: const Interval(0.0, 0.55, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.35),
    );
    _wordmarkOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOut),
    );
    _wordmarkSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.35, 0.75, curve: Curves.easeOutCubic),
    ));
    _taglineOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );

    _entry.forward();

    // Hand off to auth check after the intro animation has had time to play.
    // Total: 1.4s entry + 0.4s breathing room. Auth check itself returns
    // quickly and the router redirect immediately routes off splash.
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (mounted) {
        ref.read(authProvider.notifier).checkAuthStatus();
      }
    });
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
              AppColors.grape,
              AppColors.primary,
              AppColors.lime,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 4),
              AnimatedBuilder(
                animation: Listenable.merge([_entry, _pulse]),
                builder: (_, __) {
                  final pulseScale = 1.0 + (_pulse.value * 0.04);
                  return Transform.scale(
                    scale: _logoScale.value * pulseScale,
                    child: Opacity(
                      opacity: _logoOpacity.value,
                      child: _LogoMark(pulse: _pulse.value),
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              SlideTransition(
                position: _wordmarkSlide,
                child: FadeTransition(
                  opacity: _wordmarkOpacity,
                  child: const Text(
                    'Reverse Match',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _taglineOpacity,
                child: const Text(
                  'where girls choose first',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(flex: 5),
              FadeTransition(
                opacity: _taglineOpacity,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogoMark extends StatelessWidget {
  final double pulse;

  const _LogoMark({required this.pulse});

  @override
  Widget build(BuildContext context) {
    final glow = 0.2 + (pulse * 0.2);
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 144,
          height: 144,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: glow * 0.5),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: Colors.white,
            size: 56,
          ),
        ),
      ],
    );
  }
}
