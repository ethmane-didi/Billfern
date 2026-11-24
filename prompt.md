# Billfern — Flutter Development Brief

Act as a senior Flutter engineer and mobile UI/UX designer. We are building a production-quality mobile application called **Billfern**.

## 1. Product Overview

Billfern is a premium AI-powered subscription tracker and personal finance application that helps users manage recurring payments, track expenses, identify unnecessary subscriptions and save money.

**Brand:** Billfern
**Tagline:** Track smarter. Spend less.
**Platforms:** iOS and Android
**Initial development platform:** iOS

## 2. Technology Stack

- Flutter and Dart
- Riverpod for state management
- GoRouter for navigation
- Google Fonts (Manrope)
- FL Chart for analytics
- Lucide Icons for iconography
- Supabase for future authentication and database integration
- OpenAI API for future AI-powered insights
- RevenueCat for future monetization
- Flutter Local Notifications for future renewal reminders

Inspect the existing pubspec.yaml before installing dependencies. Use compatible package versions.

## 3. Project Architecture

I have already initialized the Flutter project and created the following folder structure:

```
lib/
├── core/
│   ├── theme/
│   ├── constants/
│   ├── router/
│   ├── utils/
│   └── services/
├── features/
│   ├── onboarding/
│   ├── authentication/
│   ├── dashboard/
│   ├── subscriptions/
│   ├── analytics/
│   └── settings/
├── shared/
│   ├── widgets/
│   ├── models/
│   └── providers/
├── app.dart
└── main.dart
```

Use a scalable, feature-first architecture. Separate presentation, domain and data layers where appropriate, without unnecessary overengineering.

## 4. Design System

Follow the attached UI reference closely. We want the same premium fintech aesthetic, pastel color palette, rounded components and visual hierarchy while establishing Billfern's own brand identity.

### Color Palette

| Token | Hex |
|---|---|
| Primary / Midnight | #202020 |
| Accent / Yellow | #FFDA69 |
| Success / Mint | #43C4AE |
| Lavender | #E7E8F4 |
| Warm Cream | #F5EFEB |
| Surface | #FFFFFF |
| Secondary Text | #85858D |

### Visual Direction

- Soft pastel gradient backgrounds
- Clean white cards
- Large rounded corners
- Subtle shadows
- Premium minimalist fintech appearance
- Manrope typography
- Bold financial figures
- Generous whitespace
- Floating pill-shaped bottom navigation
- Consistent Lucide icons
- Smooth, subtle animations
- Responsive layouts and proper safe areas
- Accessible text contrast
- No generic default Material UI appearance

Centralize all colors, typography, spacing, gradients, shadows and border radius values into reusable design tokens.

Avoid hardcoding design values throughout the application.

## 5. Product Features

The eventual application will include:

- Subscription management
- Monthly and annual spending summaries
- Upcoming renewal dates
- Subscription categories
- Active and paused subscriptions
- Spending analytics
- Renewal notifications
- AI-powered savings recommendations
- Personalized financial insights
- Premium subscription plans

## 6. Current Development Phase

For now, focus exclusively on the frontend foundation and dashboard using realistic mock data.

Do not integrate Supabase, authentication, OpenAI, payment services or banking APIs yet.

### Phase 1 — Design Foundation

Create:

- app_colors.dart
- app_typography.dart
- app_spacing.dart
- app_radius.dart
- app_gradients.dart
- app_shadows.dart
- app_theme.dart
- app_router.dart

Build reusable shared components:

- Gradient scaffold
- Primary button
- Secondary button
- App card
- Section header
- Floating bottom navigation
- Subscription icon
- Spending summary card

### Phase 2 — Dashboard

Build a polished dashboard inspired by the attached reference design, including:

- Personalized greeting
- Monthly subscription spending
- Spending comparison
- Active subscription count
- Spending visualization
- Upcoming renewals
- Subscription cards
- AI savings insight preview
- Add subscription action
- Floating bottom navigation

Use realistic mock subscriptions such as Netflix, Spotify, Apple Music, Figma and ChatGPT.

### Phase 3 — Navigation

Configure four main destinations:

1. Home
2. Subscriptions
3. Analytics
4. Settings

Create placeholder screens for unfinished destinations while keeping the navigation functional.

## 7. Engineering Rules

- Follow Flutter and Dart best practices.
- Use null-safe, strongly typed code.
- Prefer const constructors wherever possible.
- Keep widgets small, focused and reusable.
- Avoid unnecessarily large files.
- Use Riverpod for shared application state.
- Use GoRouter for navigation.
- Avoid deprecated APIs.
- Do not expose API keys or secrets.
- Do not modify unrelated platform configurations.
- Maintain consistent naming conventions.
- Avoid unnecessary dependencies.
- Ensure the project compiles successfully.
- Update or replace the default Flutter widget test.

## 8. Project Documentation

Create a root-level CLAUDE.md containing the project's architecture, design tokens, coding conventions, product requirements and development rules so future Claude Code sessions maintain consistency.

Also create a professional README.md with the project overview, technology stack, architecture and local development instructions.

## 9. Execution Instructions

First inspect the existing repository, dependencies and folder structure.

Then:

1. Create the project documentation.
2. Implement the centralized design system.
3. Build the reusable UI components.
4. Configure routing and navigation.
5. Implement the dashboard using mock data.
6. Format the Dart code.
7. Run flutter analyze.
8. Run flutter test.
9. Resolve any errors or warnings introduced by your changes.

Do not commit or push changes without my approval.

At the end, provide a concise summary of the files created, architectural decisions, validation results and remaining work.

Start implementing the frontend foundation now. Prioritize visual quality, maintainability and consistency with the reference design.
