import 'package:billfern/features/subscriptions/domain/subscription_draft.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/reminder_preference.dart';
import 'package:billfern/shared/models/subscription.dart';
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

final _today = DateTime(2026, 11, 24);

SubscriptionDraft _valid() => SubscriptionDraft.fromCatalog(
  _netflix,
  currencyCode: 'USD',
).copyWith(amountMinor: 1549, nextRenewal: DateTime(2026, 12, 3));

void main() {
  test('selecting a catalog service pre-fills name, category and link', () {
    final draft = SubscriptionDraft.fromCatalog(_netflix, currencyCode: 'USD');
    expect(draft.name, 'Netflix');
    expect(draft.category, SubscriptionCategory.entertainment);
    expect(draft.catalogId, 'netflix');
    expect(draft.isCustom, isFalse);
    expect(draft.currencyCode, 'USD', reason: 'starts as preferred currency');
    expect(
      draft.validate(today: _today).keys,
      containsAll([DraftField.amount, DraftField.nextRenewal]),
    );
  });

  group('validation', () {
    test('requires name, amount and renewal date', () {
      final errors = SubscriptionDraft.custom(currencyCode: 'USD')
          .validate(today: _today);
      expect(errors.keys, {
        DraftField.name,
        DraftField.amount,
        DraftField.nextRenewal,
      });
    });

    test('rejects zero amounts, past dates, bad websites and long text', () {
      final errors = _valid()
          .copyWith(
            amountMinor: 0,
            nextRenewal: DateTime(2026, 11, 23),
            website: 'not a website',
            name: 'x' * 61,
            notes: 'n' * 501,
          )
          .validate(today: _today);
      expect(errors.keys, {
        DraftField.amount,
        DraftField.nextRenewal,
        DraftField.website,
        DraftField.name,
        DraftField.notes,
      });
    });

    test('accepts today as the renewal date', () {
      expect(
        _valid().copyWith(nextRenewal: _today).isValid(today: _today),
        isTrue,
      );
    });

    test('toSubscription refuses invalid drafts', () {
      expect(
        () => SubscriptionDraft.custom(
          currencyCode: 'USD',
          name: 'X',
        ).toSubscription(id: 'x', today: _today),
        throwsStateError,
      );
    });
  });

  test('user only adds amount, currency, cycle and renewal date', () {
    final sub = _valid()
        .copyWith(
          amountMinor: 15900,
          currencyCode: 'NOK',
          billingCycle: BillingCycle.monthly,
        )
        .toSubscription(id: 'sub-1', today: _today);

    expect(sub.catalogId, 'netflix');
    expect(sub.priceMinor, 15900);
    expect(sub.currencyCode, 'NOK');
    expect(sub.nextRenewal(_today), DateTime(2026, 12, 3));
    expect(sub.startedOn, _today, reason: 'tracking starts today');
    expect(sub.createdAt, _today);
    expect(sub.customColor, isNull);
  });

  test('renewal dates round-trip for every billing cycle', () {
    for (final cycle in [
      ...BillingCycle.presets,
      const BillingCycle.custom(2, BillingUnit.week),
      const BillingCycle.custom(10, BillingUnit.day),
      const BillingCycle.custom(6, BillingUnit.month),
    ]) {
      final sub = _valid()
          .copyWith(billingCycle: cycle, nextRenewal: DateTime(2027, 1, 31))
          .toSubscription(id: 's', today: _today);
      expect(sub.nextRenewal(_today), DateTime(2027, 1, 31), reason: '$cycle');
    }
  });

  test('custom subscriptions keep website, colour and icon', () {
    final sub =
        SubscriptionDraft.custom(
              currencyCode: 'NOK',
              name: 'Local Gym',
              category: SubscriptionCategory.health,
            )
            .copyWith(
              amountMinor: 49900,
              nextRenewal: DateTime(2026, 12, 1),
              website: 'https://www.LocalGym.no/members',
              customColor: const Color(0xFF00897B),
              customGlyph: SubscriptionGlyph.dumbbell,
              reminder: ReminderPreference.threeDaysBefore,
              notes: '  Family plan  ',
            )
            .toSubscription(id: 'sub-3', today: _today);

    expect(sub.catalogId, isNull);
    expect(sub.websiteDomain, 'localgym.no');
    expect(sub.customColor, const Color(0xFF00897B));
    expect(sub.customGlyph, SubscriptionGlyph.dumbbell);
    expect(sub.reminder, ReminderPreference.threeDaysBefore);
    expect(sub.notes, 'Family plan');
  });

  group('editing', () {
    final existing = Subscription(
      id: 'netflix-1',
      name: 'Netflix',
      plan: 'Standard',
      priceMinor: 1549,
      currencyCode: 'USD',
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.entertainment,
      startedOn: DateTime(2025, 3, 10),
      catalogId: 'netflix',
      status: SubscriptionStatus.paused,
      pausedOn: DateTime(2026, 11, 1),
      pauseHistory: [
        PausePeriod(from: DateTime(2026, 2, 1), until: DateTime(2026, 3, 1)),
      ],
      createdAt: DateTime(2025, 3, 10),
    );

    test('pre-fills from the subscription', () {
      final draft = SubscriptionDraft.fromSubscription(existing, today: _today);
      expect(draft.amountMinor, 1549);
      expect(draft.nextRenewal, DateTime(2026, 12, 10));
      expect(draft.isValid(today: _today), isTrue);
    });

    test('keeps identity, status and history; moves only the anchor', () {
      final edited = SubscriptionDraft.fromSubscription(existing, today: _today)
          .copyWith(amountMinor: 1799, nextRenewal: DateTime(2026, 12, 20))
          .toSubscription(id: 'ignored', today: _today, existing: existing);

      expect(edited.id, 'netflix-1');
      expect(edited.priceMinor, 1799);
      expect(edited.status, SubscriptionStatus.paused);
      expect(edited.pausedOn, existing.pausedOn);
      expect(edited.pauseHistory, existing.pauseHistory);
      expect(edited.startedOn, existing.startedOn);
      expect(edited.createdAt, existing.createdAt);
      expect(edited.billingAnchor, DateTime(2026, 12, 20));
      expect(edited.isBilledInMonth(DateTime(2025, 6)), isTrue);
    });
  });

  test('normalizeDomain', () {
    expect(
      SubscriptionDraft.normalizeDomain('HTTPS://www.Example.com/a?b'),
      'example.com',
    );
    expect(SubscriptionDraft.normalizeDomain('play.tv2.no'), 'play.tv2.no');
    expect(SubscriptionDraft.normalizeDomain('localhost'), isNull);
    expect(SubscriptionDraft.normalizeDomain(''), isNull);
  });
}
