# Billfern

**Track smarter. Spend less.**

Billfern is a premium, AI-powered subscription tracker and personal finance app for
iOS and Android. It helps people manage recurring payments, see upcoming renewals,
find subscriptions they no longer need, and save money.

> **Status:** early development. Users can manage their own subscriptions (add from an
> 82-service catalog or create custom ones, edit, pause, resume and delete), stored locally
> on the device, and explore spending analytics. An optional account adds cloud backup
> and sync through Supabase. Billfern works fully offline and without an account.
> Exchange rates are development mock rates, and savings suggestions are local rules,
> not AI.

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

## Branding

The official Billfern logo lives in `assets/branding/` and is shown on the first-launch
welcome screen, in the dashboard header and in Settings → About. Third-party service
logos are kept separately in `assets/logos/`.

## Subscription management

- **Subscriptions tab:** monthly total, active and paused counts, search, All, Active
  and Paused tabs, category filters, and sorting by next renewal, name or price
  (compared in your display currency).
- **Add:** search the catalog or browse popular services, filter by category, or
  create a custom subscription. Picking a service fills in its name, logo, category
  and brand colour. You enter the amount, currency, billing cycle (weekly, monthly,
  quarterly, yearly or a custom interval) and the next renewal date, plus an
  optional reminder preference, plan, website and notes.
- **Details:** original price and currency, converted monthly and yearly estimates,
  schedule, category, reminder and notes, with edit, pause or resume, and delete
  (with confirmation).
- **Storage:** data is stored on the device in a small local database (sembast) and
  survives restarts. Pausing, price changes, billing-cycle changes and deletions
  never rewrite past months (see [Analytics](#analytics)).
- **Sample data:** you can explore sample data from the empty state. It's kept
  separate, never saved, and clearly labelled.

## Analytics

The Analytics tab shows, in your display currency:

- **Overview:** this month's spending (the same figure as the dashboard), the change
  against last month, projected yearly cost, active and paused counts, and the
  exchange-rate status.
- **Spending trend:** an interactive chart over 3, 6 or 12 months. Tap a month (or use
  the arrows) to see its total and the change from the month before. Below the chart
  are the period total, the monthly average and a comparison with the previous period.
- **Monthly and yearly summaries:** this month, the average month, the year so far and
  the next 12 months.
- **Category breakdown:** each category's monthly spending, share, number of active
  subscriptions and a progress ring. Tap a category to see the subscriptions in it.
- **Upcoming payments:** expected payments in the next 7, 30 or 90 days. Every payment
  in the window is counted, so a weekly plan can appear several times.
- **Smart suggestions:** local rules flag possible duplicates, several music or
  streaming services, annual renewals coming up and your largest subscription, with
  potential monthly and yearly savings.

### How spending is calculated

Every figure is labelled with how it was produced:

| Label | Meaning |
|---|---|
| **Estimated** | Past and current months, calculated from your recorded billing schedules, price changes and pauses. Yearly plans are spread evenly across 12 months. |
| **Projected** | Future payments, calculated from the billing schedules of active subscriptions. |
| **Confirmed** | Payments you have actually recorded. Not available yet: there is no payment confirmation or bank connection, so all history is estimated. |

Billfern never invents history:

- Months before you started tracking show **no data**, not zero.
- A trend needs at least two months of history.
- A change against a month with no spending shows no percentage.
- Price, currency and billing-cycle changes are saved as revisions, so earlier months
  keep the price that applied then.
- Pauses stay in the history.
- Deleted subscriptions stay in earlier months but leave current totals and
  projections. A subscription added and deleted in the same month leaves nothing behind.

### Known limitations

- Exchange rates are development mock rates, and converted totals are estimates.
- Subscriptions in a currency without a rate are left out of totals, and the screen
  says so.
- Suggestions only look at your subscription list. Billfern has no usage data, so it
  never claims that a service is unused.
- History starts on the day each subscription was added. Earlier spending can't be
  entered yet.
- Deleted subscriptions keep their history. You can't erase that history from the app
  yet.
- Paused subscriptions are not projected, even if you plan to resume them.

## Accounts and cloud sync (optional)

Billfern never requires an account. Everything works offline on the device, and an
account only adds backup and sync across devices.

- **Sign-in:** an email one-time code. You enter your email, then type or paste the
  verification code from the email (Billfern accepts 6 to 10 digits; the Supabase
  project currently sends 8). That verifies the address, and there is no password.
  - The **Resend** button waits 60 seconds between emails, and Supabase also limits
    how often emails can be sent.
  - The session is stored in the iOS Keychain or Android Keystore.
  - Sign in with Apple and Google are not available yet.
- **Where data lives:**
  - The device is the source of truth. Every change is saved locally first, so you
    can create, edit, pause, resume and delete subscriptions, and view analytics,
    while offline.
  - Changes are queued in a durable outbox and sent when a connection is available:
    after sign-in, after edits, when the app returns to the foreground, on
    **Settings → Sync now**, and on automatic retries with backoff.
- **Several devices:**
  - If the same subscription was changed on two devices, Billfern doesn't pick a
    winner. Settings shows the conflict, and you choose which version to keep.
  - Deleted subscriptions are never brought back by an outdated device.
- **Settings → Account & sync** shows:
  - your sign-in status
  - the sync status (offline, syncing, synced, pending changes, conflict or failed)
  - when you last synced and how many changes are waiting
  - Sync now / Retry, Sign out and Delete account

  "Synced" is only shown once the server has confirmed every change.
- **Signing out:** the account's data is hidden on the device, not deleted. Changes
  that haven't synced yet stay on the device and sync after you sign in again.
  Switching accounts never shows another account's data.
- **Subscriptions you tracked before signing in:** after you sign in, Billfern asks
  before uploading them. You can add them to your account or keep them on the device
  only. All history is kept, subscriptions are never combined by name, and the copy
  on the device is never deleted.
- **Sample data** stays in memory and is never saved or uploaded.
- **Deleting your account** removes it from Billfern's database right away: your
  subscriptions, history, preferences and pending changes. The account's data on
  this device is erased too. Database backups expire according to the Supabase
  project's backup retention, and are not rewritten.
- **Erasing this device's data** (Settings → Privacy) needs confirmation. For a
  guest, it permanently deletes local subscriptions and history. For an account, it
  removes the device's copy, which then downloads again from the cloud.

### Supabase setup

Use a **dedicated development project**. Nothing here touches production.

1. Create a project at [supabase.com](https://supabase.com).
2. **Configure the app.** Copy `config/supabase.example.json` to
   `config/supabase.json` (git-ignored). Fill in:
   - `SUPABASE_URL`: Project Settings → API → Project URL.
   - `SUPABASE_PUBLISHABLE_KEY`: the **publishable** key (`sb_publishable_…`), or the
     legacy anon key.

   Never use the service-role or secret key, or the database password, in the app.
3. **Apply the database migrations** in filename order. Use either:
   - the [Supabase CLI](https://supabase.com/docs/guides/cli):
     ```bash
     supabase link --project-ref <your-dev-project-ref>
     supabase db push            # applies supabase/migrations/*.sql in order
     ```
   - or the dashboard **SQL Editor**: paste and run each file in
     `supabase/migrations/`, oldest first.
4. **Deploy the account-deletion function.** Use `supabase functions deploy
   delete-account`, or Dashboard → Edge Functions → Deploy a new function: name it
   `delete-account`, paste `supabase/functions/delete-account/index.ts`, and keep
   **Verify JWT** on. It reads `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` from the
   Edge runtime; the key stays on the server.
5. **Use codes in sign-in emails.** Under Authentication → Emails, edit the
   **Magic Link** template so the email contains the code `{{ .Token }}` (for example
   "Your Billfern code is {{ .Token }}"). For production, configure custom SMTP.
6. **Run the app** with the configuration:
   ```bash
   flutter run --dart-define-from-file=config/supabase.json
   ```

Without `config/supabase.json`, Billfern runs in local-only mode.

### Database

| Migration | Contents |
|---|---|
| `20261125120000_billfern_schema.sql` | `profiles`, `subscriptions` (integer minor units, tombstones, versions, server change sequence), immutable `subscription_revisions` (price terms and pauses), `payment_records` (prepared, unused), `sync_operations` (idempotency), integrity checks and triggers |
| `20261125120100_billfern_rls.sql` | Revokes Supabase's default privileges, then grants the minimum. Row Level Security on every table with owner-only policies; financial tables are read-only for clients; no `anon` access |
| `20261125120200_billfern_sync_functions.sql` | `sync_push` (idempotent, version-checked, the only write path) and `sync_pull` (transaction-ordered cursor, safe under concurrent writes). Both are `SECURITY DEFINER` with an empty `search_path`, require `auth.uid()` and filter every statement by it |

**Security model:** clients can only **read** their own subscriptions, revisions and
sync records. All writes go through `sync_push`, a `SECURITY DEFINER` function with an
empty `search_path` that filters every statement by `auth.uid()`. Default Supabase
table privileges (including `TRUNCATE`) are revoked, and anonymous clients have no
access.

**Security tests (pgTAP)** act as two separate users and an anonymous client, inside
a transaction that is rolled back. Run them with `supabase test db` against a local
stack (needs Docker). You can also paste
`supabase/tests/database/rls.test.sql` into the dev project's SQL Editor after
enabling the `pgtap` extension.

### Live validation (dev project only)

1. In the **dev** project, go to Authentication → Users → Add user. Create three
   **test** users with "Auto confirm": A, B, and a disposable "delete me" user.
2. Copy `config/supabase.test.example.json` to `config/supabase.test.local.json`
   (git-ignored) and enter those test credentials.
3. Run the live suite:
   ```bash
   flutter test test_live/live_supabase_test.dart --concurrency=1
   ```

It covers sign-in, anonymous and cross-account isolation, refused direct writes,
two-device sync, offline recovery and duplicate delivery, conflicts, tombstones,
guest migration, the display currency, and account deletion. It uses synthetic data
only, and every test user's email must start with `billfern-test-`. The suite refuses
to run otherwise.

Account deletion is destructive, so it only runs with
`BILLFERN_LIVE_DELETION=run`. Recreate the "delete me" user before each such run.
Other options:
- `BILLFERN_LIVE_CONFIG` and `BILLFERN_LIVE_USERS` override the configuration paths.
- `BILLFERN_LIVE_REQUIRED=true` makes a missing configuration fail instead of skip.

Email-code sign-in itself needs a real inbox, so test it manually in the app.

### Continuous integration

There are two GitHub Actions tracks, kept strictly apart.

**Track 1: isolated backend CI** (`.github/workflows/backend-ci.yml`), active.

- **Triggers:**
  - pushes and pull requests to `main` and `feat/backend` that touch backend
    files: `supabase/`, `test_live/`, `lib/features/sync|account`, `lib/core`,
    `lib/shared`, `lib/main.dart`, the sync and account tests and helpers, the
    example configs, `tool/ci/`, `pubspec.*`, `analysis_options.yaml` or the
    workflow itself
  - manual runs
- **Where:** a GitHub-hosted Ubuntu runner with a **disposable** local Supabase
  stack. `supabase start` runs Postgres, Auth, PostgREST, the gateway and the Edge
  runtime; everything else is disabled.
- **Credentials:** none. No repository secrets and no remote Supabase credentials.
  The stack's keys and three synthetic users with random passwords exist only for
  the run.
- **Coverage:**
  - the mocked sync and account suites (at least 95 tests)
  - every migration applied from scratch, checked against
    `supabase_migrations.schema_migrations`
  - all **37** pgTAP checks in `supabase/tests/database/rls.test.sql`
  - the full live suite against the local stack, all 11 tests including end-to-end
    account deletion: cross-account isolation, sync, offline recovery and duplicate
    delivery, conflicts, tombstones, guest migration and display currency
- **Strict checks:** `tool/ci/check_test_report.py` fails the job if any test is
  skipped, failed, missing or duplicated, or if fewer tests ran than expected. The
  expected live tests are listed in `tool/ci/live_suite_tests.txt`.
- **Pinned versions:** Flutter 3.47.2, Supabase CLI 2.113.0, Postgres 17 (the dev
  project's version) and actions pinned to commit SHAs.
- **Limits:** 30-minute timeout; a new push cancels the previous run on the same ref.

**Track 2: live dev-project validation** (`.github/workflows/backend-live-dev.yml`),
prepared but **not active**.

- **Trigger:** manual only, and only once the workflow is on `main` (GitHub offers
  manual runs only for workflows on the default branch).
- **Safety gate:** it fails closed unless all of these hold:
  - the repository variable `BILLFERN_LIVE_DEV_ENABLED` is `true`
  - the run is on `main` or `feat/backend`
  - the run is at the exact commit SHA you entered
  - the `supabase-dev` environment has required reviewers and a deployment branch
    policy
- **Project guard:** the dev URL must match `BILLFERN_DEV_PROJECT_REF`, and must not
  match `BILLFERN_PROD_PROJECT_REF` if that is set.
- **Test users:** must be synthetic (`billfern-test-*`).
- **Concurrency:** one live run at a time; queued runs wait.
- **Account deletion:**
  - off by default
  - needs the input, the typed phrase `DELETE SYNTHETIC TEST USER`, and a separate
    approval in the `supabase-dev-destructive` environment
  - runs only the deletion test

**Future environment configuration** (not yet set; activation needs explicit
approval):

| Where | Name | Kind |
|---|---|---|
| Repository | `BILLFERN_LIVE_DEV_ENABLED` | Variable (`true` to activate) |
| Environment `supabase-dev` (required reviewers, branches `main` and `feat/backend`) | `DEV_SUPABASE_URL`, `DEV_SUPABASE_PUBLISHABLE_KEY`, `DEV_TEST_USER_A_EMAIL`, `DEV_TEST_USER_A_PASSWORD`, `DEV_TEST_USER_B_EMAIL`, `DEV_TEST_USER_B_PASSWORD` | Secrets |
| Environment `supabase-dev` | `BILLFERN_DEV_PROJECT_REF`, optionally `BILLFERN_PROD_PROJECT_REF` | Variables |
| Environment `supabase-dev-destructive` (its own required reviewers) | The same secrets and variables plus `DEV_TEST_DELETE_EMAIL` and `DEV_TEST_DELETE_PASSWORD` | Secrets and variables |

No service-role key, database password or Supabase access token is ever stored in
CI. Migrations and Edge Functions are deployed manually, after approval.

**Security boundaries:**
- The repository is public, so logs are public:
  - values derived from secrets (the dev host and project ref) are masked
  - configuration files are written to the runner's temporary directory, outside
    the workspace, and deleted after the run
  - nothing is uploaded as an artifact
- Workflows get `contents: read` permissions only (the gate adds `actions: read`).
- Workflows never use `pull_request_target`, and secrets never reach pull requests
  from forks.
- The local-user script refuses any API URL that is not `127.0.0.1` or
  `localhost`.

**Estimated runner costs** (check GitHub's current pricing):
- Standard GitHub-hosted runners are free for public repositories.
- A Track 1 run takes about 10–15 minutes (image pulls, Flutter setup, tests); a
  Track 2 run about 5 minutes.
- If the repository becomes private, the Free plan includes 2,000 Linux minutes a
  month, which is roughly 130–200 Track 1 runs.
- The dev project stays on Supabase's free plan. Free projects pause after about a
  week of inactivity, so resume it before running Track 2.

### Validation status (Phase 5 checkpoint)

**Verified manually against the dev project:**

- Email-code sign-in, with emails delivered through Resend and 8-digit codes.
- Offline edits saved locally and synced after reconnecting. The records arrived in
  the remote database with the correct prices, currencies and billing cycles.
- Recovery after a token refresh or request that hung while offline (15-second
  HTTP timeout).

**Covered by isolated CI** (Track 1, once the workflow is committed and green):
migrations from scratch, all 37 pgTAP checks, cross-account isolation, sync, offline
recovery, conflicts, guest migration, display currency, and end-to-end account
deletion on a disposable local stack.

**Still required before release (dev project, synthetic data only):**

- [ ] A first green Track 1 run on GitHub Actions.
- [ ] Activate and run Track 2 (non-destructive) against the dev project, once
      approved and configured.
- [ ] Delete an account end to end on the dev project (Track 2's destructive job or
      by hand), and confirm that the gateway JWT setting works with the project's API
      keys.
- [ ] Check migration drift by hand: `supabase migration list` and
      `supabase db push --dry-run`.
- [ ] Sync between two real devices, including resolving a conflict in the UI.
- [ ] Check the display currency syncs both ways between two devices.
- [ ] Import guest data into an account that already has cloud data.
- [ ] Check automatic sync after reconnecting on a **physical** iPhone. The
      simulator may not report Wi-Fi changes.
- [ ] Do an iOS build after adding `connectivity_plus` (`pod install`), with at least
      15 GiB of free disk.
- [ ] For production: custom SMTP, Sign in with Apple and Google, the App Store
      sign-in requirements, and a backup and retention review.

### Sync limitations

- Live validation is **partial** (see Validation status). The RLS and end-to-end
  tests run on a disposable local Supabase stack in CI. The dev project itself has
  only been validated manually so far.
- Account deletion has not been tested against a live project, so it blocks release.
- Sign in with Apple and Google, data export from the UI, and permanent deletion of
  the server history of individual subscriptions are not available yet.
- **Reconnecting:** when the device's network comes back, Billfern waits a few
  seconds for it to settle and then sends pending changes automatically. You don't
  need to tap **Retry sync**.
  - A network connection doesn't guarantee that the server is reachable. If the
    attempt fails, changes stay safely queued on the device and are retried with
    increasing delays.
  - If there's nothing to send, reconnecting makes no request.
  - Changes the server rejected wait for **Retry sync**.
  - Every Supabase request times out after 15 seconds, so a request that hung while
    offline never blocks sync after the connection returns.
  - The iOS Simulator may not report Wi-Fi changes. There, sync still recovers on the
    next retry, when the app returns to the foreground, or with **Retry sync**.
- If the display currency changes on two devices before they sync, the cloud value
  wins (it's a display preference only).

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
| Local storage | sembast (one database per identity), shared_preferences |
| Backend (optional) | Supabase: Auth (email codes), PostgreSQL with RLS, Edge Functions; `flutter_secure_storage` for sessions |
| Planned | OpenAI (insights), RevenueCat (monetization), Flutter Local Notifications (reminders) |

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
supabase test db               # database security tests (local Supabase stack)
```

## Configuration

No configuration is needed for local-only use. Cloud sync reads `SUPABASE_URL` and
`SUPABASE_PUBLISHABLE_KEY` at build time from `config/supabase.json` (see
[Supabase setup](#supabase-setup)). That file is git-ignored and must only contain the
public URL and the publishable key. Secrets such as the service-role key belong only in
Supabase's server-side environment and are never committed.

## License

Proprietary. All rights reserved.
