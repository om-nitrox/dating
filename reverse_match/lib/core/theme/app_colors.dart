import 'package:flutter/material.dart';

/// "Velvet Burgundy & Champagne" claymorphism palette.
///
/// Warm ivory clay surfaces + velvet-burgundy primary + champagne-gold metallic
/// accent + deep wine-charcoal text. Romantic and premium (wine, candlelight,
/// date-night) — deliberately NOT the pink/red dating-app cliché.
///
/// Token NAMES are preserved from the original system so the ~100 files
/// referencing them keep compiling — only VALUES changed. A token's *semantic*
/// (e.g. `grape` = the playful accent used on hearts / verified badges) is kept,
/// but its hue is remapped into this palette (grape → champagne gold).
class AppColors {
  // Primary — velvet burgundy (CTAs, like, brand).
  static const Color primary = Color(0xFF9E2A4E);
  static const Color primaryLight = Color(0xFFC24E70);
  static const Color primaryDark = Color(0xFF7C1E3C);

  // Secondary — champagne gold (the single metallic accent).
  static const Color secondary = Color(0xFFC8A24C);
  static const Color secondaryLight = Color(0xFFDCC081);

  // Neutral — warm ivory clay surfaces (light theme).
  static const Color background = Color(0xFFF4EDE4); // warm ivory base
  static const Color surface = Color(0xFFFFFCF7); // raised warm-white clay card
  static const Color surfaceVariant = Color(0xFFEDE2D5); // recessed well
  static const Color textPrimary = Color(0xFF322028); // deep wine-charcoal
  static const Color textSecondary = Color(0xFF8A7670);
  static const Color textHint = Color(0xFFB3A39A);
  static const Color divider = Color(0xFFE7D9C9);

  // Button + pill accents — burgundy clay.
  static const Color pill = Color(0xFF9E2A4E);
  static const Color pillDisabled = Color(0xFFE0D2C6);
  static const Color inputFill = Color(0xFFFFFCF7);
  static const Color inputBorder = Color(0xFFE7D9C9);

  // Status
  static const Color success = Color(0xFF4FA07A); // refined sage (reads "go")
  static const Color error = Color(0xFFB3324C); // burgundy-red
  static const Color warning = Color(0xFFD99A4E); // amber

  // Swipe
  static const Color likeGreen = Color(0xFF4FA07A); // sage green (like)
  static const Color nopeRed = Color(0xFFB3324C); // burgundy-red (nope)

  // Boost — kept metallic; gold pulled toward champagne for cohesion.
  static const Color bronze = Color(0xFFCD7F32);
  static const Color silver = Color(0xFFC0C0C0);
  static const Color gold = Color(0xFFE2B73D);

  // ---- Velvet clay accents ----
  static const Color hot = Color(0xFFB83C5E); // wine-rose (fire / hot)
  static const Color grape = Color(0xFFC8A24C); // champagne gold (hearts/verified)
  static const Color sky = Color(0xFF6E9E94); // muted sage-teal (rare accent)
  static const Color lime = Color(0xFF4FA07A); // sage (like)
  static const Color sunset = Color(0xFFD99A4E); // amber (undo)

  /// Signature burgundy→rose→gold velvet gradient for primary CTAs.
  static const List<Color> hypeGradient = [primary, hot, secondary];
  static const List<Color> clayGradient = [primary, secondary];

  // ---- Claymorphism shadow tokens (LIGHT theme — warm ivory) ----
  /// Inner top-left highlight (lifts the surface).
  static const Color clayHighlight = Color(0xFFFFFFFF);
  /// Inner bottom-right shadow (warm taupe — the clay "curve away").
  static const Color clayShadowDark = Color(0xFFD7C1AC);
  /// Legacy alias kept for any old references.
  static const Color clayShadowLight = Color(0xFFFFFFFF);
  /// Big soft outer drop shadow (warm).
  static const Color clayDrop = Color(0xFFC9B099);

  // ---- Dark theme — "Midnight Wine" deep wine-plum clay ----
  static const Color darkBackground = Color(0xFF1A1119);
  static const Color darkSurface = Color(0xFF271A26);
  static const Color darkSurfaceVariant = Color(0xFF33232F);
  static const Color darkTextPrimary = Color(0xFFF3E9EC);
  static const Color darkTextSecondary = Color(0xFFBBA7B0);
  static const Color darkDivider = Color(0xFF3D2B38);

  /// Dark-theme clay shadows.
  static const Color clayHighlightDk = Color(0xFF3A2836); // faint wine lift
  static const Color clayShadowDarkDk = Color(0xFF0E0810); // deep recess
  static const Color clayDropDk = Color(0xFF080509);
  // Legacy aliases.
  static const Color clayShadowLightDk = Color(0xFF3A2836);
}
