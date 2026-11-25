# CLAUDE.md — Billfern

Guidance for Claude Code sessions working in this repository. `prompt.md` is the
primary product specification; this file records how it has been implemented
and the conventions every change must follow.

## Product

**Billfern**: a premium AI-powered subscription tracker and personal finance app.
**Tagline:** Track smarter. Spend less.
**Platforms:** iOS and Android. iOS is the primary development target.

Eventual features: subscription management, monthly and annual spending summaries,
upcoming renewals, categories, active and paused subscriptions, spending analytics,
renewal notifications, AI savings recommendations, personalized insights and
premium plans.

### Current phase

Frontend only, with data stored locally on the device. **Do not integrate** Supabase,
authentication, OpenAI, RevenueCat, payments, banking or exchange-rate APIs until asked.

| Phase | Scope | Status |
|---|---|---|
| 1 — Design foundation | Tokens, theme, router, shared components | ✅ Done |
| 2 — Dashboard | Greeting, spending summary, comparison, chart, categories, renewals, subscription cards, AI insight preview, add action | ✅ Done |
| 2.1 — Catalog and logos | 82-service catalog, 59 Simple Icons logos, `SubscriptionLogo` | ✅ Done |
| 2.2 — Multi-currency | `Money`, conversion, display-currency preference | ✅ Done |
| 3 — Subscription management | Subscriptions list, add (catalog or custom), details, edit, pause/resume, delete, local persistence | ✅ Done (awaiting review) |
| 3.1 — Branding | Official logo (`BillfernLogo`), first-launch welcome, onboarding gate, Settings About | ✅ Done |
| Later | Analytics screen, reminder notifications, Supabase sync, real exchange rates | ⏳ |

Home is the dashboard (`DashboardScreen`). "+" opens the add flow, and renewal cards and
recent rows open subscription details. Notifications and the smart tip still show a
"coming soon" snackbar (`showComingSoon`). Analytics is a placeholder.

**Design reference:** `docs/design/dashboard-reference.png` is the primary visual guide
(dashboard, subscriptions list and analytics screens). Match its layout, proportions,
weights and chart styling, using Billfern's tokens and brand.

## Tech stack

| Concern | Package |
|---|---|
| State | `flutter_riverpod` ^3 |
| Routing | `go_router` ^18 (`StatefulShellRoute.indexedStack`) |
| Fonts | `google_fonts`: Manrope |
| Icons | `lucide_icons_flutter`: **not** `lucide_icons`, which does not compile on Flutter ≥ 3.4x because `IconData` is now final |
| Charts | `fl_chart` |
| Formatting | `intl` |
| Local storage | `sembast` (pure-Dart document DB: subscriptions) and `shared_preferences` (small settings), plus `path_provider` |
| Future work | `supabase_flutter`, `flutter_local_notifications` (installed, not wired yet) |

Identifiers: Dart package `billfern` (`package:billfern/…` imports), bundle ID / application ID
`com.billfern.app` (iOS, Android, macOS, Linux), display name **Billfern**. Android's
`MainActivity` lives in `android/app/src/main/kotlin/com/billfern/app/`.

Flutter 3.47 / Dart SDK ^3.13. Check `pubspec.yaml` before adding a dependency, and
avoid adding new ones without a clear need.

## Architecture

Feature-first, with layers added only when they earn their place.

```
lib/
├── main.dart                  # ProviderScope + runApp
├── app.dart                   # BillfernApp: MaterialApp.router + theme
├── core/
│   ├── constants/             # AppConstants (name, tagline)
│   ├── money/                 # Currency, Money, CurrencyConverter/MoneyConverter, ExchangeRates(+state), ExchangeRateRepository, LocaleCurrency
│   ├── router/                # app_router.dart (Riverpod provider), app_shell.dart, app_destination.dart
│   ├── theme/                 # design tokens + AppTheme; import via theme.dart barrel
│   ├── utils/                 # CurrencyFormatter, DateMath, DateLabels
│   └── services/              # (future) notifications, API clients
├── features/<feature>/
│   ├── data/                  # repositories, DTOs, mock sources (when needed)
│   ├── domain/                # entities, business logic (when needed)
│   └── presentation/
│       ├── screens/           # route-level widgets
│       ├── widgets/           # feature-private widgets
│       └── providers/         # feature-scoped Riverpod providers
└── shared/
    ├── widgets/               # reusable design-system components
    ├── models/                # Subscription, SubscriptionCatalogItem, SubscriptionBranding, BillingCycle, SubscriptionCategory, SubscriptionGlyph, UserProfile
    ├── data/                  # SubscriptionRepository + mocks, SubscriptionCatalogRepository, SubscriptionCatalog (search), SubscriptionLogoResolver
    └── providers/             # clock, subscriptions, catalog + search + branding, current user

assets/
├── data/subscription_catalog.json   # generated service catalog (no prices)
└── logos/<catalog-id>.svg           # generated Simple Icons brand marks
tool/catalog/build_catalog.py        # source of truth for catalog + logos
docs/brand-logos.md                  # generated logo attribution and guidelines
docs/design/dashboard-reference.png  # visual reference
```

### Routing

- `AppDestination` (enum) is the single source of truth for tab order, path, label
  and icon. Its order must match the branch order in `app_router.dart`.
- `appRouterProvider` exposes the `GoRouter`. Add auth and onboarding redirects there later.
- Tabs use `NoTransitionPage`. Pushed routes use the theme's Cupertino transition.
- Tapping the active tab again resets it to its root (`goBranch(initialLocation: true)`).

### State

Riverpod for shared state. Keep ephemeral UI state (press, animation, form fields) in
`StatefulWidget`s. Data flows through repositories, so Supabase can be swapped in
without touching widgets.

**Data flow (single source of truth):**

```
dataModeProvider ─┬─ personal → personalSubscriptionRepositoryProvider (sembast, overridden in main)
                  └─ sample   → sampleSubscriptionRepositoryProvider (in-memory demo data)
  → subscriptionRepositoryProvider → subscriptionsProvider (SubscriptionsNotifier) ─┐
preferredCurrencyProvider + exchangeRatesProvider → moneyConverterProvider ──────────┴→ dashboard / list / details providers → widgets
```

### Subscriptions and persistence

- **`subscriptionsProvider`** is a `NotifierProvider` (`SubscriptionsNotifier`) with
  `add`, `update`, `pause`, `resume` and `delete`. Every screen (dashboard, list,
  details, and analytics later) derives from it, so any change updates everything at
  once. Always mutate through the notifier.
- **`SubscriptionRepository`**: `fetchAll()` is a synchronous in-memory snapshot,
  while `save` and `delete` are async and write through. The repository is
  replaceable:
  - `SembastSubscriptionRepository`: one record per subscription, keyed by id, in
    the `subscriptions` store of `<documents>/billfern.db`. It loads once in
    `main`, and corrupt records are skipped and counted.
  - `InMemorySubscriptionRepository`: tests and defaults.
  - `DemoSubscriptionRepository`: sample data.
  - For Supabase, either keep this load-then-cache shape or move the notifier to an
    `AsyncNotifier`.
- **`SubscriptionCodec`**: a versioned map format (`schema: 1`). Money is stored as
  integer `priceMinor` plus `currencyCode`, and dates as ISO calendar dates.
- **Sample vs personal data** (`DataMode`, persisted under `data_mode`):
  - A fresh install starts in **personal** mode, empty, and shows "Start tracking"
    or "No subscriptions yet" states with "Explore sample data".
  - Sample mode reads an in-memory demo repository. Changes are discarded on
    restart, and a `SampleDataBanner` is always shown.
  - **Adding** a subscription in sample mode switches to personal mode first, so
    demo records are never written to the database.
- **`Subscription` equality is by value** (all fields). Riverpod only notifies when
  `==` changes, so id-only equality would hide edits. Use `id` for identity.
- **History-safe dates:**
  - `startedOn` is when spending starts counting. For new subscriptions it's the day
    they were added, so the history chart isn't invented.
  - `billingAnchor` is a known billing date that renewals are computed from. Edits
    move only this.
  - `pausedOn` and `pauseHistory` (`PausePeriod`s): `isBilledInMonth` counts a month
    when the subscription had started and wasn't paused on the month's last day. So
    pausing removes it from the current month and projections, past months stay, and
    paused months stay excluded after resuming.
- **`BillingCycle`** is a value type (`count` and `BillingUnit` day, week, month or
  year):
  - Presets are `weekly`, `monthly`, `quarterly` and `yearly`, plus
    `BillingCycle.custom(n, unit)`.
  - Cost equivalents use exact fractions (52 weeks or 365 days a year) with one
    rounding step (`Money.scaleRounded`).
- **`ReminderPreference`** is stored per subscription. Notification scheduling comes
  in a later phase.
- **IDs** come from `subscriptionIdGeneratorProvider` (time plus random). Tests
  override it for stable IDs.

- **Money is `Money`**: integer minor units plus an ISO currency code. Never use
  `double` amounts or bare ints for money. Format only with `CurrencyFormatter.format(money)`.
- **No financial maths in widgets.** All totals, comparisons, category shares,
  history and renewals come from `SpendingCalculator`
  (`features/dashboard/domain/`), exposed through `dashboard_providers.dart`.
  Widgets such as `SpendingSummaryCard` only display values they're given.
- Monthly spending = sum of the converted `monthlyCost` of subscriptions billed that month
  (`Subscription.isBilledInMonth`: started before month end, not paused before it).
  So the hero total, the chart's current bar and the category slices always agree.
- Category percentages use the largest-remainder method and always sum to 100. Beyond
  five categories the tail merges into "Other".
- Yearly mock prices divide evenly by 12. Projected yearly is the sum of converted
  `annualCost` values, so with conversion it can differ from monthly × 12 by a few minor
  units of rounding.
- Mock data is built relative to `today`. Tests use `appTestOverrides` from
  `test/helpers/fixed_clock.dart`: a fixed clock (Tue 24 Nov 2026, 09:00) and an
  en_US device locale, so the display currency is USD.
- AI insights come from `MockSavingsInsightEngine` (local rules, no network) behind
  `savingsInsightEngineProvider`. The UI presents them as a "Smart tip" tagged
  *Sample data*, never as real AI analysis. Swap the provider to integrate OpenAI later.
- Sample data (`buildMockSubscriptions`) is only ever served by
  `DemoSubscriptionRepository`; see Subscriptions and persistence.

### Multi-currency

- **Each subscription has its own currency** (`Subscription.currencyCode`, required) and
  a price in that currency's minor units (`priceMinor`). Changing the display currency
  never modifies prices.
- **Supported currencies:** `Currency.supported` lists USD, EUR, NOK, GBP, SEK, DKK, CHF,
  CAD and AUD, with curated symbols (`$ € kr £ kr kr CHF CA$ A$`). `Currency.of(code)`
  derives any other ISO 4217 currency (symbol and decimal precision, e.g. JPY has 0)
  from `intl`. To offer a new currency, add it to `supported`, and add a mock rate if
  needed.
- **`Money` never mixes currencies.** `+`, `-`, `compareTo` and `Money.sum` throw
  `CurrencyMismatchError`. Rounding is half away from zero.
- **Conversion** happens only in `CurrencyConverter.convert`. It uses exact `BigInt`
  arithmetic on minor units, rates stored as integer millionths, and a single rounding
  to the target precision. It returns `null` when a rate is missing.
  `MoneyConverter` (from `moneyConverterProvider`) binds the target currency and the
  current rate state.
- **All aggregates** (hero, yearly projection, history chart, categories, due this week,
  savings insight) go through `SpendingCalculator.convertedSum`, which converts each
  subscription and then sums. Subscriptions without a rate are **excluded and
  reported** (`excludedCount`, `missingCurrencies`), never mixed in. Totals with any
  conversion carry `isEstimate`.
- **Rates:** `ExchangeRateSource` (development uses `MockExchangeRateSource`:
  deterministic units-per-USD, **development only**), `ExchangeRateCache` (in memory,
  pre-filled with the mock snapshot in development) and `ExchangeRateRepository`
  produce an `ExchangeRateState`: `RatesAvailable(rates, isStale)` (older than 24 h) or
  `RatesUnavailable`. `exchangeRatesProvider.notifier.refresh()` fetches, and falls back
  to the cache. There is no external API yet; plug one in by overriding
  `exchangeRateSourceProvider` (plus a persistent cache).
- **UI rules:** converted totals show "≈" and a `ConversionNote` ("Estimate · mock
  exchange rates", stale or excluded warnings). Subscription cards and renewals show
  the **original** currency. Recently added rows add an "(≈ converted)" hint.
- **Preference:** `preferredCurrencyProvider` (Notifier) holds the saved choice, or else
  the `suggestedCurrencyProvider` value derived from `deviceLocaleProvider` via
  `LocaleCurrency` (region first, then language; euro-area countries map to EUR;
  fallback USD). It's persisted by `CurrencyPreferenceStore`: `main` creates
  `SharedPreferencesWithCache` and overrides the provider, and the default is in
  memory, so tests stay hermetic. `select(code)` and `useSuggested()` change it.
- **Components:** `CurrencySelector` (pill on the dashboard hero),
  `showCurrencyPicker` (bottom sheet), `CurrencyOptionList` (shared with
  `CurrencyPreferenceScreen` at `/settings/currency`, `AppRoutes.currency`), and
  `ConversionNote`.
- **Number locale:** `CurrencyFormatter.configure(deviceLocale)` runs in `main`, so
  grouping, decimal separator and symbol position follow the device (e.g.
  `199,00 kr` in nb_NO). Tests use `en_US`, and `CurrencyFormatter.reset()` restores
  it. Alphabetic symbols get a non-breaking space ("kr 199.00").
- **Mock data** mixes USD, EUR (Figma) and NOK (Viaplay, Storytel). With an en_US
  device the dashboard shows ≈ $164.35/month.

### Branding and onboarding

- **Official logo:** `assets/branding/billfern_logo.png` (path in
  `BrandAssets.logo`). It's 1254 × 1254 with transparent corners: the "B" mark and
  wordmark on a dark rounded tile.
  - Always render it with `BillfernLogo(size:)`. That keeps the aspect ratio,
    decodes at display size to save memory, and falls back if the asset is
    missing.
  - **Never crop, recolour or edit it in code**, and never put it in
    `assets/logos/`. That folder is for third-party service logos only.
  - The launcher icon will use a separate symbol-only asset, not yet supplied.
    Don't generate one from this logo.
  - Used in: the welcome screen (168 px), the dashboard header
    (`AppSizes.brandMarkHeader`) and the Settings About card
    (`AppSizes.brandMarkAbout`).
- **Onboarding** (`features/onboarding/`):
  - `OnboardingStep` (currently just `welcome` at `/welcome`) and
    `onboardingCompletedProvider` (persisted as `onboarding_completed`).
  - The router redirects to `/welcome` until onboarding is complete, and away
    from it afterwards (`refreshListenable`).
  - `WelcomeScreen` offers "Get started" (personal mode) or "Explore with sample
    data". Add future steps such as currency, reminders and account to
    `OnboardingStep`.
- **Tests:** `baseTestOverrides` plus `preferenceOverrides(mode:, onboarded:)`, or
  `pumpBillfern(onboarded: false)` to test the welcome flow.

### Subscription catalog (separate from user subscriptions)

- **Catalog** = known services (`SubscriptionCatalogItem`: id, name, domain, category,
  brand colour, logo path, aliases, popular flag, regions). There are **82 services and
  never any prices**. A **user subscription** (`Subscription`) links to it with an
  optional `catalogId`. Several subscriptions may share a `catalogId` (e.g. personal
  and business accounts), and identity is the subscription `id`.
- **Editing the catalog:** edit `SERVICES` in `tool/catalog/build_catalog.py`, then run
  it against an extracted `simple-icons` npm package (see the script's docstring). It
  rewrites the JSON, the SVGs and `docs/brand-logos.md`. Don't hand-edit those outputs.
- `AssetSubscriptionCatalogRepository` loads the JSON and drops logo paths missing
  from the asset manifest. `subscriptionCatalogProvider` (a `FutureProvider`) loads it once.
- **Search:** `SubscriptionCatalog.search(query, category:)` matches names, aliases and
  domains, ignoring case, accents and punctuation ("+" matches "plus"). Ranking is
  exact, then prefix, word prefix, alias and substring. Empty queries return popular
  services. Providers: `catalogQueryProvider` (Notifier: text and category),
  `catalogSearchResultsProvider`, `popularCatalogItemsProvider`.
- **Add and edit flow** (`features/subscriptions/`):
  - **Screens:** `AddSubscriptionScreen` (search, popular grid, category pills,
    "Create custom subscription") leads to `SubscriptionFormScreen` (`.catalog`,
    `.custom` or `.edit`), then to `SubscriptionDetailsScreen`.
  - **Routes:** `/subscriptions/add`, `/subscriptions/add/custom`,
    `/subscriptions/add/service/:catalogId`, `/subscriptions/:id` and
    `/subscriptions/:id/edit`. Add and edit open on the **root navigator**, above the
    floating nav, while details stay in the tab. Use the `AppRoutes` helpers.
  - **`SubscriptionDraft`** holds the form state:
    - `fromCatalog(item, currencyCode:)` pre-fills name, category and catalog link
      (and so the logo and brand colour).
    - The currency starts as the display currency and can be overridden.
    - `validate(today:)` returns `DraftField` errors: name required (≤ 60),
      amount > 0, renewal today or later, valid website domain, notes ≤ 500.
    - `toSubscription(existing:)` keeps identity, status and history when editing.
  - **`MoneyParser`** parses typed amounts into exact minor units. It accepts `.`
    or `,` decimals, grouping and currency precision. A three-digit tail is
    treated as grouping, and the form shows a live formatted preview so mistakes
    are visible.
  - **List:** `SubscriptionListQuery` (`features/subscriptions/domain/`) is pure
    search, filter and sort logic. Price sorting uses the converted monthly
    equivalent, with unconvertible subscriptions last.
- `catalogSearchResultsProvider` is **synchronous** over the loaded catalog
  (`AsyncValue` only while the asset first loads), so typing never flashes a
  loading state.

### Logos

- **Always render logos through `SubscriptionLogo`** (or `UserSubscriptionLogo` /
  `CatalogServiceLogo`, which resolve via providers). Never draw brand marks ad hoc.
- **Resolution** (`SubscriptionLogoResolver`): bundled SVG → bundled raster → remote
  provider (`RemoteLogoProvider`, currently `NoRemoteLogoProvider`, so the app stays
  fully offline and Logo.dev can be plugged in later) → custom glyph → coloured
  initials → category icon. Asset load errors fall back to initials at render time.
- **Tile colours** (`LogoTileColors.forBrand`): the brand-coloured mark sits on a soft
  tint of the brand colour. Near-black brands get a neutral tile, and very light
  brands get a solid tile with a midnight mark. Marks keep their aspect ratio.
- **Source:** Simple Icons only (CC0; see `docs/brand-logos.md` for per-logo sources
  and guidelines). **Never fabricate or approximate a logo.** Brands Simple Icons
  removed at their request (Microsoft, Adobe, Slack, Disney, OpenAI/ChatGPT, …) stay
  as initials unless an official brand kit permits use, and must be documented.

## Design system

The visual direction is a premium, minimalist fintech look: soft pastel gradients,
clean white cards, large radii, subtle shadows, bold figures, generous whitespace
and a floating pill navigation. **No default Material look.**

**Never hardcode design values in widgets.** Import `core/theme/theme.dart` and use tokens.
Add a token if one is missing. Brand colours inside mock data are the only exception.

### Tokens (`lib/core/theme/`)

| File | Contents |
|---|---|
| `app_colors.dart` | Brand palette, tints, semantic text and status colours, borders |
| `app_typography.dart` | Manrope scale: `amountHero/Large/Medium/Small`, `display`, `headline*`, `title*`, `sectionTitle` (20/600), `cardTitle`, `statValue`, `body*`, `label*`, `caption`, `monogram` |
| `app_spacing.dart` | 4-pt scale `xxs 4 · xs 8 · sm 12 · md 16 · lg 20 · xl 24 · xxl 32 · xxxl 40 · huge 56`, screen and card padding |
| `app_radius.dart` | `xs 8 · sm 12 · md 16 · lg 20 · xl 28 · xxl 32 · pill`, plus `BorderRadius` constants |
| `app_gradients.dart` | `background` (cream → lavender → mint, top to bottom), ambient glows, `midnight`, `accent`, `insight`, `mint` |
| `app_shadows.dart` | `none`, `card`, `button`, `floating` |
| `app_sizes.dart` | Icon sizes, button heights, tap target (48), nav and icon-tile dimensions |
| `app_motion.dart` | Durations `fast 150 · medium 260 · slow 420ms`, curves, press scale, disabled opacity |
| `app_theme.dart` | `AppTheme.light`: ColorScheme and component themes built from the tokens |

### Palette

| Token | Hex | Use |
|---|---|---|
| `midnight` | #202020 | Primary actions, dark cards, primary text |
| `yellow` | #FFDA69 | Accent, selected nav, CTAs on dark |
| `mint` | #43C4AE | Success and savings (fills, or text on dark only) |
| `lavender` | #E7E8F4 | Gradient, soft containers |
| `cream` | #F5EFEB | Gradient, soft containers |
| `surface` | #FFFFFF | Cards and sheets |
| `secondaryText` / `textSecondary` | #85858D | **Large text (≥18px, or ≥14px bold), icons and hints only** (3.7:1) |
| `textMuted` | #6B6B73 | AA-compliant small secondary copy |
| `successStrong` / `dangerStrong` | #17725F / #C2363B | Status text on light surfaces |

### Accessibility rules

- Keep text contrast at WCAG AA or better. Never put white text on yellow or mint, and
  don't use mint or `danger` for small text on light backgrounds; use the `*Strong` variants instead.
- Touch targets must be at least 48 px (`AppSizes.minTapTarget`).
- Give custom tappables `Semantics(button: true, label: …)`. Mark decorative visuals with `ExcludeSemantics`.
- Mark section titles with `Semantics(header: true)`.
- Use `container: true` on any `Semantics` that must be its own node (buttons, headers,
  list rows). Without it, the annotation merges into the enclosing list item, so a
  whole section is read as one blob and flagged as a button.
- Give money figures a plain semantics label, e.g. `$248.97`.

### Typography gotcha

`google_fonts` registers a separate font family per weight. **Never change `fontWeight`
with `copyWith` on an `AppTypography` style**, because that synthesizes a fake weight.
Add a new token instead. Changing `color` or `fontSize` is fine.

### Shared components (`lib/shared/widgets/`)

| Widget | Purpose |
|---|---|
| `GradientScaffold` | Root of every screen: pastel gradient, ambient glows, dark status bar |
| `PrimaryButton` | Pill CTA. Variants: `midnight` (default) and `accent` (yellow). Supports `icon`, `isLoading`, `isExpanded`, `ButtonSize` |
| `SecondaryButton` | White pill with hairline border |
| `BaseButton` | Shared button implementation; don't use it directly in features |
| `AppCard` | White rounded card. Optional `gradient`, `onTap` (press-scale), `clipBehavior` |
| `SectionHeader` | Title, optional subtitle and an optional "See all" action |
| `FloatingBottomNav` | Compact white pill with icon-only tabs. Selected tab is a midnight circle. Labels are exposed via semantics. Handles its own safe area |
| `SubscriptionLogo` | Brand logo in a circle or squircle tile (see Logos). `UserSubscriptionLogo` / `CatalogServiceLogo` resolve branding via providers |
| `SpendingSummaryCard` | Dark hero card (no longer used on Home, kept for future screens): split `Money` amount, `TrendBadge`, active count, projected yearly |
| `CurrencySelector` / `CurrencyOptionList` / `showCurrencyPicker` | Display-currency pill, list and bottom sheet (see Multi-currency) |
| `ConversionNote` | Caption labelling converted totals as estimates, or warning about stale or missing rates |
| `TrendBadge` | Spending-change pill (decrease is mint/good, increase is coral/bad), with an `onDark` mode |
| `PressableScale` | Shared tap affordance: press-scale and selection haptic, used instead of ink ripples |
| `PlaceholderView` | "Coming soon" state for unfinished destinations |
| `EmptyStateCard` | Empty or no-results card: icon tile, title, message, action buttons |
| `ScreenHeader` / `CircleIconButton` | Title row with a circular back button and trailing action |
| `SearchField` | Pill search input with clear button |
| `ChoicePill` / `ChoicePillRow` | Selectable filter or option pills (selected = midnight). The label truncates rather than overflowing |
| `showConfirmationSheet()` | Bottom-sheet confirmation (destructive variant for delete) |
| `SampleDataBanner` | Visible whenever sample data is shown, with "Exit" |
| `FadeSlideIn` | Subtle staggered entrance (fade and 16 px rise). Respects reduced motion |
| `showComingSoon()` | Snackbar for actions whose flow isn't built yet |

### Dashboard widgets (`lib/features/dashboard/presentation/widgets/`)

In order:

- `DashboardHeader`: wordmark, plus "+" add, bell with due-soon dot, avatar.
- `SpendingOverview`: centred greeting, total and yearly projection, plus three
  translucent stat chips.
- `UpcomingRenewalsSection`: horizontal cards, two per width, with a plan tag.
- `CategoryBreakdownCard`: "Where your money goes". A custom-painted donut with round
  caps and a hatched "Other" slice, plus a bar legend. Stacks below 290 px.
- `AiInsightCard`: "Smart tip", tagged *Sample data*.
- `SpendingTrendCard`: a yellow `fl_chart` area line, with a mint marker on the
  current month.
- `RecentlyAddedSection`: list rows.

Content is centred at a maximum of `AppSizes.contentMaxWidth` on large screens.

Layout notes:
- The shell's `GradientScaffold` uses `extendBody: true`. Inside tab screens, read
  `MediaQuery.paddingOf(context).bottom` to clear the floating nav.
- Wrap tab content in `SafeArea(bottom: false)`, and apply the bottom inset as list padding.
- Use `AppSpacing.screenHorizontal` (20) for the horizontal screen inset.

## Coding conventions

- Null-safe, strongly typed code. Use `const` constructors wherever possible.
- Keep files and widgets small. Extract private `_Widget` classes rather than helper methods that return widgets.
- Use `abstract final class` for token and utility namespaces.
- Use enums with fields for variants (`ButtonSize`, `SubscriptionLogoSize`, `AppDestination`).
- Naming: `snake_case.dart` files, `PascalCase` types, `lowerCamelCase` members, and
  `*Screen` for route widgets.
- Avoid deprecated APIs: use `withValues(alpha:)` not `withOpacity`, `*ThemeData`
  classes for component themes, and `isSemantics` in tests.
- Represent money only as `Money`, convert only via `CurrencyConverter`/`MoneyConverter`,
  and format only through `CurrencyFormatter`. Never hardcode currency symbols.
- Never commit secrets or API keys. Future keys belong in `--dart-define` or env config, never in source.
- Don't modify platform folders (`ios/`, `android/`, …) unless the task requires it.

## Testing and validation

Run after every change:

```bash
dart format lib test
flutter analyze        # must report: No issues found
flutter test
```

- `test/flutter_test_config.dart` disables Google Fonts runtime fetching so tests stay hermetic.
- `test/helpers/app_harness.dart`: `pumpBillfern(seed:, mode:, size:, textScale:)` pumps
  the whole app with an in-memory personal repository (returned for assertions). It
  also provides `openTab`, `tapVisible` (scrolls lazy lists and centres targets away
  from the floating nav), `enterField`, `scrollToTop`, `tapBack` and `pickDay`.
- `test/helpers/fixed_clock.dart`: `emptyAppTestOverrides` (first launch) and
  `appTestOverrides` (sample data).
- Subscription management tests: `subscription_management_flow_test.dart` (end to end:
  add from catalog and custom, validation, edit, pause/resume, delete confirmation,
  dashboard updates, overflow sweep), `subscription_persistence_test.dart` (real
  sembast file DB across "restarts"), `subscriptions_notifier_test.dart`,
  `subscription_list_query_test.dart`, `billing_cycle_test.dart` and
  `money_parser_test.dart`.
- `test/helpers/pump_themed.dart` provides `tester.pumpThemed(widget)`.
- Add a widget test for each new shared component, and a smoke test for each new screen.
- `test/features/dashboard/dashboard_screen_test.dart` includes a **layout overflow
  sweep** (iPhone SE, 13 mini, 16 and 16 Pro Max, at 1.0× and 1.35× text). Extend it
  when adding sections.
- Provider/domain tests assert cross-component consistency (hero = chart's last bar =
  sum of categories). Keep them green when changing calculations.
- Catalog tests (`test/shared/data/`) check that every bundled logo path exists, the
  required services are present, there are no prices, and search ranking. Logo tests
  cover the resolution order and missing-asset fallbacks.
- Currency tests: `test/core/money/money_test.dart` (Money, conversion, rounding,
  rates, locale suggestions), `test/core/utils/currency_formatter_test.dart`,
  `test/shared/providers/currency_preference_test.dart` (persistence), and provider
  tests for mixed currencies, unavailable or stale rates and switching currency. Run
  with `flutter test --concurrency=2` on 8 GB machines.
- Widget tests that need the catalog must let the real asset read finish:
  `await tester.runAsync(() => container.read(subscriptionCatalogProvider.future))`.

## Workflow rules

- Never commit or push without explicit approval from the user.
- Inspect the code before changing it. Keep changes scoped to the task.
- Keep this file up to date when architecture, tokens or conventions change.
