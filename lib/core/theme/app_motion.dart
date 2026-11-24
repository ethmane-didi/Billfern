import 'package:flutter/animation.dart';

/// Animation tokens. Motion should be smooth and subtle.
abstract final class AppMotion {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration medium = Duration(milliseconds: 260);
  static const Duration slow = Duration(milliseconds: 420);

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeOutQuart;

  /// Scale applied to tappable surfaces while pressed.
  static const double pressScale = 0.97;

  /// Opacity of disabled interactive components.
  static const double disabledOpacity = 0.4;
}
