import 'package:flutter/material.dart';

/// Shows a brief "coming soon" message for features that are not built yet.
void showComingSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}
