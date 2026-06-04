import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/clay.dart';

/// Claymorphic full-screen onboarding scaffold.
///
/// Top: puffy clay progress track + clay back chip (left) + optional skip.
/// Body: rounded title (optionally centered), optional subtitle, optional
/// "Why?" link, scrollable child.
/// Bottom: clay "Continue" pill OR a puffy gradient circle-next button.
///
/// Public API preserved exactly — every onboarding screen upgrades
/// automatically without changes.
class OnboardingScaffold extends StatefulWidget {
  final String title;
  final String? subtitle;
  final String? whyText;
  final Widget child;
  final VoidCallback? onNext;
  final String nextLabel;
  final VoidCallback? onSkip;
  final bool showBack;
  final double? progress;
  final bool centerTitle;
  final OnboardingVisibility? visibility;
  final bool useCircleNext;

  const OnboardingScaffold({
    super.key,
    required this.title,
    this.subtitle,
    this.whyText,
    required this.child,
    this.onNext,
    this.nextLabel = 'Continue',
    this.onSkip,
    this.showBack = true,
    this.progress,
    this.centerTitle = true,
    this.visibility,
    this.useCircleNext = false,
  });

  @override
  State<OnboardingScaffold> createState() => _OnboardingScaffoldState();
}

class _OnboardingScaffoldState extends State<OnboardingScaffold>
    with SingleTickerProviderStateMixin {
  late final AnimationController _entry;

  @override
  void initState() {
    super.initState();
    _entry = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    )..forward();
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final fade = CurvedAnimation(
      parent: _entry,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entry, curve: Curves.easeOutCubic));

    return Scaffold(
      backgroundColor: Clay.base(context),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              showBack: widget.showBack && Navigator.canPop(context),
              onSkip: widget.onSkip,
              progress: widget.progress,
            ),
            Expanded(
              child: FadeTransition(
                opacity: fade,
                child: SlideTransition(
                  position: slide,
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                    child: Column(
                      crossAxisAlignment: widget.centerTitle
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          textAlign: widget.centerTitle
                              ? TextAlign.center
                              : TextAlign.start,
                          style: AppTheme.serifHeading(fontSize: 29),
                        ),
                        if (widget.subtitle != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.subtitle!,
                            textAlign: widget.centerTitle
                                ? TextAlign.center
                                : TextAlign.start,
                            style: TextStyle(
                              fontSize: 14,
                              color:
                                  Theme.of(context).textTheme.bodyMedium?.color,
                              height: 1.45,
                            ),
                          ),
                        ],
                        if (widget.whyText != null) ...[
                          const SizedBox(height: 10),
                          _WhyLink(text: widget.whyText!),
                        ],
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          child: widget.child,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _BottomBar(
              onNext: widget.onNext,
              nextLabel: widget.nextLabel,
              bottomInset: bottomInset,
              visibility: widget.visibility,
              useCircleNext: widget.useCircleNext,
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingVisibility {
  final bool visible;
  final ValueChanged<bool> onChanged;
  final bool hideable;

  const OnboardingVisibility({
    required this.visible,
    required this.onChanged,
    this.hideable = true,
  });
}

class _TopBar extends StatelessWidget {
  final bool showBack;
  final VoidCallback? onSkip;
  final double? progress;

  const _TopBar({
    required this.showBack,
    required this.onSkip,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: showBack
                ? ClayButton(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: 14,
                    depth: 0.55,
                    padding: const EdgeInsets.all(10),
                    color: Clay.surface(context),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: textColor),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(width: 12),
          if (progress != null)
            Expanded(
              child: ClayContainer(
                pressed: true,
                borderRadius: 12,
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: progress!),
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    builder: (_, value, __) => LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: Colors.transparent,
                      valueColor:
                          const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
              ),
            )
          else
            const Spacer(),
          const SizedBox(width: 12),
          SizedBox(
            width: 52,
            child: onSkip != null
                ? TextButton(
                    onPressed: onSkip,
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).textTheme.bodyMedium?.color,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    child: const Text('Skip'),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final VoidCallback? onNext;
  final String nextLabel;
  final double bottomInset;
  final OnboardingVisibility? visibility;
  final bool useCircleNext;

  const _BottomBar({
    required this.onNext,
    required this.nextLabel,
    required this.bottomInset,
    required this.visibility,
    required this.useCircleNext,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      padding: EdgeInsets.fromLTRB(
        24,
        4,
        24,
        bottomInset > 0 ? 12 : MediaQuery.paddingOf(context).bottom + 18,
      ),
      child: useCircleNext
          ? _CircleNextRow(onNext: onNext, visibility: visibility)
          : _PillRow(onNext: onNext, label: nextLabel, visibility: visibility),
    );
  }
}

class _PillRow extends StatelessWidget {
  final VoidCallback? onNext;
  final String label;
  final OnboardingVisibility? visibility;

  const _PillRow({
    required this.onNext,
    required this.label,
    required this.visibility,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (visibility != null) ...[
          _VisibilityRow(toggle: visibility!),
          const SizedBox(height: 10),
        ],
        ClayButton(
          onTap: onNext,
          enabled: onNext != null,
          borderRadius: 22,
          padding: const EdgeInsets.symmetric(vertical: 18),
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.grape],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleNextRow extends StatelessWidget {
  final VoidCallback? onNext;
  final OnboardingVisibility? visibility;

  const _CircleNextRow({required this.onNext, required this.visibility});

  @override
  Widget build(BuildContext context) {
    final enabled = onNext != null;
    return Row(
      children: [
        if (visibility != null)
          Expanded(child: _VisibilityRow(toggle: visibility!))
        else
          const Spacer(),
        ClayButton(
          onTap: onNext,
          enabled: enabled,
          borderRadius: 32,
          depth: 0.9,
          padding: const EdgeInsets.all(19),
          gradient: enabled
              ? const LinearGradient(
                  colors: [AppColors.primary, AppColors.grape],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: enabled ? null : AppColors.pillDisabled,
          child: const Icon(Icons.arrow_forward_rounded,
              color: Colors.white, size: 26),
        ),
      ],
    );
  }
}

class _VisibilityRow extends StatelessWidget {
  final OnboardingVisibility toggle;
  const _VisibilityRow({required this.toggle});

  @override
  Widget build(BuildContext context) {
    final visible = toggle.visible;
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: toggle.hideable ? () => toggle.onChanged(!visible) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (visible)
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.grape],
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              )
            else
              Icon(
                Icons.visibility_off_outlined,
                size: 22,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            const SizedBox(width: 10),
            Text(
              visible ? 'Visible on profile' : 'Hidden on profile',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WhyLink extends StatelessWidget {
  final String text;
  const _WhyLink({required this.text});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(6),
      onTap: () {
        showModalBottomSheet(
          context: context,
          backgroundColor: Clay.surface(context),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          builder: (_) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerTheme.color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text('Why we ask', style: AppTheme.serifHeading(fontSize: 22)),
                const SizedBox(height: 12),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          'Why?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
        ),
      ),
    );
  }
}
