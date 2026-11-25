import 'package:flutter/painting.dart';

/// Elevation tokens. Shadows are soft, low-opacity and tinted with midnight.
abstract final class AppShadows {
  static const List<BoxShadow> none = [];

  /// Resting cards.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0F202020), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x06202020), blurRadius: 4, offset: Offset(0, 1)),
  ];

  /// Primary buttons.
  static const List<BoxShadow> button = [
    BoxShadow(color: Color(0x29202020), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Floating elements: bottom navigation, hero cards.
  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x33202020), blurRadius: 32, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x14202020), blurRadius: 8, offset: Offset(0, 2)),
  ];
}
