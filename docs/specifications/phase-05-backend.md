# Billfern — Phase 5: Supabase Backend and Offline-First Synchronization

## 1. Starting Point

Phases 1–4 have been completed, committed, pushed and merged into main.

Current baseline: `27d0890`

Previous validation:

- 267 passing tests.
- Clean Flutter analysis.
- Successful iOS simulator build.
- Functional subscription management.
- Sembast local database.
- Multi-currency support.
- Financial analytics and subscription history.
- Billfern branding and onboarding.
- Subscription catalog containing 82 services and 59 bundled brand logos.

Before implementation, read:

- `CLAUDE.md`
- `README.md`
- `docs/specifications/phase-04-analytics.md`
- `docs/specifications/phase-05-backend.md`

Inspect the existing repository and confirm the current branch.

Use `feat/backend` for this phase. Create it from main only if it does not already exist.

Do not repeat completed phases or rewrite Git history.

## 2. Objective

Transform Billfern into a connected, secure, offline-first subscription management application using Supabase.

The backend should provide:

- Optional user authentication.
- Cloud data synchronization.
- Cloud backups.
- Account recovery.
- Multi-device support.
- Secure user data storage.
- Account and data deletion.

Billfern must remain fully functional without an internet connection or user account.

Authentication must never be required simply to track subscriptions.

## 3. Technology Stack

Continue using the existing technology stack:

- Flutter and Dart.
- Riverpod.
- GoRouter.
- Sembast.
- Shared Preferences.
- Supabase Flutter.
- PostgreSQL.
- Supabase Authentication.
- Supabase Row Level Security.

Inspect existing dependencies before adding new packages.

Use compatible package versions and avoid unnecessary dependencies.

## 4. Offline-First Architecture

Preserve Sembast as the local source of truth for the application.

Riverpod providers and presentation widgets should continue reading from the local subscription repository.

Supabase should act as the remote synchronization and backup layer rather than a separate, competing UI data source.

The application must support:

- Creating subscriptions offline.
- Editing subscriptions offline.
- Pausing and resuming subscriptions offline.
- Deleting subscriptions offline.
- Viewing analytics offline.
- Changing local preferences offline.
- Synchronizing changes when connectivity returns.

Local operations must not depend on a successful network request.

Do not replace the existing local database with Supabase.

Preserve the existing subscription history, financial calculations and multi-currency architecture.

## 5. Supabase Configuration

Use a dedicated development Supabase project.

Configure Supabase through build-time environment variables.

Provide an example configuration containing:

- SUPABASE_URL
- SUPABASE_PUBLISHABLE_KEY

Never embed privileged credentials in the Flutter application.

Never expose:

- Supabase service-role keys.
- PostgreSQL passwords.
- Administrative tokens.
- Private API keys.
- Authentication session tokens.

Use the appropriate public client key for mobile applications.

If Supabase configuration is missing, Billfern must continue working in local-only mode without crashing.

Document the configuration and setup process in README.md.

Report any credentials or dashboard configuration that requires my action.

Do not deploy migrations or modify a production Supabase project without my explicit approval.

## 6. Authentication

Authentication must be optional.

Preserve the existing welcome screen and onboarding flow.

Users should be able to choose between:

- Continue without an account.
- Create an account.
- Sign in to an existing account.

Implement verified email authentication using a supported email OTP or magic-link flow.

Document the selected authentication approach.

**Selected approach (Phase 5.1):** email one-time codes. The code length is set in
the Supabase project (currently 8 digits), so the app must not assume a fixed length:

- Accept numeric codes of 6 to 10 digits, kept as strings (leading zeros preserved).
- No hardcoded 6-digit input limit; the field caps input at 10 digits.
- Pasting the whole code works, including a pasted email line ("Your code: 0123 4567").
- Copy says "Enter the verification code", never a fixed digit count.
- The complete code is passed to Supabase `verifyOTP` unchanged.

Support:

- Account creation.
- Email verification.
- Sign-in.
- Session restoration.
- Sign-out.
- Expired-session handling.
- Authentication error states.
- Invalid or expired verification links or codes.
- Resend limits.
- Offline authentication states.

Prepare the architecture for future:

- Sign in with Apple.
- Sign in with Google.

Do not claim that Apple or Google authentication works until provider credentials, callback URLs and platform configurations have been configured and tested.

Review applicable App Store authentication requirements before release.

Use an appropriate secure storage mechanism for authentication sessions.

Never log authentication tokens or credentials.

## 7. Account and Synchronization Settings

Extend the existing Settings screen with an Account & Sync section.

For guest users, display:

- Local-only account status.
- Explanation of cloud synchronization.
- Create account action.
- Sign-in action.

For authenticated users, display:

- Account email.
- Account status.
- Cloud synchronization status.
- Last successful synchronization.
- Pending changes.
- Manual synchronization action.
- Retry failed synchronization.
- Sign-out action.
- Delete account action.

Synchronization states should include:

- Offline.
- Syncing.
- Synced.
- Pending changes.
- Conflict.
- Failed.

Never display a successful synchronization status while pending operations remain unacknowledged.

Use clear, accessible language.

## 8. PostgreSQL Database Architecture

Inspect the existing Sembast database schema, subscription models, codecs, archived subscriptions, historical revisions and payment-history structures before designing the PostgreSQL schema.

Preserve stable subscription IDs.

Use UUIDs or a documented collision-safe mapping for existing local IDs.

Create versioned SQL migrations inside:

`supabase/migrations/`

### Profiles

Suggested fields:

- User ID.
- Display name, if needed.
- Preferred display currency.
- Relevant synchronization preferences.
- Created timestamp.
- Updated timestamp.

Avoid collecting unnecessary personal information.

### Subscriptions

The remote subscription model must preserve the existing local subscription information, including:

- Unique subscription ID.
- User ID.
- Catalog reference.
- Custom subscription name.
- Website domain.
- Category.
- Brand color.
- Custom icon metadata.
- Original amount in integer minor units.
- ISO currency code.
- Billing cycle.
- Custom billing interval.
- Next renewal date.
- Subscription status.
- Reminder preferences.
- Notes.
- Creation timestamp.
- Update timestamp.
- Archive or deletion timestamp.
- Synchronization version.

Do not introduce floating-point monetary storage.

Do not modify the original subscription amount when the preferred display currency changes.

### Subscription Revisions

Preserve historical subscription information.

Support historical changes to:

- Subscription price.
- Original currency.
- Billing cycle.
- Pause periods.
- Resume events.
- Archived subscriptions.

Store revisions as immutable or explicitly versioned historical records.

Historical Analytics must remain accurate after synchronization.

Do not apply current subscription prices retroactively to older periods.

### Payment Records

Preserve or prepare the existing payment-history architecture where appropriate.

Potential fields include:

- Payment ID.
- Subscription ID.
- User ID.
- Subscription name snapshot.
- Amount in minor units.
- Original currency.
- Payment date.
- Payment status.
- Payment source.
- Creation timestamp.

Do not fabricate payment records from expected renewals.

Confirmed payment tracking is not part of this phase unless explicitly requested.

### Deletion Tombstones

Implement deletion tombstones or an equivalent durable change-tracking mechanism.

Deleted subscriptions must not reappear when an older offline device reconnects.

Track ownership, synchronization version and deletion timestamps.

### Database Integrity

Use appropriate:

- Primary keys.
- Foreign keys.
- Unique constraints.
- Ownership-consistent relationships.
- Validation constraints.
- Database indexes.

Prevent relationships between records belonging to different users.

Keep calendar dates separate from UTC event timestamps.

Do not upload the bundled subscription catalog or logo assets as user records.

Never upload sample subscriptions.

## 9. Row Level Security

Enable Row Level Security on every user-owned table.

Use Supabase authentication ownership through `auth.uid()`.

Implement appropriate policies for:

- SELECT.
- INSERT.
- UPDATE.
- DELETE.

Use both USING and WITH CHECK where appropriate.

Prevent users from:

- Reading another user's subscriptions.
- Editing another user's records.
- Deleting another user's records.
- Creating records under another user's identity.
- Changing record ownership.
- Referencing another user's subscription revisions or payment records.

Unauthenticated users must not have access to private cloud records.

Never treat Flutter UI filtering as a security boundary.

Create reproducible security tests using two distinct authenticated users and an anonymous client.

Mocked Flutter tests do not prove that PostgreSQL security policies work.

Document real Supabase RLS validation separately.

## 10. Synchronization Service

Create a dedicated synchronization layer using repository abstractions and Riverpod.

Inspect the current architecture before introducing new providers or services.

Keep synchronization logic separate from presentation widgets.

### Local Changes

When a user creates, edits, pauses, resumes or deletes a subscription:

1. Update local storage.
2. Update the UI immediately.
3. Record the pending synchronization operation.
4. Upload the operation when cloud synchronization is available.
5. Mark the operation complete only after successful server acknowledgement.

Persist pending operations in a durable outbox or equivalent crash-safe mechanism.

Local updates and pending-operation recording must be atomic or provide equivalent recovery guarantees.

Pending operations must survive application restarts.

### Uploading Changes

Support:

- Stable identifiers.
- Idempotent operations.
- Retry handling.
- Bounded retry backoff.
- Partial failure recovery.
- Process interruption recovery.
- Duplicate request prevention.

Never silently discard unsynchronized changes.

### Downloading Changes

Pull remote changes when appropriate, including:

- Successful sign-in.
- Application resume.
- Manual synchronization.
- Reconnection after offline usage.

Use a reliable server-side cursor, version or equivalent synchronization mechanism.

Handle pagination and records with equal timestamps.

Do not rely entirely on device clocks.

Prevent missed changes during concurrent remote writes.

Apply incoming updates transactionally where required.

Remote changes must not create duplicate outgoing synchronization operations.

Prevent multiple concurrent synchronization loops.

### Conflict Resolution

Implement an explicit and deterministic conflict-resolution strategy.

Use optimistic concurrency or server-side version checks.

Handle:

- A subscription edited on two devices.
- Conflicting price changes.
- Conflicting billing-cycle changes.
- Concurrent pause and resume operations.
- Deletion on one device while another device edits the same subscription.

Never silently overwrite conflicting financial information.

Preserve conflicting versions or provide a clear resolution choice where necessary.

Prevent deleted records from being resurrected by outdated devices.

Document the conflict strategy.

## 11. Guest-to-Account Migration

Existing local users must be able to create an account without losing their subscriptions.

Before uploading guest data:

- Explain what information will be uploaded.
- Request explicit user consent.
- Offer the option to remain local-only.

When the cloud account already contains subscriptions, provide an understandable import or merge decision.

Preserve:

- Subscription IDs.
- Subscription amounts.
- Original currencies.
- Billing cycles.
- Categories.
- Notes.
- Renewal dates.
- Pause periods.
- Historical revisions.
- Archived subscriptions.

Do not deduplicate subscriptions solely by service name.

Users may legitimately have multiple subscriptions to the same service.

Migration must be resumable and idempotent.

Do not delete guest data before synchronization has been verified and the user has made an informed choice.

Never upload demonstration subscriptions or sample-mode data.

## 12. Account Isolation

Scope local storage, cached records, pending operations and synchronization state to the correct guest or account identity.

When switching accounts:

- Never expose another account's subscription data.
- Never upload another account's pending operations.
- Reset account-specific providers appropriately.
- Preserve or securely isolate cached records.

Sign-out must not silently discard unsynchronized changes.

Provide synchronization, retry or explicit informed discard options where appropriate.

Keep private cached data inaccessible to other account sessions.

## 13. Privacy and Data Protection

Billfern handles sensitive personal financial information.

Apply privacy-conscious engineering throughout the backend.

Requirements:

- Minimize collected personal information.
- Never log private financial records.
- Never log credentials.
- Never expose administrative secrets.
- Use secure authentication storage.
- Enforce ownership at the database level.
- Explain local versus cloud storage.
- Obtain consent before uploading existing local data.

Update privacy-related onboarding and Settings copy.

Do not claim that all data remains exclusively on the device when cloud synchronization is enabled.

Do not transmit user financial records to external AI services during this phase.

## 14. Account Deletion and Data Export

Provide an account-data deletion and export design.

Implement a secure account deletion path before enabling account creation for general release.

Use a trusted server-side function for privileged Supabase authentication-user deletion.

Require authenticated ownership and explicit confirmation.

Never expose a service-role key in Flutter.

Account deletion must address:

- Cloud subscriptions.
- Historical revisions.
- Archived subscriptions.
- Payment-history records, where applicable.
- User preferences.
- Pending synchronization operations.
- Deletion tombstones.
- Local cached data.
- Authentication account.

Prevent stale offline devices from recreating deleted account records.

Clearly distinguish:

- Ordinary subscription deletion or archival.
- Permanent financial-history deletion.
- Complete account deletion.

Provide an explicitly confirmed local-data reset.

Prepare an export architecture for users to retrieve their own subscription information.

Document backup retention limitations.

Do not promise immediate deletion from backups unless that behavior has been verified.

If account deletion cannot be tested against a real Supabase project, identify it as a release blocker.

## 15. Multi-Currency and Analytics

Preserve the existing financial architecture.

All subscription amounts must retain their original currency.

Continue supporting:

- USD.
- EUR.
- NOK.
- GBP.
- SEK.
- DKK.
- CHF.
- CAD.
- AUD.
- Other supported ISO currencies.

Preserve integer minor-unit calculations.

Dashboard and Analytics must remain consistent before and after synchronization.

Preserve:

- Historical price revisions.
- Billing-cycle revisions.
- Pause and resume history.
- Archived subscription history.
- Upcoming renewal projections.
- Preferred display currency.
- Missing and stale exchange-rate handling.

Mock exchange rates must remain clearly labelled.

Real exchange-rate integration is outside this phase.

Do not represent projected or estimated spending as confirmed payments.

## 16. Sample Data Isolation

Preserve the existing sample-data mode.

Sample data must:

- Remain in memory.
- Never enter the user's real local database.
- Never enter the synchronization outbox.
- Never be uploaded to Supabase.
- Never appear in another account.

Ensure that authentication and cloud synchronization cannot accidentally migrate sample records.

## 17. UI and Design Requirements

Continue using Billfern's established design system.

### Colors

- Midnight: #202020
- Soft Yellow: #FFDA69
- Mint: #43C4AE
- Lavender: #E7E8F4
- Warm Cream: #F5EFEB
- White: #FFFFFF
- Secondary Text: #85858D

Typography: Manrope.

Use:

- Existing reusable components.
- Official Billfern branding.
- Soft pastel gradients.
- Rounded white cards.
- Consistent spacing.
- Accessible text contrast.
- Responsive layouts.
- Existing floating bottom navigation.

Create polished:

- Sign-in screen.
- Account creation screen.
- Email verification state.
- Account Settings section.
- Synchronization status components.
- Guest-data migration confirmation.
- Account deletion confirmation.

Preserve the existing Dashboard, Subscriptions and Analytics visual design.

Do not introduce unnecessary redesigns.

## 18. Testing and Acceptance Criteria

Add comprehensive tests covering the following.

### Authentication

- Guest mode without Supabase configuration.
- Account creation.
- Email authentication, including 8-digit codes with leading zeros and pasted codes.
- Session restoration.
- Sign-out.
- Expired sessions.
- Authentication failures.
- Account switching.

### Database Security

- User ownership.
- Row Level Security.
- Anonymous access rejection.
- Cross-account read rejection.
- Cross-account insert rejection.
- Cross-account update rejection.
- Cross-account delete rejection.
- Cross-owner relationship rejection.

### Synchronization

- Offline subscription creation.
- Offline editing.
- Pause and resume.
- Deletion synchronization.
- Retry behavior.
- Duplicate operation prevention.
- Partial failures.
- Application restart recovery.
- Concurrent changes.
- Conflict resolution.
- Deletion-versus-edit conflicts.
- Account isolation.

### Migration

- Guest-to-account migration.
- Existing cloud account merge.
- Stable subscription IDs.
- Historical revision preservation.
- Archived subscription preservation.
- Currency preservation.
- Repeated migration attempts.
- Sample-data exclusion.
- Non-destructive local database migrations.

### Financial Consistency

- Dashboard and Analytics agreement.
- Mixed-currency subscriptions.
- Historical spending preservation.
- Upcoming renewal projections.
- Missing exchange rates.
- Local and synchronized data consistency.

### Privacy and UI

- Account deletion.
- Local-data reset.
- Missing configuration.
- Offline states.
- Synchronization errors.
- Pending changes.
- Responsive layouts.
- Accessibility.

Use mocked clients for deterministic unit and widget tests.

Separately document real Supabase integration and RLS validation.

If credentials are unavailable, provide exact setup instructions and mark remote validation as pending.

Do not claim production readiness based only on mocked tests.

## 19. Development Resource Constraints

The development machine has:

- 8 GB RAM.
- Approximately 256 GB SSD storage.

Follow the resource constraints already documented in CLAUDE.md.

Requirements:

- Run Flutter commands sequentially.
- Shut down simulators before the full test suite.
- Limit Flutter test concurrency to two workers.
- Monitor memory consumption.
- Use a memory watchdog for long test runs where appropriate.
- Report terminated or runaway tests as failures.
- Aim for at least 15 GiB of available storage before iOS builds.
- Stop resource-intensive tasks below 5 GiB of free storage.
- Avoid repeated builds when implementation files have not changed.
- Never run multiple simulators simultaneously.
- Shut down the simulator after visual validation.
- Do not run a local Docker or Supabase stack concurrently with iOS builds.
- Never delete personal files, databases, projects or simulators without explicit approval.

Run:

- `flutter pub get`
- Dart formatting on modified files.
- `flutter analyze`
- `flutter test --concurrency=2`

Check storage before running:

`flutter build ios --simulator --debug`

Use only the existing Billfern Simulator for targeted visual review.

Report any validation checks that could not be completed.

## 20. Scope Restrictions

Do not implement the following during Phase 5:

- OpenAI integration.
- AI-powered financial recommendations.
- RevenueCat.
- Premium subscriptions.
- Paywalls.
- Banking integrations.
- Live exchange-rate APIs.
- Scheduled renewal notifications.
- App Store submission.
- Unrelated features.

Do not modify the launcher icon.

Do not replace the existing local-first architecture.

Do not introduce unnecessary dependencies.

Do not start later development phases.

## 21. Documentation

Update CLAUDE.md with:

- Supabase architecture.
- Authentication conventions.
- Database security requirements.
- Synchronization rules.
- Conflict-resolution strategy.
- Offline-first architecture.
- Guest-data migration.
- Account isolation.
- Privacy requirements.
- Testing conventions.

Update README.md with:

- Supabase setup instructions.
- Environment configuration.
- Database migrations.
- Local development instructions.
- Authentication behavior.
- Synchronization behavior.
- Known limitations.
- Validation instructions.

Keep SQL migrations versioned in `supabase/migrations/`.

Preserve all existing phase specifications.

Do not modify Phase 6, Phase 7 or Phase 8 specifications without approval.

## 22. Git and Attribution Rules

Remain on `feat/backend`.

Preserve the existing Git history.

Do not modify main directly.

Do not add Claude or Anthropic co-author trailers.

Do not add automatic AI attribution footers to commit messages or pull requests.

Preserve my configured Git author name and email.

Do not commit or push without my explicit approval.

## 23. Definition of Done

Phase 5 is complete when:

- Billfern remains functional without an account.
- Local subscription management works offline.
- Optional authentication works.
- Authentication sessions are securely managed.
- Cloud synchronization preserves existing subscription data.
- Pending offline operations survive restarts.
- Historical subscription information is preserved.
- Users cannot access another user's private records.
- Account switching does not leak cached data.
- Guest-data migration is safe and consent-based.
- Sample data never reaches Supabase.
- Synchronization errors and conflicts are handled explicitly.
- Account deletion is secure.
- Existing Dashboard and Analytics remain functional.
- Flutter analysis is clean.
- All applicable tests pass.
- Documentation is complete.
- Remaining release blockers are clearly identified.

## 24. Final Implementation Report

At completion, provide:

- Implementation summary.
- Architectural decisions.
- Database schema.
- SQL migrations.
- Row Level Security policies.
- Authentication implementation.
- Synchronization and conflict-resolution behavior.
- Guest-data migration behavior.
- Privacy and deletion handling.
- Files created and modified.
- Dependencies added.
- Flutter analysis results.
- Test results.
- Real Supabase integration results.
- iOS build and simulator review results.
- Known limitations.
- Release blockers.
- Configuration requiring my action.
- Final Git status.

Do not commit or push until I have reviewed and approved the implementation.

Begin by inspecting the existing repository, reading all relevant specifications and identifying the required Supabase configuration.
