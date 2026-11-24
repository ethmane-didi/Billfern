import 'package:billfern/app.dart';
import 'package:billfern/core/router/app_destination.dart';
import 'package:billfern/shared/data/app_preference_store.dart';
import 'package:billfern/shared/data/subscription_repository.dart';
import 'package:billfern/shared/models/subscription.dart';
import 'package:billfern/shared/providers/catalog_providers.dart';
import 'package:billfern/shared/providers/subscription_providers.dart';
import 'package:billfern/shared/widgets/floating_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixed_clock.dart';

const double _dpr = 3;

/// Pumps the whole app with an in-memory personal repository (returned so
/// tests can inspect what was persisted) and waits for the catalog asset.
Future<InMemorySubscriptionRepository> pumpBillfern(
  WidgetTester tester, {
  List<Subscription> seed = const [],
  DataMode mode = DataMode.personal,
  Size size = const Size(393, 1400),
  double textScale = 1,
}) async {
  tester.view
    ..physicalSize = size * _dpr
    ..devicePixelRatio = _dpr
    ..padding = const FakeViewPadding(top: 59 * _dpr, bottom: 34 * _dpr)
    ..viewPadding = const FakeViewPadding(top: 59 * _dpr, bottom: 34 * _dpr);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  final repository = InMemorySubscriptionRepository(seed);
  var counter = 0;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...emptyAppTestOverrides,
        personalSubscriptionRepositoryProvider.overrideWithValue(repository),
        appPreferenceStoreProvider.overrideWith(
          (ref) =>
              InMemoryAppPreferenceStore({PreferenceKeys.dataMode: mode.name}),
        ),
        subscriptionIdGeneratorProvider.overrideWithValue(
          () => 'sub-${++counter}',
        ),
      ],
      child: const BillfernApp(),
    ),
  );
  final container = ProviderScope.containerOf(
    tester.element(find.byType(BillfernApp)),
  );
  await tester.runAsync(
    () => container.read(subscriptionCatalogProvider.future),
  );
  await tester.pumpAndSettle();
  return repository;
}

/// Taps a bottom-navigation destination.
Future<void> openTab(WidgetTester tester, AppDestination destination) async {
  await tester.tap(
    find.descendant(
      of: find.byType(FloatingBottomNav),
      matching: find.byIcon(destination.icon),
    ),
  );
  await tester.pumpAndSettle();
}

/// Scrolls the current screen's main list until [finder] is visible.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Taps [finder] after scrolling it into view (building it first if the
/// lazy list has not created it yet).
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) await scrollTo(tester, finder);
  // Centre it so floating chrome (the bottom navigation) never covers it.
  await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrolls to the text field labelled [label] and types [text] into it.
Future<void> enterField(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label);
  if (field.evaluate().isEmpty) await scrollTo(tester, field);
  await Scrollable.ensureVisible(tester.element(field), alignment: 0.5);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pumpAndSettle();
}

/// Scrolls the current screen's main list back to the top.
Future<void> scrollToTop(WidgetTester tester) async {
  await tester.drag(find.byType(Scrollable).first, const Offset(0, 10000));
  await tester.pumpAndSettle();
}

/// Taps the screen's custom back button.
Future<void> tapBack(WidgetTester tester) async {
  await tester.tap(find.bySemanticsLabel('Back'));
  await tester.pumpAndSettle();
}

/// Picks [day] of the month shown by the open date picker and confirms.
Future<void> pickDay(WidgetTester tester, int day) async {
  await tester.tap(find.text('$day').last);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}
