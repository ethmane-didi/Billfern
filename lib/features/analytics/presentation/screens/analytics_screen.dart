import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../shared/widgets/placeholder_view.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderView(
      icon: LucideIcons.chartColumn,
      title: 'Analytics',
      message:
          'Spending trends, categories and AI savings insights. '
          'Coming soon.',
    );
  }
}
