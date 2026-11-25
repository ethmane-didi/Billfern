import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Gradient tokens.
abstract final class AppGradients {
  /// Soft pastel screen background: warm cream at the top, lavender in the
  /// middle, a hint of mint at the bottom.
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.cream, AppColors.lavender, AppColors.mintMist],
    stops: [0, 0.55, 1],
  );

  /// Warm glow layered over [background] (top-right).
  static const RadialGradient glowYellow = RadialGradient(
    colors: [Color(0x40FFDA69), Color(0x00FFDA69)],
  );

  /// Cool glow layered over [background] (left edge).
  static const RadialGradient glowMint = RadialGradient(
    colors: [Color(0x2943C4AE), Color(0x0043C4AE)],
  );

  /// Accent glow used inside dark cards.
  static const RadialGradient glowYellowOnDark = RadialGradient(
    colors: [Color(0x40FFDA69), Color(0x00FFDA69)],
  );

  /// Premium dark card fill.
  static const LinearGradient midnight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.midnightElevated, AppColors.midnight],
  );

  static const LinearGradient accent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFE592), AppColors.yellow],
  );

  /// Soft tinted card used for AI insights.
  static const LinearGradient insight = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.yellowSoft, AppColors.surface, AppColors.mintSoft],
    stops: [0, 0.55, 1],
  );

  static const LinearGradient mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6ED6C4), AppColors.mint],
  );
}
