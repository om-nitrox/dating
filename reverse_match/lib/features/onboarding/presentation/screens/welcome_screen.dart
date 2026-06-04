import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/theme/app_colors.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with TickerProviderStateMixin {
  final _controller = PageController();
  int _currentPage = 0;

  late final AnimationController _pulse;

  final _pages = const [
    _PageData(
      hero: _HeroVariant.heart,
      title: 'Meaningful matches,\nnot endless swipes',
      subtitle:
          'Reverse Match is built for people who want connection, not just attention.',
    ),
    _PageData(
      hero: _HeroVariant.reverse,
      title: 'Girls choose first,\nboys decide back',
      subtitle:
          'No random matches. She likes a profile, he accepts. Both have to mean it.',
    ),
    _PageData(
      hero: _HeroVariant.chat,
      title: 'Match.\nThen talk like real people.',
      subtitle:
          'Real-time chat, photo prompts, and roses for the moments that matter.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _completeOnboarding() {
    ref.read(localStorageProvider).setOnboardingSeen();
    context.go('/login');
  }

  void _nextOrFinish() {
    if (_currentPage == _pages.length - 1) {
      _completeOnboarding();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isLastPage = _currentPage == _pages.length - 1;

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
              _TopBar(
                onSkip: _completeOnboarding,
                showSkip: !isLastPage,
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (i) => setState(() => _currentPage = i),
                  itemBuilder: (_, i) {
                    return _WelcomePageView(
                      data: _pages[i],
                      pulse: _pulse,
                      heroSize: math.min(size.width * 0.55, 240),
                    );
                  },
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: SmoothPageIndicator(
                  key: ValueKey(_currentPage),
                  controller: _controller,
                  count: _pages.length,
                  effect: const ExpandingDotsEffect(
                    dotHeight: 8,
                    dotWidth: 8,
                    expansionFactor: 4,
                    spacing: 6,
                    activeDotColor: Colors.white,
                    dotColor: Colors.white38,
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _nextOrFinish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        isLastPage ? 'Create my account' : 'Continue',
                        key: ValueKey(isLastPage),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _completeOnboarding,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                ),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                    children: [
                      TextSpan(text: 'Already have an account? '),
                      TextSpan(
                        text: 'Sign in',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onSkip;
  final bool showSkip;

  const _TopBar({required this.onSkip, required this.showSkip});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                    width: 1.2,
                  ),
                ),
                child: const Icon(
                  Icons.favorite,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Reverse Match',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 220),
            opacity: showSkip ? 1.0 : 0.0,
            child: TextButton(
              onPressed: showSkip ? onSkip : null,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: const Text('Skip'),
            ),
          ),
        ],
      ),
    );
  }
}

enum _HeroVariant { heart, reverse, chat }

class _PageData {
  final _HeroVariant hero;
  final String title;
  final String subtitle;

  const _PageData({
    required this.hero,
    required this.title,
    required this.subtitle,
  });
}

class _WelcomePageView extends StatelessWidget {
  final _PageData data;
  final AnimationController pulse;
  final double heroSize;

  const _WelcomePageView({
    required this.data,
    required this.pulse,
    required this.heroSize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          _Hero(variant: data.hero, pulse: pulse, size: heroSize),
          const SizedBox(height: 48),
          Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              height: 1.15,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            data.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final _HeroVariant variant;
  final AnimationController pulse;
  final double size;

  const _Hero({
    required this.variant,
    required this.pulse,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulse,
      builder: (_, __) {
        final scale = 1.0 + (pulse.value * 0.05);
        final glow = 0.2 + (pulse.value * 0.15);
        return Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: scale * 1.15,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: glow * 0.3),
                ),
              ),
            ),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white, AppColors.background],
                ),
                boxShadow: [
                  // big soft outer drop
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 40,
                    offset: const Offset(0, 22),
                  ),
                  // inner-style highlight bloom
                  BoxShadow(
                    color: Colors.white.withValues(alpha: glow + 0.3),
                    blurRadius: 30,
                    spreadRadius: -6,
                    offset: const Offset(-10, -10),
                  ),
                ],
              ),
              child: Center(
                child: Transform.scale(
                  scale: variant == _HeroVariant.heart ? scale : 1.0,
                  child: _heroContent(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _heroContent() {
    switch (variant) {
      case _HeroVariant.heart:
        return Icon(
          Icons.favorite_rounded,
          size: size * 0.42,
          color: Colors.white,
        );
      case _HeroVariant.reverse:
        return SizedBox(
          width: size * 0.7,
          height: size * 0.45,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned(
                left: 0,
                child: _GenderBubble(
                  icon: Icons.female_rounded,
                  color: AppColors.primary,
                  size: size * 0.38,
                ),
              ),
              Positioned(
                right: 0,
                child: _GenderBubble(
                  icon: Icons.male_rounded,
                  color: AppColors.secondary,
                  size: size * 0.38,
                ),
              ),
              Container(
                width: size * 0.18,
                height: size * 0.18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.favorite_rounded,
                  size: size * 0.1,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      case _HeroVariant.chat:
        return SizedBox(
          width: size * 0.7,
          height: size * 0.55,
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                child: _ChatBubble(
                  text: 'Hey!',
                  color: Colors.white,
                  textColor: AppColors.primary,
                  fontSize: size * 0.08,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: _ChatBubble(
                  text: 'Hi 👋',
                  color: AppColors.primary,
                  textColor: Colors.white,
                  fontSize: size * 0.08,
                  borderColor: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
    }
  }
}

class _GenderBubble extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _GenderBubble({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final Color color;
  final Color textColor;
  final double fontSize;
  final Color? borderColor;

  const _ChatBubble({
    required this.text,
    required this.color,
    required this.textColor,
    required this.fontSize,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 1.4,
        vertical: fontSize * 0.7,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(fontSize * 1.5),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.5)
            : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
