# Billfern

**Track smarter. Spend less.**

Billfern is a premium, AI-powered subscription tracker and personal finance app for
iOS and Android. It helps people manage recurring payments, see upcoming renewals,
find subscriptions they no longer need, and save money.

> **Status:** early development. The design system, shared components and navigation
> shell are in place, and the dashboard is next. All data is mocked; there is no backend yet.

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
│   ├── models/      # Shared models
│   └── providers/   # App-wide Riverpod providers
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
flutter test
```

## Configuration

No API keys are required at this stage. When backend services are added, secrets will
be supplied through `--dart-define` or environment configuration and will never be committed.

## License

Proprietary. All rights reserved.
