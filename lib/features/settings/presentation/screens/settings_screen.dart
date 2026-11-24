import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../shared/widgets/placeholder_view.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      icon: LucideIcons.slidersHorizontal,
      title: 'Settings',
      message:
          'Currency, reminders, account and premium plans. '
          'Coming soon.',
    );
  }
}
