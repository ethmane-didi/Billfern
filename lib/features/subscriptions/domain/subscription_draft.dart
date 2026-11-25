import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../../../core/utils/date_math.dart';
import '../../../shared/models/billing_cycle.dart';
import '../../../shared/models/reminder_preference.dart';
import '../../../shared/models/subscription.dart';
import '../../../shared/models/subscription_catalog_item.dart';
import '../../../shared/models/subscription_category.dart';
import '../../../shared/models/subscription_glyph.dart';

/// Form fields that can fail validation.
enum DraftField { name, amount, nextRenewal, website, notes }

/// Form state for adding or editing a subscription.
///
/// Picking a catalog service ([SubscriptionDraft.fromCatalog]) fills in the
/// name, category and branding, so the user only enters the amount, currency,
/// billing cycle and next renewal date. The currency starts as the user's
/// preferred currency but is the subscription's own: it is stored with the
/// price and never converted.
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
    this.reminder = ReminderPreference.oneDayBefore,
    this.notes = '',
    this.website = '',
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

  /// Pre-fills the edit form from an existing subscription.
  factory SubscriptionDraft.fromSubscription(
    Subscription subscription, {
    required DateTime today,
  }) => SubscriptionDraft(
    name: subscription.name,
    category: subscription.category,
    currencyCode: subscription.currencyCode,
    catalogId: subscription.catalogId,
    plan: subscription.plan,
    amountMinor: subscription.priceMinor,
    billingCycle: subscription.billingCycle,
    nextRenewal: subscription.scheduledRenewal(today),
    reminder: subscription.reminder,
    notes: subscription.notes ?? '',
    website: subscription.websiteDomain ?? '',
    customColor: subscription.customColor,
    customGlyph: subscription.customGlyph,
  );

  static const int maxNameLength = 60;
  static const int maxNotesLength = 500;

  final String name;
  final SubscriptionCategory category;
  final String? catalogId;
  final String plan;

  /// Price in minor units of [currencyCode].
  final int? amountMinor;
  final String currencyCode;
  final BillingCycle billingCycle;
  final DateTime? nextRenewal;
  final ReminderPreference reminder;
  final String notes;

  /// Website as typed; normalised to a domain on save.
  final String website;
  final Color? customColor;
  final SubscriptionGlyph? customGlyph;

  bool get isCustom => catalogId == null;

  /// Field errors for this draft; empty when it can be saved.
  Map<DraftField, String> validate({required DateTime today}) {
    final errors = <DraftField, String>{};
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      errors[DraftField.name] = 'Enter a name';
    } else if (trimmedName.length > maxNameLength) {
      errors[DraftField.name] = 'Use at most $maxNameLength characters';
    }

    final amount = amountMinor;
    if (amount == null) {
      errors[DraftField.amount] = 'Enter an amount';
    } else if (amount <= 0) {
      errors[DraftField.amount] = 'Amount must be greater than zero';
    }

    final renewal = nextRenewal;
    if (renewal == null) {
      errors[DraftField.nextRenewal] = 'Choose the next renewal date';
    } else if (DateMath.dateOnly(renewal).isBefore(DateMath.dateOnly(today))) {
      errors[DraftField.nextRenewal] = 'Choose today or a future date';
    }

    if (website.trim().isNotEmpty && normalizeDomain(website) == null) {
      errors[DraftField.website] = 'Enter a valid website, e.g. example.com';
    }
    if (notes.length > maxNotesLength) {
      errors[DraftField.notes] = 'Use at most $maxNotesLength characters';
    }
    return errors;
  }

  bool isValid({required DateTime today}) => validate(today: today).isEmpty;

  SubscriptionDraft copyWith({
    String? name,
    SubscriptionCategory? category,
    String? plan,
    int? amountMinor,
    bool clearAmount = false,
    String? currencyCode,
    BillingCycle? billingCycle,
    DateTime? nextRenewal,
    ReminderPreference? reminder,
    String? notes,
    String? website,
    Color? customColor,
    SubscriptionGlyph? customGlyph,
  }) {
    return SubscriptionDraft(
      name: name ?? this.name,
      category: category ?? this.category,
      catalogId: catalogId,
      plan: plan ?? this.plan,
      amountMinor: clearAmount ? null : (amountMinor ?? this.amountMinor),
      currencyCode: currencyCode ?? this.currencyCode,
      billingCycle: billingCycle ?? this.billingCycle,
      nextRenewal: nextRenewal ?? this.nextRenewal,
      reminder: reminder ?? this.reminder,
      notes: notes ?? this.notes,
      website: website ?? this.website,
      customColor: customColor ?? this.customColor,
      customGlyph: customGlyph ?? this.customGlyph,
    );
  }

  /// Builds the subscription to save.
  ///
  /// - New ([existing] is `null`): tracking starts [today] (so history is
  ///   not invented) and renewals are anchored on [nextRenewal].
  /// - Edit: keeps id, status, pause history, start and creation dates;
  ///   only the billing anchor moves, so past months are unaffected.
  ///
  /// Throws [StateError] when [validate] reports errors.
  Subscription toSubscription({
    required String id,
    required DateTime today,
    DateTime? now,
    Subscription? existing,
  }) {
    final errors = validate(today: today);
    if (errors.isNotEmpty) {
      throw StateError('Invalid subscription: ${errors.values.join(', ')}');
    }
    final renewal = DateMath.dateOnly(nextRenewal!);
    final trimmedNotes = notes.trim();
    return Subscription(
      id: existing?.id ?? id,
      name: name.trim(),
      plan: plan.trim(),
      priceMinor: amountMinor!,
      currencyCode: currencyCode,
      billingCycle: billingCycle,
      category: category,
      startedOn: existing?.startedOn ?? DateMath.dateOnly(today),
      billingAnchor: renewal,
      catalogId: catalogId,
      websiteDomain: normalizeDomain(website),
      customColor: isCustom ? customColor : null,
      customGlyph: isCustom ? customGlyph : null,
      status: existing?.status ?? SubscriptionStatus.active,
      pausedOn: existing?.pausedOn,
      pauseHistory: existing?.pauseHistory ?? const [],
      reminder: reminder,
      notes: trimmedNotes.isEmpty ? null : trimmedNotes,
      createdAt: existing?.createdAt ?? now ?? today,
    );
  }

  /// `https://www.Example.com/path` → `example.com`; `null` when empty or
  /// not a plausible domain.
  static String? normalizeDomain(String? value) {
    if (value == null) return null;
    var domain = value.trim().toLowerCase();
    if (domain.isEmpty) return null;
    domain = domain.replaceFirst(RegExp(r'^[a-z][a-z0-9+.-]*://'), '');
    domain = domain.replaceFirst(RegExp(r'^www\.'), '');
    domain = domain.split(RegExp(r'[/?#:]')).first;
    final valid = RegExp(
      r'^(?:[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,24}$',
    ).hasMatch(domain);
    return valid ? domain : null;
  }
}
