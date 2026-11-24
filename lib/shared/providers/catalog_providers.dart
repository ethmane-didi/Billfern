import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/subscription_catalog.dart';
import '../data/subscription_catalog_repository.dart';
import '../data/subscription_logo_resolver.dart';
import '../models/subscription.dart';
import '../models/subscription_branding.dart';
import '../models/subscription_catalog_item.dart';
import '../models/subscription_category.dart';

final subscriptionCatalogRepositoryProvider =
    Provider<SubscriptionCatalogRepository>(
      (ref) => AssetSubscriptionCatalogRepository(bundle: rootBundle),
    );

/// The bundled service catalog, loaded once.
final subscriptionCatalogProvider = FutureProvider<SubscriptionCatalog>(
  (ref) => ref.watch(subscriptionCatalogRepositoryProvider).load(),
);

/// Search input for the catalog (used by the Phase 3 Add Subscription flow).
class CatalogQuery {
  const CatalogQuery({this.text = '', this.category});

  final String text;
  final SubscriptionCategory? category;

  @override
  bool operator ==(Object other) =>
      other is CatalogQuery && other.text == text && other.category == category;

  @override
  int get hashCode => Object.hash(text, category);
}

class CatalogQueryNotifier extends Notifier<CatalogQuery> {
  @override
  CatalogQuery build() => const CatalogQuery();

  void setText(String text) =>
      state = CatalogQuery(text: text, category: state.category);

  void setCategory(SubscriptionCategory? category) =>
      state = CatalogQuery(text: state.text, category: category);

  void clear() => state = const CatalogQuery();
}

final catalogQueryProvider =
    NotifierProvider<CatalogQueryNotifier, CatalogQuery>(
      CatalogQueryNotifier.new,
    );

/// Catalog results for the current [catalogQueryProvider] state. Empty
/// queries return popular services (or a category's services).
///
/// Derived synchronously from the loaded catalog, so typing never flashes a
/// loading state; it is only loading while the catalog asset first loads.
final catalogSearchResultsProvider =
    Provider<AsyncValue<List<SubscriptionCatalogItem>>>((ref) {
      final query = ref.watch(catalogQueryProvider);
      return ref
          .watch(subscriptionCatalogProvider)
          .whenData(
            (catalog) => catalog.search(query.text, category: query.category),
          );
    });

/// Popular services for the "browse" grid.
final popularCatalogItemsProvider =
    Provider<AsyncValue<List<SubscriptionCatalogItem>>>(
      (ref) => ref
          .watch(subscriptionCatalogProvider)
          .whenData((catalog) => catalog.popular),
    );

final subscriptionLogoResolverProvider = Provider<SubscriptionLogoResolver>(
  (ref) => const SubscriptionLogoResolver(),
);

/// How to draw [Subscription]'s logo. While the catalog is loading (or if it
/// fails) this falls back to initials in the category colour.
final subscriptionBrandingProvider =
    Provider.family<SubscriptionBranding, Subscription>((ref, subscription) {
      final catalog = ref.watch(subscriptionCatalogProvider).value;
      return ref
          .watch(subscriptionLogoResolverProvider)
          .forSubscription(
            subscription,
            catalogItem: catalog?.byId(subscription.catalogId),
          );
    });

/// How to draw a catalog service's logo (search results, browse grid).
final catalogItemBrandingProvider =
    Provider.family<SubscriptionBranding, SubscriptionCatalogItem>(
      (ref, item) =>
          ref.watch(subscriptionLogoResolverProvider).forCatalogItem(item),
    );
