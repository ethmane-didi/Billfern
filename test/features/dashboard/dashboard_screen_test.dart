import 'package:billfern/app.dart';
import 'package:billfern/features/dashboard/presentation/widgets/ai_insight_card.dart';
import 'package:billfern/features/dashboard/presentation/widgets/category_breakdown_card.dart';
import 'package:billfern/features/dashboard/presentation/widgets/recently_added_section.dart';
import 'package:billfern/features/dashboard/presentation/widgets/spending_trend_card.dart';
import 'package:billfern/shared/providers/catalog_providers.dart';
import 'package:billfern/shared/widgets/subscription_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixed_clock.dart';

/// Logical sizes and safe-area insets of current iPhone screens.
const _iPhones = <String, ({Size size, double top, double bottom})>{
  'iPhone SE': (size: Size(375, 667), top: 20, bottom: 0),
  'iPhone 13 mini': (size: Size(375, 812), top: 50, bottom: 34),
  'iPhone 16': (size: Size(393, 852), top: 59, bottom: 34),
  'iPhone 16 Pro Max': (size: Size(440, 956), top: 62, bottom: 34),
};

const double _dpr = 3;

Future<void> _pumpDashboard(
  WidgetTester tester, {
  Size size = const Size(393, 852),
  double top = 59,
  double bottom = 34,
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size * _dpr
    ..devicePixelRatio = _dpr
    ..padding = FakeViewPadding(top: top * _dpr, bottom: bottom * _dpr)
    ..viewPadding = FakeViewPadding(top: top * _dpr, bottom: bottom * _dpr);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(
    ProviderScope(overrides: fixedClockOverrides, child: const BillfernApp()),
  );
  // Let the catalog (a real asset read) finish loading before settling.
  final container = ProviderScope.containerOf(
    tester.element(find.byType(BillfernApp)),
  );
  await tester.runAsync(
    () => container.read(subscriptionCatalogProvider.future),
  );
  await tester.pumpAndSettle();
}

Finder get _dashboardScrollable => find.byType(Scrollable).first;

Future<void> _scrollTo(WidgetTester tester, Finder finder) =>
    tester.scrollUntilVisible(finder, 300, scrollable: _dashboardScrollable);

/// Scrolls the dashboard to its end, building every lazily-built section.
Future<void> _scrollToEnd(WidgetTester tester) async {
  await _scrollTo(tester, find.byType(RecentlyAddedSection));
  await tester.drag(_dashboardScrollable, const Offset(0, -2000));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows header, hero figures and every dashboard section', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    expect(find.bySemanticsLabel('Billfern'), findsOneWidget);
    expect(find.bySemanticsLabel('Add subscription'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Notifications, 2 renewals due soon'),
      findsOneWidget,
    );
    expect(find.text('Good morning, Alex'), findsOneWidget);
    expect(find.text(r'$123.42'), findsWidgets);
    expect(
      find.text(r'Total monthly spending · $1,481 a year'),
      findsOneWidget,
    );
    expect(find.text('11 active'), findsOneWidget);
    expect(find.text('−7.5%'), findsOneWidget);
    expect(find.text(r'$36.48'), findsOneWidget);
    expect(find.text('Upcoming renewals'), findsOneWidget);

    await _scrollTo(tester, find.byType(CategoryBreakdownCard));
    expect(find.text('Where your money goes'), findsOneWidget);
    expect(find.text('Entertainment'), findsOneWidget);
    expect(find.text('Other'), findsOneWidget);

    await _scrollTo(tester, find.byType(AiInsightCard));
    expect(find.text('Overlapping music services'), findsOneWidget);
    expect(find.text('Smart tip · Sample data'), findsOneWidget);

    await _scrollTo(tester, find.byType(SpendingTrendCard));
    expect(
      find.textContaining(r'$9.99 less than last month', findRichText: true),
      findsOneWidget,
    );

    await _scrollToEnd(tester);
    expect(find.text('11 active · 1 paused'), findsOneWidget);
    expect(find.text('Strava · Premium'), findsOneWidget);
  });

  testWidgets('renders bundled brand logos and initials fallbacks', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    final logos = tester
        .widgetList<SubscriptionLogo>(find.byType(SubscriptionLogo))
        .toList();
    expect(logos, isNotEmpty);
    // Netflix renews today and has a bundled mark.
    expect(
      find.descendant(
        of: find.byType(SubscriptionLogo).first,
        matching: find.byType(SvgPicture),
      ),
      findsOneWidget,
    );

    // ChatGPT has no permitted bundled logo, so it falls back to initials.
    await _scrollToEnd(tester);
    expect(find.text('C'), findsWidgets);
  });

  testWidgets('add subscription shows a coming-soon message', (tester) async {
    await _pumpDashboard(tester);

    await tester.tap(find.bySemanticsLabel('Add subscription'));
    await tester.pump();
    expect(find.text('Adding subscriptions is coming soon.'), findsOneWidget);
  });

  testWidgets('view all on renewals opens the Subscriptions tab', (
    tester,
  ) async {
    await _pumpDashboard(tester);

    await tester.tap(find.text('View all').first);
    await tester.pumpAndSettle();
    expect(find.text('Upcoming renewals'), findsNothing);
  });

  group('no layout overflow', () {
    for (final MapEntry(key: name, value: device) in _iPhones.entries) {
      for (final textScale in [1.0, 1.35]) {
        testWidgets('$name at ${textScale}x text', (tester) async {
          await _pumpDashboard(
            tester,
            size: device.size,
            top: device.top,
            bottom: device.bottom,
            textScale: textScale,
          );
          await _scrollToEnd(tester);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });
}
