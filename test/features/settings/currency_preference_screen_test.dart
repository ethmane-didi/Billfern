import 'package:billfern/app.dart';
import 'package:billfern/core/router/app_destination.dart';
import 'package:billfern/features/settings/presentation/screens/currency_preference_screen.dart';
import 'package:billfern/shared/data/currency_preference_store.dart';
import 'package:billfern/shared/providers/currency_providers.dart';
import 'package:billfern/shared/widgets/floating_bottom_nav.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fixed_clock.dart';

Future<InMemoryCurrencyPreferenceStore> _openCurrencyScreen(
  WidgetTester tester,
) async {
  // A tall phone so the whole currency screen is built.
  tester.view
    ..physicalSize = const Size(393, 1400) * 3
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final store = InMemoryCurrencyPreferenceStore();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appTestOverrides,
        currencyPreferenceStoreProvider.overrideWithValue(store),
      ],
      child: const BillfernApp(),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(
    find.descendant(
      of: find.byType(FloatingBottomNav),
      matching: find.byIcon(AppDestination.settings.icon),
    ),
  );
  await tester.pumpAndSettle();
  expect(
    find.bySemanticsLabel('Display currency, USD · US Dollar'),
    findsOneWidget,
  );

  await tester.tap(find.bySemanticsLabel('Display currency, USD · US Dollar'));
  await tester.pumpAndSettle();
  expect(find.byType(CurrencyPreferenceScreen), findsOneWidget);
  return store;
}

void main() {
  testWidgets('lists supported currencies and explains mock rates', (
    tester,
  ) async {
    await _openCurrencyScreen(tester);

    expect(
      find.bySemanticsLabel('US Dollar, USD, suggested for your region'),
      findsOneWidget,
    );
    for (final name in [
      'Euro, EUR',
      'Swiss Franc, CHF',
      'Australian Dollar, AUD',
    ]) {
      expect(find.bySemanticsLabel(name), findsOneWidget, reason: name);
    }
    expect(find.textContaining('Development mock rates'), findsOneWidget);
    expect(find.textContaining('estimates'), findsOneWidget);
  });

  testWidgets('selecting a currency persists it and updates Settings', (
    tester,
  ) async {
    final store = await _openCurrencyScreen(tester);

    await tester.tap(find.bySemanticsLabel('Euro, EUR'));
    await tester.pumpAndSettle();
    expect(store.read(), 'EUR');
    expect(
      tester.getSemantics(find.bySemanticsLabel('Euro, EUR')),
      isSemantics(isButton: true, isSelected: true),
    );

    // Resetting follows the locale suggestion again.
    await tester.tap(find.text('Use suggested (USD)'));
    await tester.pumpAndSettle();
    expect(store.read(), isNull);

    await tester.tap(find.bySemanticsLabel('Back'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel('Display currency, USD · US Dollar'),
      findsOneWidget,
    );
  });
}
