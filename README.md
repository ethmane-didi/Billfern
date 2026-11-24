# Billfern

**Track smarter. Spend less.**

Billfern is a premium, AI-powered subscription tracker and personal finance app for
iOS and Android. It helps people manage recurring payments, see upcoming renewals,
find subscriptions they no longer need, and save money.

> **Status:** early development. The design system, navigation shell and home dashboard
> are in place. All data is mocked, and AI insights are local sample rules. There is no backend yet.

## Dashboard

The home screen shows:

- A personalised greeting and a notifications button
- Monthly spending, the change versus last month, the number of active subscriptions
  and a projected yearly total
- Upcoming renewals for the next 30 days
- An AI savings insight preview, using mock data
- A six-month spending trend and a breakdown by category
- Subscription cards and an "Add subscription" action

Every figure is derived from one subscription list (`subscriptionsProvider`) by
`SpendingCalculator`. Amounts are stored as integer cents, so totals always agree
across cards.

The visual reference is [`docs/design/dashboard-reference.png`](docs/design/dashboard-reference.png).

## Subscription catalog and logos

- **Catalog:** 82 popular services across entertainment, music, AI, design,
  productivity, cloud storage, development, gaming, fitness, education, security and
  Nordic services, in `assets/data/subscription_catalog.json`. It stores identity,
  category, brand colour, aliases and the logo path, never prices.
- **Logos:** 59 brand logos are bundled as offline SVGs in `assets/logos/`, from
  [Simple Icons](https://simpleicons.org/) (CC0). Services without a permitted logo
  show coloured initials. Sources and brand guidelines are listed in
  [`docs/brand-logos.md`](docs/brand-logos.md).
- **Regenerating:** run `python3 tool/catalog/build_catalog.py <extracted simple-icons package>`.
  That script is the single source of truth for the catalog.

Users will be able to search the catalog or add custom subscriptions (Phase 3).

## Multi-currency

Billfern is built for international users:

- **Original currencies:** every subscription keeps the currency it is billed in.
- **Display currency:** totals, charts and insights are converted into the user's
  preferred currency. It's suggested from the device locale, can be changed from the
  dashboard or **Settings → Display currency**, and is saved on the device.
- **Supported:** USD, EUR, NOK, GBP, SEK, DKK, CHF, CAD and AUD. Other ISO 4217
  currencies work through `intl`.
- **Exact amounts:** money is stored as integer minor units in its own currency.
  Conversion uses exact integer arithmetic with one rounding step, and amounts in
  different currencies are never added directly.
- **Rates:** exchange rates come from a replaceable provider. Development uses
  deterministic **mock rates**, and converted totals are labelled as estimates. No
  external exchange-rate API is connected yet.

See [CLAUDE.md](CLAUDE.md#multi-currency) for the architecture.

## Features (roadmap)

- Subscription management, with active and paused subscriptions
- Monthly and annual spending summaries
- Upcoming renewal timeline and reminders
- Categories and spending analytics
- AI-powered savings recommendations and insights
- Premium plans

## Tech stack

| Area | Technology |
|---|---|
| Framework | Flutter (Dart 3.13+) |
| State management | Riverpod 3 |
| Navigation | GoRouter (stateful shell routes) |
| Typography | Google Fonts, Manrope |
| Icons | Lucide (`lucide_icons_flutter`) |
| Charts | FL Chart |
| Planned | Supabase (auth and data), OpenAI (insights), RevenueCat (monetization), Flutter Local Notifications (reminders) |

## Architecture

Feature-first structure with a centralized design system:

```
lib/
├── core/
│   ├── constants/   # App-wide constants
│   ├── router/      # GoRouter config, app shell, destinations
│   ├── theme/       # Design tokens: colors, typography, spacing, radius, gradients, shadows, sizes, motion, theme
│   ├── utils/       # Formatters and helpers
│   └── services/    # Platform and API services (future)
├── features/
│   ├── dashboard/  subscriptions/  analytics/  settings/
│   └── onboarding/ authentication/            # each: data / domain / presentation as needed
├── shared/
│   ├── widgets/     # Reusable UI components
│   ├── models/      # Subscription, catalog item, branding, billing cycle, category, user
│   ├── data/        # Repositories (subscriptions, catalog), catalog search, logo resolver
│   └── providers/   # Clock, subscriptions, catalog/search/branding, current user
├── app.dart         # Root widget (theme + router)
└── main.dart        # Entry point
```

Design values are never hardcoded in widgets. Everything comes from the tokens in
`lib/core/theme/`. See [CLAUDE.md](CLAUDE.md) for the full design system,
conventions and contribution rules.

## Getting started

### Prerequisites

- Flutter 3.47+ (stable channel)
- Xcode with an iOS Simulator (for iOS), or Android Studio with an emulator (for Android)

### Run locally

```bash
flutter pub get
open -a Simulator           # or start an Android emulator
flutter run
```

Manrope is fetched by `google_fonts` on first launch, so the device needs a
network connection the first time the app runs.

### Quality checks

```bash
dart format lib test
flutter analyze
flutter test --concurrency=2   # keeps memory use modest
```

## Configuration

No API keys are required at this stage. When backend services are added, secrets will
be supplied through `--dart-define` or environment configuration and will never be committed.

## License

Proprietary. All rights reserved.
