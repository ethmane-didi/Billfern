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

Frontend only, with realistic mock data. **Do not integrate** Supabase,
authentication, OpenAI, RevenueCat, payments or banking APIs until asked.

| Phase | Scope | Status |
|---|---|---|
| 1 — Design foundation | Tokens, theme, router, shared components | ✅ Done |
| 2 — Dashboard | Greeting, spending summary, comparison, chart, categories, renewals, subscription cards, AI insight preview, add action | ✅ Done (awaiting review) |
| 3 — Navigation | Home / Subscriptions / Analytics / Settings with placeholders | ✅ Shell and placeholders done |

Home is the Phase 2 dashboard (`DashboardScreen`). Add, notifications, insight and card
taps show a "coming soon" snackbar (`showComingSoon`) until those flows exist.

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
│   ├── constants/             # AppConstants (name, tagline, default currency)
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

Riverpod for shared state. Keep ephemeral UI state (press, animation) in
`StatefulWidget`s. Mock data flows through providers/repositories so Supabase can be
swapped in without touching widgets.

**Data flow (single source of truth):**

```
clockProvider → todayProvider → subscriptionRepositoryProvider (MockSubscriptionRepository)
  → subscriptionsProvider (de-duplicated by id) → dashboard providers → widgets
```

- **Money is integer cents** (`priceCents`, `monthlyTotalCents`, …). Sum in cents and
  convert only at the UI boundary with `CurrencyFormatter.formatCents` / `fromCents`.
- **No financial maths in widgets.** All totals, comparisons, category shares,
  history and renewals come from `SpendingCalculator`
  (`features/dashboard/domain/`), exposed through `dashboard_providers.dart`.
  Widgets such as `SpendingSummaryCard` only display values they're given.
- Monthly spending = sum of `monthlyCostCents` of subscriptions billed that month
  (`Subscription.isBilledInMonth`: started before month end, not paused before it).
  So the hero total, the chart's current bar and the category slices always agree.
- Category percentages use the largest-remainder method and always sum to 100. Beyond
  five categories the tail merges into "Other".
- Yearly mock prices divide evenly by 12, so monthly × 12 equals the projected yearly figure.
- Mock data is built relative to `today`. Tests pin the clock with
  `test/helpers/fixed_clock.dart` (Tue 24 Nov 2026, 09:00).
- AI insights come from `MockSavingsInsightEngine` (local rules, no network) behind
  `savingsInsightEngineProvider`. The UI presents them as a "Smart tip" tagged
  *Sample data*, never as real AI analysis. Swap the provider to integrate OpenAI later.
- The repository is synchronous for now. With Supabase, `subscriptionsProvider`
  becomes an `AsyncNotifier` and the derived providers propagate `AsyncValue`.

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
- **Add flow (Phase 3):** `SubscriptionDraft` (`features/subscriptions/domain/`).
  `fromCatalog(item)` pre-fills name, category and catalog link. The user supplies
  amount, currency, cycle and next renewal. `custom()` also accepts a website domain,
  colour and `SubscriptionGlyph`.

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
| `SpendingSummaryCard` | Dark hero card (no longer used on Home, kept for future screens): split amount, `TrendBadge`, active count, projected yearly |
| `TrendBadge` | Spending-change pill (decrease is mint/good, increase is coral/bad), with an `onDark` mode |
| `PressableScale` | Shared tap affordance: press-scale and selection haptic, used instead of ink ripples |
| `PlaceholderView` | "Coming soon" state for unfinished destinations |
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
- Format money only through `CurrencyFormatter`.
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
- Widget tests that need the catalog must let the real asset read finish:
  `await tester.runAsync(() => container.read(subscriptionCatalogProvider.future))`.

## Workflow rules

- Never commit or push without explicit approval from the user.
- Inspect the code before changing it. Keep changes scoped to the task.
- Keep this file up to date when architecture, tokens or conventions change.
