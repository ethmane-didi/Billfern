import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:billfern/shared/widgets/subscription_icon.dart';

import '../../helpers/pump_themed.dart';

void main() {
  group('SubscriptionIcon.monogramFor', () {
    test('uses up to two initials', () {
      expect(SubscriptionIcon.monogramFor('Netflix'), 'N');
      expect(SubscriptionIcon.monogramFor('Apple Music'), 'AM');
      expect(SubscriptionIcon.monogramFor('  google one  storage '), 'GO');
    });

    test('falls back for empty names', () {
      expect(SubscriptionIcon.monogramFor('   '), '?');
    });
  });

  testWidgets('prefers an explicit icon over the monogram', (tester) async {
    await tester.pumpThemed(
      const SubscriptionIcon(name: 'Apple Music', icon: LucideIcons.music),
    );

    expect(find.byIcon(LucideIcons.music), findsOneWidget);
    expect(find.text('AM'), findsNothing);
  });
}
