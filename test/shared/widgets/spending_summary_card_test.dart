import 'package:flutter_test/flutter_test.dart';
import 'package:billfern/core/money/money.dart';
import 'package:billfern/shared/widgets/spending_summary_card.dart';

import '../../helpers/pump_themed.dart';

void main() {
  testWidgets('renders amount, trend and stats', (tester) async {
    await tester.pumpThemed(
      const SpendingSummaryCard(
        amount: Money(24897, 'USD'),
        changePercent: -8.2,
        activeCount: 12,
        projectedYearly: Money(298764, 'USD'),
      ),
    );

    expect(find.text('Monthly spending'), findsOneWidget);
    expect(find.bySemanticsLabel(r'$248.97'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Spending down 8.2 percent vs last month'),
      findsOneWidget,
    );
    expect(find.text('12'), findsOneWidget);
    expect(find.text(r'$2,988'), findsOneWidget);
  });
}
