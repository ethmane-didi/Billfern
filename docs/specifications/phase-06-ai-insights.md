# Billfern — Phase 6: Smart Insights and AI Intelligence

## 1. Starting Point

Billfern is an offline-first subscription management application built with Flutter.

Completed development phases:

- Phase 1: Design foundation.
- Phase 2: Dashboard, subscription catalog and multi-currency support.
- Phase 3: Subscription management, branding and onboarding.
- Phase 4: Spending analytics, subscription history and rule-based smart suggestions.
- Phase 5: Optional Supabase authentication and offline-first synchronization.

Phase 5 checkpoint:

- Branch: `feat/backend`
- Commit: `51883b2d20746cc859fb068b9bfd00b0bf238fe5`
- Automated tests: 362 passing.
- Flutter analysis: clean.
- Live backend validation: partially completed (see README "Validation status").
- Phase 5 has **not** been merged into `main`.

This specification does not by itself authorize implementation. Each part starts only
after the prerequisites in section 3 are met and the user explicitly approves it.

Phase 6 has two parts, delivered and approved separately:

| Part | Scope | Backend | Migrations | New dependencies |
|---|---|---|---|---|
| **6A — Local Smart Insights** | Insights engine, ranking, budget, savings scenarios, Insights screens, dashboard preview, review and dismissal state | None | None | None |
| **6B — AI Intelligence** | Optional AI explanations through a Supabase Edge Function calling OpenAI, with consent, quotas, cost controls and a cache | Supabase Edge Function | One new migration | None in Flutter (Edge Function uses its runtime's standard library and `fetch`) |

Before implementation of either part:

- Read `CLAUDE.md`, `README.md`, this specification and the Phase 4 and Phase 5
  specifications completely.
- Inspect existing models, repositories, providers and analytics services.
- Do not modify or overwrite existing functionality except where this specification
  explicitly replaces it (section 4.3).

## 2. Product Vision

Billfern helps users understand their recurring expenses, notice costs worth
reviewing and make informed subscription decisions.

The insights layer answers:

- Where is my subscription money going?
- Which subscriptions deserve my attention?
- How has my recurring spending changed?
- Where could I potentially save money?
- Which renewals should I review?
- Am I approaching my monthly subscription budget?

Insights are actionable and evidence-based, never generic financial advice.

Billfern never cancels, purchases, renews, pauses or modifies a subscription without
an explicit user action in the existing subscription screens.

## 3. Prerequisites and Approval Gates

### 3.1 Phase 6A

Phase 6A may begin only when **all** of the following are true:

1. The user has approved merging Phase 5 (`feat/backend`) into `main`, and the merge
   is complete.
2. The user has explicitly approved Phase 6A implementation.
3. `feat/ai-insights` has been created from the merged `main`.
4. `CLAUDE.md` "Current phase" is updated to authorize local insights only (OpenAI
   integration remains prohibited until 6B is approved).

Phase 6A has no dependency on Phase 5 live validation, because it adds no backend
behavior.

### 3.2 Phase 6B

Phase 6B may begin only when **all** of the following are true:

1. Phase 6A is complete, reviewed and approved.
2. Phase 5 live security validation is complete against the development project:
   - The live suite (`test_live/live_supabase_test.dart`) passes.
   - The pgTAP RLS tests (`supabase/tests/database/rls.test.sql`) pass.
3. Phase 5 account isolation is validated live (cross-account reads and writes are
   refused).
4. Phase 5 end-to-end account deletion is validated live through the
   `delete-account` Edge Function, including the gateway JWT configuration.
5. The OpenAI verification record (section 16.1) is completed and approved.
6. The user has explicitly approved Phase 6B implementation.

Security blockers are never silently deferred. If any item fails, Phase 6B stops and
the failure is reported.

## 4. Architecture

### 4.1 Layers

1. **Local Insights Engine (6A).** Deterministic Dart. Every calculation, comparison,
   ranking and monetary figure. Works offline, for guests and accounts, and in sample
   mode (labelled as sample data).
2. **AI Insights Service (6B).** Optional. Explains and prioritizes evidence produced
   by layer 1. It is never a source of financial figures.
3. **Presentation.** Flutter and Riverpod: cards, details, states, consent, settings
   and refresh behavior.

Sembast remains the local source of truth. Supabase remains the optional
authentication, sync and server-side service layer.

### 4.2 Reuse of existing architecture

Phase 6A **extends** Phase 4; it does not duplicate it.

| Existing component | Phase 6 use |
|---|---|
| `RuleBasedSuggestionEngine` (`features/analytics/domain/smart_suggestion_engine.dart`) | Remains the rule source for duplicate services, overlapping services, annual renewals and the largest subscription. New rules are added alongside it behind one engine interface. |
| `SmartSuggestion`, `SmartSuggestions`, `SuggestionKind` | Mapped into the shared insight model. `SmartSuggestions`' "count each subscription once" savings rule is the single implementation of non-double-counting. |
| `AnalyticsCalculator`, `PeriodComparison.between` (`noBaseline`, `fromZero`, `increase`, `decrease`, `unchanged`) | The only source of period comparisons for spending growth. |
| `SpendingCalculator` (`totalForMonth`, `convertedSum`, `projectedPayments`) | The only source of totals, converted sums and projected payments. |
| `Subscription.monthlyCost`, `annualCost`, `monthlyCostForMonth`, `priceHistory`, `billingDatesBetween` | Normalized costs, history-safe terms and renewal dates. |
| `Money.scaleRounded`, `CurrencyConverter` / `MoneyConverter`, `CurrencyFormatter` | All arithmetic, conversion and formatting. |
| `AnalyticsCopy` pattern | `InsightCopy` holds all insight wording. |
| `LocalStore` / `activeLocalStoreProvider` | Identity-scoped persistence for budgets, review and dismissal state, and the AI cache. |

No widget performs financial calculations.

### 4.3 Replaced components

Phase 6A **removes**:

- `MockSavingsInsightEngine` and `savingsInsightEngineProvider`
  (`features/dashboard/domain/savings_insight_engine.dart`).
- `AiInsightCard` (`features/dashboard/presentation/widgets/ai_insight_card.dart`).

They are replaced by `InsightPreviewCard` on the dashboard (section 13). There is
never more than one insight card on the dashboard. Their tests are replaced, not
deleted without replacement.

`SmartSuggestionsSection` on the Analytics screen is rebuilt on the shared insight
model so that Analytics, the Insights screen and the dashboard present the same
ranked insights with the same wording.

### 4.4 Module layout

```
lib/features/insights/
├── domain/
│   ├── insight.dart                 # Insight, InsightKind, InsightPriority, InsightSource
│   ├── insight_evidence.dart        # typed evidence (sealed classes)
│   ├── insight_engine.dart          # interface + LocalInsightEngine (wraps RuleBasedSuggestionEngine)
│   ├── insight_rules/               # price change, renewal cluster, spending growth, budget, expensive
│   ├── insight_ranking.dart         # deterministic ranking
│   ├── insight_identity.dart        # stable ids and evidence fingerprints
│   ├── savings_scenario.dart        # scenario calculator
│   └── budget.dart                  # SubscriptionBudget, BudgetStatus
├── data/
│   ├── insight_state_store.dart     # identity-scoped sembast stores
│   └── (6B) ai_insights_remote.dart, ai_insight_cache.dart
└── presentation/
    ├── insight_copy.dart            # all wording
    ├── providers/insight_providers.dart
    ├── screens/                     # InsightsScreen, InsightDetailScreen, BudgetScreen, (6B) AiInsightsSettingsScreen
    └── widgets/                     # cards, savings overview, budget progress, scenario sheet
```

Exact names may be adjusted after inspecting conventions, but the responsibilities and
boundaries above are fixed.

### 4.5 Routing

- `/analytics/insights` — `InsightsScreen` (inside the Analytics branch).
- `/analytics/insights/:id` — `InsightDetailScreen`.
- `/analytics/insights/budget` — budget editor (root navigator, like add and edit).
- `/settings/ai-insights` — AI settings and consent (6B only).

Add `AppRoutes` helpers for each. The bottom navigation is unchanged: no new tab.

## 5. Insight Data Model

```
Insight
  id: String                 // stable, see 5.2
  kind: InsightKind
  priority: InsightPriority  // informational, low, medium, high
  evidence: InsightEvidence  // typed, sealed; the only source of figures and copy
  subscriptionIds: List<String>
  fingerprint: String        // see 5.3
  validUntil: DateTime?      // calendar date; null = valid while evidence holds
  source: InsightSource      // local (6A); aiExplained (6B overlay only)
  isSample: bool             // derived from DataMode.sample
```

`InsightKind`: `duplicateService`, `overlappingServices`, `annualRenewal`,
`largestSubscription` (existing Phase 4 kinds), plus `priceChange`, `termsChange`,
`renewalCluster`, `upcomingHighCostRenewal`, `spendingGrowth`, `budgetNearLimit`,
`budgetExceeded`, `reviewReminder`.

Rules:

- **Titles and descriptions are not stored.** `InsightCopy` generates them from typed
  evidence at render time, so wording rules stay centralized and testable.
- All money in evidence is `Money` (integer minor units plus currency code). Converted
  values carry `isEstimate`.
- Evidence keeps original-currency values alongside any converted value.
- Copy is English today. `InsightCopy` formats numbers and money only through
  `CurrencyFormatter` and `intl`, and is structured so translations can be added
  without changing the engine. A translation framework is out of scope.

### 5.1 Language rules

Allowed: "worth reviewing", "consider whether you still need this", "review before
renewal", "potential", "hypothetical", "estimated".

Banned (enforced by tests, extending the Phase 4 banned-phrase list): any claim that a
service is unused, unnecessary, wasted or forgotten; "you are wasting money"; "you
haven't used"; guaranteed savings or refunds; urgency pressure ("act now", "don't
miss"); alarming words ("warning", "danger") outside genuine budget-exceeded copy.

Legitimate multiple accounts are never called accidental duplicates: duplicate copy
says "You have two subscriptions to …; review whether you need both".

### 5.2 Stable identifiers

`id = "<kind>:<sorted subscription ids joined by ','>[:<scope key>]"`

Scope keys:

- Renewal insights: the renewal date (`YYYY-MM-DD`).
- Price and terms changes: the revision's `until` date.
- Spending growth: the period (`6m`, `12m`) and the period end month.
- Budget: `budget`.

The id is unchanged while the underlying evidence identity is unchanged.

### 5.3 Evidence fingerprints

`fingerprint` is a deterministic, non-cryptographic hash (FNV-1a 64-bit, implemented
locally; no new dependency) over a canonical string of the evidence that drives the
insight:

- Subscription ids, `priceMinor`, `currencyCode`, billing cycle, status, `pausedOn`,
  `endedOn` and the relevant revision dates.
- Display currency.
- Exchange-rate state identity: `available` / `stale` / `unavailable` plus the rate
  snapshot timestamp.
- Budget amount and currency (budget insights).

A fingerprint change means the evidence changed (section 7).

## 6. Insight Rules (Phase 6A)

All rules are pure functions of: current subscriptions, history
(`subscriptionHistoryProvider`), today (`clockProvider`), the money converter, the
budget and review state. Paused and ended subscriptions follow their actual financial
status (they are excluded from current totals, renewals and projections).

### 6.1 Duplicate and overlapping services

- Reuse `RuleBasedSuggestionEngine` duplicate and overlap rules.
- **Functional groups.** Add an optional `overlapGroup` field to catalog entries in
  `tool/catalog/build_catalog.py` (for example `videoStreaming`, `musicStreaming`,
  `cloudStorage`, `aiAssistant`, `fitness`, `productivitySuite`) and regenerate the
  catalog. No prices are ever added.
- Overlap uses `overlapGroup` when present. Custom subscriptions without a group fall
  back to the existing `overlapCategories` rule. Two subscriptions in the same broad
  category but different groups are **not** an overlap.
- Copy: "You have three video streaming subscriptions. Review whether all three are
  still useful to you."

### 6.2 Price changes and terms changes

From `priceHistory` (`PriceRevision`: terms in force **until** a date) and current terms:

- Compare the revision before the change with the terms after it, as **normalized
  monthly equivalents in the same original currency** (`monthlyCost` semantics,
  `Money.scaleRounded`).
- Same currency, higher monthly equivalent → `priceChange` with previous price,
  current price, absolute monthly difference, percentage (basis points, integer
  maths), annualized impact (`scaleRounded` ×12/1 on the monthly difference, or the
  exact annual equivalents' difference), effective date.
- Same currency, lower → `priceChange` (decrease), informational.
- Different currency → `termsChange`: shows old and new terms in their own
  currencies. **No percentage, no "increase" wording**, no converted difference.
- Billing-cycle-only change with an unchanged monthly equivalent → `termsChange`,
  informational.
- Never apply current prices to historical periods.

### 6.3 Expensive subscriptions

- Reuse the `largestSubscription` rule (≥ 10% share, ≥ 3 subscriptions).
- Show the share of current monthly recurring spending (largest-remainder percentages
  are not needed for a single share; use integer basis points).
- Proportional wording only: "Your cloud storage subscription represents 28% of your
  monthly recurring expenses."
- Requires conversion for mixed currencies; if any required rate is missing, the
  share is not shown and the insight is suppressed.

### 6.4 Upcoming renewals

Reuse `SpendingCalculator.projectedPayments`.

- `annualRenewal`: existing rule (cycles of six months or longer, within 60 days).
- `upcomingHighCostRenewal`: a projected payment within 14 days whose converted amount
  is ≥ 25% of current monthly recurring spending.
- `renewalCluster`: three or more projected payments within any 7-day window starting
  in the next 30 days.
- No notification scheduling (Phase 7).

### 6.5 Spending growth

- Use `AnalyticsCalculator` and `PeriodComparison.between` unchanged, including
  `noBaseline` and `fromZero` behavior. Never divide by zero; `percent == null` has no
  percentage copy.
- Only complete comparison periods with full history are compared; otherwise no
  insight.
- Explain the drivers that can be computed deterministically: new subscriptions,
  price increases (6.2), billing-cycle changes, resumed subscriptions.
- **Exchange-rate movement attribution is deferred.** Billfern has no historical rates;
  never infer a currency effect. When converted totals are involved, label them as
  estimates.

### 6.6 Budget

See section 8.

### 6.7 Annual billing review

The catalog has no prices, so Billfern never proposes annual-plan savings,
discounts, provider offers, promotional rates or cancellation conditions. The
existing `annualRenewal` insight covers "review your plan before it renews"; when
relevant, its copy suggests checking available plans directly with the provider.

### 6.8 Review reminders

A subscription the user marked for review (section 7.3) produces `reviewReminder`
when it has a projected renewal within 14 days.

### 6.9 Volume limits

- At most 20 local insights are generated; extra low-priority insights are dropped by
  rank.
- At most one insight per (kind, subscription set).

## 7. Expiry, Dismissal and Review

### 7.1 Expiry

Insights are recomputed whenever subscriptions, history, display currency, rates,
budget, review state or the date change. In addition:

| Kind | `validUntil` |
|---|---|
| `annualRenewal`, `upcomingHighCostRenewal`, `reviewReminder` | The renewal date (end of that local day) |
| `renewalCluster` | The last payment date in the cluster |
| `priceChange`, `termsChange` | 60 days after the effective date |
| Overlap, duplicate, expensive, growth, budget | None: valid while the rule still holds |

An expired insight is never shown, even if it is still cached.

### 7.2 Dismissal

- Stored per identity as `(insightId, fingerprint, dismissedAt)`.
- A dismissed insight stays hidden while its fingerprint is unchanged.
- If the fingerprint changes (evidence changed: price, members, currency, budget, rate
  state), the insight returns, because it is a materially different observation.
- Dismissals of expired insights, and of insights not generated for 30 days, are
  removed on the next recomputation.
- Users can restore dismissed insights from the expanded view ("Show dismissed").

### 7.3 Review state

- "Mark for review" is stored per identity as `(subscriptionId, markedAt)`, **separate
  from `Subscription`**. It never changes the subscription codec, the sync payload or
  SQL.
- The mark is removed when the subscription is deleted or ended, or when the user
  clears it.
- No free-text notes are stored with it.

### 7.4 Evidence invalidation (AI overlay, 6B)

A cached AI explanation is shown only for evidence whose current fingerprint equals
the fingerprint it was generated for. Otherwise the explanation is hidden and the
local insight is shown alone, with "AI explanation outdated".

## 8. Subscription Budget

- Optional monthly budget, set, edited and removed from the Insights screen.
- Stored per identity as `Money` in the currency the user chose (default: the display
  currency at creation). Validation: > 0 and ≤ 1,000,000 major units.
- **Local only in Phase 6.** No sync, no migration.
- Compared with current monthly recurring spending (the dashboard hero total from
  `SpendingCalculator`), in the display currency.
- If the budget currency equals the display currency: show budget, spending, remaining
  or exceeded amount and percentage used (integer basis points, rounded for display).
- If they differ and a rate exists: convert the budget with `MoneyConverter`, label it
  "≈" with a `ConversionNote`, and keep the original amount visible ("Budget kr 2,000
  ≈ $186"). The saved budget is never rewritten.
- If any required rate is missing or spending excludes subscriptions: show the budget
  in its own currency, show spending with the existing exclusion note, and **suppress**
  the percentage, remaining and exceeded figures, with an explanation.
- Insights: `budgetNearLimit` at ≥ 90% used, `budgetExceeded` above 100%.

## 9. Savings Scenarios

A deterministic calculator. Scenario selections never modify subscriptions.

- The user selects active subscriptions and, per subscription, **cancel** or **pause
  for N months** (1–12). Billfern does not claim the provider supports pausing.
- Paused and ended subscriptions cannot be selected; they already contribute nothing
  to current recurring costs.
- Each subscription contributes once (the `SmartSuggestions` rule).
- Outputs, all as `Money` with estimates labelled:
  - Current monthly recurring cost.
  - Selected subscriptions' monthly equivalents (original currency, plus converted).
  - Hypothetical revised monthly cost.
  - **Annualized potential savings**: the sum of `annualCost` for cancellations; for
    pauses, the monthly equivalent × N via `scaleRounded`.
  - **Payments avoidable in the next 12 months**: the sum of projected payments
    (`projectedPayments(withinDays: 365)`) for cancellations, or within the pause
    window for pauses.
  - **First avoidable payment date**: the next projected payment of each selection.
    For yearly and other long cycles, copy states that the current period may already
    be paid and savings start at the next renewal.
- Annualized savings and avoidable payments are always shown as separate, labelled
  figures, never combined.
- No refunds are claimed. Copy: "potential", "hypothetical".
- Each selection links to its subscription details for any real action.

## 10. Insight Ranking

Deterministic, applied after expiry and dismissal filtering:

1. Priority tier (high > medium > low > informational).
2. Within a tier: days until the relevant date (sooner first; insights without a date
   last).
3. Recurring financial impact (converted monthly impact; unconverted impacts rank after
   converted ones and are never mixed across currencies).
4. Evidence recency (newer price or terms changes first).
5. Kind order, then `id` (total order, stable output).

Priority assignment (initial constants, tunable in one place and tested):

| Priority | Conditions |
|---|---|
| High | `budgetExceeded`; `upcomingHighCostRenewal` within 7 days; `priceChange` increase ≥ 10% effective within the last 30 days |
| Medium | `budgetNearLimit`; overlaps and duplicates; `annualRenewal` within 30 days; `renewalCluster`; expensive share ≥ 25% |
| Low | Remaining renewal insights; `priceChange` increases; `spendingGrowth` increases; expensive share ≥ 10% |
| Informational | Decreases, `termsChange`, `reviewReminder` without high cost |

Ranking never uses subscription price alone, and dismissed or expired insights are
never ranked.

## 11. Financial Accuracy Requirements

- Money is integer minor units plus an ISO currency code. No `double` amounts.
- Original subscription currencies are preserved and shown where relevant.
- Billing-cycle normalization and rounding use the existing `BillingCycle`,
  `monthlyCost`, `annualCost` and `Money.scaleRounded`.
- Percentages use integer basis points.
- Never add different currencies without conversion through `CurrencyConverter`.
  Unconvertible subscriptions are excluded **and reported**, as today.
- Missing or stale rates show the existing warnings; unsupported converted totals are
  not shown. Mock rates remain labelled as mock.
- Historical revisions, archived (ended) history and pause history are preserved and
  respected.
- Calendar dates and UTC timestamps stay distinct.
- Projected, estimated and confirmed figures stay distinct and labelled
  (`SpendingBasis`).
- Annualized recurring cost and upcoming cash-flow projections are different metrics
  and are never presented as the same number.
- AI output never supplies or overrides a figure (section 15).

## 12. Insights Screen (`/analytics/insights`)

Entry points: a "See insights" action on the Analytics screen's suggestions section and
the dashboard preview card. Uses Billfern's tokens, `GradientScaffold`, `AppCard`,
`SectionHeader`, buttons and `lucide_icons_flutter` icons. No new design system.

Order:

1. **Header**: `ScreenHeader` "Your insights", subtitle "Understand your spending".
   In 6B, a trailing AI status or refresh action.
2. `SampleDataBanner` when in sample mode.
3. **Savings overview**: midnight card with yellow highlights showing the top
   validated savings scenario (overlap or largest subscription), labelled
   "Potential savings", with annualized savings and avoidable payments shown
   separately, and an "Explore scenarios" action (opens the scenario sheet).
4. **Priority recommendations**: top 5 ranked insights. Each row: icon, title, concise
   description, the key figure, and a review action (opens detail).
5. **Spending patterns**: category concentration (reusing `categoryBreakdownProvider`),
   price and terms changes, spending growth, overlaps.
6. **Upcoming renewals**: renewal insights.
7. **Budget overview**: progress (section 8) or a "Set a monthly budget" prompt.
8. **AI summary** (6B): optional, visually distinct (restrained sparkle icon, "AI"
   label). Other cards never look AI-generated.
9. **All insights**: expanded list (remaining insights) and "Show dismissed".

### 12.1 Insight Detail Screen (`/analytics/insights/:id`)

- Title and description (from `InsightCopy`).
- Supporting evidence: every figure with its basis (estimated, projected), currency and
  any conversion note; previous vs current terms for price changes; renewal dates.
- Related subscriptions: logo (`UserSubscriptionLogo`), name, original price, link to
  details.
- Validated financial impact (monthly, annualized, avoidable payments as applicable).
- Explanation: the local explanation; in 6B, the validated AI explanation below it,
  labelled.
- Actions: "Mark for review" / "Clear review", "Dismiss" / "Restore", "Open
  subscription", and for savings-related kinds "Explore scenario".
- An unknown or expired id shows an "This insight is no longer current" empty state
  with a link back.

### 12.2 Scenario sheet and budget editor

- Scenario: bottom sheet listing active subscriptions with cancel and pause choices,
  live recalculated outputs (section 9), and links to details.
- Budget editor: amount field using `MoneyParser` with a live formatted preview,
  currency picker (`CurrencyOptionList`), save, and "Remove budget" with
  `showConfirmationSheet`.

## 13. Dashboard Integration

- `InsightPreviewCard` replaces `AiInsightCard` at the same position.
- Shows the single top-ranked, non-dismissed insight with its key figure and "See all
  insights".
- No insights: shows a quiet "No insights right now" line, or nothing when there are
  no subscriptions (existing empty states remain).
- Sample mode: tagged "Sample data".
- Works offline, rebuilds only when the top insight changes (select the needed fields),
  and adds no animation beyond the existing `FadeSlideIn`.
- Dashboard financial figures are unchanged.

## 14. Loading, Error and Empty States

| Situation | Behavior |
|---|---|
| Catalog still loading | Insights that need `overlapGroup` wait; others show immediately (no full-screen spinner) |
| No subscriptions | `EmptyStateCard` with "Add subscription" and "Explore sample data" |
| Subscriptions but no insights | "Nothing needs your attention right now" with the budget prompt |
| Rates missing or stale | Existing `ConversionNote` warnings; affected figures suppressed as specified |
| Not enough history | Growth insights absent; no "0%" placeholders |
| Insight state store failure | Insights still render; dismiss, review and budget actions show a non-blocking error |
| (6B) AI unavailable, offline, quota reached, disabled by kill switch | Local insights unaffected; AI section shows a single calm status line and the last valid cached result with its timestamp, if any; no automatic retries |

## 15. Phase 6B — AI Intelligence

### 15.1 Flow

1. Flutter computes local insights (6A).
2. The user is signed in, has given consent (section 17) and taps **Generate AI
   summary**. Generation happens only on this explicit action.
3. Flutter builds a minimized request (15.3) from the top ≤ 10 local insights.
4. The request goes to the `generate-insights` Edge Function with the standard
   authenticated Supabase request (JWT in the header, never in the payload).
5. The function verifies the session, consent, kill switch and request schema.
6. The function atomically reserves quota (section 18).
7. The function **rebuilds the prompt server-side** from validated fields only and
   calls the OpenAI Responses API with a strict structured-output schema and
   `store: false`.
8. The function validates the structured output (15.4), records usage metadata (no
   content), and returns the validated result.
9. Flutter re-validates the response, renders figures from local evidence only, and
   caches the result for the identity (section 19).

Never for guests, never for sample data, never automatically (launch, rebuild, edit,
navigation, sync, background).

### 15.2 Edge Function

- Location: `supabase/functions/generate-insights/`.
- POST only; `verify_jwt = true` in `supabase/config.toml`, plus in-function token
  validation as in `delete-account`.
- Uses the service-role key **only** server-side for quota accounting through the
  definer functions in section 18; the OpenAI key comes from Edge Function secrets.
- Fails closed: missing configuration, quota store errors, kill switch on, consent
  missing or invalid schema → no provider call.
- Never logs payloads, generated text, emails or tokens; logs only request id, status
  class and token counts.
- Typed error responses: `not_authenticated`, `consent_required`, `ai_disabled`,
  `quota_exhausted`, `budget_exhausted`, `invalid_request`, `provider_unavailable`,
  `invalid_output`. Flutter maps each to fixed copy.

### 15.3 Request contract (`schemaVersion: 1`)

```
{
  "schemaVersion": 1,
  "requestId": "<uuid v4, stable per fingerprint+day>",
  "consentVersion": "<string>",
  "displayCurrency": "USD",
  "fingerprint": "<combined evidence fingerprint>",
  "summary": {
    "activeCount": 7,
    "monthlyTotalMinor": 16435,           // converted; omitted when unavailable
    "isEstimate": true,
    "categoryShares": [{"category": "entertainment", "basisPoints": 4200}],
    "comparison": {"kind": "increase", "basisPoints": 1250}   // PeriodComparison
  },
  "evidence": [                              // ≤ 10
    {
      "ref": "e1",                           // request-scoped opaque id
      "kind": "overlappingServices",
      "priority": "medium",
      "category": "entertainment",
      "overlapGroup": "videoStreaming",
      "count": 3,
      "monthlyImpactMinor": 4297,
      "annualImpactMinor": 51564,
      "basisPoints": null,
      "daysUntil": null
    }
  ]
}
```

Rules:

- Allowed fields only; unknown fields are rejected. All strings are enums from a fixed
  server-side allowlist. Amounts are integers. Payload ≤ 16 KB; evidence ≤ 10.
- **Never included:** email, account UUID, tokens, payment or bank data, notes, custom
  subscription names, **catalog service names**, catalog ids, website domains,
  subscription ids, full database contents.
- `ref` values map to local insight ids only on the device; the server never sees
  subscription ids.

### 15.4 Response contract

```
{
  "schemaVersion": 1,
  "promptVersion": "2026-xx",
  "modelConfigId": "<opaque>",
  "summary": "Your entertainment spending is concentrated in {{e1.count}} overlapping services …",
  "items": [
    {
      "ref": "e1",
      "actionType": "reviewCategory",
      "explanation": "These services may serve a similar purpose; {{e1.monthly}} per month is worth reviewing.",
      "evidenceQuality": "strong"
    }
  ],
  "limitations": "Usage information is not available."
}
```

- `actionType` ∈ {`reviewSubscription`, `reviewCategory`, `reviewRenewal`,
  `reviewPriceChange`, `reviewBudget`, `comparePlans`}.
- `evidenceQuality` ∈ {`strong`, `limited`}.
- **Placeholders:** `{{<ref>.<field>}}` with `field` ∈ {`monthly`, `annual`,
  `percent`, `date`, `count`, `days`}. Flutter replaces each with the value from its
  own local evidence, formatted by `CurrencyFormatter` / `intl`.
- **Validation (server and client):**
  - Strict schema; refs must exist in the request; no duplicate refs; ≤ 10 items.
  - Length limits: summary ≤ 400 characters, explanation ≤ 280, limitations ≤ 200.
  - After removing valid placeholders, text contains **no digits, no currency symbols
    (`\p{Sc}`), no `%`**, no URLs, no email addresses, no markup, no code.
  - A placeholder referencing a field the evidence does not have is invalid.
  - Refusals, incomplete output or any violation → `invalid_output`; nothing is
    displayed and the attempt counts against quota.
- Unvalidated AI output is never displayed.

### 15.5 Prompt requirements

Server-side, versioned (`promptVersion`) together with the schema:

- Role: a subscription spending assistant explaining supplied evidence.
- Use only supplied evidence; never calculate, estimate or state figures; use
  placeholders for every number.
- Never infer usage, guarantee savings, pressure cancellation, give investment, tax or
  legal advice, request credentials or suggest modifying records.
- Explain what was observed, why it matters and what to review, with appropriate
  uncertainty.
- Concise, friendly, neutral language matching section 5.1.
- Validated fields are inserted as structured data in a separate input section, never
  concatenated into the system instructions.

### 15.6 Model and provider

- OpenAI Responses API with structured outputs, `store: false`.
- The model is configured server-side (`OPENAI_MODEL`) and identified to the client only
  by `modelConfigId`. No model name is hardcoded in Flutter.
- No chatbot.

## 16. Provider Verification and Secrets (6B)

### 16.1 OpenAI verification record

Before 6B implementation, record in this specification (Appendix A), with links to
official documentation and the date checked:

- Selected cost-efficient model supporting strict structured outputs, and its
  deprecation status.
- Supported Responses API parameters used (`store`, structured output format, max
  output tokens).
- Current pricing per input and output token.
- Data retention behavior with `store: false` and for abuse monitoring, and whether
  zero data retention is available to the account.
- Processing regions and the data processing agreement relevant to European users.

`store: false` is never described as a guarantee of zero provider-side retention.

### 16.2 Secrets and configuration

Edge Function secrets only (separate development and production values):

- `OPENAI_API_KEY`, `OPENAI_MODEL`, `AI_MAX_OUTPUT_TOKENS`, `AI_MAX_INPUT_TOKENS`.

Never in Flutter source, Dart defines, SharedPreferences, sembast, GitHub, public
configuration files or logs. Provide placeholder-only examples
(`supabase/functions/generate-insights/.env.example`).

Operational limits and the kill switch live in the `ai_config` table (section 18), so
they change without redeploying the function or updating the app. An
`AI_INSIGHTS_ENABLED=false` secret acts as a hard override that also disables the
feature.

## 17. AI Settings and Consent (6B)

Screen: `/settings/ai-insights`, linked from Settings and from the AI section of the
Insights screen. Shown only when Supabase is configured and the user is signed in;
guests see "AI insights require an account" and local insights only.

- **Disabled by default.**
- Before enabling, the screen explains:
  - What is sent: categories, normalized amounts, comparisons and insight types.
  - What is excluded: email, account id, payment details, notes, subscription and
    service names.
  - Why: to write a short personalized explanation of local insights.
  - Who processes it: Billfern's server and OpenAI.
  - Retention limits: per the verification record, without promising zero retention.
  - How to disable it at any time.
- Consent copy (subject to legal review):
  "AI insights use a limited summary of your subscription spending to provide
  personalized explanations. Your email address, payment details, private notes and
  subscription names are not included."
- Enabling records consent locally (identity store) **and** server-side through the
  `ai_set_consent(version)` function. The server refuses requests without current
  consent.
- Disabling: stops future requests, withdraws consent server-side
  (`ai_withdraw_consent()`), ignores any in-flight result, and offers "Clear cached AI
  insights".
- Declining never affects local insights.
- The UI never claims all data stays on the device while AI is enabled, and never
  claims legal compliance.

## 18. Server Data, Quotas and Cost Controls (6B)

One new migration (for example `supabase/migrations/2027xxxxxxxxxx_ai_insights.sql`).
Existing migrations are never edited. It follows every Phase 5 database rule:
revoke all from `public`, `anon`, `authenticated`; grant the minimum; RLS on
user-owned tables; `SECURITY DEFINER` functions with `set search_path = ''`; no
caller-supplied user ids; trigger and helper functions not executable by clients.

Tables:

| Table | Purpose | Client access |
|---|---|---|
| `ai_config` (single row) | `enabled`, `model_config_id`, per-user daily and monthly limits, global daily attempt limit, global **monthly** cost cap (micro-USD; development: 5,000,000 = $5) | None |
| `ai_consents` | `user_id` (FK `auth.users` on delete cascade), `version`, `granted_at`, `withdrawn_at` | Through `ai_set_consent` / `ai_withdraw_consent` only |
| `ai_usage_events` | `user_id` (FK cascade), `request_id`, `fingerprint`, `status` (`reserved`, `succeeded`, `failed`, `uncertain`), timestamps, token counts, estimated and actual cost, `model_config_id`; **no request or response content** | None |
| `ai_global_usage` | Day and month buckets: attempts, estimated and actual cost | None |

Functions (definer, executable only by `service_role` unless noted):

- `ai_set_consent(version)`, `ai_withdraw_consent()`: `authenticated`, own row only.
- `ai_reserve(user_id, request_id, fingerprint)`: in one transaction with row locks,
  checks the kill switch, consent, per-user daily (1 success) and monthly (10 attempts)
  limits, global daily attempts (20) and the global monthly cost cap ($5 in
  development) with a conservative cost estimate reserved up front; deduplicates by `request_id` and by (`user_id`, `fingerprint`, day);
  inserts a `reserved` event or returns a typed refusal. Concurrent requests cannot
  bypass limits.
- `ai_complete(request_id, status, tokens, cost)`: records the outcome. Timeouts and
  unknown upstream outcomes are recorded as `uncertain` and count as attempts and
  estimated cost.

Initial development limits (approved; engineering limits, not commercial
entitlements): 1 successful generation per account per day; 10 attempts per account
per month; 20 provider attempts globally per day; an application-enforced global
budget of **$5 per calendar month (UTC)** in development; 4,000 input tokens; 800
output tokens; 10 evidence items.

When the monthly budget would be exceeded by a request's conservative estimate, the
request is refused with `budget_exhausted` before any provider call. A device that has
lost its cached summary cannot regenerate it on the same day once the daily success
is used; the AI section explains when a new summary is available.

Provider dashboard budgets are not treated as hard caps; the database cap is
authoritative.

Account deletion: every table above cascades from `auth.users`, so the existing
`delete-account` function removes AI metadata. pgTAP tests prove it.

Entitlements: a fixed development allowance from `ai_config`. RevenueCat, pricing and
commercial entitlements are deferred to Phase 8; access checks stay server-side.

## 19. AI Cache and Offline Behavior (6B)

- Validated AI responses are cached in the **identity's sembast file** (never
  SharedPreferences), keyed by: identity (implicit), combined fingerprint, display
  currency, exchange-rate state identity, `promptVersion`, `schemaVersion` and
  `modelConfigId`.
- Lifetime 24 hours. Expired or mismatched entries are not shown as current.
- Per-evidence invalidation follows section 7.4.
- Offline: the last valid cached summary is viewable with "Generated <time>"; refresh is
  disabled with an explanation.
- Erase this device, sign-out isolation and account deletion behave as for all other
  identity data. "Clear cached AI insights" deletes only the cache.

## 20. Security and Privacy Requirements

- No secret or API key in the app; OpenAI is called only server-side.
- AI requires authentication and current consent; checked server-side.
- Guest and sample data are never sent.
- Payload minimization per section 15.3; all user-provided text is excluded and
  treated as untrusted; prompts are rebuilt server-side.
- Output validation per section 15.4 on both server and client.
- The AI service cannot modify subscriptions or financial records.
- No operational logs contain payloads, generated text, emails or tokens.
- Account deletion covers all new server data.
- Phase 5 isolation guarantees extend to all new local stores (budgets, review and
  dismissal state, AI cache).
- GDPR obligations for European users are reviewed before public release; a consent
  screen alone is not presented as compliance.

## 21. Automated Testing and Acceptance Criteria

Follow the existing test structure and helpers. Add a smoke test for each new screen and
a widget test for each new shared component.

### 21.1 Phase 6A

- **Engine and rules** (`test/features/insights/`):
  - Each rule, including boundaries (thresholds, windows, leap days, month ends).
  - Overlap groups versus broad categories; multiple accounts wording.
  - Price change vs terms change: same-currency increase and decrease, currency change
    (no percentage), cycle-only change, history never using today's price.
  - Growth reuses `PeriodComparison` including `noBaseline` and `fromZero`.
  - Mixed, missing and stale rates: exclusion and suppression.
  - Paused and ended subscriptions.
- **Identity, fingerprints and expiry:** ids stable under unrelated edits; fingerprint
  changes on relevant edits; expiry per kind; dismissal hidden until fingerprint
  changes; restore; cleanup.
- **Ranking:** deterministic total order and priority table.
- **Savings scenarios:** no double counting; annualized vs avoidable payments; yearly
  cycles; pause windows; paused and ended excluded; no mutation of subscriptions.
- **Budget:** same currency; different currency with conversion and estimate label;
  missing rates suppress percentages; ≥ 90% and exceeded insights; validation.
- **Wording:** banned phrases across all `InsightCopy` output.
- **Persistence and isolation:** budget, review and dismissal state per identity;
  sign-out and switch; erase; sample mode writes nothing; real file database across
  restarts.
- **Consistency:** the top insight's figures equal the dashboard and Analytics figures
  they reference; `SmartSuggestionsSection` and the Insights screen show the same
  ranking.
- **UI:** Insights, detail, scenario sheet and budget editor; dashboard preview replaces
  `AiInsightCard`; empty and error states; accessibility guidelines; overflow sweep
  (iPhone SE, 13 mini, 16, 16 Pro Max at 1.0× and 1.35× text); dashboard sweep extended.
- **Regression:** all existing tests pass (362 at the Phase 5 checkpoint, adjusted
  only for the intentionally replaced mock engine and card).

### 21.2 Phase 6B

- **Flutter:** request builder excludes all forbidden fields (tests assert no names,
  ids, notes or emails); request limits; response validator (unknown refs, duplicate
  refs, digits, currency symbols, `%`, URLs, length limits, bad placeholders,
  refusals); placeholder rendering from local evidence; cache keys, lifetime and
  invalidation; consent enable, disable, withdraw-in-flight; guests and sample mode
  never call the remote; typed error mapping; offline behavior.
- **Edge Function:** unit tests (Deno) for auth, consent, kill switch, schema
  validation, prompt construction from validated fields only, output validation, fail
  closed, no content in logs. Uses a stubbed OpenAI client; no real provider call in
  automated tests.
- **Database (pgTAP):** no client access to config, usage or global tables; consent
  functions own-row only; `ai_reserve` limits, dedupe, kill switch and global cap;
  concurrent reservations cannot exceed limits; deletion cascade.

### 21.3 Acceptance criteria

6A is accepted when every rule, state and screen above works offline for guests and
accounts, figures match existing calculations, the mock engine and card are gone, and
`flutter analyze` and the full suite are clean.

6B is accepted when the live validation in section 22 passes and no unvalidated or
invented figure can reach the UI.

## 22. Live Integration Validation (6B)

Against the **development** project only, with synthetic test users and data, after the
user approves each deployment:

1. Apply the AI migration; run pgTAP.
2. Deploy `generate-insights` with development secrets and low limits.
3. Verify: unauthenticated and no-consent requests refused; kill switch (table and
   secret) refuses without a provider call; quota limits including two concurrent
   requests; global cap; dedupe by request id and fingerprint; invalid output handled;
   usage events contain no content; account deletion removes consent and usage rows.
4. Generate one real summary from the app and confirm placeholders render local
   figures only.
5. Record results in the final report. Never use production, real personal financial
   data or production keys.

## 23. Resource Constraints

The development machine is a Mac with 8 GB of RAM:

- Run Flutter commands sequentially; never parallel builds, tests or analyzers.
- Shut down simulators before tests (`xcrun simctl shutdown all`); use only the existing
  Billfern Simulator for visual review, and shut it down afterwards.
- `flutter test --concurrency=2`, with a memory watchdog for long runs (kill
  `flutter_tester` above about 1.5 GB).
- At least 15 GiB free before iOS builds; stop resource-intensive work below 5 GiB.
- Never run Docker and the iOS simulator at the same time.
- Do not repeat successful validation when implementation files have not changed.
- Do not connect to physical devices or restart the Mac without explicit approval.

## 24. Scope Restrictions

Not in Phase 6:

- Notification scheduling or reminders (Phase 7).
- RevenueCat, payments, paywalls, pricing or commercial entitlements (Phase 8).
- Banking connections, payment confirmation or usage tracking.
- Historical exchange rates or exchange-rate attribution.
- Provider plan prices, discounts or offers.
- A chatbot or free-form AI questions.
- Budget or insight-state sync, or any new sync payload fields.
- Changes to `Subscription`, `SubscriptionCodec` or the Phase 5 SQL.
- User feedback on insights (deferred until specified).
- A translation framework.
- In 6A: any backend, migration or new dependency.

## 25. Documentation Requirements

- `CLAUDE.md`: current phase line, insights architecture, routes, identity-scoped
  stores, removed components, wording rules, (6B) AI architecture, database rules for
  AI tables, tests.
- `README.md`: Insights feature, budget, savings scenarios, privacy and AI consent
  (6B), limitations, validation status.
- This specification: Appendix A (OpenAI verification record) before 6B.
- Placeholder-only configuration examples for any new secret.

## 26. Git and Attribution Rules

- Work on `feat/ai-insights`, created from `main` after the Phase 5 merge. No other
  branches unless approved.
- Never commit or push without explicit approval. Never merge into `main` without
  approval.
- No Claude or Anthropic attribution in commits, pull requests or files.
- Never commit secrets; verify ignored files before each commit; run `git diff --check`.
- Do not deploy migrations or Edge Functions, or change project secrets, without
  explicit approval. Never deploy to production.

## 27. Implementation Milestones

### Phase 6A

| Milestone | Content | Prerequisites |
|---|---|---|
| A0 Kickoff | Branch from merged `main`; update `CLAUDE.md` current phase | Section 3.1 items 1–2 |
| A1 Domain | Insight model, evidence, ids and fingerprints, `InsightCopy`, engine wrapping `RuleBasedSuggestionEngine`, new rules, ranking; catalog `overlapGroup` (data only) | A0 |
| A2 Local state | Identity-scoped stores for budget, review and dismissal; providers following `activeLocalStoreProvider`; expiry and dismissal logic | A1 |
| A3 Calculators | Savings scenarios and budget status | A1 |
| A4 Screens | Insights, detail, scenario sheet, budget editor, routes; Analytics suggestions on the shared model | A2, A3 |
| A5 Dashboard | `InsightPreviewCard`; remove `MockSavingsInsightEngine` and `AiInsightCard` | A4 |
| A6 Hardening | Accessibility, overflow sweeps, docs, full suite, Billfern Simulator review | A5; ≥ 15 GiB free for any iOS build |

### Phase 6B

| Milestone | Content | Prerequisites |
|---|---|---|
| B0 Gate | Appendix A verification record; confirm section 3.2 | 6A approved; Phase 5 live validation, isolation and deletion validated |
| B1 Database | AI migration, definer functions, pgTAP | B0 |
| B2 Edge Function | `generate-insights`, validation, prompt, quotas, kill switch, Deno tests | B1 |
| B3 Flutter client | Request builder, response validator, placeholder renderer, cache, consent and settings screen, states | B2 contract frozen |
| B4 Live validation | Section 22 on the development project | User approval for each deployment; development secrets set by the user |
| B5 Wrap-up | Docs, full suite, final report | B4 |

## 28. Definition of Done

Each part is done when:

- All requirements in scope are implemented and approved decisions are respected.
- `dart format lib test` produces no changes; `flutter analyze` reports no issues; the
  full suite passes (and, for 6B, pgTAP and Edge Function tests pass).
- No figure in the UI comes from anything other than the deterministic local engine.
- Identity isolation, erase and deletion cover all new data.
- Accessibility and overflow sweeps pass.
- Documentation is updated.
- No secrets are committed; the working tree is reviewed.
- (6B) Live validation passed on the development project, or every unmet item is
  reported as a blocker, never silently deferred.

## 29. Final Implementation Report

For each part, report:

1. What was implemented, by milestone.
2. Architectural decisions and any deviations from this specification, with reasons.
3. Files added, changed and removed.
4. Test results (counts, suites, any skipped tests and why).
5. Live validation results (6B), with what was not validated.
6. Security and privacy review results.
7. Known limitations and remaining blockers.
8. Resource usage notes (memory, disk) and any validation not repeated.
9. Final Git status. No commit or push without approval.

## 30. Decisions

### 30.1 Approved decisions

| Decision | Outcome |
|---|---|
| Overlap detection | Curated functional `overlapGroup` values in the catalog (section 6.1). The group list and assignments are proposed at A1 and reviewed with the A1 changes |
| Priority thresholds | The initial values in section 10 are approved (tunable later in one place) |
| Budget and review state | Local only (identity sembast); no sync in Phase 6 |
| OpenAI model | Selected at milestone B0 and recorded in Appendix A |
| Development AI budget | Application-enforced, $5 per calendar month (UTC), server-side (section 18) |
| AI generation frequency | One successful generation per account per day initially; a lost cache cannot regenerate the same day |
| Privacy, consent and GDPR | Review required before public release; development may proceed |

### 30.2 Still open

| Decision | Needed before |
|---|---|
| Final `overlapGroup` list and service assignments | A1 review |
| Model, pricing and retention (Appendix A) | B0 |
| Consent copy legal wording and GDPR assessment | Before public release |
| Whether budgets and review state sync in a later phase | Not needed for Phase 6 |

## Appendix A — OpenAI Verification Record

To be completed at milestone B0. Not filled in until verified against official
documentation.

| Item | Value | Source | Date checked |
|---|---|---|---|
| Model | | | |
| Structured output support | | | |
| Parameters used | | | |
| Pricing (input / output) | | | |
| Retention with `store: false` | | | |
| Abuse-monitoring retention | | | |
| Zero data retention eligibility | | | |
| Processing region / DPA | | | |
