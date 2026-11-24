import 'package:flutter/painting.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/date_math.dart';
import '../../../shared/models/billing_cycle.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_catalog_item.dart';
import '../../../shared/models/subscription_category.dart';
import '../../../shared/models/subscription_glyph.dart';

/// Form state for the Phase 3 Add Subscription flow.
///
/// Picking a catalog service ([SubscriptionDraft.fromCatalog]) fills in the
/// name, category and branding, so the user only enters the amount, currency,
/// billing cycle and next renewal date. The currency starts as the user's
/// preferred currency but is the subscription's own: it is stored with the
/// price and never converted. A custom draft
/// ([SubscriptionDraft.custom]) also accepts an optional website, colour and
/// icon.
@immutable
class SubscriptionDraft {
  const SubscriptionDraft({
    required this.name,
    required this.category,
    required this.currencyCode,
    this.catalogId,
    this.plan = '',
    this.amountMinor,
    this.billingCycle = BillingCycle.monthly,
    this.nextRenewal,
    this.websiteDomain,
    this.customColor,
    this.customGlyph,
  });

  factory SubscriptionDraft.fromCatalog(
    SubscriptionCatalogItem item, {
    required String currencyCode,
  }) => SubscriptionDraft(
    name: item.name,
    category: item.category,
    catalogId: item.id,
    currencyCode: currencyCode,
  );

  factory SubscriptionDraft.custom({
    required String currencyCode,
    String name = '',
    SubscriptionCategory category = SubscriptionCategory.productivity,
  }) => SubscriptionDraft(
    name: name,
    category: category,
    currencyCode: currencyCode,
  );

  final String name;
  final SubscriptionCategory category;
  final String? catalogId;
  final String plan;

  /// Price in minor units of [currencyCode].
  final int? amountMinor;
  final String currencyCode;
  final BillingCycle billingCycle;
  final DateTime? nextRenewal;
  final String? websiteDomain;
  final Color? customColor;
  final SubscriptionGlyph? customGlyph;

  bool get isCustom => catalogId == null;

  /// Whether every field the user must provide is filled in.
  bool get isComplete =>
      name.trim().isNotEmpty &&
      amountMinor != null &&
      amountMinor! >= 0 &&
      nextRenewal != null;

  SubscriptionDraft copyWith({
    String? name,
    SubscriptionCategory? category,
    String? plan,
    int? amountMinor,
    String? currencyCode,
    BillingCycle? billingCycle,
    DateTime? nextRenewal,
    String? websiteDomain,
    Color? customColor,
    SubscriptionGlyph? customGlyph,
  }) {
    return SubscriptionDraft(
      name: name ?? this.name,
      category: category ?? this.category,
      catalogId: catalogId,
      plan: plan ?? this.plan,
      amountMinor: amountMinor ?? this.amountMinor,
      currencyCode: currencyCode ?? this.currencyCode,
      billingCycle: billingCycle ?? this.billingCycle,
      nextRenewal: nextRenewal ?? this.nextRenewal,
      websiteDomain: websiteDomain ?? this.websiteDomain,
      customColor: customColor ?? this.customColor,
      customGlyph: customGlyph ?? this.customGlyph,
    );
  }

  /// Builds the subscription. The billing anchor is set one cycle before
  /// [nextRenewal], so `Subscription.nextRenewal` returns exactly that date.
  /// Custom branding fields are only kept for custom subscriptions.
  Subscription toSubscription({required String id}) {
    if (!isComplete) {
      throw StateError(
        'Draft is incomplete: name, amount and renewal date '
        'are required.',
      );
    }
    final renewal = DateMath.dateOnly(nextRenewal!);
    return Subscription(
      id: id,
      name: name.trim(),
      plan: plan.trim().isEmpty ? billingCycle.label : plan.trim(),
      priceMinor: amountMinor!,
      billingCycle: billingCycle,
      category: category,
      startedOn: DateMath.addMonths(renewal, -billingCycle.months),
      catalogId: catalogId,
      currencyCode: currencyCode,
      websiteDomain: isCustom ? _cleanDomain(websiteDomain) : null,
      customColor: isCustom ? customColor : null,
      customGlyph: isCustom ? customGlyph : null,
    );
  }

  /// `https://www.Example.com/path` → `example.com`.
  static String? _cleanDomain(String? value) {
    if (value == null) return null;
    var domain = value.trim().toLowerCase();
    domain = domain.replaceFirst(RegExp(r'^[a-z]+://'), '');
    domain = domain.replaceFirst(RegExp(r'^www\.'), '');
    domain = domain.split(RegExp(r'[/?#]')).first;
    return domain.isEmpty ? null : domain;
  }
}
