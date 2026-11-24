import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../shared/widgets/placeholder_view.dart';

class SubscriptionsScreen extends StatelessWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      icon: LucideIcons.layers,
      title: 'Subscriptions',
      message:
          'Manage active and paused subscriptions in one place. '
          'Coming soon.',
    );
  }
}
