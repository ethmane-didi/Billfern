import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/subscription_catalog_item.dart';
import 'subscription_catalog.dart';

/// Source of the subscription service catalog.
abstract interface class SubscriptionCatalogRepository {
  Future<SubscriptionCatalog> load();
}

/// Loads the bundled catalog from `assets/data/subscription_catalog.json`.
///
/// Logo paths that are not present in the asset manifest are dropped, so a
/// missing file falls back to initials instead of failing at render time.
class AssetSubscriptionCatalogRepository
    implements SubscriptionCatalogRepository {
  const AssetSubscriptionCatalogRepository({
    required this.bundle,
    this.path = defaultPath,
  });

  static const String defaultPath = 'assets/data/subscription_catalog.json';

  final AssetBundle bundle;
  final String path;

  @override
  Future<SubscriptionCatalog> load() async {
    // Decode manually rather than via loadString, which hands large files
    // to an isolate and cannot complete inside widget tests' fake async zone.
    final bytes = await bundle.load(path);
    final source = utf8.decode(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    final manifest = await AssetManifest.loadFromAssetBundle(bundle);
    return parse(source, availableAssets: manifest.listAssets().toSet());
  }

  /// Parses catalog JSON. When [availableAssets] is given, logo paths not in
  /// it are removed. Duplicate ids keep their first occurrence.
  static SubscriptionCatalog parse(
    String source, {
    Set<String>? availableAssets,
  }) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, Object?> || decoded['services'] is! List) {
      throw const FormatException('Catalog must contain a "services" list.');
    }

    final seen = <String>{};
    final items = <SubscriptionCatalogItem>[];
    for (final entry in decoded['services']! as List) {
      if (entry is! Map<String, Object?>) {
        throw FormatException('Invalid catalog entry: $entry');
      }
      var item = SubscriptionCatalogItem.fromJson(entry);
      if (!seen.add(item.id)) continue;
      final logo = item.logoAsset;
      if (logo != null &&
          availableAssets != null &&
          !availableAssets.contains(logo)) {
        item = item.copyWithoutLogo();
      }
      items.add(item);
    }
    return SubscriptionCatalog(items);
  }
}
