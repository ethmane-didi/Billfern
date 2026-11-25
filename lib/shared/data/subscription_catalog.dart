import '../models/subscription_catalog_item.dart';
import '../models/subscription_category.dart';

/// In-memory, indexed catalog of subscription services.
class SubscriptionCatalog {
  SubscriptionCatalog(Iterable<SubscriptionCatalogItem> items)
    : items = List.unmodifiable(items),
      _byId = {for (final item in items) item.id: item} {
    assert(_byId.length == this.items.length, 'Catalog ids must be unique.');
  }

  static final SubscriptionCatalog empty = SubscriptionCatalog(const []);

  /// All services, in catalog order.
  final List<SubscriptionCatalogItem> items;
  final Map<String, SubscriptionCatalogItem> _byId;

  SubscriptionCatalogItem? byId(String? id) => id == null ? null : _byId[id];

  List<SubscriptionCatalogItem> get popular => [
    for (final item in items)
      if (item.isPopular) item,
  ];

  /// Searches by name, alias and domain, optionally limited to [category].
  ///
  /// An empty [query] returns the category's services (or the popular ones
  /// when no category is set), popular first. Matching ignores case, accents,
  /// spacing and punctuation, and "+" matches "plus". Results are ranked:
  /// exact name, name prefix, word prefix, alias, then substring matches.
  List<SubscriptionCatalogItem> search(
    String query, {
    SubscriptionCategory? category,
    int? limit,
  }) {
    final scoped = category == null
        ? items
        : [
            for (final item in items)
              if (item.category == category) item,
          ];
    final needle = normalize(query);

    List<SubscriptionCatalogItem> results;
    if (needle.isEmpty) {
      results = category == null
          ? popular
          : ([...scoped]..sort((a, b) => _popularFirst(a, b)));
    } else {
      final scored = <({SubscriptionCatalogItem item, int score})>[];
      for (final item in scoped) {
        final score = _score(item, needle);
        if (score > 0) scored.add((item: item, score: score));
      }
      scored.sort((a, b) {
        final byScore = b.score.compareTo(a.score);
        if (byScore != 0) return byScore;
        final byPopular = _popularFirst(a.item, b.item);
        return byPopular != 0 ? byPopular : a.item.name.compareTo(b.item.name);
      });
      results = [for (final entry in scored) entry.item];
    }
    return limit == null ? results : results.take(limit).toList();
  }

  static int _popularFirst(
    SubscriptionCatalogItem a,
    SubscriptionCatalogItem b,
  ) {
    if (a.isPopular == b.isPopular) return 0;
    return a.isPopular ? -1 : 1;
  }

  static int _score(SubscriptionCatalogItem item, String needle) {
    final name = normalize(item.name);
    if (name == needle) return 100;
    if (name.startsWith(needle)) return 80;
    final words = _words(item.name);
    if (words.any((word) => word.startsWith(needle))) return 70;
    for (final alias in item.aliases) {
      final normalized = normalize(alias);
      if (normalized == needle) return 65;
      if (normalized.startsWith(needle)) return 55;
    }
    if (name.contains(needle)) return 40;
    if (normalize(item.domain).startsWith(needle)) return 35;
    if (item.aliases.any((alias) => normalize(alias).contains(needle))) {
      return 20;
    }
    return 0;
  }

  static List<String> _words(String value) => [
    for (final word in value.split(RegExp(r'[\s\-.]+')))
      if (normalize(word).isNotEmpty) normalize(word),
  ];

  static const Map<String, String> _accents = {
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ä': 'a',
    'å': 'a',
    'æ': 'ae',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ë': 'e',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ï': 'i',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'ö': 'o',
    'ø': 'o',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ü': 'u',
    'ñ': 'n',
    'ç': 'c',
  };

  /// Lower-cases, folds accents, turns "+" into "plus" and drops everything
  /// that is not a letter or digit.
  static String normalize(String value) {
    final buffer = StringBuffer();
    for (final char in value.toLowerCase().split('')) {
      if (char == '+') {
        buffer.write('plus');
      } else {
        final folded = _accents[char] ?? char;
        if (RegExp(r'[a-z0-9]').hasMatch(folded)) buffer.write(folded);
      }
    }
    return buffer.toString();
  }
}
