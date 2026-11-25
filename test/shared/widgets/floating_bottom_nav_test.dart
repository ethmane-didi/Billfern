import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:billfern/shared/widgets/floating_bottom_nav.dart';

import '../../helpers/pump_themed.dart';

const _items = [
  FloatingNavItem(icon: LucideIcons.house, label: 'Home'),
  FloatingNavItem(icon: LucideIcons.layoutGrid, label: 'Subscriptions'),
  FloatingNavItem(icon: LucideIcons.chartPie, label: 'Analytics'),
  FloatingNavItem(icon: LucideIcons.settings, label: 'Settings'),
];

void main() {
  testWidgets('draws icons only and reports taps', (tester) async {
    int? selected;
    await tester.pumpThemed(
      FloatingBottomNav(
        items: _items,
        currentIndex: 0,
        onSelected: (index) => selected = index,
      ),
    );

    for (final item in _items) {
      expect(find.byIcon(item.icon), findsOneWidget);
      expect(find.text(item.label), findsNothing);
    }

    await tester.tap(find.byIcon(LucideIcons.chartPie));
    await tester.pumpAndSettle();

    expect(selected, 2);
  });

  testWidgets('exposes selected state to assistive technology', (tester) async {
    await tester.pumpThemed(
      FloatingBottomNav(items: _items, currentIndex: 1, onSelected: (_) {}),
    );

    final selected = tester.getSemantics(
      find.bySemanticsLabel('Subscriptions'),
    );
    final unselected = tester.getSemantics(find.bySemanticsLabel('Settings'));

    expect(selected, isSemantics(isButton: true, isSelected: true));
    expect(unselected, isSemantics(isButton: true, isSelected: false));
  });
}
