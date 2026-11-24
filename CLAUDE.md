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
| 2 — Dashboard | Greeting, spending summary, comparison, chart, renewals, subscription cards, AI insight preview, add action | ⏳ Next |
| 3 — Navigation | Home / Subscriptions / Analytics / Settings with placeholders | ✅ Shell and placeholders done |

Home currently shows a **component preview** (`DashboardScreen`) that Phase 2 replaces.

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
│   ├── utils/                 # CurrencyFormatter, etc.
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
    ├── models/                # cross-feature models (e.g. Subscription)
    └── providers/             # app-wide providers
```

### Routing

- `AppDestination` (enum) is the single source of truth for tab order, path, label
  and icon. Its order must match the branch order in `app_router.dart`.
- `appRouterProvider` exposes the `GoRouter`. Add auth and onboarding redirects there later.
- Tabs use `NoTransitionPage`. Pushed routes use the theme's Cupertino transition.
- Tapping the active tab again resets it to its root (`goBranch(initialLocation: true)`).

### State

Riverpod for shared state. Keep ephemeral UI state (press, animation) in
`StatefulWidget`s. Mock data should flow through providers/repositories so Phase 2+
can swap in Supabase without touching widgets.

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
| `app_typography.dart` | Manrope scale: `amountHero/Large/Medium/Small`, `display`, `headline*`, `title*`, `body*`, `label*`, `monogram` |
| `app_spacing.dart` | 4-pt scale `xxs 4 · xs 8 · sm 12 · md 16 · lg 20 · xl 24 · xxl 32 · xxxl 40 · huge 56`, screen and card padding |
| `app_radius.dart` | `xs 8 · sm 12 · md 16 · lg 20 · xl 28 · xxl 32 · pill`, plus `BorderRadius` constants |
| `app_gradients.dart` | `background`, ambient glows, `midnight` (dark cards), `accent`, `mint` |
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
| `FloatingBottomNav` | Midnight pill nav. Selected item expands into a yellow labelled pill. Handles its own safe area |
| `SubscriptionIcon` | Squircle tile with a brand colour and monogram (or icon). Brand logos are not bundled |
| `SpendingSummaryCard` | Dark hero card: split amount, `TrendBadge`, active count, projected yearly total |
| `TrendBadge` | Spending-change pill (decrease is mint/good, increase is coral/bad), with an `onDark` mode |
| `PressableScale` | Shared tap affordance: press-scale and selection haptic, used instead of ink ripples |
| `PlaceholderView` | "Coming soon" state for unfinished destinations |

Layout notes:
- The shell's `GradientScaffold` uses `extendBody: true`. Inside tab screens, read
  `MediaQuery.paddingOf(context).bottom` to clear the floating nav.
- Wrap tab content in `SafeArea(bottom: false)`, and apply the bottom inset as list padding.
- Use `AppSpacing.screenHorizontal` (20) for the horizontal screen inset.

## Coding conventions

- Null-safe, strongly typed code. Use `const` constructors wherever possible.
- Keep files and widgets small. Extract private `_Widget` classes rather than helper methods that return widgets.
- Use `abstract final class` for token and utility namespaces.
- Use enums with fields for variants (`ButtonSize`, `SubscriptionIconSize`, `AppDestination`).
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

## Workflow rules

- Never commit or push without explicit approval from the user.
- Inspect the code before changing it. Keep changes scoped to the task.
- Keep this file up to date when architecture, tokens or conventions change.
