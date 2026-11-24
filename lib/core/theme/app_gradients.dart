import 'package:flutter/painting.dart';

import 'app_colors.dart';

/// Gradient tokens.
abstract final class AppGradients {
  /// Soft pastel screen background: lavender fading into warm cream.
  static const LinearGradient background = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.lavender, Color(0xFFF0EDF1), AppColors.cream],
    stops: [0, 0.5, 1],
  );

  /// Warm glow layered over [background] (top-right).
  static const RadialGradient glowYellow = RadialGradient(
    colors: [Color(0x66FFDA69), Color(0x00FFDA69)],
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

  static const LinearGradient mint = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6ED6C4), AppColors.mint],
  );
}
