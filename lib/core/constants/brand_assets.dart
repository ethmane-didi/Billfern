/// Billfern's own brand assets.
///
/// Kept apart from third-party subscription logos (`assets/logos/`, rendered
/// by `SubscriptionLogo`). Use them through `BillfernLogo`; never crop or
/// recolour them in code. The launcher icon uses a separate symbol-only
/// asset (not yet supplied).
abstract final class BrandAssets {
  /// Full logo: the "B" mark and "Billfern" wordmark on a dark rounded tile,
  /// square (1254 × 1254) with transparent corners.
  static const String logo = 'assets/branding/billfern_logo.png';

  /// Width ÷ height of [logo].
  static const double logoAspectRatio = 1;
}
