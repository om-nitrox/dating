import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Claymorphism theme — soft pastel lavender + mint, puffy rounded surfaces.
class AppTheme {
  /// Big rounded display heading used on onboarding / auth screens.
  /// Switched to a soft rounded sans (Baloo 2) to match the clay vibe.
  static TextStyle serifHeading({
    double fontSize = 30,
    Color color = AppColors.textPrimary,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = -0.4,
    double height = 1.15,
  }) {
    return GoogleFonts.baloo2(
      fontSize: fontSize,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
    );
    return _common(
      base,
      bg: AppColors.background,
      surface: AppColors.surface,
      surfaceVariant: AppColors.surfaceVariant,
      textPrimary: AppColors.textPrimary,
      textSecondary: AppColors.textSecondary,
      textHint: AppColors.textHint,
      border: AppColors.inputBorder,
    );
  }

  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.dark,
        primary: AppColors.primaryLight,
        secondary: AppColors.secondaryLight,
        surface: AppColors.darkSurface,
        error: AppColors.error,
      ),
    );
    return _common(
      base,
      bg: AppColors.darkBackground,
      surface: AppColors.darkSurface,
      surfaceVariant: AppColors.darkSurfaceVariant,
      textPrimary: AppColors.darkTextPrimary,
      textSecondary: AppColors.darkTextSecondary,
      textHint: AppColors.darkTextSecondary,
      border: AppColors.darkDivider,
    );
  }

  static ThemeData _common(
    ThemeData base, {
    required Color bg,
    required Color surface,
    required Color surfaceVariant,
    required Color textPrimary,
    required Color textSecondary,
    required Color textHint,
    required Color border,
  }) {
    const r = 22.0;
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: serifHeading(fontSize: 34, color: textPrimary),
        displayMedium: serifHeading(fontSize: 30, color: textPrimary),
        headlineLarge: serifHeading(fontSize: 28, color: textPrimary),
        headlineMedium: serifHeading(fontSize: 24, color: textPrimary),
        bodyLarge: GoogleFonts.inter(
          fontSize: 15,
          color: textPrimary,
          height: 1.5,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: textSecondary,
          height: 1.5,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: bg,
        foregroundColor: textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.baloo2(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary, size: 22),
      ),
      // Clay-consistent elevated button: solid coral with a soft puffy coral
      // drop shadow + big radius, so every ElevatedButton across the app
      // floats like the gradient ClayButtons rather than looking flat.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.pillDisabled;
            }
            return AppColors.primary;
          }),
          foregroundColor: const WidgetStatePropertyAll(Colors.white),
          iconColor: const WidgetStatePropertyAll(Colors.white),
          minimumSize: const WidgetStatePropertyAll(Size(140, 54)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(r)),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return 0;
            if (states.contains(WidgetState.pressed)) return 2;
            return 9;
          }),
          shadowColor: const WidgetStatePropertyAll(AppColors.primary),
          overlayColor: WidgetStatePropertyAll(
            Colors.white.withValues(alpha: 0.14),
          ),
        ),
      ),
      // Clay-consistent outlined button: puffy surface tile with a soft
      // neutral drop shadow (matches ClayButton's raised feel).
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.primary),
          backgroundColor: WidgetStatePropertyAll(surface),
          minimumSize: const WidgetStatePropertyAll(Size(double.infinity, 54)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(r)),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(color: AppColors.primary.withValues(alpha: 0.35),
                width: 1.4),
          ),
          textStyle: WidgetStatePropertyAll(
            GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 1;
            return 6;
          }),
          shadowColor: WidgetStatePropertyAll(
            AppColors.clayShadowDark.withValues(alpha: 0.9),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        hintStyle: GoogleFonts.inter(fontSize: 16, color: textHint),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(r),
          borderSide: const BorderSide(color: AppColors.error, width: 1.6),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(26),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textPrimary,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: bg,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: AppColors.primary,
        unselectedItemColor: textSecondary,
        backgroundColor: surface,
        type: BottomNavigationBarType.fixed,
      ),
      colorScheme: base.colorScheme.copyWith(
        surfaceContainerHighest: surfaceVariant,
        outline: border,
      ),
    );
  }
}
