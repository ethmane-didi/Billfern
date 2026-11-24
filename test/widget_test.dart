import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:billfern/app.dart';
import 'package:billfern/core/router/app_destination.dart';
import 'package:billfern/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:billfern/shared/widgets/floating_bottom_nav.dart';
import 'package:billfern/features/settings/presentation/screens/settings_screen.dart';
import 'package:billfern/shared/widgets/placeholder_view.dart';

import 'helpers/fixed_clock.dart';

Finder _navIcon(AppDestination destination) => find.descendant(
  of: find.byType(FloatingBottomNav),
  matching: find.byIcon(destination.icon),
);

void main() {
  testWidgets('boots into Home with the floating navigation', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: appTestOverrides, child: const BillfernApp()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(DashboardScreen), findsOneWidget);
    expect(find.byType(FloatingBottomNav), findsOneWidget);
    for (final destination in AppDestination.values) {
      expect(_navIcon(destination), findsOneWidget);
    }
  });

  testWidgets('navigates between all destinations', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: appTestOverrides, child: const BillfernApp()),
    );
    await tester.pumpAndSettle();

    for (final destination in [
      AppDestination.subscriptions,
      AppDestination.analytics,
      AppDestination.settings,
    ]) {
      await tester.tap(_navIcon(destination));
      await tester.pumpAndSettle();

      expect(
        tester.getSemantics(
          find.descendant(
            of: find.byType(FloatingBottomNav),
            matching: find.bySemanticsLabel(destination.label),
          ),
        ),
        isSemantics(isButton: true, isSelected: true),
        reason: 'selected tab reports its selected state',
      );
      expect(
        destination == AppDestination.settings
            ? find.byType(SettingsScreen)
            : find.widgetWithText(PlaceholderView, destination.label),
        findsOneWidget,
        reason: 'destination screen is shown',
      );
    }

    await tester.tap(_navIcon(AppDestination.home));
    await tester.pumpAndSettle();
    expect(find.text('Upcoming renewals'), findsOneWidget);
  });
}
