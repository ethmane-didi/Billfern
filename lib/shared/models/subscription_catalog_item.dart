import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

import 'subscription_category.dart';

/// A known subscription service the user can pick when adding a
/// subscription. Catalog entries carry identity and branding only — never
/// prices, which depend on country, plan and currency.
@immutable
class SubscriptionCatalogItem {
  const SubscriptionCatalogItem({
    required this.id,
    required this.name,
    required this.domain,
    required this.category,
    this.brandColor,
    this.logoAsset,
    this.aliases = const [],
    this.isPopular = false,
    this.regions = const [],
  });

  /// Parses one entry of `assets/data/subscription_catalog.json`. Throws a
  /// [FormatException] when a required field is missing or invalid.
  factory SubscriptionCatalogItem.fromJson(Map<String, Object?> json) {
    String requireString(String key) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value;
      throw FormatException('Catalog entry is missing "$key": $json');
    }

    final categoryKey = requireString('category');
    final category = SubscriptionCategory.tryParse(categoryKey);
    if (category == null) {
      throw FormatException('Unknown catalog category "$categoryKey".');
    }

    final logo = json['logo'];
    return SubscriptionCatalogItem(
      id: requireString('id'),
      name: requireString('name'),
      domain: requireString('domain'),
      category: category,
      brandColor: parseHexColor(json['brandColor']),
      logoAsset: logo is String && logo.isNotEmpty ? logo : null,
      aliases: _stringList(json['aliases']),
      isPopular: json['popular'] == true,
      regions: _stringList(json['regions']),
    );
  }

  final String id;
  final String name;

  /// Primary website, e.g. `netflix.com`.
  final String domain;

  final SubscriptionCategory category;

  /// Official brand colour, or `null` when not verified.
  final Color? brandColor;

  /// Bundled logo (`assets/logos/<id>.svg`), or `null` when none is bundled.
  final String? logoAsset;

  /// Alternative names matched by search, e.g. "hbo" for HBO Max.
  final List<String> aliases;

  final bool isPopular;

  /// Market tags such as `nordic`. Empty means global.
  final List<String> regions;

  SubscriptionCatalogItem copyWithoutLogo() => SubscriptionCatalogItem(
    id: id,
    name: name,
    domain: domain,
    category: category,
    brandColor: brandColor,
    aliases: aliases,
    isPopular: isPopular,
    regions: regions,
  );

  /// Parses `#RRGGBB` (or `RRGGBB`) into an opaque colour.
  static Color? parseHexColor(Object? value) {
    if (value is! String) return null;
    final hex = value.startsWith('#') ? value.substring(1) : value;
    if (hex.length != 6) return null;
    final rgb = int.tryParse(hex, radix: 16);
    return rgb == null ? null : Color(0xFF000000 | rgb);
  }

  static List<String> _stringList(Object? value) => value is List
      ? List.unmodifiable(value.whereType<String>())
      : const <String>[];

  @override
  bool operator ==(Object other) =>
      other is SubscriptionCatalogItem && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SubscriptionCatalogItem($id)';
}
