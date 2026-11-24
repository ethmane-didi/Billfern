import 'dart:async';

import 'package:google_fonts/google_fonts.dart';

/// Global test setup: never hit the network for fonts. Text falls back to the
/// default test font, which keeps tests hermetic.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  await testMain();
}
