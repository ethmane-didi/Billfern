import '../models/billing_cycle.dart';
import '../models/subscription.dart';
import '../models/subscription_category.dart';

/// Realistic sample subscriptions used until a backend exists.
///
/// Dates are relative to [today] so renewals always look current. Prices are
/// in US cents; yearly prices divide evenly by twelve so monthly equivalents
/// stay exact. Logos and brand colours come from the catalog via `catalogId`.
List<Subscription> buildMockSubscriptions(DateTime today) {
  DateTime daysAgo(int days) =>
      DateTime(today.year, today.month, today.day - days);

  return [
    Subscription(
      id: 'netflix',
      catalogId: 'netflix',
      name: 'Netflix',
      plan: 'Standard',
      priceCents: 1549,
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.entertainment,
      startedOn: daysAgo(426),
    ),
    Subscription(
      id: 'spotify',
      catalogId: 'spotify',
      name: 'Spotify',
      plan: 'Premium Individual',
      priceCents: 1199,
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.music,
      startedOn: daysAgo(702),
    ),
    Subscription(
      id: 'apple-music',
      catalogId: 'apple-music',
      name: 'Apple Music',
      plan: 'Individual',
      priceCents: 1099,
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.music,
      startedOn: daysAgo(118),
    ),
    Subscription(
      id: 'chatgpt',
      catalogId: 'chatgpt',
      name: 'ChatGPT',
      plan: 'Plus',
      priceCents: 2000,
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.aiTools,
      startedOn: daysAgo(52),
    ),
    Subscription(
      id: 'figma',
      catalogId: 'figma',
      name: 'Figma',
      plan: 'Professional',
      priceCents: 1500,
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.design,
      startedOn: daysAgo(311),
    ),
    Subscription(
      id: 'youtube-premium',
      catalogId: 'youtube-premium',
      name: 'YouTube Premium',
      plan: 'Individual',
      priceCents: 1399,
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.entertainment,
      startedOn: daysAgo(205),
    ),
    Subscription(
      id: 'notion',
      catalogId: 'notion',
      name: 'Notion',
      plan: 'Plus',
      priceCents: 1000,
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.productivity,
      startedOn: daysAgo(487),
    ),
    Subscription(
      id: 'icloud',
      catalogId: 'icloud-plus',
      name: 'iCloud+',
      plan: '200 GB',
      priceCents: 299,
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.cloudStorage,
      startedOn: daysAgo(893),
    ),
    Subscription(
      id: 'adobe-lightroom',
      catalogId: 'adobe-lightroom',
      name: 'Adobe Lightroom',
      plan: 'Photography',
      priceCents: 11988,
      billingCycle: BillingCycle.yearly,
      category: SubscriptionCategory.design,
      startedOn: daysAgo(348),
    ),
    Subscription(
      id: 'duolingo',
      catalogId: 'duolingo',
      name: 'Duolingo',
      plan: 'Super',
      priceCents: 8388,
      billingCycle: BillingCycle.yearly,
      category: SubscriptionCategory.learning,
      startedOn: daysAgo(160),
    ),
    Subscription(
      id: 'strava',
      catalogId: 'strava',
      name: 'Strava',
      plan: 'Premium',
      priceCents: 7188,
      billingCycle: BillingCycle.yearly,
      category: SubscriptionCategory.health,
      startedOn: daysAgo(24),
    ),
    Subscription(
      id: 'disney-plus',
      catalogId: 'disney-plus',
      name: 'Disney+',
      plan: 'Basic',
      priceCents: 999,
      billingCycle: BillingCycle.monthly,
      category: SubscriptionCategory.entertainment,
      startedOn: daysAgo(371),
      status: SubscriptionStatus.paused,
      pausedOn: daysAgo(12),
    ),
  ];
}
