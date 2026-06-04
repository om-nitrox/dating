import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Claymorphism toolkit — REAL puffy clay using inner shadows.
///
/// Authentic claymorphism = a rounded surface with TWO inner shadows (a light
/// highlight on the top-left + a dark shadow on the bottom-right, painted
/// *inside* the shape so it looks inflated) PLUS one big soft outer drop shadow
/// so it floats. Flutter's BoxShadow can't do inner shadows, so [ClayContainer]
/// paints them with a [CustomPainter].
class Clay {
  const Clay._();

  static const double radius = 30;
  static const double radiusSm = 22;
  static const double radiusLg = 40;

  static bool _isDark(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark;

  static Color surface(BuildContext c) =>
      _isDark(c) ? AppColors.darkSurface : AppColors.surface;

  static Color base(BuildContext c) =>
      _isDark(c) ? AppColors.darkBackground : AppColors.background;
}

/// Paints a single puffy clay surface: outer drop shadow → body → inner
/// highlight (top-left) → inner shadow (bottom-right).
class _ClayPainter extends CustomPainter {
  final double radius;
  final Color color;
  final Gradient? gradient;
  final Color highlight;
  final Color depthColor;
  final Color dropColor;
  final double depth;
  final bool pressed;

  _ClayPainter({
    required this.radius,
    required this.color,
    required this.gradient,
    required this.highlight,
    required this.depthColor,
    required this.dropColor,
    required this.depth,
    required this.pressed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // 1) Outer drop shadow — big, soft, offset down. Skipped when pressed.
    if (!pressed) {
      final drop = Paint()
        ..color = dropColor
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 26 * depth);
      canvas.drawRRect(rr.shift(Offset(0, 12 * depth)), drop);
    }

    // 2) Body fill (solid or gradient).
    final body = Paint()..isAntiAlias = true;
    if (gradient != null) {
      body.shader = gradient!.createShader(rect);
    } else {
      body.color = color;
    }
    canvas.drawRRect(rr, body);

    // 3 + 4) Inner shadows — clipped inside the shape.
    final d = (pressed ? 9.0 : 7.0) * depth;
    final blur = (pressed ? 14.0 : 12.0) * depth;
    canvas.save();
    canvas.clipRRect(rr);
    if (pressed) {
      // Recessed: dark settles top-left, light at bottom-right.
      _inner(canvas, rr, depthColor, Offset(d, d), blur);
      _inner(canvas, rr, highlight, Offset(-d, -d), blur * 0.8);
    } else {
      // Raised: highlight top-left, dark shadow bottom-right.
      _inner(canvas, rr, highlight, Offset(d, d), blur);
      _inner(canvas, rr, depthColor, Offset(-d, -d), blur);
    }

    // 5) Satin sheen — a soft top-down highlight band that makes the raised
    // surface read like inflated, lightly-glossy clay (skipped when recessed).
    if (!pressed) {
      final sheenH = size.height * 0.6;
      final sheen = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            highlight.withValues(alpha: gradient != null ? 0.22 : 0.12),
            highlight.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, sheenH));
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, sheenH), sheen);
    }
    canvas.restore();

    // 6) Directional rim light — a hairline edge that runs bright on the
    // top-left and fades to shadow on the bottom-right, crisping the puffy
    // silhouette without a hard border.
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: pressed
            ? [
                depthColor.withValues(alpha: 0.40),
                highlight.withValues(alpha: 0.30),
              ]
            : [
                highlight.withValues(alpha: 0.65),
                depthColor.withValues(alpha: 0.28),
              ],
      ).createShader(rect);
    canvas.drawRRect(rr.deflate(0.6), rim);
  }

  /// Draws an inner shadow of [color] biased toward the side OPPOSITE [offset].
  /// (We fill everything except the shape shifted by [offset]; clipped to the
  /// shape, the blurred edge bleeds inward.)
  void _inner(Canvas canvas, RRect rr, Color color, Offset offset, double blur) {
    final paint = Paint()
      ..color = color
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    final pad = blur * 3 + offset.distance + 24;
    final outer = Path()..addRect(rr.outerRect.inflate(pad));
    final hole = Path()..addRRect(rr.shift(offset));
    final shadow = Path.combine(PathOperation.difference, outer, hole);
    canvas.drawPath(shadow, paint);
  }

  @override
  bool shouldRepaint(_ClayPainter old) =>
      old.color != color ||
      old.gradient != gradient ||
      old.pressed != pressed ||
      old.depth != depth ||
      old.radius != radius ||
      old.highlight != highlight ||
      old.depthColor != depthColor ||
      old.dropColor != dropColor;
}

/// A reusable puffy clay surface.
class ClayContainer extends StatelessWidget {
  final Widget? child;
  final Color? color;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? width;
  final double? height;
  final double depth;

  /// Recessed (carved-in) look — used for inputs / wells.
  final bool pressed;

  /// Kept for API compat (the painter now handles the sheen). Ignored.
  final bool sheen;

  final Gradient? gradient;
  final AlignmentGeometry? alignment;

  const ClayContainer({
    super.key,
    this.child,
    this.color,
    this.borderRadius = Clay.radius,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.depth = 1,
    this.pressed = false,
    this.sheen = true,
    this.gradient,
    this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final base = color ?? Clay.surface(context);
    final colored = gradient != null;

    // Inner highlight / depth / drop tuned per fill type + theme.
    final Color highlight;
    final Color depthColor;
    final Color dropColor;
    if (colored) {
      // On a vivid fill, use translucent white + black so it reads on any hue.
      highlight = Colors.white.withValues(alpha: dark ? 0.30 : 0.50);
      depthColor = Colors.black.withValues(alpha: dark ? 0.34 : 0.22);
      final tint = (gradient is LinearGradient)
          ? (gradient as LinearGradient).colors.first
          : AppColors.primary;
      dropColor = tint.withValues(alpha: dark ? 0.45 : 0.38);
    } else if (dark) {
      highlight = AppColors.clayHighlightDk.withValues(alpha: 0.9);
      depthColor = AppColors.clayShadowDarkDk.withValues(alpha: 0.8);
      dropColor = AppColors.clayDropDk.withValues(alpha: 0.55);
    } else {
      highlight = AppColors.clayHighlight.withValues(alpha: 0.95);
      depthColor = AppColors.clayShadowDark.withValues(alpha: 0.55);
      dropColor = AppColors.clayDrop.withValues(alpha: 0.30);
    }

    Widget content = CustomPaint(
      painter: _ClayPainter(
        radius: borderRadius,
        color: base,
        gradient: gradient,
        highlight: highlight,
        depthColor: depthColor,
        dropColor: dropColor,
        depth: depth,
        pressed: pressed,
      ),
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    if (alignment != null && (width != null || height != null)) {
      content = Align(alignment: alignment!, child: content);
    }

    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: (width == null && height == null) ? alignment : null,
      child: content,
    );
  }
}

/// A tappable clay surface with a satisfying press-down squish (the inner
/// shadows invert to recessed while pressed).
class ClayButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double depth;
  final bool enabled;

  const ClayButton({
    super.key,
    required this.child,
    this.onTap,
    this.color,
    this.gradient,
    this.borderRadius = Clay.radius,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
    this.depth = 1,
    this.enabled = true,
  });

  @override
  State<ClayButton> createState() => _ClayButtonState();
}

class _ClayButtonState extends State<ClayButton> {
  bool _down = false;

  void _set(bool v) {
    if (widget.enabled && widget.onTap != null && _down != v) {
      setState(() => _down = v);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && widget.onTap != null;
    return GestureDetector(
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: active ? widget.onTap : null,
      child: AnimatedScale(
        scale: _down ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: active ? 1 : 0.5,
          duration: const Duration(milliseconds: 150),
          child: ClayContainer(
            depth: widget.depth,
            borderRadius: widget.borderRadius,
            padding: widget.padding,
            color: widget.color,
            gradient: widget.gradient,
            pressed: _down,
            alignment: Alignment.center,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
