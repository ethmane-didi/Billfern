import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:billfern/shared/widgets/buttons/primary_button.dart';
import 'package:billfern/shared/widgets/buttons/secondary_button.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('PrimaryButton invokes onPressed when tapped', (tester) async {
    var taps = 0;
    await tester.pumpThemed(
      PrimaryButton(
        label: 'Add subscription',
        icon: LucideIcons.plus,
        onPressed: () => taps++,
      ),
    );

    await tester.tap(find.text('Add subscription'));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(find.byIcon(LucideIcons.plus), findsOneWidget);
  });

  testWidgets('disabled PrimaryButton ignores taps', (tester) async {
    await tester.pumpThemed(
      const PrimaryButton(label: 'Continue', onPressed: null),
    );

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(find.bySemanticsLabel('Continue'));
    expect(semantics, isSemantics(isButton: true, isEnabled: false));
  });

  testWidgets('loading button shows a spinner and blocks taps', (tester) async {
    var taps = 0;
    await tester.pumpThemed(
      SecondaryButton(label: 'Save', isLoading: true, onPressed: () => taps++),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save'), findsNothing);

    await tester.tap(find.byType(SecondaryButton));
    await tester.pump();
    expect(taps, 0);
  });
}
