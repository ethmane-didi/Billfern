import 'package:flutter/painting.dart';

/// Billfern color tokens.
///
/// The brand palette is defined first, followed by semantic aliases. Widgets
/// should reference the semantic tokens (`textPrimary`, `success`, `border`…)
/// rather than raw brand colors whenever a semantic token exists.
abstract final class AppColors {
  // ---------------------------------------------------------------------------
  // Brand palette
  // ---------------------------------------------------------------------------

  /// Primary brand color. Used for primary actions, dark cards and text.
  static const Color midnight = Color(0xFF202020);

  /// Accent color for highlights, selected states and CTAs on dark surfaces.
  static const Color yellow = Color(0xFFFFDA69);

  /// Success / savings color.
  static const Color mint = Color(0xFF43C4AE);

  /// Cool pastel used in background gradients and soft containers.
  static const Color lavender = Color(0xFFE7E8F4);

  /// Warm pastel used in background gradients and soft containers.
  static const Color cream = Color(0xFFF5EFEB);

  /// Card and sheet surface.
  static const Color surface = Color(0xFFFFFFFF);

  /// Brand secondary text color (3.7:1 on white).
  ///
  /// Only meets WCAG AA for large text (≥18px, or ≥14px bold), icons and
  /// non-essential hints. Use [textMuted] for small secondary copy.
  static const Color secondaryText = Color(0xFF85858D);

  // ---------------------------------------------------------------------------
  // Tints (opaque, pre-blended on white)
  // ---------------------------------------------------------------------------

  static const Color yellowSoft = Color(0xFFFFF6D9);
  static const Color mintSoft = Color(0xFFDDF4F0);
  static const Color peachSoft = Color(0xFFFFE6D9);
  static const Color skySoft = Color(0xFFDDEBFF);
  static const Color midnightElevated = Color(0xFF2E2E2E);

  // ---------------------------------------------------------------------------
  // Text
  // ---------------------------------------------------------------------------

  static const Color textPrimary = midnight;

  /// Large / non-essential secondary text. See [secondaryText].
  static const Color textSecondary = secondaryText;

  /// AA-compliant secondary text for small copy (5.3:1 on white, 4.6:1 on
  /// cream).
  static const Color textMuted = Color(0xFF6B6B73);

  static const Color textOnDark = surface;

  /// Secondary text on [midnight] surfaces (≈6.7:1).
  static const Color textOnDarkMuted = Color(0xA6FFFFFF);

  /// Text placed on [yellow] or [mint] fills.
  static const Color textOnAccent = midnight;

  // ---------------------------------------------------------------------------
  // Semantic status
  // ---------------------------------------------------------------------------

  static const Color success = mint;

  /// Success text/icons on light surfaces (5.8:1 on white).
  static const Color successStrong = Color(0xFF17725F);

  static const Color danger = Color(0xFFFF6B6B);

  /// Danger text/icons on light surfaces (5.4:1 on white).
  static const Color dangerStrong = Color(0xFFC2363B);

  /// Danger text/icons on [midnight] surfaces.
  static const Color dangerOnDark = Color(0xFFFF8A80);

  static const Color dangerSoft = Color(0xFFFDE4E4);

  // ---------------------------------------------------------------------------
  // Lines & overlays
  // ---------------------------------------------------------------------------

  static const Color border = Color(0x14202020);
  static const Color borderStrong = Color(0x29202020);
  static const Color overlayOnDark = Color(0x1AFFFFFF);

  /// Unselected icons on [midnight] navigation surfaces.
  static const Color navInactive = Color(0x99FFFFFF);

  static const Color transparent = Color(0x00000000);

  /// Background tints for subscription icons without a brand color.
  static const List<Color> iconTints = [
    lavender,
    yellowSoft,
    mintSoft,
    peachSoft,
    skySoft,
    cream,
  ];
}
