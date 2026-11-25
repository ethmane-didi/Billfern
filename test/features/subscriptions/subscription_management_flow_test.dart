import 'package:billfern/core/router/app_destination.dart';
import 'package:billfern/features/subscriptions/presentation/screens/add_subscription_screen.dart';
import 'package:billfern/features/subscriptions/presentation/screens/subscription_details_screen.dart';
import 'package:billfern/features/subscriptions/presentation/screens/subscription_form_screen.dart';
import 'package:billfern/features/subscriptions/presentation/widgets/subscription_list_tile.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:billfern/shared/widgets/subscription_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

Subscription _netflix() => Subscription(
  id: 'netflix-1',
  name: 'Netflix',
  plan: 'Standard',
  priceMinor: 1549,
  currencyCode: 'USD',
  billingCycle: BillingCycle.monthly,
  category: SubscriptionCategory.entertainment,
  startedOn: DateTime(2026, 3, 10),
  billingAnchor: DateTime(2026, 12, 10),
  catalogId: 'netflix',
);

Finder _field(String label) => find.widgetWithText(TextField, label);

void main() {
  group('subscriptions screen', () {
    testWidgets('fresh install shows an empty state', (tester) async {
      await pumpBillfern(tester);
      await openTab(tester, AppDestination.subscriptions);

      expect(find.text('No subscriptions yet'), findsOneWidget);
      await tapVisible(tester, find.text('Explore sample data'));
      expect(find.text('Sample data · changes are not saved'), findsOneWidget);
      expect(find.byType(SubscriptionListTile), findsWidgets);
    });

    testWidgets('lists sample subscriptions with totals and filters', (
      tester,
    ) async {
      await pumpBillfern(tester, mode: DataMode.sample);
      await openTab(tester, AppDestination.subscriptions);

      expect(find.text(r'≈ $164.35'), findsOneWidget);
      expect(find.text('All 14'), findsOneWidget);
      expect(find.text('Active 13'), findsOneWidget);
      expect(find.text('Paused 1'), findsOneWidget);

      await tester.tap(find.text('Paused 1'));
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionListTile), findsOneWidget);
      expect(find.textContaining('Disney+'), findsOneWidget);

      await tester.tap(find.text('All 14'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'spot');
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionListTile), findsOneWidget);
      expect(find.textContaining('Spotify'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matches'), findsOneWidget);
      await tapVisible(tester, find.text('Clear filters'));
      expect(find.text('No matches'), findsNothing);
    });

    testWidgets('shows original currencies and sorts', (tester) async {
      await pumpBillfern(tester, mode: DataMode.sample);
      await openTab(tester, AppDestination.subscriptions);

      // Viaplay keeps NOK, with a converted hint.
      await scrollTo(tester, find.textContaining('Viaplay'));
      expect(find.text(r'≈ $18.43/mo'), findsOneWidget);

      await tapVisible(tester, find.bySemanticsLabel(RegExp('^Sort by')));
      await tester.tap(find.text('Name'));
      await tester.pumpAndSettle();
      final first = tester
          .widgetList<SubscriptionListTile>(find.byType(SubscriptionListTile))
          .first;
      expect(first.subscription.name, 'Adobe Lightroom');
    });
  });

  group('add subscription', () {
    testWidgets('from the catalog pre-fills, validates and saves', (
      tester,
    ) async {
      final repo = await pumpBillfern(tester);
      await openTab(tester, AppDestination.subscriptions);
      await tester.tap(find.bySemanticsLabel('Add subscription').first);
      await tester.pumpAndSettle();
      expect(find.byType(AddSubscriptionScreen), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'netfl');
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Netflix, Entertainment'));
      await tester.pumpAndSettle();

      expect(find.byType(SubscriptionFormScreen), findsOneWidget);
      expect(find.text('New subscription'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('Name')).controller!.text,
        'Netflix',
      );
      expect(
        find.bySemanticsLabel('Currency, US Dollar. Change'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SubscriptionLogo),
          matching: find.byType(SvgPicture),
        ),
        findsOneWidget,
        reason: 'catalog logo resolved',
      );

      // Submitting empty shows validation errors.
      await tapVisible(tester, find.text('Add subscription'));
      expect(find.text('Check the highlighted fields.'), findsOneWidget);
      expect(find.text('Choose the next renewal date'), findsOneWidget);
      await scrollToTop(tester);
      expect(find.text('Enter an amount'), findsOneWidget);
      expect(repo.fetchAll(), isEmpty);

      await enterField(tester, 'Amount', '15.49');
      await tester.pumpAndSettle();
      expect(find.text(r'$15.49 monthly'), findsOneWidget);
      await tapVisible(
        tester,
        find.bySemanticsLabel(RegExp('^Next renewal date')),
      );
      await pickDay(tester, 30);

      await tapVisible(tester, find.text('Add subscription'));
      expect(find.byType(SubscriptionDetailsScreen), findsOneWidget);
      expect(repo.fetchAll(), hasLength(1));
      final saved = repo.fetchAll().single;
      expect(saved.catalogId, 'netflix');
      expect(saved.priceMinor, 1549);
      expect(saved.currencyCode, 'USD');
      expect(saved.nextRenewal(DateTime(2026, 11, 24)), DateTime(2026, 12, 30));

      // The dashboard updates immediately.
      await openTab(tester, AppDestination.home);
      expect(find.text(r'$15.49'), findsWidgets);
      expect(find.text('1 active'), findsOneWidget);
    });

    testWidgets('custom subscription with its own currency and interval', (
      tester,
    ) async {
      final repo = await pumpBillfern(tester);
      await openTab(tester, AppDestination.subscriptions);
      await tester.tap(find.bySemanticsLabel('Add subscription').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Create custom subscription'));
      await tester.pumpAndSettle();

      await enterField(tester, 'Name', 'Local Gym');
      await enterField(tester, 'Amount', '399');
      await tester.tap(find.bySemanticsLabel('Currency, US Dollar. Change'));
      await tester.pumpAndSettle();
      expect(find.text('Subscription currency'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Norwegian Krone, NOK'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          r'kr 399.00 monthly · ≈ $36.94/mo in USD (mock rates)'.replaceAll(
            'kr ',
            'kr ',
          ),
        ),
        findsOneWidget,
      );

      await tapVisible(tester, find.text('Custom'));
      await enterField(tester, 'Every', '2');
      await tapVisible(tester, find.text('weeks'));
      await tapVisible(tester, find.text('Health & fitness'));
      await tapVisible(tester, find.text('3 days before'));
      await enterField(tester, 'Website', 'https://www.localgym.no');
      await enterField(tester, 'Notes', 'Student discount');
      await tapVisible(
        tester,
        find.bySemanticsLabel(RegExp('^Next renewal date')),
      );
      await pickDay(tester, 1);

      await tapVisible(tester, find.text('Add subscription'));
      final saved = repo.fetchAll().single;
      expect(saved.catalogId, isNull);
      expect(saved.name, 'Local Gym');
      expect(saved.price.minorUnits, 39900);
      expect(saved.currencyCode, 'NOK');
      expect(
        saved.billingCycle,
        const BillingCycle.custom(2, BillingUnit.week),
      );
      expect(saved.category, SubscriptionCategory.health);
      expect(saved.websiteDomain, 'localgym.no');
      expect(saved.notes, 'Student discount');

      expect(find.text('Every 2 weeks'), findsOneWidget);
      expect(find.text('localgym.no'), findsOneWidget);
      expect(find.text('3 days before'), findsOneWidget);
    });

    testWidgets('allows a second subscription to the same service', (
      tester,
    ) async {
      final repo = await pumpBillfern(tester, seed: [_netflix()]);
      await openTab(tester, AppDestination.subscriptions);
      await tester.tap(find.bySemanticsLabel('Add subscription').first);
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Netflix'));
      await tester.pumpAndSettle();
      await enterField(tester, 'Amount', '22.99');
      await enterField(tester, 'Plan', 'Premium (family)');
      await tapVisible(
        tester,
        find.bySemanticsLabel(RegExp('^Next renewal date')),
      );
      await pickDay(tester, 5);
      await tapVisible(tester, find.text('Add subscription'));

      expect(
        repo.fetchAll().where((s) => s.catalogId == 'netflix'),
        hasLength(2),
      );
    });
  });

  group('details', () {
    Future<void> openDetails(WidgetTester tester) async {
      await openTab(tester, AppDestination.subscriptions);
      await tester.tap(find.byType(SubscriptionListTile).first);
      await tester.pumpAndSettle();
      expect(find.byType(SubscriptionDetailsScreen), findsOneWidget);
    }

    testWidgets('shows price, schedule and metadata', (tester) async {
      await pumpBillfern(tester, seed: [_netflix()]);
      await openDetails(tester);

      expect(find.text('Netflix'), findsWidgets);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text(r'$185.88 per year'), findsOneWidget);
      expect(find.textContaining('Dec 10'), findsOneWidget);
      expect(find.text('US Dollar (USD)'), findsOneWidget);
      expect(find.text('1 day before'), findsOneWidget);
    });

    testWidgets('edit updates the subscription everywhere', (tester) async {
      final repo = await pumpBillfern(tester, seed: [_netflix()]);
      await openDetails(tester);

      await tester.tap(find.bySemanticsLabel('Edit Netflix'));
      await tester.pumpAndSettle();
      expect(find.text('Edit subscription'), findsOneWidget);
      expect(
        tester.widget<TextField>(_field('Amount')).controller!.text,
        '15.49',
      );

      await enterField(tester, 'Amount', '17.99');
      await tapVisible(tester, find.text('Save changes'));

      expect(find.byType(SubscriptionDetailsScreen), findsOneWidget);
      expect(repo.fetchAll().single.priceMinor, 1799);
      expect(repo.fetchAll().single.id, 'netflix-1');
      await scrollToTop(tester);
      expect(find.textContaining(r'$17.99', findRichText: true), findsWidgets);
    });

    testWidgets('pause and resume', (tester) async {
      final repo = await pumpBillfern(tester, seed: [_netflix()]);
      await openDetails(tester);

      await tapVisible(tester, find.text('Pause subscription'));
      expect(repo.fetchAll().single.isActive, isFalse);
      await scrollToTop(tester);
      expect(find.text('Paused'), findsOneWidget);
      expect(find.text('Paused since'), findsOneWidget);

      await tapVisible(tester, find.text('Resume subscription'));
      expect(repo.fetchAll().single.isActive, isTrue);
      await scrollToTop(tester);
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('delete asks for confirmation', (tester) async {
      final repo = await pumpBillfern(tester, seed: [_netflix()]);
      await openDetails(tester);

      await tapVisible(tester, find.text('Delete subscription'));
      expect(find.text('Delete Netflix?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.fetchAll(), hasLength(1));

      await tapVisible(tester, find.text('Delete subscription'));
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Delete subscription'),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.fetchAll(), isEmpty);
      expect(find.text('No subscriptions yet'), findsOneWidget);
    });
  });

  group('no layout overflow', () {
    const sizes = {
      'iPhone SE': Size(375, 667),
      'iPhone 16 Pro Max': Size(440, 956),
    };
    for (final MapEntry(key: name, value: size) in sizes.entries) {
      for (final scale in [1.0, 1.35]) {
        testWidgets('$name at ${scale}x text', (tester) async {
          await pumpBillfern(
            tester,
            mode: DataMode.sample,
            size: size,
            textScale: scale,
          );
          await openTab(tester, AppDestination.subscriptions);
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, 6000),
          );
          await tester.pumpAndSettle();

          await tester.tap(find.bySemanticsLabel('Add subscription').first);
          await tester.pumpAndSettle();
          await tester.tap(find.bySemanticsLabel('Create custom subscription'));
          await tester.pumpAndSettle();
          await tapVisible(tester, find.text('Custom'));
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          await scrollToTop(tester);
          await tapBack(tester);
          await tapBack(tester);

          await tapVisible(tester, find.byKey(const ValueKey('netflix')));
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -3000),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
