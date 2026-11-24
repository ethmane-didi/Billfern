import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Billfern type scale, built on Manrope.
///
/// Google Fonts registers one font family per weight, so **never change
/// `fontWeight` with `copyWith`** on these styles — add a new token instead.
/// Changing `color` or `fontSize` via `copyWith` is fine.
abstract final class AppTypography {
  static const List<FontFeature> _tabularFigures = [
    FontFeature.tabularFigures(),
  ];

  static TextStyle _manrope(
    double fontSize,
    FontWeight fontWeight, {
    double height = 1.35,
    double letterSpacing = 0,
    Color color = AppColors.textPrimary,
    List<FontFeature>? fontFeatures,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
      fontFeatures: fontFeatures,
    );
  }

  // ---------------------------------------------------------------------------
  // Financial figures — bold, tight, tabular.
  // ---------------------------------------------------------------------------

  /// Hero balance, e.g. monthly spending total.
  static final TextStyle amountHero = _manrope(
    44,
    FontWeight.w800,
    height: 1.05,
    letterSpacing: -1.6,
    fontFeatures: _tabularFigures,
  );

  static final TextStyle amountLarge = _manrope(
    28,
    FontWeight.w800,
    height: 1.1,
    letterSpacing: -0.8,
    fontFeatures: _tabularFigures,
  );

  static final TextStyle amountMedium = _manrope(
    20,
    FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.4,
    fontFeatures: _tabularFigures,
  );

  static final TextStyle amountSmall = _manrope(
    15,
    FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
    fontFeatures: _tabularFigures,
  );

  // ---------------------------------------------------------------------------
  // Headings
  // ---------------------------------------------------------------------------

  static final TextStyle displayLarge = _manrope(
    36,
    FontWeight.w800,
    height: 1.1,
    letterSpacing: -1.2,
  );

  static final TextStyle headlineLarge = _manrope(
    28,
    FontWeight.w800,
    height: 1.15,
    letterSpacing: -0.8,
  );

  static final TextStyle headlineMedium = _manrope(
    24,
    FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.6,
  );

  static final TextStyle titleLarge = _manrope(
    20,
    FontWeight.w700,
    height: 1.25,
    letterSpacing: -0.4,
  );

  static final TextStyle titleMedium = _manrope(
    17,
    FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
  );

  static final TextStyle titleSmall = _manrope(15, FontWeight.w600);

  /// Heavy style for monograms and compact badges.
  static final TextStyle monogram = _manrope(
    16,
    FontWeight.w800,
    height: 1,
    letterSpacing: -0.2,
  );

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  static final TextStyle bodyLarge = _manrope(16, FontWeight.w500, height: 1.5);

  static final TextStyle bodyMedium = _manrope(
    14,
    FontWeight.w500,
    height: 1.45,
  );

  static final TextStyle bodySmall = _manrope(
    13,
    FontWeight.w500,
    height: 1.4,
    color: AppColors.textMuted,
  );

  // ---------------------------------------------------------------------------
  // Labels
  // ---------------------------------------------------------------------------

  /// Button labels.
  static final TextStyle labelLarge = _manrope(
    15,
    FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.1,
  );

  static final TextStyle labelMedium = _manrope(
    13,
    FontWeight.w600,
    height: 1.25,
    letterSpacing: 0.1,
  );

  /// Overlines and small caps-style labels.
  static final TextStyle labelSmall = _manrope(
    11,
    FontWeight.w700,
    height: 1.2,
    letterSpacing: 0.6,
    color: AppColors.textMuted,
  );

  /// Material text theme mapped onto the Billfern scale.
  static final TextTheme textTheme = TextTheme(
    displayLarge: displayLarge,
    displayMedium: headlineLarge,
    displaySmall: headlineMedium,
    headlineLarge: headlineLarge,
    headlineMedium: headlineMedium,
    headlineSmall: titleLarge,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    titleSmall: titleSmall,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
