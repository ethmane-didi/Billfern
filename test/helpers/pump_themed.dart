import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:billfern/core/theme/app_theme.dart';

extension PumpThemed on WidgetTester {
  /// Pumps [child] inside a themed [MaterialApp] and [Scaffold].
  Future<void> pumpThemed(Widget child) {
    return pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Center(
            child: Padding(padding: const EdgeInsets.all(16), child: child),
          ),
        ),
      ),
    );
  }
}
