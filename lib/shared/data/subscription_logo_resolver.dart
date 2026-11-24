import 'package:flutter/painting.dart';

import '../models/subscription.dart';
import '../models/subscription_branding.dart';
import '../models/subscription_catalog_item.dart';
import '../models/subscription_category.dart';
import '../models/subscription_glyph.dart';

/// Resolves a logo URL for a website domain. Reserved for a future provider
/// such as Logo.dev; the app ships without any remote logo dependency.
abstract interface class RemoteLogoProvider {
  Uri? logoFor(String domain);
}

/// Default provider: never resolves remote logos, keeping the app offline.
class NoRemoteLogoProvider implements RemoteLogoProvider {
  const NoRemoteLogoProvider();

  @override
  Uri? logoFor(String domain) => null;
}

/// Decides how a subscription or catalog service is drawn.
///
/// Priority:
/// 1. Bundled SVG brand mark from the catalog.
/// 2. Bundled raster logo from the catalog.
/// 3. Remote logo for the service or custom website domain (future).
/// 4. The user's chosen glyph, then coloured initials, then the category
///    icon when the name has no letters or digits.
class SubscriptionLogoResolver {
  const SubscriptionLogoResolver({
    this.remoteProvider = const NoRemoteLogoProvider(),
  });

  final RemoteLogoProvider remoteProvider;

  static const Set<String> _rasterExtensions = {
    '.png',
    '.webp',
    '.jpg',
    '.jpeg',
  };

  /// Branding for a catalog service on its own (e.g. in search results).
  SubscriptionBranding forCatalogItem(SubscriptionCatalogItem item) {
    return resolve(name: item.name, category: item.category, catalogItem: item);
  }

  /// Branding for a user subscription; [catalogItem] is its catalog entry,
  /// if any.
  SubscriptionBranding forSubscription(
    Subscription subscription, {
    SubscriptionCatalogItem? catalogItem,
  }) {
    return resolve(
      name: catalogItem?.name ?? subscription.name,
      category: subscription.category,
      catalogItem: catalogItem,
      websiteDomain: subscription.websiteDomain,
      customColor: subscription.customColor,
      customGlyph: subscription.customGlyph,
    );
  }

  SubscriptionBranding resolve({
    required String name,
    required SubscriptionCategory category,
    SubscriptionCatalogItem? catalogItem,
    String? websiteDomain,
    Color? customColor,
    SubscriptionGlyph? customGlyph,
  }) {
    final color = catalogItem?.brandColor ?? customColor ?? category.color;
    final fallback = _fallback(name, category, customGlyph);

    final asset = catalogItem?.logoAsset;
    if (asset != null) {
      final lower = asset.toLowerCase();
      if (lower.endsWith('.svg')) {
        return SubscriptionBranding(
          name: name,
          color: color,
          logo: SvgAssetLogo(asset),
          fallback: fallback,
        );
      }
      if (_rasterExtensions.any(lower.endsWith)) {
        return SubscriptionBranding(
          name: name,
          color: color,
          logo: RasterAssetLogo(asset),
          fallback: fallback,
        );
      }
    }

    final domain = catalogItem?.domain ?? websiteDomain;
    final remote = domain == null ? null : remoteProvider.logoFor(domain);
    if (remote != null) {
      return SubscriptionBranding(
        name: name,
        color: color,
        logo: RemoteLogo(remote),
        fallback: fallback,
      );
    }

    return SubscriptionBranding(name: name, color: color, logo: fallback);
  }

  static LogoSource _fallback(
    String name,
    SubscriptionCategory category,
    SubscriptionGlyph? glyph,
  ) {
    if (glyph != null) return GlyphLogo(glyph.icon);
    final initials = initialsFor(name);
    return initials.isEmpty ? GlyphLogo(category.icon) : InitialsLogo(initials);
  }

  /// Up to two initials: "Apple Music" → "AM", "Netflix" → "N".
  /// Returns an empty string when the name has no letters or digits.
  static String initialsFor(String name) {
    final words = name
        .split(RegExp(r'[\s\-_/]+'))
        .map(
          (word) =>
              word.replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), ''),
        )
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    return words
        .take(2)
        .map((word) => String.fromCharCode(word.runes.first))
        .join()
        .toUpperCase();
  }
}
