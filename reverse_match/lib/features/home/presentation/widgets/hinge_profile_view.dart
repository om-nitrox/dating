import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/clay.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/app_cached_image.dart';

/// Hinge-style single-profile discovery view.
///
/// Instead of a Tinder swipe deck, one profile is shown at a time as a
/// vertical scroll of content cards (photos + prompts), each with its own
/// "heart" like button. A single floating "X" passes the whole profile.
///
/// Because the backend likes a *user* (not a specific photo/prompt), every
/// heart tap calls [onLike] with the profile; the per-card affordance is
/// purely the Hinge interaction feel. [onPass] skips the profile.
class HingeProfileView extends StatefulWidget {
  final UserModel user;
  final VoidCallback onLike;
  final VoidCallback onPass;
  final VoidCallback? onUndo;
  final bool canUndo;

  const HingeProfileView({
    super.key,
    required this.user,
    required this.onLike,
    required this.onPass,
    this.onUndo,
    this.canUndo = false,
  });

  // ---- enum → human label helpers ----
  static String _humanize(String? v) {
    if (v == null || v.isEmpty) return '';
    return v
        .split('_')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  static const _genderLabels = {
    'female': 'Woman',
    'male': 'Man',
    'nonbinary': 'Nonbinary',
  };

  static const _intentionLabels = {
    'life_partner': 'Life partner',
    'long_term': 'Long-term relationship',
    'long_term_open_short': 'Long-term, open to short',
    'short_term_open_long': 'Short-term, open to long',
    'short_term': 'Short-term relationship',
    'new_friends': 'New friends',
    'figuring_out': 'Figuring out my dating goals',
  };

  @override
  State<HingeProfileView> createState() => _HingeProfileViewState();
}

class _HingeProfileViewState extends State<HingeProfileView>
    with TickerProviderStateMixin {
  static const _swipeThreshold = 110.0;

  /// Current horizontal drag offset of the whole profile (px).
  double _dx = 0;

  /// True while the card is flying off after a committed like/pass — used to
  /// fade it out as it leaves.
  bool _flinging = false;

  late final AnimationController _ctrl;
  Animation<double>? _anim;

  /// Plays once when a new profile mounts, so each card eases in (fade + rise
  /// + scale) instead of popping into place.
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

  void _flingLike(double width) {
    HapticFeedback.mediumImpact();
    setState(() => _flinging = true);
    _animateTo(width * 1.5, curve: Curves.easeIn, ms: 300, then: widget.onLike);
  }

  void _flingPass(double width) {
    HapticFeedback.lightImpact();
    setState(() => _flinging = true);
    _animateTo(-width * 1.5, curve: Curves.easeIn, ms: 300, then: widget.onPass);
  }

  void _onDragEnd(double width) {
    if (_dx > _swipeThreshold) {
      _flingLike(width);
    } else if (_dx < -_swipeThreshold) {
      _flingPass(width);
    } else {
      // Bouncy settle back to center.
      _animateTo(0, curve: Curves.easeOutBack, ms: 320);
    }
  }

  List<_Vital> _buildVitals() {
    final user = widget.user;
    final vitals = <_Vital>[];
    if (user.education != null && user.education!.isNotEmpty) {
      vitals.add(_Vital(Icons.school_outlined, user.education!));
    }
    final faith = user.religion;
    if (faith != null && faith.isNotEmpty) {
      vitals.add(_Vital(Icons.menu_book_outlined, faith));
    }
    if (user.hometown != null && user.hometown!.isNotEmpty) {
      vitals.add(_Vital(Icons.home_outlined, user.hometown!));
    } else if (user.location?.city != null &&
        user.location!.city!.isNotEmpty) {
      vitals.add(_Vital(Icons.home_outlined, user.location!.city!));
    }
    if (user.politics != null && user.politics!.isNotEmpty) {
      vitals.add(_Vital(Icons.account_balance_outlined,
          HingeProfileView._humanize(user.politics)));
    }
    if (user.ethnicity.isNotEmpty) {
      vitals.add(_Vital(Icons.public,
          user.ethnicity.map(HingeProfileView._humanize).join(', ')));
    }
    if ((user.jobTitle ?? '').isNotEmpty) {
      final job = user.workplace != null && user.workplace!.isNotEmpty
          ? '${user.jobTitle} · ${user.workplace}'
          : user.jobTitle!;
      vitals.add(_Vital(Icons.work_outline, job));
    }
    if (user.datingIntentions != null) {
      vitals.add(_Vital(
        Icons.search_rounded,
        HingeProfileView._intentionLabels[user.datingIntentions] ??
            HingeProfileView._humanize(user.datingIntentions),
      ));
    }
    return vitals;
  }

  /// Interleave content the way Hinge does: photo, vitals, prompt, photo,
  /// prompt, photo… so the scroll never feels like a wall of one type.
  List<Widget> _buildContent() {
    final user = widget.user;
    final onLike = widget.onLike;
    final items = <Widget>[];
    final photos = user.photos;
    final prompts = user.prompts;

    if (photos.isNotEmpty) {
      items.add(_PhotoCard(url: photos.first.url, onLike: onLike));
    }
    items.add(_VitalsCard(user: user, vitals: _buildVitals()));

    var pi = 0;
    for (var i = 1; i < photos.length; i++) {
      if (pi < prompts.length) {
        items.add(_PromptCard(prompt: prompts[pi], onLike: onLike));
        pi++;
      }
      items.add(_PhotoCard(url: photos[i].url, onLike: onLike));
    }
    // Any remaining prompts after the photos run out.
    for (; pi < prompts.length; pi++) {
      items.add(_PromptCard(prompt: prompts[pi], onLike: onLike));
    }
    return items;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final likeOpacity = (_dx / 90).clamp(0.0, 1.0);
    final passOpacity = (-_dx / 90).clamp(0.0, 1.0);
    // Subtle card tilt that tracks the finger (max ~4.5°).
    final angle = (_dx / width).clamp(-1.0, 1.0) * 0.08;
    // Fade the card out as it flies past the screen edge on a committed swipe.
    final flyOpacity =
        _flinging ? (1 - (_dx.abs() / (width * 1.25))).clamp(0.0, 1.0) : 1.0;

    return GestureDetector(
      // Horizontal drags swipe the whole profile; vertical drags fall through
      // to the inner ListView so scrolling still works.
      onHorizontalDragUpdate: (d) {
        _anim = null; // detach the animation so it doesn't fight the finger
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
              offset: Offset(_dx, (1 - t) * 24),
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
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
              physics: const BouncingScrollPhysics(),
              children: [
                _Header(
                  user: widget.user,
                  canUndo: widget.canUndo,
                  onUndo: widget.onUndo,
                ),
                const SizedBox(height: 14),
                ..._intersperse(
                  _buildContent(),
                  const SizedBox(height: 14),
                ),
              ],
            ),
            // LIKE / PASS stamps — fade in with the drag, Tinder-style.
            Positioned(
              top: 28,
              left: 24,
              child: Opacity(
                opacity: likeOpacity,
                child: Transform.scale(
                  scale: 0.8 + 0.2 * likeOpacity,
                  child: const _Stamp(text: 'LIKE', color: AppColors.lime),
                ),
              ),
            ),
            Positioned(
              top: 28,
              right: 24,
              child: Opacity(
                opacity: passOpacity,
                child: Transform.scale(
                  scale: 0.8 + 0.2 * passOpacity,
                  child: const _Stamp(text: 'PASS', color: AppColors.nopeRed),
                ),
              ),
            ),
            // Floating pass button — bottom-left, Hinge-style.
            Positioned(
              left: 8,
              bottom: 18,
              child: _CircleButton(
                icon: Icons.close_rounded,
                iconColor: AppColors.textPrimary,
                size: 60,
                onTap: () => _flingPass(width),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Widget> _intersperse(List<Widget> items, Widget separator) {
    if (items.isEmpty) return items;
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i != items.length - 1) out.add(separator);
    }
    return out;
  }
}

class _Vital {
  final IconData icon;
  final String label;
  const _Vital(this.icon, this.label);
}

class _Header extends StatelessWidget {
  final UserModel user;
  final bool canUndo;
  final VoidCallback? onUndo;

  const _Header({required this.user, required this.canUndo, this.onUndo});

  @override
  Widget build(BuildContext context) {
    final pronouns = user.pronouns.isNotEmpty ? user.pronouns.join('/') : null;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      user.name ?? 'Someone',
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                        color: AppColors.textPrimary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.verified_rounded,
                        color: AppColors.grape, size: 22),
                  ],
                ],
              ),
              if (pronouns != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    pronouns,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (canUndo && onUndo != null)
          IconButton(
            onPressed: onUndo,
            icon: const Icon(Icons.undo_rounded, color: AppColors.textSecondary),
            tooltip: 'Undo last pass',
          ),
      ],
    );
  }
}

class _VitalsCard extends StatelessWidget {
  final UserModel user;
  final List<_Vital> vitals;

  const _VitalsCard({required this.user, required this.vitals});

  @override
  Widget build(BuildContext context) {
    final orientation =
        user.orientation.isNotEmpty ? user.orientation.first : null;

    return ClayContainer(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
        children: [
          // Top tri-column row: age | gender | orientation.
          IntrinsicHeight(
            child: Row(
              children: [
                if (user.age != null)
                  _TopVital(
                    icon: Icons.cake_outlined,
                    label: '${user.age}',
                  ),
                if (user.gender != null) ...[
                  const _VDivider(),
                  _TopVital(
                    icon: Icons.person_outline_rounded,
                    label: HingeProfileView._genderLabels[user.gender] ??
                        HingeProfileView._humanize(user.gender),
                  ),
                ],
                if (orientation != null) ...[
                  const _VDivider(),
                  _TopVital(
                    icon: Icons.favorite_border_rounded,
                    label: HingeProfileView._humanize(orientation),
                  ),
                ],
              ],
            ),
          ),
          for (final v in vitals) ...[
            // Inset, soft hairline — aligns with the label text (past the icon)
            // instead of a harsh full-bleed line, for a clean premium list.
            Padding(
              padding: const EdgeInsets.only(left: 56),
              child: Divider(
                height: 1,
                thickness: 1,
                color: AppColors.divider.withValues(alpha: 0.55),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
              child: Row(
                children: [
                  Icon(v.icon, size: 22, color: AppColors.primary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      v.label,
                      style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
        ),
      ),
    );
  }
}

class _TopVital extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TopVital({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.textPrimary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) => VerticalDivider(
        width: 1,
        indent: 14,
        endIndent: 14,
        color: AppColors.divider.withValues(alpha: 0.55),
      );
}

class _PhotoCard extends StatelessWidget {
  final String url;
  final VoidCallback onLike;

  const _PhotoCard({required this.url, required this.onLike});

  @override
  Widget build(BuildContext context) {
    // Cap the photo to a controlled banner height (~46% of the screen) so the
    // card no longer dominates the whole viewport. BoxFit.cover crops cleanly.
    final h = MediaQuery.sizeOf(context).height * 0.46;
    return ClayContainer(
      borderRadius: 24,
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              height: h,
              width: double.infinity,
              child: AppCachedImage(imageUrl: url, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            right: 14,
            bottom: 14,
            child: _HeartButton(onTap: onLike),
          ),
        ],
      ),
    );
  }
}

class _PromptCard extends StatelessWidget {
  final PromptModel prompt;
  final VoidCallback onLike;

  const _PromptCard({required this.prompt, required this.onLike});

  @override
  Widget build(BuildContext context) {
    return ClayContainer(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            prompt.question,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            prompt.answer,
            style: AppTheme.serifHeading(fontSize: 26, height: 1.2),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: _HeartButton(onTap: onLike),
          ),
        ],
      ),
    );
  }
}

/// LIKE / PASS stamp that fades in as the profile is dragged sideways.
class _Stamp extends StatelessWidget {
  final String text;
  final Color color;
  const _Stamp({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: text == 'LIKE' ? -0.2 : 0.2,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

/// White circular heart button shown on each photo/prompt.
class _HeartButton extends StatelessWidget {
  final VoidCallback onTap;
  const _HeartButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _CircleButton(
      icon: Icons.favorite_border_rounded,
      iconColor: AppColors.grape,
      size: 50,
      onTap: () {
        HapticFeedback.mediumImpact();
        onTap();
      },
    );
  }
}

/// Reusable bouncy white circle button with a soft shadow.
class _CircleButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final double size;
  final VoidCallback onTap;

  const _CircleButton({
    required this.icon,
    required this.iconColor,
    required this.size,
    required this.onTap,
  });

  @override
  State<_CircleButton> createState() => _CircleButtonState();
}

class _CircleButtonState extends State<_CircleButton> {
  double _scale = 1;

  void _set(double v) => setState(() => _scale = v);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _set(0.88),
      onTapUp: (_) => _set(1),
      onTapCancel: () => _set(1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: ClayContainer(
          width: widget.size,
          height: widget.size,
          borderRadius: widget.size / 2,
          padding: EdgeInsets.zero,
          alignment: Alignment.center,
          child: Icon(widget.icon,
              color: widget.iconColor, size: widget.size * 0.46),
        ),
      ),
    );
  }
}
