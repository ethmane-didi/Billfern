import 'package:flutter/painting.dart';

import '../models/billing_cycle.dart';
import '../models/reminder_preference.dart';
import '../models/subscription.dart';
import '../models/subscription_category.dart';
import '../models/subscription_glyph.dart';

/// Converts [Subscription]s to and from JSON-compatible maps for storage.
///
/// Money stays in integer minor units with its currency code; dates are
/// stored as ISO-8601 calendar dates. [schemaVersion] is written with every
/// record so migrations can recognise old data.
///
/// Versions:
/// - **1**: Phase 3 fields.
/// - **2**: adds `priceHistory` (earlier billing terms) and `endedOn`
///   (removed subscriptions kept for history). Version 1 records read as
///   having no price changes and not ended, so they decode unchanged.
abstract final class SubscriptionCodec {
  static const int schemaVersion = 2;

  static Map<String, Object?> toMap(Subscription s) => {
    'schema': schemaVersion,
    'id': s.id,
    'name': s.name,
    'plan': s.plan,
    'priceMinor': s.priceMinor,
    'currencyCode': s.currencyCode,
    'billingCycle': s.billingCycle.toJson(),
    'category': s.category.name,
    'startedOn': _date(s.startedOn),
    'billingAnchor': s.billingAnchor == null ? null : _date(s.billingAnchor!),
    'catalogId': s.catalogId,
    'websiteDomain': s.websiteDomain,
    'customColor': s.customColor?.toARGB32(),
    'customGlyph': s.customGlyph?.name,
    'status': s.status.name,
    'pausedOn': s.pausedOn == null ? null : _date(s.pausedOn!),
    'pauseHistory': [
      for (final p in s.pauseHistory)
        {'from': _date(p.from), 'until': _date(p.until)},
    ],
    'priceHistory': [
      for (final r in s.priceHistory)
        {
          'until': _date(r.until),
          'priceMinor': r.priceMinor,
          'currencyCode': r.currencyCode,
          'billingCycle': r.billingCycle.toJson(),
        },
    ],
    'endedOn': s.endedOn == null ? null : _date(s.endedOn!),
    'reminder': s.reminder.name,
    'notes': s.notes,
    'createdAt': s.createdAt?.toIso8601String(),
  };

  /// Parses a stored map. Throws [FormatException] for unusable records.
  static Subscription fromMap(Map<String, Object?> map) {
    String requireString(String key) {
      final value = map[key];
      if (value is String && value.isNotEmpty) return value;
      throw FormatException('Stored subscription is missing "$key".');
    }

    final priceMinor = map['priceMinor'];
    if (priceMinor is! int || priceMinor < 0) {
      throw const FormatException('Stored subscription has an invalid price.');
    }
    final status = map['status'] == SubscriptionStatus.paused.name
        ? SubscriptionStatus.paused
        : SubscriptionStatus.active;
    final pausedOn = _parseDate(map['pausedOn']);
    final color = map['customColor'];
    final glyph = map['customGlyph'];

    return Subscription(
      id: requireString('id'),
      name: requireString('name'),
      plan: map['plan'] as String? ?? '',
      priceMinor: priceMinor,
      currencyCode: requireString('currencyCode'),
      billingCycle: BillingCycle.fromJson(map['billingCycle']),
      category:
          SubscriptionCategory.tryParse(map['category'] as String? ?? '') ??
          SubscriptionCategory.productivity,
      startedOn:
          _parseDate(map['startedOn']) ??
          (throw const FormatException('Stored subscription has no start.')),
      billingAnchor: _parseDate(map['billingAnchor']),
      catalogId: map['catalogId'] as String?,
      websiteDomain: map['websiteDomain'] as String?,
      customColor: color is int ? Color(color) : null,
      customGlyph: glyph is String
          ? SubscriptionGlyph.values.where((g) => g.name == glyph).firstOrNull
          : null,
      // A paused record without a date would break the model; treat it as
      // paused from its start.
      status: status,
      pausedOn: status == SubscriptionStatus.paused
          ? (pausedOn ?? _parseDate(map['startedOn']))
          : null,
      pauseHistory: [
        for (final entry in (map['pauseHistory'] as List?) ?? const [])
          if (entry is Map &&
              _parseDate(entry['from']) != null &&
              _parseDate(entry['until']) != null)
            PausePeriod(
              from: _parseDate(entry['from'])!,
              until: _parseDate(entry['until'])!,
            ),
      ],
      priceHistory: _parsePriceHistory(map['priceHistory']),
      endedOn: _parseDate(map['endedOn']),
      reminder: ReminderPreference.fromName(map['reminder']),
      notes: map['notes'] as String?,
      createdAt: map['createdAt'] is String
          ? DateTime.tryParse(map['createdAt']! as String)
          : null,
    );
  }

  /// Valid revisions, oldest first. Malformed entries are dropped rather
  /// than failing the whole record.
  static List<PriceRevision> _parsePriceHistory(Object? value) {
    final revisions = <PriceRevision>[];
    for (final entry in (value as List?) ?? const []) {
      if (entry is! Map) continue;
      final until = _parseDate(entry['until']);
      final price = entry['priceMinor'];
      final currency = entry['currencyCode'];
      if (until == null ||
          price is! int ||
          price < 0 ||
          currency is! String ||
          currency.isEmpty) {
        continue;
      }
      revisions.add(
        PriceRevision(
          until: until,
          priceMinor: price,
          currencyCode: currency,
          billingCycle: BillingCycle.fromJson(entry['billingCycle']),
        ),
      );
    }
    return revisions..sort((a, b) => a.until.compareTo(b.until));
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    return parsed == null
        ? null
        : DateTime(parsed.year, parsed.month, parsed.day);
  }
}
