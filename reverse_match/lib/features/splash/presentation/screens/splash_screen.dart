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
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // Logo pops in with a soft overshoot, then settles.
    _logoScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _entry,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );
    _logoOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.0, 0.4),
    );
    _taglineOpacity = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    _entry.forward();

    // Hand off to auth check after the intro animation has had time to play.
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
        // Force full-screen. Without an explicit size a decorated Container
        // shrink-wraps to its widest child (the ~280px logo halo), so the
        // gradient only covered ~68% of the width and the Scaffold background
        // showed as a band on the right.
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          // Warm ivory wash so the deep-burgundy HOOK logo pops.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFBF4EE),
              AppColors.background,
              Color(0xFFEFE0D3),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 4),
              AnimatedBuilder(
                animation: Listenable.merge([_entry, _pulse]),
                builder: (_, child) {
                  // Gentle breathing once the logo has settled in.
                  final breathe = 1.0 + (_pulse.value * 0.03);
                  final glow = 0.10 + (_pulse.value * 0.12);
                  return Opacity(
                    opacity: _logoOpacity.value.clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: _logoScale.value * breathe,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Soft champagne-gold halo that breathes behind the
                          // logo for a premium, lit-from-behind feel.
                          Container(
                            width: 280,
                            height: 280,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppColors.secondary.withValues(alpha: glow),
                                  AppColors.secondary.withValues(alpha: 0.0),
                                ],
                                stops: const [0.0, 1.0],
                              ),
                            ),
                          ),
                          child!,
                        ],
                      ),
                    ),
                  );
                },
                child: Image.asset(
                  'assets/images/hook_logo.png',
                  width: 230,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 18),
              FadeTransition(
                opacity: _taglineOpacity,
                child: const Text(
                  'where girls choose first',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
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
                    color: AppColors.primary,
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
