# Billfern — Phase 4: Analytics

**Branch:** `feat/analytics` (shared with Phase 3.1 branding).
**Status:** Implemented and approved.

Read this specification completely before changing Analytics. Permanent architecture
and conventions live in `CLAUDE.md`, and public documentation lives in `README.md`.

## 1. Financial history

Do not invent historical spending. Clearly distinguish between:

- **Estimated historical spending:** calculated from recorded subscription schedules
  and historical revisions.
- **Projected spending:** expected future payments based on active subscription
  schedules.
- **Confirmed spending:** actual payments explicitly recorded or confirmed by the user.

Billfern has no banking integration or manual payment confirmation yet, so historical
spending must be labelled as estimated.

Prepare the data architecture for future confirmed payment records, but do not
implement a complete payment management system now.

Preserve historical subscription information after price changes, billing-cycle
changes, pauses, resumes and deletions.

Introduce subscription revisions, or an equivalent history mechanism, if necessary.
Never apply today's prices retroactively to previous months.

Preserve existing user data through safe database migrations.

## 2. Spending trends

Use `fl_chart` to implement:

- An interactive yellow line or area chart.
- A subtle yellow gradient fill.
- 3-month, 6-month and 12-month period selectors.
- A monthly spending comparison.
- The percentage change.
- Interactive tooltips.
- Monthly and yearly spending summaries.
- Empty and insufficient-history states.

Handle comparisons against zero spending correctly.

Never display fabricated history for real users.

## 3. Category breakdown

Display each category with:

- Its icon and name.
- Monthly spending.
- Percentage of total spending.
- Active subscription count.
- A circular progress indicator.

Let users select a category to see the subscriptions in it.

Category percentages and totals must agree with the dashboard.

## 4. Upcoming payments

Display projected renewal commitments for the next 7, 30 and 90 days.

Show the number of expected payments and their combined estimated cost.

Respect custom billing cycles, paused subscriptions, month-end dates and leap years.

## 5. Smart savings insights

Implement local rule-based suggestions for:

- Potentially overlapping subscriptions.
- Multiple music or streaming services.
- Expensive recurring subscriptions.
- Upcoming annual renewals.
- Potential monthly and yearly savings from cancellation.

Do not claim that a subscription is unused without actual usage information.

Do not assume overlapping subscriptions are unnecessary.

Label these as smart suggestions, not verified AI analysis.

## 6. Architecture

Reuse the existing:

- Riverpod `subscriptionsProvider`.
- Sembast repository.
- Subscription catalog and logos.
- Currency conversion service.
- Currency preferences.
- Integer minor-unit monetary models.
- Sample-data architecture.

Create dedicated Analytics providers and calculators where appropriate.

Keep financial calculations out of UI widgets.

Analytics must update automatically after a subscription is created, edited, paused,
resumed or deleted, and after a currency change.

Preserve historical records when subscriptions change.

Keep clearly labelling mock, missing and stale exchange rates.

## 7. UI design

Read `docs/design/dashboard-reference.png`, especially the Analytics screen on the
right.

Keep using the established Billfern design system:

- Midnight: #202020
- Yellow: #FFDA69
- Mint: #43C4AE
- Lavender: #E7E8F4
- Warm cream: #F5EFEB
- White: #FFFFFF
- Typography: Manrope

Screen structure:

1. Analytics header and preferred currency selector.
2. Spending overview.
3. Interactive spending chart.
4. Monthly and yearly summaries.
5. Category breakdown.
6. Upcoming payments.
7. Smart savings insights.
8. The existing floating bottom navigation.

Use pastel gradients, rounded white cards, generous whitespace and accessible
typography.

Reuse existing components and keep the official Billfern branding.

Provide polished empty states with an "Add subscription" action.

Keep sample data visibly labelled and isolated from real user data.

## 8. Scope restrictions

Do not integrate Supabase, authentication, OpenAI, RevenueCat, banking APIs, external
exchange-rate APIs or notification scheduling yet.

Do not change the launcher icon; a separate symbol-only asset will be provided.

Do not introduce unrelated changes.

## 9. Validation

Add tests covering:

- Monthly and yearly spending totals.
- Category percentages.
- Period comparisons.
- Mixed currencies.
- Missing and stale exchange rates.
- Historical price and billing-cycle changes.
- Pause, resume and deletion history.
- Upcoming payment projections.
- Custom billing intervals.
- Leap years and month-end dates.
- Savings estimates.
- Dashboard and Analytics consistency.
- Empty states and sample-data isolation.
- Responsive layouts and accessibility.
- Database migrations, if needed.

Run these in order:

1. `flutter pub get`
2. `dart format` on modified files
3. `flutter analyze`
4. `flutter test --concurrency=2`

Keep the simulator closed during testing. Check available disk space before the iOS
simulator build. Use only the existing Billfern Simulator to review Analytics and the
branding screens. Follow the resource constraints in `CLAUDE.md`.

## 10. Completion

Update `CLAUDE.md` and `README.md` with the Analytics architecture, historical
spending rules, currency handling and known limitations.

Report the implementation, architectural decisions, files changed, test results and
the simulator review.

## Acceptance criteria

- [x] Historical figures are labelled **estimated**, future figures **projected**, and
  confirmed payments are prepared in the data model (`PaymentRecord`).
- [x] Months before tracking show no data, never zero. Insufficient history and
  comparisons against zero are handled.
- [x] Price, currency and billing-cycle revisions (`priceHistory`) and deletions
  (`endedOn`) keep past months intact. The schema 1 → 2 migration preserves data.
- [x] Interactive 3, 6 and 12-month trend with tooltips, selected month and period
  comparison.
- [x] Category rows match the dashboard's breakdown and expand to their subscriptions.
- [x] 7, 30 and 90-day projected payments respect custom cycles, pauses, month ends and
  leap years.
- [x] Rule-based suggestions with savings estimates, honest wording and a
  "not AI" label.
- [x] Empty state with "Add subscription". Sample data is labelled and isolated.
- [x] Tests for every validation item, including overflow sweeps and accessibility
  guidelines.
