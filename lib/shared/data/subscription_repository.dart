import '../models/subscription.dart';
import 'mock_subscriptions.dart';

/// Source of the user's subscriptions.
///
/// The mock implementation is synchronous. A Supabase implementation will be
/// asynchronous; when it lands, `subscriptionsProvider` becomes an
/// `AsyncNotifier` and the derived providers propagate `AsyncValue`.
abstract interface class SubscriptionRepository {
  List<Subscription> fetchAll();
}

/// Serves [buildMockSubscriptions] relative to the injected clock.
class MockSubscriptionRepository implements SubscriptionRepository {
  const MockSubscriptionRepository({required this.today});

  final DateTime today;

  @override
  List<Subscription> fetchAll() => buildMockSubscriptions(today);
}
