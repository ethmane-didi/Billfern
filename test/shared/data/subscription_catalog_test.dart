import 'dart:convert';

import 'package:billfern/shared/data/subscription_catalog.dart';
import 'package:billfern/shared/data/subscription_catalog_repository.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/providers/catalog_providers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

String _catalogJson(List<Map<String, Object?>> services) =>
    jsonEncode({'version': 1, 'services': services});

Map<String, Object?> _entry(
  String id, {
  String? name,
  String category = 'music',
  String? logo,
  List<String> aliases = const [],
  bool popular = false,
}) => {
  'id': id,
  'name': name ?? id,
  'domain': '$id.com',
  'category': category,
  'brandColor': '#1ED760',
  'logo': logo,
  'aliases': aliases,
  'popular': popular,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('bundled catalog', () {
    late SubscriptionCatalog catalog;

    setUpAll(() async {
      catalog = await AssetSubscriptionCatalogRepository(bundle: rootBundle)
          .load();
    });

    test('loads 60–90 services with unique ids', () {
      expect(catalog.items.length, inInclusiveRange(60, 90));
      expect(
        catalog.items.map((i) => i.id).toSet(),
        hasLength(catalog.items.length),
      );
    });

    test('includes the required services', () {
      for (final id in [
        'netflix',
        'disney-plus',
        'hbo-max',
        'prime-video',
        'spotify',
        'apple-music',
        'chatgpt',
        'claude',
        'figma',
        'canva',
        'notion',
        'microsoft-365',
        'icloud-plus',
        'github',
        'xbox-game-pass',
        'strava',
        'duolingo',
        'nordvpn',
        '1password',
        'viaplay',
        'tv2-play',
        'storytel',
        'podme',
        'sats',
      ]) {
        expect(catalog.byId(id), isNotNull, reason: id);
      }
    });

    test('every bundled logo path exists and is an SVG', () async {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      final assets = manifest.listAssets().toSet();
      final withLogo = catalog.items.where((i) => i.logoAsset != null);
      expect(withLogo.length, greaterThanOrEqualTo(50));
      for (final item in withLogo) {
        expect(assets, contains(item.logoAsset), reason: item.id);
        expect(item.logoAsset, endsWith('.svg'));
      }
    });

    test('services without a permitted logo have none', () {
      for (final id in ['chatgpt', 'disney-plus', 'microsoft-365', 'slack']) {
        expect(catalog.byId(id)!.logoAsset, isNull, reason: id);
      }
    });

    test('contains no prices', () async {
      final raw = await rootBundle.loadString(
        AssetSubscriptionCatalogRepository.defaultPath,
      );
      expect(raw, isNot(contains('price')));
    });
  });

  group('parsing', () {
    test('drops logos missing from the asset manifest', () {
      final catalog = AssetSubscriptionCatalogRepository.parse(
        _catalogJson([
          _entry('present', logo: 'assets/logos/present.svg'),
          _entry('missing', logo: 'assets/logos/missing.svg'),
        ]),
        availableAssets: {'assets/logos/present.svg'},
      );
      expect(catalog.byId('present')!.logoAsset, 'assets/logos/present.svg');
      expect(catalog.byId('missing')!.logoAsset, isNull);
    });

    test('keeps the first of duplicate ids', () {
      final catalog = AssetSubscriptionCatalogRepository.parse(
        _catalogJson([_entry('a', name: 'First'), _entry('a', name: 'Second')]),
      );
      expect(catalog.items, hasLength(1));
      expect(catalog.byId('a')!.name, 'First');
    });

    test('rejects unknown categories', () {
      expect(
        () => AssetSubscriptionCatalogRepository.parse(
          _catalogJson([_entry('x', category: 'astrology')]),
        ),
        throwsFormatException,
      );
    });
  });

  group('search', () {
    final catalog = AssetSubscriptionCatalogRepository.parse(
      _catalogJson([
        _entry(
          'netflix',
          name: 'Netflix',
          category: 'entertainment',
          popular: true,
        ),
        _entry(
          'disney-plus',
          name: 'Disney+',
          category: 'entertainment',
          aliases: ['disney plus'],
        ),
        _entry(
          'hbo-max',
          name: 'HBO Max',
          category: 'entertainment',
          aliases: ['max', 'hbo'],
        ),
        _entry('spotify', name: 'Spotify', popular: true),
        _entry('apple-music', name: 'Apple Music'),
        _entry(
          'tv2-play',
          name: 'TV 2 Play',
          category: 'entertainment',
          aliases: ['tv2'],
        ),
        _entry('sats', name: 'SATS', category: 'health'),
      ]),
    );

    test('empty query returns popular services', () {
      expect(catalog.search('').map((i) => i.id), ['netflix', 'spotify']);
    });

    test('ranks exact and prefix matches first', () {
      expect(catalog.search('net').first.id, 'netflix');
      expect(catalog.search('music').first.id, 'apple-music');
    });

    test('matches aliases, "+" and spacing', () {
      expect(catalog.search('hbo').first.id, 'hbo-max');
      expect(catalog.search('Disney Plus').first.id, 'disney-plus');
      expect(catalog.search('disney+').first.id, 'disney-plus');
      expect(catalog.search('tv2').first.id, 'tv2-play');
      expect(catalog.search('TV 2').first.id, 'tv2-play');
    });

    test('ignores case and accents', () {
      expect(catalog.search('SPÖTIFY').first.id, 'spotify');
    });

    test('filters by category', () {
      final results = catalog.search('', category: SubscriptionCategory.health);
      expect(results.map((i) => i.id), ['sats']);
      expect(
        catalog
            .search('spo', category: SubscriptionCategory.music)
            .map((i) => i.id),
        ['spotify'],
      );
    });

    test('returns nothing for unknown services', () {
      expect(catalog.search('zzzz'), isEmpty);
    });
  });

  test('search provider follows the query notifier', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    container.read(catalogQueryProvider.notifier).setText('spot');
    final results = await container.read(catalogSearchResultsProvider.future);
    expect(results.first.id, 'spotify');

    container
        .read(catalogQueryProvider.notifier)
        .setCategory(SubscriptionCategory.gaming);
    container.read(catalogQueryProvider.notifier).setText('');
    final gaming = await container.read(catalogSearchResultsProvider.future);
    expect(gaming, isNotEmpty);
    expect(
      gaming.every((i) => i.category == SubscriptionCategory.gaming),
      isTrue,
    );
  });
}
