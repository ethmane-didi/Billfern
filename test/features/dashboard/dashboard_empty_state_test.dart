import 'package:billfern/core/router/app_destination.dart';
import 'package:billfern/features/subscriptions/presentation/screens/add_subscription_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/app_harness.dart';

void main() {
  testWidgets('first launch shows a start-tracking state', (tester) async {
    await pumpBillfern(tester);

    expect(find.text('Start tracking'), findsOneWidget);
    expect(find.text('Upcoming renewals'), findsNothing);
    expect(find.text('Sample data · changes are not saved'), findsNothing);

    await tapVisible(tester, find.text('Add subscription').last);
    expect(find.byType(AddSubscriptionScreen), findsOneWidget);
  });

  testWidgets('sample data can be explored and exited', (tester) async {
    await pumpBillfern(tester);

    await tapVisible(tester, find.text('Explore sample data'));
    expect(find.text('Sample data · changes are not saved'), findsOneWidget);
    expect(find.text('Upcoming renewals'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Exit sample data'));
    await tester.pumpAndSettle();
    expect(find.text('Start tracking'), findsOneWidget);

    // The Subscriptions tab reflects the same data.
    await openTab(tester, AppDestination.subscriptions);
    expect(find.text('No subscriptions yet'), findsOneWidget);
  });
}
