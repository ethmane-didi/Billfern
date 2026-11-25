import 'package:billfern/app.dart';
import 'package:billfern/core/router/app_destination.dart';
import 'package:billfern/core/theme/theme.dart';
import 'package:billfern/features/analytics/domain/analytics_models.dart';
import 'package:billfern/features/analytics/presentation/providers/analytics_providers.dart';
import 'package:billfern/features/analytics/presentation/screens/analytics_screen.dart';
import 'package:billfern/features/subscriptions/presentation/screens/add_subscription_screen.dart';
import 'package:billfern/shared/models/billing_cycle.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/models/subscription_category.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';
import '../../helpers/fixed_clock.dart';

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(BillfernApp)));

Subscription _sub(String id, int priceMinor, {DateTime? startedOn}) =>
    Subscription(
      id: id,
      name: id,
      plan: '',
      priceMinor: priceMinor,
      currencyCode: 'USD',
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.productivity,
      startedOn: startedOn ?? DateTime(2026, 1, 1),
      billingAnchor: DateTime(2026, 11, 28),
    );

Future<void> _openAnalytics(
  WidgetTester tester, {
  List<Subscription> seed = const [],
  DataMode mode = DataMode.personal,
  Size size = const Size(393, 1400),
  double textScale = 1,
}) async {
  await pumpBillfern(
    tester,
    seed: seed,
    mode: mode,
    size: size,
    textScale: textScale,
  );
  await openTab(tester, AppDestination.analytics);
}

/// The Analytics list (the Home tab's list stays mounted offstage).
Finder get _list => find
    .descendant(
      of: find.byType(AnalyticsScreen),
      matching: find.byType(Scrollable),
    )
    .first;

/// Drags the list from its left gutter, so the drag never starts on the
/// interactive chart (which handles its own pan gestures).
Future<void> _dragList(WidgetTester tester, double dy) async {
  await tester.dragFrom(
    tester.getTopLeft(_list) + const Offset(AppSpacing.xs, AppSpacing.huge),
    Offset(0, dy),
  );
  await tester.pump();
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await _dragList(tester, -300);
  }
  await tester.pumpAndSettle();
}

/// Builds [finder] by scrolling the Analytics list, then taps it centred.
Future<void> _tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) await _scrollTo(tester, finder);
  await tapVisible(tester, finder);
}

/// Scrolls to the end of the screen, building every lazy section.
Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await _dragList(tester, -500);
  }
  await tester.pumpAndSettle();
}

/// A category row, found by its (container) semantics label.
Finder _categoryRow(String name) => find.byWidgetPredicate(
  (widget) =>
      widget is Semantics &&
      (widget.properties.label ?? '').startsWith('$name, ') &&
      widget.properties.button == true,
);

Finder _inAnalytics(Finder finder) =>
    find.descendant(of: find.byType(AnalyticsScreen), matching: finder);

const _iPhones = <String, Size>{
  'iPhone SE': Size(375, 667),
  'iPhone 13 mini': Size(375, 812),
  'iPhone 16': Size(393, 852),
  'iPhone 16 Pro Max': Size(440, 956),
};

void main() {
  testWidgets('empty state offers Add subscription', (tester) async {
    await _openAnalytics(tester);
    expect(find.text('No spending to analyse yet'), findsOneWidget);
    expect(find.text('Spending trend'), findsNothing);
    await _tap(tester, find.text('Add subscription'));
    expect(find.byType(AddSubscriptionScreen), findsOneWidget);
  });

  testWidgets('sample data is labelled and agrees with the dashboard', (
    tester,
  ) async {
    await _openAnalytics(tester, mode: DataMode.sample);
    expect(find.text('Sample data · changes are not saved'), findsOneWidget);
    expect(find.text('Analytics'), findsOneWidget);
    expect(_inAnalytics(find.text('≈ \$164.35')), findsWidgets);
    expect(find.textContaining('Mock exchange rates'), findsOneWidget);
    for (final section in [
      'Spending trend',
      'Category breakdown',
      'Upcoming payments',
      'Smart suggestions',
    ]) {
      await _scrollTo(tester, find.text(section));
      expect(find.text(section), findsOneWidget);
    }
    expect(find.textContaining('not AI'), findsOneWidget);
  });

  testWidgets('period selector, month stepping and tooltips data', (
    tester,
  ) async {
    await _openAnalytics(tester, mode: DataMode.sample);
    final container = _container(tester);

    await _tap(tester, find.text('12M'));
    expect(container.read(trendPeriodProvider), TrendPeriod.twelveMonths);
    expect(container.read(spendingTrendProvider).points, hasLength(12));
    expect(find.bySemanticsLabel(RegExp('last 12 months')), findsOneWidget);

    await _tap(tester, find.text('3M'));
    expect(container.read(spendingTrendProvider).points, hasLength(3));

    expect(find.textContaining('This month ·'), findsOneWidget);
    await _tap(tester, find.bySemanticsLabel('Previous month'));
    expect(find.textContaining('October ·'), findsOneWidget);
  });

  testWidgets('selecting a category reveals its subscriptions', (tester) async {
    await _openAnalytics(tester, mode: DataMode.sample);
    await _tap(tester, _categoryRow('Entertainment'));
    expect(_inAnalytics(find.text('Netflix')), findsWidgets);
    expect(_inAnalytics(find.text('YouTube Premium')), findsWidgets);
  });

  testWidgets('upcoming payment windows switch between 7, 30 and 90 days', (
    tester,
  ) async {
    await _openAnalytics(tester, mode: DataMode.sample);
    final windows = _container(tester).read(upcomingPaymentsProvider);
    await _tap(tester, find.text('90 days'));
    expect(
      find.bySemanticsLabel(
        RegExp('^Next 90 days: ${windows[2].count} payments'),
      ),
      findsOneWidget,
    );
    await _tap(tester, find.text('7 days'));
    expect(find.bySemanticsLabel(RegExp('^Next 7 days: ')), findsOneWidget);
  });

  testWidgets('new users see an insufficient-history state', (tester) async {
    await _openAnalytics(
      tester,
      seed: [_sub('first', 1000, startedOn: fixedNow)],
    );
    expect(find.text('Your trend starts next month'), findsOneWidget);
    expect(find.text('No earlier data'), findsWidgets);
    expect(find.text('Sample data · changes are not saved'), findsNothing);
  });

  testWidgets('updates after a pause', (tester) async {
    await _openAnalytics(tester, seed: [_sub('a', 1000), _sub('b', 500)]);
    expect(_inAnalytics(find.text('\$15.00')), findsWidgets);
    await _container(tester).read(subscriptionsProvider.notifier).pause('a');
    await tester.pumpAndSettle();
    expect(_inAnalytics(find.text('\$5.00')), findsWidgets);
    expect(_inAnalytics(find.text('\$15.00')), findsNothing);
  });

  testWidgets('headers and tap targets are accessible', (tester) async {
    final handle = tester.ensureSemantics();
    await _openAnalytics(tester, mode: DataMode.sample);
    expect(
      tester.getSemantics(_inAnalytics(find.bySemanticsLabel('Analytics'))),
      isSemantics(isHeader: true),
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel('12M')),
      isSemantics(isButton: true, isSelected: false),
    );
    expect(
      find.bySemanticsLabel(RegExp('^Estimated spending this month')),
      findsOneWidget,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  group('no layout overflow', () {
    for (final MapEntry(key: name, value: size) in _iPhones.entries) {
      for (final textScale in [1.0, 1.35]) {
        testWidgets('$name at ${textScale}x text', (tester) async {
          await _openAnalytics(
            tester,
            mode: DataMode.sample,
            size: size,
            textScale: textScale,
          );
          await _tap(tester, find.text('12M'));
          await _tap(tester, _categoryRow('Entertainment'));
          await _scrollToEnd(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('empty and insufficient states on iPhone SE at 1.35x', (
      tester,
    ) async {
      await _openAnalytics(
        tester,
        size: _iPhones['iPhone SE']!,
        textScale: 1.35,
      );
      await _scrollToEnd(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
