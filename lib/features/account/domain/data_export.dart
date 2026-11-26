import 'dart:convert';

import '../../../shared/data/subscription_codec.dart';
import '../../../shared/models/subscription.dart';

/// Builds a portable JSON export of the user's own subscriptions.
///
/// **Architecture for data portability.** The export uses the same record
/// format as local storage and cloud sync (SubscriptionCodec), including
/// price revisions, pause periods and archived subscriptions, with money as
/// integer minor units plus currency codes. A user-facing "Export my data"
/// action (share sheet / file) can be added on top of this.
class DataExportService {
  const DataExportService();

  static const int formatVersion = 1;

  Map<String, Object?> build(
    Iterable<Subscription> subscriptions, {
    required DateTime exportedAt,
  }) {
    final all = subscriptions.toList()..sort((a, b) => a.id.compareTo(b.id));
    return {
      'format': 'billfern-export',
      'formatVersion': formatVersion,
      'recordSchema': SubscriptionCodec.schemaVersion,
      'exportedAt': exportedAt.toUtc().toIso8601String(),
      'subscriptions': [
        for (final s in all)
          if (!s.isEnded) SubscriptionCodec.toMap(s),
      ],
      'endedSubscriptions': [
        for (final s in all)
          if (s.isEnded) SubscriptionCodec.toMap(s),
      ],
    };
  }

  String toJson(
    Iterable<Subscription> subscriptions, {
    required DateTime exportedAt,
  }) =>
      const JsonEncoder.withIndent('  ')
          .convert(build(subscriptions, exportedAt: exportedAt));
}
