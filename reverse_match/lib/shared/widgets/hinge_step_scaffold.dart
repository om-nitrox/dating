import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/clay.dart';

/// Claymorphic scaffold for onboarding / auth single-question screens.
///
/// Layout: back arrow (top-left) → rounded [title] → optional [subtitle] →
/// [child] (form body) → bottom action area.
///
/// Action area variants:
///   * [HingeStepAction.next] — bottom-right puffy clay `>` button
///   * [HingeStepAction.continue_] — bottom-center gradient "Continue" pill
class HingeStepScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final HingeStepAction action;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool actionEnabled;
  final bool actionLoading;
  final bool showBackButton;
  final VoidCallback? onBack;
  final HingeVisibilityToggle? visibilityToggle;
  final String? topTitle;
  final EdgeInsetsGeometry? contentPadding;

  const HingeStepScaffold({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.action = HingeStepAction.continue_,
    this.actionLabel = 'Continue',
    this.onAction,
    this.actionEnabled = true,
    this.actionLoading = false,
    this.showBackButton = true,
    this.onBack,
    this.visibilityToggle,
    this.topTitle,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Clay.base(context),
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(
              showBack: showBackButton,
              onBack: onBack ??
                  (Navigator.canPop(context)
                      ? () => Navigator.pop(context)
                      : null),
              title: topTitle,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: contentPadding ??
                    const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      title,
                      textAlign: action == HingeStepAction.continue_
                          ? TextAlign.center
                          : TextAlign.start,
                      style: AppTheme.serifHeading(fontSize: 30),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        subtitle!,
                        textAlign: action == HingeStepAction.continue_
                            ? TextAlign.center
                            : TextAlign.start,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          height: 1.45,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    child,
                  ],
                ),
              ),
            ),
            _BottomActionBar(
              action: action,
              actionLabel: actionLabel,
              onAction: actionEnabled && !actionLoading ? onAction : null,
              loading: actionLoading,
              visibilityToggle: visibilityToggle,
            ),
          ],
        ),
      ),
    );
  }
}

enum HingeStepAction {
  next,
  // ignore: constant_identifier_names
  continue_,
}

class HingeVisibilityToggle {
  final bool visible;
  final ValueChanged<bool> onChanged;
  final bool hideable;

  const HingeVisibilityToggle({
    required this.visible,
    required this.onChanged,
    this.hideable = true,
  });
}

class _TopBar extends StatelessWidget {
  final bool showBack;
  final VoidCallback? onBack;
  final String? title;

  const _TopBar({required this.showBack, required this.onBack, this.title});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (title != null)
            Text(title!, style: Theme.of(context).appBarTheme.titleTextStyle),
          if (showBack && onBack != null)
            Positioned(
              left: 16,
              child: ClayButton(
                onTap: onBack,
                borderRadius: 16,
                depth: 0.6,
                padding: const EdgeInsets.all(11),
                color: Clay.surface(context),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  final HingeStepAction action;
  final String actionLabel;
  final VoidCallback? onAction;
  final bool loading;
  final HingeVisibilityToggle? visibilityToggle;

  const _BottomActionBar({
    required this.action,
    required this.actionLabel,
    required this.onAction,
    required this.loading,
    required this.visibilityToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: action == HingeStepAction.next
          ? _NextRow(
              onAction: onAction,
              loading: loading,
              visibilityToggle: visibilityToggle,
            )
          : _ContinuePillRow(
              label: actionLabel,
              onAction: onAction,
              loading: loading,
              visibilityToggle: visibilityToggle,
            ),
    );
  }
}

class _NextRow extends StatelessWidget {
  final VoidCallback? onAction;
  final bool loading;
  final HingeVisibilityToggle? visibilityToggle;

  const _NextRow({
    required this.onAction,
    required this.loading,
    required this.visibilityToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (visibilityToggle != null)
          Expanded(child: _VisibilityRow(toggle: visibilityToggle!))
        else
          const Spacer(),
        _CircleNextButton(onPressed: onAction, loading: loading),
      ],
    );
  }
}

class _ContinuePillRow extends StatelessWidget {
  final String label;
  final VoidCallback? onAction;
  final bool loading;
  final HingeVisibilityToggle? visibilityToggle;

  const _ContinuePillRow({
    required this.label,
    required this.onAction,
    required this.loading,
    required this.visibilityToggle,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onAction != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (visibilityToggle != null) ...[
          _VisibilityRow(toggle: visibilityToggle!),
          const SizedBox(height: 12),
        ],
        ClayButton(
          onTap: onAction,
          enabled: enabled,
          borderRadius: 22,
          padding: const EdgeInsets.symmetric(vertical: 17),
          gradient: const LinearGradient(
            colors: [AppColors.grape, AppColors.primary],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          child: loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : Text(
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

class _CircleNextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const _CircleNextButton({required this.onPressed, required this.loading});

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return ClayButton(
      onTap: onPressed,
      enabled: enabled,
      borderRadius: 30,
      padding: const EdgeInsets.all(18),
      gradient: enabled
          ? const LinearGradient(
              colors: [AppColors.grape, AppColors.primary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            )
          : null,
      color: enabled ? null : AppColors.pillDisabled,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Center(
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 22,
                ),
        ),
      ),
    );
  }
}

class _VisibilityRow extends StatelessWidget {
  final HingeVisibilityToggle toggle;

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
                    colors: [AppColors.grape, AppColors.primary],
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

/// Claymorphic choice tile — puffy card that depresses + shows a lilac→mint
/// indicator when selected. Used by gender, pronouns, ethnicity, etc.
class HingeChoiceTile extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final bool multi;
  final VoidCallback onTap;

  const HingeChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sublabel,
    this.multi = false,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).textTheme.bodyLarge?.color;
    final subColor = Theme.of(context).textTheme.bodyMedium?.color;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ClayButton(
        onTap: onTap,
        borderRadius: 20,
        depth: selected ? 0.45 : 0.7,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        color: selected ? AppColors.surfaceVariant : Clay.surface(context),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  if (sublabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      sublabel!,
                      style: TextStyle(
                        fontSize: 12,
                        color: subColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Indicator(selected: selected, multi: multi),
          ],
        ),
      ),
    );
  }
}

class _Indicator extends StatelessWidget {
  final bool selected;
  final bool multi;

  const _Indicator({required this.selected, required this.multi});

  @override
  Widget build(BuildContext context) {
    final borderColor = Theme.of(context).dividerTheme.color ??
        AppColors.inputBorder;
    const grad = LinearGradient(colors: [AppColors.grape, AppColors.primary]);

    if (multi) {
      return Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          gradient: selected ? grad : null,
          color: selected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          border: selected ? null : Border.all(color: borderColor, width: 1.4),
        ),
        child: selected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      );
    }
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: selected ? grad : null,
        border: selected ? null : Border.all(color: borderColor, width: 1.4),
      ),
      child: selected
          ? const Icon(Icons.check, size: 15, color: Colors.white)
          : null,
    );
  }
}
