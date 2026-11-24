import 'package:billfern/features/subscriptions/domain/subscription_draft.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription_catalog_item.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/models/subscription_glyph.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _netflix = SubscriptionCatalogItem(
  id: 'netflix',
  name: 'Netflix',
  domain: 'netflix.com',
  category: SubscriptionCategory.entertainment,
  brandColor: Color(0xFFE50914),
  logoAsset: 'assets/logos/netflix.svg',
);

void main() {
  final today = DateTime(2026, 11, 24);

  test('selecting a catalog service pre-fills name, category and link', () {
    final draft = SubscriptionDraft.fromCatalog(_netflix);
    expect(draft.name, 'Netflix');
    expect(draft.category, SubscriptionCategory.entertainment);
    expect(draft.catalogId, 'netflix');
    expect(draft.isCustom, isFalse);
    expect(draft.isComplete, isFalse, reason: 'amount and date still needed');
  });

  test('user only adds amount, currency, cycle and renewal date', () {
    final sub = SubscriptionDraft.fromCatalog(_netflix)
        .copyWith(
          amountCents: 15900,
          currencyCode: 'NOK',
          billingCycle: BillingCycle.monthly,
          nextRenewal: DateTime(2026, 12, 3),
        )
        .toSubscription(id: 'sub-1');

    expect(sub.catalogId, 'netflix');
    expect(sub.priceCents, 15900);
    expect(sub.currencyCode, 'NOK');
    expect(sub.nextRenewal(today), DateTime(2026, 12, 3));
    expect(sub.customColor, isNull);
  });

  test('yearly renewal dates round-trip', () {
    final sub = SubscriptionDraft.fromCatalog(_netflix)
        .copyWith(
          amountCents: 9999,
          billingCycle: BillingCycle.yearly,
          nextRenewal: DateTime(2027, 2, 10),
        )
        .toSubscription(id: 'sub-2');
    expect(sub.nextRenewal(today), DateTime(2027, 2, 10));
  });

  test('custom subscriptions keep website, colour and icon', () {
    final sub =
        SubscriptionDraft.custom(
              name: 'Local Gym',
              category: SubscriptionCategory.health,
            )
            .copyWith(
              amountCents: 49900,
              nextRenewal: DateTime(2026, 12, 1),
              websiteDomain: 'https://www.LocalGym.no/members',
              customColor: const Color(0xFF00897B),
              customGlyph: SubscriptionGlyph.dumbbell,
            )
            .toSubscription(id: 'sub-3');

    expect(sub.catalogId, isNull);
    expect(sub.websiteDomain, 'localgym.no');
    expect(sub.customColor, const Color(0xFF00897B));
    expect(sub.customGlyph, SubscriptionGlyph.dumbbell);
  });

  test('incomplete drafts cannot be saved', () {
    expect(
      () => SubscriptionDraft.custom(name: 'X').toSubscription(id: 'x'),
      throwsStateError,
    );
  });
}
