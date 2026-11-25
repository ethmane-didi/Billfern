import 'package:flutter/foundation.dart';

import '../../../core/money/money.dart';

/// How trustworthy a spending figure is.
enum SpendingBasis {
  /// Calculated from recorded subscription schedules, price revisions and
  /// pauses. All historical spending is estimated until payments can be
  /// confirmed.
  estimated('Estimated'),

  /// Expected future payments from active subscription schedules.
  projected('Projected'),

  /// Actual payments recorded or confirmed by the user (or, later, a bank
  /// connection). None exist yet.
  confirmed('Confirmed');

  const SpendingBasis(this.label);

  final String label;
}

/// Where a confirmed payment came from. Only declared so the data model is
/// ready; nothing creates records yet.
enum PaymentRecordSource { manual, bank }

/// An actual payment for a subscription, explicitly recorded or confirmed.
///
/// **Architecture only.** Billfern has no payment confirmation or banking
/// integration yet, so no records exist and every historical figure is
/// [SpendingBasis.estimated]. When records arrive, analytics shows them as
/// [SpendingBasis.confirmed] next to the estimates.
@immutable
class PaymentRecord {
  const PaymentRecord({
    required this.id,
    required this.subscriptionId,
    required this.paidOn,
    required this.amount,
    required this.source,
  });

  final String id;
  final String subscriptionId;
  final DateTime paidOn;

  /// Amount actually charged, in the currency it was charged in.
  final Money amount;

  final PaymentRecordSource source;

  @override
  bool operator ==(Object other) =>
      other is PaymentRecord &&
      other.id == id &&
      other.subscriptionId == subscriptionId &&
      other.paidOn == paidOn &&
      other.amount == amount &&
      other.source == source;

  @override
  int get hashCode => Object.hash(id, subscriptionId, paidOn, amount, source);
}

/// Source of confirmed payments. Replace [NoPaymentRecordRepository] when
/// manual confirmation or bank sync is built.
abstract interface class PaymentRecordRepository {
  List<PaymentRecord> fetchAll();
}

/// Default: no confirmed payments exist.
class NoPaymentRecordRepository implements PaymentRecordRepository {
  const NoPaymentRecordRepository();

  @override
  List<PaymentRecord> fetchAll() => const [];
}
