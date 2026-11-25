import 'package:flutter/painting.dart';

/// 4-point spacing scale.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 40;
  static const double huge = 56;

  /// Horizontal inset for screen content.
  static const double screenHorizontal = lg;

  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
  );

  static const EdgeInsets cardPadding = EdgeInsets.all(lg);
  static const EdgeInsets cardPaddingLarge = EdgeInsets.all(xl);

  /// Inner padding of pills and badges.
  static const EdgeInsets badgePadding = EdgeInsets.symmetric(
    horizontal: sm,
    vertical: 6,
  );
}
